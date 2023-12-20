# ollama-chat.nvim

This is a fork of [ollama.nvim](https://github.com/nomnivore/ollama.nvim) with added chat functionality.

The chat functionality is pretty bare-bones, and is meant to serve it's purpose temporarily, until chat gets implemented within `ollama.nvim`.  

![ollama chat](https://github.com/nomnivore/ollama.nvim/assets/15214418/8070342e-74d2-4086-afed-6835d954aeb2)

## Usage

This plugin adds the `create_chat()` function that opens a new chat buffer. The buffer is populated with a base prompt and is modifiable. 
The Ollama model can then be prompted with the chat buffer via two new prompts `Chat` and `Chat Code`, both of which send the entire buffer to the Ollama server, the difference being that `Chat Code` uses the model `model_code` set in the `opts` table.

To use the plugin with `lazy.nvim` you can add the file `lua/plugins/ollama-chat.lua`:

```lua
return {
  "gerazov/ollama-chat.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "stevearc/dressing.nvim",
  },

  -- All the user commands added by the plugin
  cmd = { "Ollama", "OllamaModel", "OllamaServe", "OllamaServeStop" },

  keys = {
    {
      "<leader>occ",
      function() require('ollama-chat').create_chat() end,
      desc = "Create Ollama Chat",
      mode = { "n", "x" },
      silent = true,
    },
    {
      "<leader>och",
      function() require('ollama-chat').prompt('Chat') end,
      desc = "Chat",
      mode = { "n" },
      silent = true,
    },
    {
      "<leader>ocd",
      function() require('ollama-chat').prompt('Chat_code') end,
      desc = "Chat Code",
      mode = { "n" },
      silent = true,
    },
    {
      "<leader>opp",
      ":<c-u>lua require('ollama-chat').prompt()<cr>",
      desc = "ollama prompt",
      mode = { "n", "x" },
      silent = true,
    },
  },

  opts = {
      model = "openhermes2-mistral",
      model_code = "codellama",
      url = "http://127.0.0.1:11434",
      serve = {
        on_start = false,
        command = "ollama",
        args = { "serve" },
        stop_command = "pkill",
        stop_args = { "-SIGTERM", "ollama" },
      },
    }
```
\* Note that to have selections to work when picking a prompt with prompt picker, i.e. when calling `prompt()` without arguments you have to map it using `:<c-u>` so that the mode changes from visual to normal and the `'<` and `'>` marks get created. On the other hand, creating the chat needs to be called from visual mode so that the selection is copied in the chat buffer.

Refer to the upstream [ollama.nvim](https://github.com/nomnivore/ollama.nvim) README for more information.
