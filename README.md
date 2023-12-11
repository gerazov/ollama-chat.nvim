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
      ":<c-u>lua require('ollama').create_chat()<cr>",
      desc = "Create Ollama Chat",
      mode = { "n" },
      silent = true,
    },
    {
      "<leader>oct",
      ":<c-u>lua require('ollama').prompt('Chat')<cr>",
      desc = "Chat",
      mode = { "n" },
      silent = true,
    },
    {
      "<leader>ocd",
      ":<c-u>lua require('ollama').prompt('Chat Code')<cr>",
      desc = "Chat Code",
      mode = { "n" },
      silent = true,
    },
    {
      "<leader>oo",
      ":<c-u>lua require('ollama').prompt()<cr>",
      desc = "ollama prompt",
      mode = { "n", "v" },
    },
  },

  ---@type Ollama.Config
  opts = {
      model = "mistral",
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

Refer to the upstream [ollama.nvim](https://github.com/nomnivore/ollama.nvim) README for more information.
