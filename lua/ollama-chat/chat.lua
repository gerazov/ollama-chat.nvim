local opts = require("ollama-chat.config").opts
local M = {}

M.parse_prompt = function(prompt)
  local text = prompt.prompt

  if text:find("$buf") then
    local buf_text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    text = text:gsub("$buf", table.concat(buf_text, "\n"))
  end

  return text
end

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
--
--- create new chat buffer and window
function M.create_chat()
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
  local out_buf = vim.api.nvim_create_buf(true, false)  -- create a normal buffer
  local out_win = vim.api.nvim_get_current_win()

  vim.api.nvim_set_current_buf(out_buf)
  vim.api.nvim_buf_set_name(out_buf, "/tmp/ollama-chat.md")
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = out_buf })
  vim.api.nvim_set_option_value("conceallevel", 1, { buf = out_buf })
  vim.api.nvim_set_option_value("wrap", true, { win = out_win })
  vim.api.nvim_set_option_value("linebreak", true, { win = out_win })

  local pre_text = "You are an AI agent *Ollama* that is helping the *User* "
  .. "with his queries. The *User* enters their prompts after lines beginning "
  .. "with '*User*'.\n"
  .. "Your answers start at lines beginning with '*Ollama*'.\n"
  .. "You should output only responses and not the special sequences '*User*' "
  .. "and '*Ollama*'.\n"
  pre_text = pre_text .. sel_text_str .. "\n" .. "\n*User*\n"
  local pre_lines = vim.split(pre_text, "\n")

  vim.api.nvim_buf_set_lines(out_buf, 0, -1, false, pre_lines)
  vim.api.nvim_win_set_cursor(0, { #pre_lines, 0 })
  -- vim.api.nvim_buf_set_keymap(out_buf, "n", "q", "<cmd>bd!<cr>", { noremap = true })
  vim.keymap.set(
    "n", "q",
    function()
      M.cancel_all_jobs()
      vim.cmd [[ normal Go*User* ]]
      vim.cmd [[ normal Go ]]
    end,
    { buffer = out_buf, noremap = true, desc = "Stop generating" }
  )
  vim.keymap.set(
    "n", "<leader>q",
    function()
      M.cancel_all_jobs()
      vim.cmd [[ bd! ]]
    end,
    { buffer = out_buf, noremap = true, desc = "QuitOllama* chat" }
  )
  vim.cmd [[ normal G ]]
  vim.cmd [[w!]]  --overwrite file if exists TODO manage chats in an ollama folder
  -- vim.api.nvim_buf_attach(out_buf, false, {
  --   on_detach = M.cancel_all_jobs(),
  -- })
end

M.chat = {
  fn = function()
    local out_buf = vim.api.nvim_get_current_buf()
    vim.cmd [[ norm Go ]]
    local pre_lines = vim.api.nvim_buf_get_lines(out_buf, 0, -1, false)
    local tokens = {}
    -- show a rotating spinner while waiting for the response
    -- local timer = require("ollama-chat.util").show_spinner(
    --   out_buf,
    --   { start_ln = #pre_lines, end_ln = #pre_lines + 1 }
    -- ) -- the +1 makes sure the old spinner is replaced
    vim.api.nvim_buf_set_lines(out_buf, #pre_lines, #pre_lines + 1, false, { "*Ollama ...*" })
    -- empty line so that the response lands in the right place
    vim.api.nvim_buf_set_lines(out_buf, -1, -1, false, { "" })
    vim.cmd [[ norm G ]]
    vim.cmd [[ w ]]

    local job
    local is_cancelled = false
    vim.api.nvim_buf_attach(out_buf, false, {
      -- this doesn't work - on bd, the job is still running
      on_detach = function()
        if job ~= nil then
          is_cancelled = true
          job:shutdown()
        end
      end,
    })

    return function(body, _job)
      if job == nil and _job ~= nil then
      -- if job == nil then
        job = _job
        if is_cancelled then
          -- timer:stop()
          job:shutdown()
        end
      end
      table.insert(tokens, body.response)
      vim.api.nvim_buf_set_lines(
        out_buf, #pre_lines + 1, -1, false, vim.split(table.concat(tokens), "\n")
      )

      if body.done then
        -- timer:stop()
        vim.api.nvim_buf_set_lines(out_buf, #pre_lines, #pre_lines + 1, false, {
          ("*Ollama in %.2f s*"):format(
            require("ollama-chat.util").nano_to_seconds(body.total_duration)
          )
        })
        vim.api.nvim_buf_set_lines(
          out_buf, -1, -1, false, vim.split("\n\n*User*\n", "\n")
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
