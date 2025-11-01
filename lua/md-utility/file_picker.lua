local M = {}

local config = require('md-utility.config').get().file_picker
local Utils = require('md-utility.utils')

---@class state
---@field visual_range number[] start_row, start_col, end_row, end_col
local state = {
	visual_range = {}
}

---@param mode string 'filelist(get all file list only)'|'headerlist(get header list)'
---@param path string absolute path to find files
---@return string[] cmd table
local function get_cmd_rg(mode, path)
	local cmd = {
	    'rg',
		'--no-heading', -- with inline filename, not grouped
		'--hidden', -- add hidden files
		'--line-number',
	}

	-- show only file names
	if mode == 'filelist' then
		table.insert(cmd, '--files')
	end

	-- -- add ignore patterns
	for _, pattern in ipairs(config.ignore) do
		table.insert(cmd, '--glob=!' .. pattern .. '')
	end

	-- if match mode
	if mode == 'headerlist' then
		table.insert(cmd, '^#+\\s') -- check only header
	end

	table.insert(cmd, path)

	return cmd
end


-- execute cmd and get stdout
---@param cmd string[] external command with splitting arguments
local function get_output(cmd)
	-- job options
	local cwd = vim.fn.expand('%:p:h')
	local cb_stderr = function (_, data)
		if not data then
			return
		end
		for _, line in ipairs(data) do
			if line ~= '' then
				vim.print(line)
			end
		end
	end

	-- executes job
	local job = vim.system(cmd, {
		cwd = cwd,
		stderr = cb_stderr,
		text = true,
	})
	local result = job:wait()
	return result.stdout
end


---@param style string markdown|wiki
---@return file_picker.picker_item
local function get_link_data(style)
	-- get root
	local root_dir = Utils.get_rootdir(0)
	root_dir = Utils.sep_unify(root_dir, nil, nil, true)
	local curdir = Utils.sep_unify(vim.fn.expand('%:p:h'), nil, nil, true)
	local curfile = vim.fn.expand('%:t')

	-- get data
	local cmd
	cmd = get_cmd_rg('filelist', root_dir)
	local filelist = vim.split(get_output(cmd), '\n')

	cmd = get_cmd_rg('headerlist', root_dir)
	local headerlist = vim.split(get_output(cmd), '\n')


	---@param abspath string absolute file path
	---@param str string? raw text of anchor
	---@return string? markdown line format
	---@return string? raw data of link
	local function get_linkformat(abspath, str)
		style = style or 'markdown'
		-- encoding for link format
		local path = Utils.get_relative_path(abspath, curdir, root_dir)
		local path_enc = (style == 'markdown') and path:gsub('[%s]', '%%20') or path -- white space must be encoded by %20 in markdown format
		local str_enc = str and
					   str:gsub('^#+%s*', '#')              -- replace multiple # to one # as anchor mark.
					      :gsub('[^#%w%d%s-_\128-\255]', '') or '' -- remove all special characters, remain english/digit/cjk
		if str_enc then
			if style == 'markdown' then
				str_enc = str_enc:gsub('[%s-]+', '-') or '' -- replace all multiple spaces/'-' to unique '-'
			elseif style == 'wiki' then -- wikilink can use white space in link
				str_enc = str_enc:gsub('[-]+', '-') or ''   -- replace all multiple '-' to unique '-'
			end
		end


		-- make link format
		local raw = not str and path or path .. ' (' .. str .. ')'

		-- get title for link format
		local title = nil
		if config.autotitle then
			-- if autotitle = 'filename', title use filename only
			local path_title = path
			if config.autotitle == 'filename' then
				path_title = vim.fn.fnamemodify(path, ':t')
			end
			-- make title
			if not str then
				title = path_title
			elseif path == curfile then
				title = str:gsub('^#+%s*', '')
			else
				title = path_title .. ' > ' .. str:gsub('^#+%s*', '')
			end
		end

		-- if visual mode, use it as title
		local m = vim.api.nvim_get_mode()
		if m.mode == 'v' or m.mode == 'V' then
			local start_row, start_col, end_row, end_col = Utils.get_visualidx() -- get index of visualized word
			state.visual_range = {start_row, start_col, end_row, end_col}
			local contents = vim.api.nvim_buf_get_text(0, start_row-1, start_col-1, end_row-1, end_col, {})
			title = vim.trim(table.concat(contents, ' '))
		else
			state.visual_range = {}
		end

		path_enc = (path == curfile) and '' or path_enc
		local link = Utils.link_formatter(style, path_enc .. str_enc, title)

		if string.match(raw, '^%s*$') then
			return nil, nil
		end
		return link, raw
	end



	---@type file_picker.picker_item[]
	local output = {}
	for _, item in ipairs(filelist) do
		local filename = vim.fn.fnamemodify(item, ':t')
		local link, raw = get_linkformat(item)
		if link and raw ~= curfile then
			table.insert(output, {
				text     = raw,
				file     = item,
				pos      = {1, 1},
				score    = 0,
				filename = filename, -- manual
				link     = link,     -- manual
				textlen  = #link,    -- manual
				str  	 = '',       -- manual
			})
		end
	end
	for _, item in ipairs(headerlist) do
		local filepath, lnum, str = string.match(item, "(.+):(%d+):(.+)")
		local filename = vim.fn.fnamemodify(filepath, ':t')
		if filepath then
			local link, raw = get_linkformat(filepath, str)
			table.insert(output, {
				text     = raw,
				file     = filepath,
				pos      = {tonumber(lnum), 1},
				score    = (filename == curfile) and 100 or 0,
				filename = filename, -- manual
				link     = link,     -- manual
				textlen  = #raw,     -- manual
				str  	 = str,      -- manual
			})
		end
	end

	return output
end


---@param style string markdown|wiki
M.file_picker = function (style)
	-- check snacks is loaded
	local snacks_ok, snacks = pcall(require, 'snacks')
	if not snacks_ok then
		vim.notify('snacks.nvim is not installed', vim.log.levels.ERROR)
		return
	end

	local curfile = vim.fn.expand('%:t')
	---@param item file_picker.picker_item
	local function formatter(item, _)
		local ret = {}
		if item.filename ~= curfile then -- if list is curfile, doesn't show
			ret[#ret +1] = {item.filename .. ' ', 'SnacksPickerGitCommit'}
		end
		ret[#ret +1] = {item.str}
		return ret
	end

	---@param item file_picker.picker_item
	local function confirmer(picker, item)
		picker:close()
		if item then
			vim.api.nvim_command('edit ' .. item.file)
			vim.api.nvim_win_set_cursor(0, {item.pos[1], item.pos[2]}) -- go to cursor
			vim.cmd("normal! zt")
		end
	end

	local m = vim.api.nvim_get_mode()
	-- remember state before picker start
	---@param item file_picker.picker_item
	local function add_link(picker, item)
		picker:close()
		if m.mode == 'v' or m.mode == 'V' then
			if not vim.tbl_isempty(state.visual_range) then
				local sr, sc, er, ec = unpack(state.visual_range)
				vim.api.nvim_buf_set_text(0, sr-1, sc-1, er-1, ec, {''})
			end
		end
		local cursor = vim.api.nvim_win_get_cursor(0)
		vim.api.nvim_buf_set_text(0,cursor[1]-1, cursor[2], cursor[1]-1, cursor[2], {item.link} )
		vim.api.nvim_win_set_cursor(0, {cursor[1], cursor[2]+1})
		if m.mode == 'i' then
			vim.api.nvim_input('i')
		end
	end

	local output = get_link_data(style)
	snacks.picker.pick({
		items = output,
		format = formatter,
		preview = 'file',
		confirm = add_link, -- '<CR>', add links
		transform = function (item,_ )
			item.score_add = item.score
			item.score_add = item.score_add + (50000 - item.pos[1]*0.01) -- default score is descent order by line number, deal up to 50000 lines
			return item
		end,
		actions = {
			confirmer = confirmer,
		},
		win = {
			input = {
				keys = {
					["<C-l>"] = { "confirmer", mode = { "n", "i" }, desc = "open the document" },
				},
			},
		},
	})

end

return M
