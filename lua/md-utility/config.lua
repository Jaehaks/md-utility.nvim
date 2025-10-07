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
		},
		-- Insert title when link is inserted.
		-- When you insert external file link(not *.md file) using 'wiki', title will be removed although 'autotitle' is nil.
		-- nil : empty title
		-- filename : set filename as title only.
		-- full : set filename with relative path as title.
		autotitle = 'filename',
	},
	paste = {
		image_path = function (ctx)
			return ctx.cur_dir
		end,
	},
	autolist = {
		patterns = {
			bullet   = "[%-%+%*>]",      -- -, +, *, >
			digit    = "%d+[.)]",        -- 1. 1)
			checkbox = "-%s%[[x%-%s]%]", -- [x], [-], [ ]
		},
		autoremove_cr = true, -- if user enter <CR> in list with empty content, remove the list and go to next line
		autoguess_tab = true, -- if user enter <TAB>, it guesses marker shape depends on adjacent usage.
	},
	follow_link = {
		image_opener = 'start ""', -- image viewer command when the link under cursor is image.
		web_opener   = 'brave',    -- web browser command when the link under cursor is web link.
		md_opener    = 'split',    -- vim command when the link under cursor is file or header link.
		file_opener  = 'start ""', -- system command when the link under cursor is other file which is not image or md file
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
