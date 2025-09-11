local M = {}

local Config = require('md-utility.config')
local Utils = require('md-utility.utils')

---@param mode string 'filelist(get all file list only)'|'headerlist(get header list)'
---@param path string absolute path to find files
---@return string[] cmd table
local function get_cmd_rg(mode, path)
	local config = Config.get()

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
	for _, pattern in ipairs(config.file_picker.ignore) do
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


---@param mode string markdown|wiki
---@return file_picker.picker_item
local function get_link_data(mode)
	-- get lsp root
	---@type vim.lsp.Client
	local client = vim.lsp.get_clients({bufnr = 0, name = 'marksman'})[1]
	local root_dir = Utils.sep_unify(client.config.root_dir)
	local curdir = Utils.sep_unify(vim.fn.expand('%:p:h'))
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
		mode = mode or 'markdown'
		-- encoding for link format
		local path = Utils.get_relative_path(abspath, curdir, root_dir)
		local path_enc = path:gsub('[%s]', '%%20') -- white space must be encoded by %20 to follow link by marksman
		local str_enc = str and
					   str:gsub('^#+%s*', '#')              -- replace multiple # to one # as anchor mark.
					      :gsub('[^#%w%d%s-_\128-\255]', '') -- remove all special characters, remain english/digit/cjk
					      :gsub('[%s-]+', '-') or ''         -- replace all spaces to '-'

		-- make link format
		local raw = not str and path or path .. ' (' .. str .. ')'

		-- get title for link format
		local title = (mode == 'wiki') and '|' or ''
		if not str then
			title = title .. path
		elseif path == curfile then
			title = title .. str:gsub('^#+%s*', '')
		else
			title = title .. path .. ' > ' .. str:gsub('^#+%s*', '')
		end

		path_enc = (path == curfile) and '' or path_enc
		local link = nil
		if mode == 'markdown' then
			-- make image token
			local image_exts = {'png', 'bmp', 'gif', 'svg', 'webp', 'jpg', 'jpeg', 'tiff', 'tif', 'row'}
			local file_ext = vim.fn.fnamemodify(path, ':e')
			local token = vim.tbl_contains(image_exts, file_ext) and '!' or ''
			link = token .. '[' .. title .. '](' .. path_enc .. str_enc .. ')'
		elseif mode == 'wiki' then
			link = '[[' .. path_enc .. str_enc .. title .. ']]'
		end

		if raw == '' then
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
				filename = filename, -- manual
				link     = link,     -- manual
				textlen  = #raw,     -- manual
				str  	 = str,      -- manual
			})
		end
	end

	return output
end


---@param mode string markdown|wiki
M.file_picker = function (mode)
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

	-- remember state before picker start
	local m = vim.api.nvim_get_mode()
	local cursor = vim.api.nvim_win_get_cursor(0)
	---@param item file_picker.picker_item
	local function add_link(picker, item)
		picker:close()
		vim.api.nvim_buf_set_text(0,cursor[1]-1, cursor[2], cursor[1]-1, cursor[2], {item.link} )
		vim.api.nvim_win_set_cursor(0, {cursor[1], cursor[2]})
		if m.mode == 'i' then
			vim.api.nvim_input('i')
		end
	end

	local output = get_link_data(mode)
	snacks.picker.pick({
		items = output,
		format = formatter,
		preview = 'file',
		confirm = confirmer,
		transform = function (item,_ )
			item.score_add = 50000 - item.pos[1] -- default score is descent order by line number, deal up to 50000 lines
			if item.filename == curfile then -- show current file anchor first
				item.score_add = item.score_add + 100
			end
			return item
		end,
		actions = {
			add_link = add_link,
		},
		win = {
			input = {
				keys = {
					["<C-l>"] = { "add_link", mode = { "n", "i" }, desc = "add markdown link from item" },
				},
			},
		},
	})

end

return M
