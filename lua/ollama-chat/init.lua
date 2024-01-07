local config = require("ollama-chat.config")
local ollama = require("ollama-chat.ollama")
local chat = require("ollama-chat.chat")

local M = {}

function M.setup(opts)
  config.update_opts(opts)

  vim.api.nvim_create_user_command(
    "OllamaCreateChat",  -- TODO finish this
    function()
      print("creating chat")
      chat.create_chat()
    end,
    {
      desc = "Create Ollama Chat buffer",
    }
  )

  vim.api.nvim_create_user_command(
    "OllamaChat",  -- TODO finish this
    function() chat.prompt("Chat") end,
    {
      desc = "Send chat to Ollama server",
    }
  )

  vim.api.nvim_create_user_command(
    "OllamaChatCode",  -- TODO finish this
    function() chat.prompt("Chat_code") end,
    {
      desc = "Send chat to Ollama server",
    }
  )

  vim.api.nvim_create_user_command(
    "OllamaModel",
    function() ollama.choose_model() end,
    {
      desc = "List and select from available ollama models",
    }
  )

  vim.api.nvim_create_user_command(
    "OllamaServe",
    function() ollama.run_serve() end,
    {
      desc = "Start the ollama server"
    }
  )

  vim.api.nvim_create_user_command(
    "OllamaStop",
    function()ollama.stop_serve()end,
    {
      desc = "Stop the ollama server"
    }
  )

  if config.opts.serve.on_start then
    M.run_serve()
  end

end

return M
