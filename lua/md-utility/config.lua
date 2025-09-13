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
