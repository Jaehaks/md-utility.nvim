local M = {}

-- default configuration
---@type md-utility.config
local default_config = {
	file_picker = {
		ignore = {
			'.git/',
			'node_modules/',
			'.obsidian/',
			'.marksman.toml',
		}
	},
	paste = {
		image_path = function (ctx)
			return ctx.cur_dir
		end,
	},
	autolist = {
		patterns = {
			bullet = "[-+*>]",
			digit = "%d+[.)]", -- 1. 1)
		},
		-- if user enter <CR> in list with empty content, remove the list and go to next line
		autoremove_cr = true,
		-- if user enter <TAB>, it guesses marker shape depends on adjacent usage.
		autoguess_tab = true,
	}
}

local config = vim.deepcopy(default_config)

-- get configuration
M.get = function ()
	return config
end

-- set configuration
M.set = function (opts)
	config = vim.tbl_deep_extend('force', default_config, opts or {})
end


return M
