local util = require("ollama-chat.util")

local M = {}
M.prompts = nil
M.timer = nil
M.spinner_line = nil
M.bufnr = nil
M.winnr = nil
M.folder = nil
M.filename = nil

M.parse_prompt = function(prompt)
  local text = prompt.prompt

  if text:find("$buf") then
    local buf_text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    text = text:gsub("$buf", table.concat(buf_text, "\n"))
  end

  return text
end

--- create new chat buffer and window
function M.create_chat(chat_type)
  chat_type = chat_type or "quick"
  local opts = require("ollama-chat.config").opts
  M.prompts = {
    Chat = {
      prompt = "$buf\n",
      action = "chat",
      model = opts.model,
    },

    Chat_code = {
      prompt = "$buf\n",
      action = "chat",
      model = opts.model_code,
    },
  }
  local filetype = vim.bo.filetype
  local cur_buf = vim.api.nvim_get_current_buf()
  -- if spawned from visual mode copy selection to chat buffer
  local mode = vim.api.nvim_get_mode().mode
  local visual_modes = { "v", "V", "" }
  local sel_text_str = ""
  if vim.tbl_contains(visual_modes, mode) then
    local sel_range = require("ollama-chat.util").get_selection_pos()

    local sel_text = vim.api.nvim_buf_get_text(
      cur_buf, sel_range[1], sel_range[2], sel_range[3], sel_range[4],
      {}
    )
    sel_text_str = table.concat(sel_text, "\n")
    -- if filetype is not text, markdown or latex then wratp in code block
    local noncode_filetypes = { "text", "markdown", "org", "mail", "latex" }
    if filetype == nil or not vim.tbl_contains(noncode_filetypes, filetype) then
      sel_text_str = "\n```" .. filetype .. "\n" .. sel_text_str .. "\n```\n"
    end
  end
  M.winnr = vim.api.nvim_get_current_win()

  -- set folder based on opt
  if opts.chats_folder == "current" then
    M.folder = vim.fn.expand("%:p:h")
  elseif opts.chats_folder == "tmp" then
    M.folder = vim.fn.expand("/tmp")
  else
    M.folder = opts.chats_folder
  end
  -- start a new chat or continue an existing one
  if chat_type == "quick" then
    M.filename = opts.quick_chat_file
    M.bufnr = vim.api.nvim_create_buf(true, false)  -- create a normal buffer
    vim.api.nvim_buf_set_name(M.bufnr, M.folder .. "/" .. M.filename)
    vim.api.nvim_set_current_buf(M.bufnr)

  elseif chat_type == "continue" then
    -- open vim telescope to choose a chat file from the chats folder
    local chat_file = require("telescope.builtin").find_files({
      prompt_title = "Choose a chat file",
      cwd = opts.chats_folder,
      hidden = false,
      search_file = "*.md",
    })
    if chat_file == nil then
      return
    end
    M.filename = vim.fn.fnamemodify(chat_file[1], ":t")
    -- open the chat file in current window
    vim.cmd "e .. chat_file[1]"
    M.bufnr = vim.api.nvim_get_current_buf()

  elseif chat_type == "new" then
    -- open user prompt to enter a new chat file name
    local chat_file = vim.fn.input("Enter a Chat Name: ")
    if chat_file == nil or chat_file == "" then
      return
    end
    M.filename = chat_file .. ".md"
    M.bufnr = vim.api.nvim_create_buf(true, false)  -- create a normal buffer
    vim.api.nvim_buf_set_name(M.bufnr, M.folder .. "/" .. M.filename)
    vim.api.nvim_set_current_buf(M.bufnr)
  end

  vim.api.nvim_set_option_value("filetype", "markdown", { buf = M.bufnr })
  vim.api.nvim_set_option_value("conceallevel", 1, { buf = M.bufnr })
  vim.api.nvim_set_option_value("wrap", true, { win = M.winnr })
  vim.api.nvim_set_option_value("linebreak", true, { win = M.winnr })

  local pre_text = "You are an AI agent *Ollama* that is helping the *User* "
  .. "with his queries. The *User* enters their prompts after lines beginning "
  .. "with '*User*'.\n"
  .. "Your answers start at lines beginning with '*Ollama*'.\n"
  .. "You should output only responses and not the special sequences '*User*' "
  .. "and '*Ollama*'.\n"
  pre_text = pre_text .. sel_text_str .. "\n" .. "\n*User*\n"
  local pre_lines = vim.split(pre_text, "\n")

  vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, pre_lines)
  vim.api.nvim_win_set_cursor(0, { #pre_lines, 0 })
  -- vim.api.nvim_buf_set_keymap(M.bufnr, "n", "q", "<cmd>bd!<cr>", { noremap = true })
  vim.keymap.set(
    "n", "q",
    function()
      util.cancel_all_jobs(M.timer, M.bufnr, M.spinner_line)
      vim.api.nvim_buf_set_lines(M.bufnr, -1, -1, false, { "", "*User*" })
      vim.cmd [[ normal Go ]]
    end,
    { buffer = M.bufnr, noremap = true, desc = "Stop generating" }
  )
  vim.keymap.set(
    "n", "<leader>q",
    function()
      util.cancel_all_jobs(M.timer, M.bufnr, M.spinner_line)
      vim.cmd [[ bd! ]]
    end,
    { buffer = M.bufnr, noremap = true, desc = "Quit Ollama chat" }
  )
  vim.cmd [[ normal G ]]
  vim.cmd [[w!]]  --overwrite file if exists TODO manage chats in an ollama folder
  -- vim.api.nvim_buf_attach(M.bufnr, false, {
  --   on_detach = M.cancel_all_jobs(),
  -- })
end

M.chat = {
  fn = function()
    M.bufnr = vim.api.nvim_get_current_buf()
    vim.cmd [[ norm Go ]]
    local pre_lines = vim.api.nvim_buf_get_lines(M.bufnr, 0, -1, false)
    local tokens = {}
    -- show a rotating spinner while waiting for the response
    M.spinner_line = #pre_lines
    M.timer = util.show_spinner(
      M.bufnr,
      { start_ln = #pre_lines, end_ln = #pre_lines + 1 }
    ) -- the +1 makes sure the old spinner is replaced
    vim.api.nvim_buf_set_lines(M.bufnr, #pre_lines, #pre_lines + 1, false, { "*Ollama ...*" })
    -- empty line so that the response lands in the right place
    vim.api.nvim_buf_set_lines(M.bufnr, -1, -1, false, { "" })
    vim.cmd [[ norm Gzz ]]
    vim.cmd [[ w ]]

    local job
    local is_cancelled = false
    vim.api.nvim_buf_attach(M.bufnr, false, {
      -- this doesn't work - on bd, the job is still running
      on_detach = function()
        if job ~= nil then
          is_cancelled = true
          M.timer:stop()
          job:shutdown()
        end
      end,
    })

    return function(body, _job)
      if job == nil and _job ~= nil then
      -- if job == nil then
        job = _job
        if is_cancelled then
          M.timer:stop()
          job:shutdown()
        end
      end
      table.insert(tokens, body.response)
      vim.api.nvim_buf_set_lines(
        M.bufnr, #pre_lines + 1, -1, false, vim.split(table.concat(tokens), "\n")
      )

      if body.done then
        M.timer:stop()
        vim.api.nvim_buf_set_lines(M.bufnr, #pre_lines, #pre_lines + 1, false, {
          ("*Ollama in %.2f s*"):format(
            require("ollama-chat.util").nano_to_seconds(body.total_duration)
          )
        })
        vim.api.nvim_buf_set_lines(
          M.bufnr, -1, -1, false, vim.split("\n\n*User*\n", "\n")
        )
        -- vim.api.nvim_win_set_cursor(0, { -1, 0 }) -- simpler to use norm
        vim.cmd [[ norm G ]]
        vim.cmd [[ w ]]
      end
    end
  end,

  opts = {
    stream = true,
  },
}

return M
