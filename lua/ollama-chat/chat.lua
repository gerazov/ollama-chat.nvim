local util = require("ollama-chat.util")

local M = {}
M.prompts = nil
M.timer = nil
M.spinner_line = nil
M.bufnr = nil
M.winnr = nil
M.folder = nil
M.filename = nil

M.update_prompts = function()
  -- so that the user opts can override the default opts
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
end

M.parse_prompt = function(prompt)
  local text = prompt.prompt

  if text:find("$buf") then
    local buf_text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    text = text:gsub("$buf", table.concat(buf_text, "\n"))
  end

  return text
end

M.sel_text_str = ""
M.chat_type = nil

--- create new chat buffer and window
function M.create_chat(chat_type)
  local opts = require("ollama-chat.config").opts
  M.chat_type = chat_type or "quick"
  local filetype = vim.bo.filetype
  local cur_buf = vim.api.nvim_get_current_buf()
  -- if spawned from visual mode copy selection to chat buffer
  local mode = vim.api.nvim_get_mode().mode
  local visual_modes = { "v", "V", "" }
  if vim.tbl_contains(visual_modes, mode) then
    local sel_range = require("ollama-chat.util").get_selection_pos()

    local sel_text = vim.api.nvim_buf_get_text(
      cur_buf, sel_range[1], sel_range[2], sel_range[3], sel_range[4],
      {}
    )
    M.sel_text_str = table.concat(sel_text, "\n")
    -- if filetype is not text, markdown or latex then wratp in code block
    local noncode_filetypes = { "text", "markdown", "org", "mail", "latex" }
    if filetype == nil or not vim.tbl_contains(noncode_filetypes, filetype) then
      M.sel_text_str = "\n```" .. filetype .. "\n" .. M.sel_text_str .. "\n```\n"
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
    -- wait until the user selects a file to continue program execution
    -- require("telescope.builtin").find_files({
    --   prompt_title = "Choose a chat file",
    --   cwd = opts.chats_folder,
    --   hidden = false,
    --   search_file = "*.md",
    -- })
    M.find_files(opts, chat_type)
    -- TODO find a way to set all the options for the opened file
    return

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
  if chat_type == "new" or chat_type == "quick" then
    M.setup_chat_buffer()
  end
end

M.setup_chat_buffer = function()
  local opts = require("ollama-chat.config").opts
  M.bufnr = vim.api.nvim_get_current_buf()
  M.winnr = vim.api.nvim_get_current_win()
  vim.b.ollama_chat = true
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = M.bufnr })
  vim.api.nvim_set_option_value("conceallevel", 1, { buf = M.bufnr })
  vim.api.nvim_set_option_value("wrap", true, { win = M.winnr })
  vim.api.nvim_set_option_value("linebreak", true, { win = M.winnr })

  -- if chat type is quick or new populate the buffer
  local pre_text
  if M.chat_type == "new" or M.chat_type == "quick" then
    pre_text = "You are an AI agent *Ollama* that is helping the *User* "
    .. "with his queries. The *User* enters their prompts after lines beginning "
    .. "with '*User*'.\n"
    .. "Your answers start at lines beginning with '*Ollama*'.\n"
    .. "You should output only responses and not the special sequences '*User*' "
    .. "and '*Ollama*'.\n"
    .. "\n*User*\n"
  else
    -- existing text is pre_text
    pre_text = table.concat(vim.api.nvim_buf_get_lines(M.bufnr, 0, -1, false), "\n")
  end
  pre_text = pre_text .. M.sel_text_str .. "\n"
  local pre_lines = vim.split(pre_text, "\n")

  vim.api.nvim_buf_set_lines(M.bufnr, 0, -1, false, pre_lines)
  vim.api.nvim_win_set_cursor(0, { #pre_lines, 0 })
  -- vim.api.nvim_buf_set_keymap(M.bufnr, "n", "q", "<cmd>bd!<cr>", { noremap = true })
  vim.keymap.set(
    "n", "q",
    function()
      if util.jobs_length > 0 then
        util.cancel_all_jobs(M.timer, M.bufnr, M.spinner_line)
        vim.api.nvim_buf_set_lines(M.bufnr, -1, -1, false, { "", "*User*" })
        vim.cmd [[ normal Go ]]
      end
    end,
    { buffer = M.bufnr, noremap = true, desc = "Stop generating" }
  )
  vim.keymap.set(
    "n", "<leader>q",
    function()
      if util.jobs_length > 0 then
        util.cancel_all_jobs(M.timer, M.bufnr, M.spinner_line)
      end
      vim.cmd [[ bd! ]]
    end,
    { buffer = M.bufnr, noremap = true, desc = "Quit Ollama chat" }
  )
  -- set highlighting if option is not nil
  if opts.highlight ~= nil then
    local hl_opts = ""
    for k, v in pairs(opts.highlight) do
      if v ~= nil then
        hl_opts = hl_opts .. " " .. k .. "=" .. v
      end
    end
    if hl_opts ~= "" then
      -- vim.cmd [[ hi @text.emphasis ]]  -- clear existing highlight
      vim.cmd("hi @text.emphasis " .. hl_opts)
    end
  end

  vim.cmd [[ normal G ]]
  vim.cmd [[w!]]  --overwrite file if exists TODO manage chats in an ollama folder
  -- vim.api.nvim_buf_attach(M.bufnr, false, {
  --   on_detach = M.cancel_all_jobs(),
  -- })
end

M.chat = {
  fn = function()
    if vim.b.ollama_chat == nil or vim.b.ollama_chat == false then
      vim.api.nvim_notify(
        "Setting up buffer for Ollama chat.",
        vim.log.levels.INFO,
        { title = "Ollama" }
      )
      M.setup_chat_buffer()
    end
    M.bufnr = vim.api.nvim_get_current_buf()
    vim.cmd [[ norm Go ]]
    local pre_lines = vim.api.nvim_buf_get_lines(M.bufnr, 0, -1, false)
    local tokens = {}
    -- show a rotating spinner while waiting for the response
    M.spinner_line = #pre_lines
    local opts = require("ollama-chat.config").opts
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
    local is_canceled = false
    vim.api.nvim_buf_attach(M.bufnr, false, {
      -- this doesn't work - on bd, the job is still running
      on_detach = function()
        if job ~= nil then
          is_canceled = true
          if M.timer ~= nil then
            M.timer:stop()
          end
          job:shutdown()
        end
      end,
    })

    return function(body, _job)
      if job == nil and _job ~= nil then
      -- if job == nil then
        job = _job
        if is_canceled then
          if M.timer ~= nil then
            M.timer:stop()
          end
          job:shutdown()
        end
      end
      table.insert(tokens, body.response)
      vim.api.nvim_buf_set_lines(
        M.bufnr, #pre_lines + 1, -1, false, vim.split(table.concat(tokens), "\n")
      )

      if body.done then
        if M.timer ~= nil then
          M.timer:stop()
        end
        vim.api.nvim_buf_set_lines(M.bufnr, M.spinner_line, M.spinner_line + 1, false, {
          ("*Ollama in %.2f s*"):format(
            require("ollama-chat.util").nano_to_seconds(body.total_duration)
          )
        })
        vim.api.nvim_buf_set_lines(
          M.bufnr, -1, -1, false, vim.split("\n\n*User*\n", "\n")
        )
        vim.schedule_wrap(vim.api.nvim_notify)(
          "Ollama generation complete.",
          vim.log.levels.INFO,
          { title = "Ollama" }
        )
        -- vim.api.nvim_win_set_cursor(0, { -1, 0 }) -- simpler to use norm
        -- vim.cmd [[ norm G ]]
        -- vim.cmd [[ w ]]
      end
    end
  end,

  opts = {
    stream = true,
  },
}

-- spcify Telescope function to return the name of the file selected
M.find_files = function(opts, chat_type)
  local telescope_opts = {
    attach_mappings = function(_, map)
      map("i", "<CR>", function(prompt_bufnr)
        -- filename is available at entry[1]
        local chat_entry = require("telescope.actions.state").get_selected_entry()
        -- vim.print(M.chat_entry)
        require("telescope.actions").close(prompt_bufnr)
        local filename = chat_entry[1]
        local open_file_cmd =  "e " .. opts.chats_folder .. "/" .. filename
        vim.cmd(open_file_cmd)
        M.setup_chat_buffer(chat_type)
      end)

      return true
    end,
    prompt_title = "Choose a chat file",
    cwd = opts.chats_folder,
    hidden = false,
    search_file = "*.md",
  }

  require("telescope.builtin").find_files(telescope_opts)
end
return M
