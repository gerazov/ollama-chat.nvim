local config = require("ollama-chat.config")
local ollama = require("ollama-chat.ollama")
local chat = require("ollama-chat.chat")

local M = {}

function M.setup(opts)
  config.update_opts(opts)

  vim.api.nvim_create_user_command(
    "OllamaCreateNewChat",
    function()
      print("creating new chat")
      chat.create_chat("new")
    end,
    {
      desc = "Create Ollama Chat",
    }
  )

  vim.api.nvim_create_user_command(
    "OllamaQuickChat",
    function()
      print("creating quick chat")
      chat.create_chat("quick")
    end,
    {
      desc = "Ollama Quick Chat",
    }
  )

  vim.api.nvim_create_user_command(
    "OllamaContinueChat",
    function()
      print("continuing chat")
      chat.create_chat("continue")
    end,
    {
      desc = "Continue Ollama Chat",
    }
  )

  vim.api.nvim_create_user_command(
    "OllamaChat",  -- TODO finish this
    function() ollama.prompt("Chat") end,
    {
      desc = "Send chat to Ollama server",
    }
  )

  vim.api.nvim_create_user_command(
    "OllamaChatCode",  -- TODO finish this
    function() ollama.prompt("Chat_code") end,
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
