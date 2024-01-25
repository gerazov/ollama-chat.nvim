# 󰧑 Ollama-chat.nvim

> Chat with Ollama models directly in a Neovim buffer!

## Features

This is a simple plugin that allows you to chat with Ollama models:
- no UI to get in the way - the chat works in a normal Neovim buffer, 
- chat history is completely modifiable - the whole conversation is sent to the model with each new prompt,
- start a chat in any open buffer,
- specify chats folder and continue previous chat, start new or open a quick chat,
- populate new chat buffer with selected text/code,
- return to other buffers while Ollama generates a response and get a notification when the generation is complete,
- stop the generation at any point using `q`,
- chat messages are bound with *User* and *Ollama*, both surrounded with an `*`, making it easy to yank, delete, and change them using `i*`.

![ollama chat](https://github.com/nomnivore/ollama.nvim/assets/15214418/8070342e-74d2-4086-afed-6835d954aeb2)

## Usage

This plugin adds the following commands that open an Ollama chat buffer:
- `OllamaQuickChat` - opens up a quick chat in the `chats_folder` with the `quick_chat_file` name, overwriting previous chats if the file exists,
- `OllamaCreateNewChat` - asks the user to input the chat name and creates new chat file in the `chats_folder`,
- `OllamaContinueChat` - opens up `Telescope` to let the user choose one of previous chats in `chats_folder`,
- alternatively open a new `md` buffer anywhere and use it as a chat buffer.

The chat buffer is populated with a base prompt and is completely modifiable. 

If there is a selection active when the chat buffer is opened, it is copied in the new chat buffer as text, or within a corresponding code block if the source file type is code.

The Ollama model can then be prompted with the chat buffer via `OllamaChat` and `OllamaChatCode`, both of which send the entire buffer to the Ollama server, the difference being that `OllamaChatCode` uses the model `model_code` rather than `model` set in the `opts` table.

During generation you can go back to your other buffers. Once Ollama generation completes an `INFO` level notification will be generated to alert the user to return to the chat.

Generation can also be canceled using `q`.

To yank, delete, and change chat messages use `i*` as they are bound with *User* and *Ollama*.

## Install

First you need [Ollama](https://ollama.ai/) installed as per their instructions.

To use the plugin with `lazy.nvim` you can add the file `lua/plugins/ollama-chat.lua`:

```lua
return {
  "gerazov/ollama-chat.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "stevearc/dressing.nvim",
    "stevearc/dressing.nvim",
    "nvim-telescope/telescope.nvim",
  },

  -- lazy load on command
  cmd = {
    "OllamaQuickChat",
    "OllamaCreateNewChat",
    "OllamaContinueChat",
    "OllamaChat",
    "OllamaChatCode",
    "OllamaModel",
    "OllamaServe",
    "OllamaServeStop"
  },

  keys = {
    {
      "<leader>ocq",
      "<cmd>OllamaQuickChat<cr>",
      desc = "Ollama Quick Chat",
      mode = { "n", "x" },
      silent = true,
    },
    {
      "<leader>ocn",
      "<cmd>OllamaCreateNewChat<cr>",
      desc = "Create Ollama Chat",
      mode = { "n", "x" },
      silent = true,
    },
    {
      "<leader>occ",
      "<cmd>OllamaContinueChat<cr>",
      desc = "Continue Ollama Chat",
      mode = { "n", "x" },
      silent = true,
    },
    {
      "<leader>och",
      "<cmd>OllamaChat<cr>",
      desc = "Chat",
      mode = { "n" },
      silent = true,
    },
    {
      "<leader>ocd",
      "<cmd>OllamaChatCode<cr>",
      desc = "Chat Code",
      mode = { "n" },
      silent = true,
    },
  },

  opts = {
    chats_folder = vim.fn.stdpath("data"), -- data folder is ~/.local/share/nvim
    -- you can also choose "current" and "tmp"
    quick_chat_file = "ollama-chat.md",
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
If you want to override your Markdown `@text.emphasis` highlight for the *User* and *Ollama* labels, you can add the following table to your `opts`:

```lua
  opts = {
    highlight = {
      guifg = "#8CAAEE",
      guibg = nil,  -- if you want transparent background
      gui = "bold,italic",
    },
  },
```

## Similar plugins

- [model.nvim](https://github.com/gsuuon/model.nvim)
- [ollama.nvim](https://github.com/nomnivore/ollama.nvim)
- [gen.nvim](https://github.com/David-Kunz/gen.nvim)
- [nvim-llama](https://github.com/jpmcb/nvim-llama)
