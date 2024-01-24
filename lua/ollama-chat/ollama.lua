local chat = require("ollama-chat.chat")
local util = require("ollama-chat.util")

local M = {}

function M.run_serve(opts)
  local ollama_chat_opts = require("ollama-chat.config").opts
  opts = opts or {}
  local serve_job = require("plenary.job"):new({
    command = ollama_chat_opts.serve.command,
    args = ollama_chat_opts.serve.args,
    on_exit = function(_, code)
      if opts.silent then
        return
      end
      -- 1 = `ollama serve` already running
      -- 125 = docker name conflict (already running)
      -- `docker start` returns 0 if already running, not sure how to catch that case
      if code == 1 or code == 125 then
        vim.schedule_wrap(vim.api.nvim_notify)(
          "Serve command exited with code 1. Is it already running?",
          vim.log.levels.WARN,
          { title = "Ollama" }
        )
      elseif code == 127 then
        vim.schedule_wrap(vim.api.nvim_notify)(
          "Serve command not found. Is it installed?",
          vim.log.levels.ERROR,
          { title = "Ollama" }
        )
      end
    end,
  })
  serve_job:start()
  -- TODO: can we check if the server started successfully from this job?
end

function M.stop_serve(opts)
  local ollama_chat_opts = require("ollama-chat.config").opts
  opts = opts or {}
  require("plenary.job")
    :new({
      command = ollama_chat_opts.serve.stop_command,
      args = ollama_chat_opts.serve.stop_args,
      on_exit = function(_, code)
        if code == 1 and not opts.silent then
          vim.schedule_wrap(vim.api.nvim_notify)(
            "Server is already stopped",
            vim.log.levels.WARN,
            { title = "Ollama" }
          )
        elseif code == 127 and not opts.silent then
          vim.schedule_wrap(vim.api.nvim_notify)(
            "Stop command not found. Is it installed?",
            vim.log.levels.ERROR,
            { title = "Ollama" }
          )
        else
          vim.schedule_wrap(vim.api.nvim_notify)(
            "Ollama server stopped",
            vim.log.levels.INFO,
            { title = "Ollama" }
          )
        end
      end,
    })
    :start()
end

local function query_models()
  local ollama_chat_opts = require("ollama-chat.config").opts
  local res = require("plenary.curl").get(ollama_chat_opts.url .. "/api/tags")

  local _, body = pcall(function()
    return vim.json.decode(res.body)
  end)

  if body == nil then
    return {}
  end

  local models = {}
  for _, model in pairs(body.models) do
    table.insert(models, model.name)
  end

  return models
end

function M.choose_model()
  local ollama_chat_opts = require("ollama-chat.config").opts
  local models = query_models()

  if #models < 1 then
    vim.api.nvim_notify(
      "No models found. Is the ollama server running?",
      vim.log.levels.ERROR,
      { title = "Ollama" }
    )
    return
  end

  vim.ui.select(models, {
    prompt = "Select a model:",
    format_item = function(item)
      if item == ollama_chat_opts.model then
        return item .. " (current)"
      end
      return item
    end,
  }, function(selected)
      if not selected then
        return
      end

      ollama_chat_opts.model = selected
      vim.api.nvim_notify(("Selected model '%s'"):format(selected), vim.log.levels.INFO, { title = "Ollama" })
    end)
end

function M.prompt(name)
  local ollama_chat_opts = require("ollama-chat.config").opts
  local prompt = chat.prompts[name]
  if prompt == nil or prompt == false then
    vim.api.nvim_notify(("Prompt '%s' not found"):format(name), vim.log.levels.ERROR, { title = "Ollama" })
    return
  end

  local model = prompt.model or ollama_chat_opts.model
  -- resolve the action fn based on priority:
  -- 1. prompt.action (if it exists)
  -- 2. config.action (if it exists)
  -- 3. default action (display)

  -- builtin actions map to the actions.lua module

  local action = chat.chat

  local parsed_prompt = chat.parse_prompt(prompt)

  -- this can probably be improved
  local fn = action[1] or action.fn
  local opts = action[2] or action.opts

  local cb = fn({
    model = model,
    prompt = prompt.prompt,
    input_label = prompt.input_label,
    action = action,
    parsed_prompt = parsed_prompt,
  })

  if not cb then
    return
  end

  local stream = opts and opts.stream or false
  local stream_called = false
  local job = require("plenary.curl").post(ollama_chat_opts.url .. "/api/generate", {
    body = vim.json.encode({
      model = model,
      prompt = parsed_prompt,
      stream = stream,
      system = prompt.system,
      format = prompt.format,
      options = prompt.options,
    }),
    stream = function(_, chunk, job)
      if stream then
        stream_called = true
        require("ollama-chat.util").handle_stream(cb)(_, chunk, job)
      end
    end,
  })
  job:add_on_exit_callback(function(j)
    if ollama_chat_opts.debug then
      vim.schedule_wrap(vim.api.nvim_notify)(
        job.pid ..  " Ollama job exited",
        vim.log.levels.INFO,
        { title = "Ollama" }
      )
    end
    if stream_called then
      return
    end

    if j.code ~= 0 then
      vim.schedule_wrap(vim.api.nvim_notify)(
        ("Connection error (Code %s)"):format(tostring(j.code)),
        vim.log.levels.ERROR,
        { title = "Ollama" }
      )
      return
    end

    -- not the prettiest, but reuses the stream handler to process the response
    -- since it comes in the same format.
    require("ollama-chat.util").handle_stream(cb)(nil, j:result()[1])

    -- if res.body is like { error = "..." } then it should
    -- be handled in the handle_stream method
  end)
  job:add_on_exit_callback(util.del_job)
  util.add_job(job)
end

return M
