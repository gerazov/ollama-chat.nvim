local M = {}

M.jobs = {}
M.jobs_length = 0

M.update_jobs_length = function()
  M.jobs_length = 0
  for _, _ in pairs(M.jobs) do
    M.jobs_length = M.jobs_length + 1
  end
end

M.add_job = function(job)
  vim.schedule_wrap(vim.api.nvim_notify)(
    "Creating Ollama job",
    vim.log.levels.INFO,
    { title = "Ollama" }
  )
  M.jobs[job.pid] = job
  M.update_jobs_length()
  vim.schedule_wrap(vim.api.nvim_notify)(
    M.jobs_length ..  " Ollama jobs in total",
    vim.log.levels.INFO,
    { title = "Ollama" }
  )
end

M.del_job = function(job)
  vim.schedule_wrap(vim.api.nvim_notify)(
    "Deleting Ollama job",
    vim.log.levels.INFO,
    { title = "Ollama" }
  )
  M.jobs[job.pid] = nil
  M.update_jobs_length()
  vim.schedule_wrap(vim.api.nvim_notify)(
    M.jobs_length ..  " Ollama jobs in total",
    vim.log.levels.INFO,
    { title = "Ollama" }
  )
end

function M.cancel_all_jobs(timer, bufnr, spinner_line)
  vim.schedule_wrap(vim.api.nvim_notify)(
    "Shutting down Ollama jobs",
    vim.log.levels.INFO,
    { title = "Ollama" }
  )
  vim.schedule_wrap(vim.api.nvim_notify)(
    M.jobs_length ..  " Ollama jobs in total",
    vim.log.levels.INFO,
    { title = "Ollama" }
  )
  if M.jobs_length == 0 then
    return
  end
  for _, job in pairs(M.jobs) do
    vim.schedule_wrap(vim.api.nvim_notify)(
      "Shutting down Ollama job " .. job.pid,
      vim.log.levels.INFO,
      { title = "Ollama" }
    )
    timer:stop()
    job:shutdown()
    vim.schedule_wrap(vim.api.nvim_notify)(
      M.jobs_length ..  " Ollama jobs remaining",
      vim.log.levels.INFO,
      { title = "Ollama" }
    )end
  vim.api.nvim_buf_set_lines(bufnr, spinner_line, spinner_line + 1, false, { "*Ollama cancelled*" })
end

function M.status()
  if M.jobs_length > 0 then
    return "WORKING"
  end
  return "IDLE"
end

function M.handle_stream(cb)
  return function(_, chunk, job)
    vim.schedule(function()
      local _, body = pcall(function()
        return vim.json.decode(chunk)
      end)
      if type(body) ~= "table" or body.response == nil then
        if body.error ~= nil then
          vim.api.nvim_notify(
            "Error: " .. body.error,
            vim.log.levels.ERROR,
            { title = "Ollama" }
          )
        end
        return
      end
      cb(body, job)
    end)
  end
end

-- Show a spinner in the given buffer (overwrites existing lines)
function M.show_spinner(bufnr, opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", {
    start_ln = 0,
    end_ln = -1,
    format = "> Generating... %s",
  }, opts)
  local spinner_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local curr_char = 1
  local spinner_lines = {}
  local timer = vim.loop.new_timer()
  timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      spinner_lines = vim.split(opts.format:format(spinner_chars[curr_char]), "\n")
      vim.api.nvim_buf_set_lines(bufnr, opts.start_ln, opts.end_ln, false, spinner_lines)
      curr_char = curr_char % #spinner_chars + 1
    end)
  )

  return timer
end

-- Get the current selection range, if any, adjusting for 0-based indexing.
-- Useful for replacing text in a buffer based on a selection range.
function M.get_selection_pos()
  local mode = vim.api.nvim_get_mode().mode
  local sel_start, sel_end
  if mode == "n" then
    print("using < and >")
    mode = vim.fn.visualmode()  -- get the last visual mode
    print(mode)
    sel_start = vim.fn.getpos("'<")
    sel_end = vim.fn.getpos("'>")
  else  -- visual mode
    sel_start = vim.fn.getpos("v")
    sel_end = vim.fn.getpos(".")
  end

  if
    sel_start == nil
    or sel_end == nil
    or sel_start[2] == 0
    or sel_start[3] == 0
    or sel_end[2] == 0
    or sel_end[3] == 0
  then
    -- no selection range found
    return nil
  end

  local start_line, start_col, end_line, end_col

  -- assign positions based on visual or visual-line mode
  if mode == "v" then
    start_line = sel_start[2]
    start_col = sel_start[3]
    end_line = sel_end[2]
    end_col = sel_end[3]
  elseif mode == "V" then
    start_line = sel_start[2]
    start_col = 1
    end_line = sel_end[2]
    end_col = #vim.fn.getline(sel_end[2])
  end

  -- validate and adjust positions
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  -- adjust for 0-based indexing
  start_line = start_line - 1
  start_col = start_col - 1
  end_line = end_line - 1
  end_col = end_col -- end_col is exclusive

  return { start_line, start_col, end_line, end_col }
end

--- Convert a nanosecond value to seconds.
function M.nano_to_seconds(nano)
  return nano / 1000000000
end

return M
