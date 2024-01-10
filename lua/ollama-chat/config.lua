local M = {}

M.default_opts = {
  model = "openhermes2-mistral",
  model_code = "codellama",
  url = "http://127.0.0.1:11434",
  prompts = {},  -- generated in setup
  serve = {
    on_start = false,
    command = "ollama",
    args = { "serve" },
    stop_command = "pkill",
    stop_args = { "-SIGTERM", "ollama" },
  },
}

M.opts = {}

function M.update_opts(opts)
  M.opts = vim.tbl_deep_extend("force", M.default_opts, opts or {})
end


return M
