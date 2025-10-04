local M = {}

local Utils = require('md-utility.utils')
local Config = require('md-utility.config')

-- check content is URL form like "https://*" or "www.*"
---@param content string web URL form
local IsUrl = function(content)
	return (string.match(content, '^(https?://)')
			or string.match(content,'^(www%.)'))
end

--- Decode unicode from non-english word in url except white space
--- @param url string web URL form with encoding character from non-english word
--- @return string decoded_url The decoded URL from UTF-8 to korean
--- @return integer? hex The number of replacements made (optional).
local url_decode = function(url)
    return url:gsub("%%(%x%x)", function(hex)
		return hex:upper() == '20' and '%20' or string.char(tonumber(hex, 16))
    end)
end

-- get filepath to save image
---@return string? filepath of image file to save
---@return string? link format for this file path
local function get_imagepath(style, title)
	style = style or 'markdown'
	local config = Config.get().paste
	-- get ctx
	local client = vim.lsp.get_clients({bufnr = 0, name = 'marksman'})[1]
	local root_dir = Utils.sep_unify(client.config.root_dir, nil, nil, true)
	local cur_dir = Utils.sep_unify(vim.fn.expand('%:p:h'), nil, nil, true)
	local ctx = {
		root_dir = root_dir,
		cur_dir = cur_dir,
	}

	local path = config.image_path(ctx)
	if not Utils.is_AbsolutePath(path) then -- if not absolute path, it considers relative path from root_dir
		path = root_dir .. path
	end

	local filepath
	if vim.fn.fnamemodify(path, ':e') ~= '' then -- if format is file, use it
		filepath = path
	else
		if not string.match(path, '[\\/]$') then -- add end slash for dir type format
			path = Utils.sep_unify(path, nil, nil, true)
		end
		local wrong = false
		while true do -- loop until proper filename
			filepath = vim.fn.input(wrong and '(Wrong extension) Save to ' or 'Save to ', path) -- ask first

			if filepath == '' then -- if Esc, cancel
				return nil, nil
			end
			if vim.fn.fnamemodify(filepath, ':e') == '' then -- if only filename, add .png
				filepath = filepath .. '.png'
			end

			if Utils.is_image(filepath) then -- if filepath is wrong
				break
			end
			wrong = true
		end
		filepath = Utils.sep_unify(filepath) -- unify slash finally
	end

	-- generate link format
	local filename = vim.fn.fnamemodify(filepath, ':t')
	title = title or filename
	local relpath = Utils.get_relative_path(filepath, cur_dir, root_dir)
	relpath = relpath:gsub('[%s]', '%%20') -- white space encoding
	local link = Utils.link_formatter(style, relpath, title)
	return filepath, link
end

-- get cmd for image paste
---@param filepath string absolute path to save image
---@return string[] cmd table
local function get_cmd_imagepaste(filepath)
	local cmd
	if Utils.is_WinOS() then
		cmd = {
			'powershell.exe',
			'-Command',
			'(Get-Clipboard -Format Image).Save("' .. filepath .. '")',
		}
	else
		cmd = {
			'xclip',
			'-selection',
			'clipboard',
			'-t',
			'image/png',
			'-o',
			'>',
			filepath,
		}
	end
	return cmd
end

-- execute cmd and get stdout
---@param cmd string[] external command with splitting arguments
---@return boolean success
local function jobstart(cmd)
	-- job options
	local cwd = vim.fn.expand('%:p:h')
	local cb_stderr = function (_, data)
		if not data then
			return
		end
		if type(data) == 'string' then
			data = {data}
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
	})
	local result = job:wait()

	if result.code ~= 0 then
		vim.notify('Save Image Failed', vim.log.levels.ERROR)
		return false
	end
	return true
end

-- add image download from clipboard and write link
---@param style string markdown|wiki
local function set_imagelink(style)

	-- get title from visualized string. Title is nil if normal mode
	local start_row, start_col, end_row, end_col = Utils.get_visualidx()
	local txt   = vim.api.nvim_buf_get_text(0, start_row-1, start_col-1, end_row-1, end_col, {})
	local title = nil
	if txt[1] ~= "" then -- if visual mode, title will be replaced with visualized word
		title = txt[1]
	else -- if normal mode, end_col = start_col in nvim_buf_set_text()
		end_col = end_col - 1
	end

	-- check image file path
	local filepath, link = get_imagepath(style, title)
	if not filepath then -- if user cancel input
		return
	end
	-- make dir
	local dirpath = vim.fn.fnamemodify(filepath, ':h')
	if vim.fn.isdirectory(dirpath) == 0 then
		local ok = vim.fn.mkdir(dirpath, 'p')
		if ok ~= 1 then
			vim.notify('mkdir is failed', vim.log.levels.ERROR)
			return
		end
	end
	-- save image
	local cmd = get_cmd_imagepaste(filepath)
	local ok = jobstart(cmd)
	-- write link
	if ok then
		vim.api.nvim_buf_set_text(0, start_row-1, start_col-1, end_row-1, end_col, {link})
		vim.api.nvim_input('<Esc>') -- go out to normal mode
	end
end

-- supports 'n' or 'v' mode
---@param style string markdown|wiki
M.ClipboardPaste = function (style)
	-- check clipboard content
	-- '+' register has non empty contents when the system clipboard saves some character not image
	local clipboard_content = vim.fn.getreg('+')
	clipboard_content = url_decode(clipboard_content)

	-- Paste depends on contents
	-- 1) If it is web url
	if IsUrl(clipboard_content) then -- if the link has web URL form, paste with link form

		-- if visual mode, get the visualized word and make it as link name
		local mode = vim.fn.mode()
		if mode == 'v' or mode == 'V' then -- if current mode is visual mode ('v') or line mode ('V')
			local start_row, start_col, end_row, end_col = Utils.get_visualidx()
			local txt   = vim.api.nvim_buf_get_text(0, start_row-1, start_col-1, end_row-1, end_col, {})
			local title = table.concat(txt, '\n')
			local link  = Utils.link_formatter(style, clipboard_content, title)
			vim.api.nvim_buf_set_text(0, start_row-1, start_col-1, end_row-1, end_col, {link})
			vim.api.nvim_input('<Esc>') -- go out to normal mode
		else -- if normal mode, make link with empty link name
			local link  = Utils.link_formatter(style, clipboard_content)
			vim.api.nvim_put({link}, 'c', true, true)
		end

	-- 2) If it is simple characters, paste from '+' register
	elseif clipboard_content ~= '' then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('"+p', true, false, true),'n', true)

	-- 3) If it is image, paste Image with obsidian function
	else
		set_imagelink(style)
	end
end



return M
