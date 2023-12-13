---@type table<string, Ollama.PromptAction>
local actions = {}

local factory = require("ollama.actions.factory")

actions.display = factory.create_action({ display = true, show_prompt = true })

actions.insert = factory.create_action({ display = false, insert = true })

actions.replace = factory.create_action({ display = false, replace = true })

-- basically a merge of display -> replace actions
-- lots of duplicated code
actions.display_replace = factory.create_action({
	replace = true,
	show_prompt = true,
})

actions.display_insert = factory.create_action({ insert = true, show_prompt = true })

-- TODO: remove this as its not used anymore
-- if you use this in your config, please switch to "display" instead
actions.display_prompt = actions.display

actions.chat = {
	fn = function()
    local out_buf = vim.api.nvim_get_current_buf()
		local pre_lines = vim.api.nvim_buf_get_lines(out_buf, 0, -1, false)
    local tokens = {}
		-- show a rotating spinner while waiting for the response
		local timer = require("ollama.util").show_spinner(
		  out_buf,
		  { start_ln = #pre_lines, end_ln = #pre_lines + 1 }
		) -- the +1 makes sure the old spinner is replaced
		-- empty line so that the response lands in the right place
		vim.api.nvim_buf_set_lines(out_buf, -1, -1, false, { "" })

		---@type Job?
		local job
		local is_cancelled = false
		vim.api.nvim_buf_attach(out_buf, false, {
			on_detach = function()
				if job ~= nil then
					is_cancelled = true
					job:shutdown()
				end
			end,
		})

		---@type Ollama.PromptActionResponseCallback
		return function(body, _job)
			if job == nil and _job ~= nil then
				job = _job
				if is_cancelled then
					timer:stop()
					job:shutdown()
				end
			end
			table.insert(tokens, body.response)
			vim.api.nvim_buf_set_lines(
			  out_buf, #pre_lines + 1, -1, false, vim.split(table.concat(tokens), "\n")
			)

			if body.done then
				timer:stop()
				vim.api.nvim_buf_set_lines(out_buf, #pre_lines, #pre_lines + 1, false, {
					("> Ollama in %ss."):format(
            require("ollama.util").nano_to_seconds(body.total_duration)
          )
        })
			vim.api.nvim_buf_set_lines(
			  out_buf, -1, -1, false, vim.split("\n\n> User\n", "\n")
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

return actions
