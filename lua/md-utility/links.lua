local M = {}

local Utils = require('md-utility.utils')
local config = require('md-utility.config').get().follow_link

---############################################################################---
---## link_picker
---############################################################################---

--- Get root, query treesitter of current buffer from parsing pattern
--- @param bufid number buffer id
--- @param ft_parsing string parser name
--- @param pattern string parsing pattern
--- @return TSNode? Root object of treesitter tree
--- @return vim.treesitter.Query? Query object of treesitter tree
local get_query = function (bufid, ft_parsing, pattern)

	ft_parsing = ft_parsing or vim.bo.filetype
	local parser = vim.treesitter.get_parser(bufid, ft_parsing)
	if not parser then
		vim.notify(' No Treesitter parser found for the filetype : ' .. ft_parsing, vim.log.levels.ERROR)
		return nil, nil
	end

	local tree = parser:parse()[1]
	if not tree then
		vim.notify(' No Treesitter tree found for this buffer : ' .. ft_parsing, vim.log.levels.ERROR)
		return nil, nil
	end

	local root = tree:root()
	if not pattern then
		return root, nil
	end

	local query = vim.treesitter.query.parse(ft_parsing, pattern)
	if not query then
		vim.notify(' Error parsing treesitter query ', vim.log.levels.ERROR)
		return nil, nil
	end

	return root, query
end

-- get which style it is from raw_link
---@param raw_link string raw format of link
---@return string? style
local function get_link_style(raw_link)
	-- check it is markdown link format
	local ms = string.find(raw_link, '%b[]%b()', 1)
	if ms then
		return 'markdown'
	end

	-- check it is wiki link format
	local ws = string.find(raw_link, '%[%[[^%]]-%]%]', 1)
	if ws then
		return 'wiki'
	end

	return nil
end

-- get each component of raw link
---@param raw_link string raw format of link
---@return string?
---@return string?
---@return string?
local function get_link_components(raw_link)
	local style = get_link_style(raw_link)
	if not style then
		return nil, nil, nil
	end

	local image, title, link = nil, nil, nil
	if style == 'markdown' then
		image, title, link = string.match(raw_link, "(!?)%[([^%]]*)%]%(([^)]*)%)")
	elseif style == 'wiki' then
		image, link, title = string.match(raw_link, "(!?)%[%[([^|%]]+)|?([^%]]*)%]%]")
		title = title == '' and vim.fn.fnamemodify(link, ':t') or title
	end
	return image, title, link
end

--- Get components about link
--- @param raw_link string whole link contents
--- @return link_picker.item_components?
local resolve_link = function (raw_link)
	-- get link components
	local image, title, link = get_link_components(raw_link)
	if not link then
		return nil
	end

	-- insert items
	---@type link_picker.item_components
	local item    = {}
	item.is_image = (image == "!")
	item.title    = title
	item.link     = link
	item.category = item.is_image and 'I' or (Utils.is_url(item.link) and 'W' or 'L') -- image(I), web(W), link(L)
	item.icon     = (item.category == 'I') and '' or ( (item.category == 'W') and '󰖟' or '')

	return item
end

-- get all link list in current buffer
---@return link_picker.picker_item?
local get_linklist = function()
	-- get root query of this file
	local cur_bufid = vim.api.nvim_get_current_buf()
	local pattern = [[
		(image) @link_node
		(inline_link) @link_node
		(shortcut_link) @link_node
	]]
	-- (image) : image format
	-- (inline_link) : markdown format
	-- (shortcut_link) : wiki format or callout
	local TSroot, query = get_query(cur_bufid, 'markdown_inline', pattern)
	if not TSroot or not query then
		return nil
	end

	-- iterate all link node and insert items to table to show in link_picker
	---@type link_picker.picker_item
	local items = {}
	local items_lochash = {}
	local maxlen = 0
	local matches = query:iter_captures(TSroot, cur_bufid, 0, -1)
	for _, node, _, _ in matches do
		local row, col = node:start()  -- line number of header
		local text = ''
		local node_range = {node:range()} -- range to check duplicated items
		if node:type() ~= 'shortcut_link' then
			text = vim.treesitter.get_node_text(node, 0) -- get text of captured node
		else
			-- if you get result of get_node_text() from wiki link, It contains only one pair of []
			-- so (shortcut_link) contains not only wiki like but also callout.
			-- To get whole link format, range is extended to sc-2 ~ ec+1
			node_range[2] = (node_range[2]-2 < 0) and 0 or node_range[2]-2
			node_range[4] = node_range[4]+1
			text = vim.api.nvim_buf_get_text(cur_bufid, node_range[1], node_range[2], node_range[3], node_range[4], {})[1]
			-- (shortcut_link) can indicate duplicated node with (image).
			-- (shortcut_link) range can be same with (image) when node_range of (shortcut_link) is adjusted.
			-- We use this to distinguish between them.
		end

		-- add range to hash if it is independent value
		local range_key = vim.inspect(node_range)
		if not items_lochash[range_key] then
			items_lochash[range_key] = true
			local link = resolve_link(text)
			if link then
				-- find max title length
				if #link.title > maxlen then
					maxlen = #link.title
				end

				table.insert(items, {
					data = link,
					text = link.category .. ' ' .. link.title .. ' ' .. link.link,
					file = vim.api.nvim_buf_get_name(cur_bufid),
					pos = {row + 1, col + 1},
				})
			end
		end
	end

	-- insert max_title length
	for _, item in ipairs(items) do
		item.data.maxlen = maxlen
	end

	if #items == 0 then
		vim.notify('No items found' , vim.log.levels.INFO)
		return nil
	end

	return items
end

--- Show all links in current buffer
M.link_picker = function ()
	-- check snacks is loaded
	local snacks_ok, snacks = pcall(require, 'snacks')
	if not snacks_ok then
		vim.notify('snacks.nvim is not installed', vim.log.levels.ERROR)
		return
	end

	snacks.picker.pick({
		finder = function ()
			local items = get_linklist()
			if items then
				return items
			end
			return {}
		end,
		format = function (item, _)
			local a = snacks.picker.util.align -- for setting strict width
			local ret = {}
			local row_highlight = item.data.category == "I" and 'MdUtilityLinkImage' or (
								  item.data.category == "W" and 'MdUtilityLinkWeb' or (
								  item.data.category == 'L' and 'MdUtilityLinkFile' or nil))
			ret[#ret +1] = {a(item.data.icon, 2), row_highlight}
			ret[#ret +1] = {a(item.data.category, 2), row_highlight}
			ret[#ret +1] = {a(item.data.title, item.data.maxlen + 2), row_highlight}
			ret[#ret +1] = {item.data.link}
			snacks.picker.highlight.markdown(ret) -- set highlight for other text
			return ret
		end,
		preview = 'file',
		confirm = function (picker, item)
			picker:close()
			if item then
				vim.api.nvim_win_set_cursor(0, {item.pos[1], item.pos[2]}) -- go to cursor
				vim.cmd("normal! zt")
			end
		end,
	})
end

---############################################################################---
---## follow_link
---############################################################################---

-- get link contents in markdoww/wiki whole format under cursor
---@return string|nil url it contains [..](..) or [[]]form
---@return string|nil style
local check_link = function ()
	-- get location of cursor
	local line = vim.api.nvim_get_current_line() -- get current line string
	local col = vim.fn.col('.') -- get current column under the cursor

	-- get start_idx / end_idx matched with each style
	---@param style string markdown|wiki
	---@param sidx number start index
	local function get_range_matched(style, sidx)
		if style == 'markdown' then
			return string.find(line, '%b[]%b()', sidx)
		elseif style == 'wiki' then
			return string.find(line, '%[%[[^%]]-%]%]', sidx)
		end
	end

	local start_idx = 0
	while start_idx < #line do
		-- get matched pattern from start_idx
		local ms, me = get_range_matched('markdown', start_idx+1)
		local ws, we = get_range_matched('wiki', start_idx+1)

		-- if link doesn't exist
		if not ms and not ws then
			vim.notify('Link doese not exist under the cursor!', vim.log.levels.ERROR)
			return nil, nil
		end

		-- if link exists, check the link is under cursor
		if ms and (ms <= col and col <= me)then
			return line:sub(ms, me), 'markdown'
		elseif ws and (ws <= col and col <= we)then
			return line:sub(ws, we), 'wiki'
		end

		-- if not, update start_idx
		if me and (not we or me > we) then
			start_idx = me
		elseif we then
			start_idx = we
		end
	end
end

-- get contents of the whole link url
---@param raw_link string whole link format contents
---@param style string markdown|wiki
---@return string
local function get_linkpath(raw_link, style)
	if style == 'markdown' then
		return string.match(raw_link, '%[.-%]%((.-)%)')
	elseif style == 'wiki' then
		return string.match(raw_link,  '%[%[([^|%]]+)')
	end
	return ''
end

-- get absolute file path in root director from relative path of file
---@param rootdir string root directory which is base.
---@param filepath string relative path of file
---@return string? absolute path of file
local function get_absolutefile(rootdir, filepath)
	local filename = vim.fn.fnamemodify(filepath, ':t')
	-- local filedir = vim.fn.fnamemodify(filepath, ':h')

	-- find filename in root
	local fd_result = vim.system({ 'fd', '--absolute-path', filename }, {
		cwd = rootdir,
		text = true,
	}):wait()

	if fd_result.code ~= 0 then
		vim.notify('fd execution failure: ' .. (fd_result.stderr or ''), vim.log.levels.ERROR)
		return nil
	end

	-- check the result is unique
	local fd_file = vim.split(fd_result.stdout, "\n", { trimempty = true })
	if #fd_file == 1 then
		return fd_file[1]
	elseif #fd_file == 0 then
		return nil
	end

	-- filter from stdout of fd to find unique one using relative directory of file
	-- --fixed-strings allows you to use \ without having to replace with \\
	local filepath_os = Utils.sep_unify(filepath, nil, nil, false)
	local rg_result = vim.system( { "rg", '--fixed-strings', filepath_os }, {
		stdin = fd_result.stdout,
		text = true,
	}):wait()

	if rg_result.code ~= 0 then
		vim.notify("rg cannot matched with " .. filepath_os, vim.log.levels.ERROR)
		return nil
	end

	-- Output results
	local rg_file = vim.split(rg_result.stdout, "\n", { trimempty = true })
	if #rg_file ~= 1 then
		vim.notify("There are multiple matched items from link, select first item", vim.log.levels.WARN)
		vim.print(rg_file)
	end
	return rg_file[1]
end

M.follow_link = function ()
	-- get full link format
	local raw, style = check_link()
	if not raw or not style then
		return
	end
	-- get only link pattern from full link
	local path = get_linkpath(raw, style)

	if Utils.is_url(path) then
		if vim.g.has_win32 then
			os.execute('start ' .. config.web_opener .. ' ' .. path) -- if url is web link, use brave web browser
		else
			os.execute(config.web_opener .. ' \'' ..  path .. '\'' .. ' > /dev/null 2>&1 &') -- if url is web link, use brave web browser
		end
	elseif Utils.is_image(path) then
		-- get absolute path of image file
		local rootdir = Utils.get_rootdir(0)
		local filepath = get_absolutefile(rootdir, path)
		if not filepath then
			vim.notify('This image file cannot be found in rootdir (' .. rootdir .. ')', vim.log.levels.ERROR)
			return
		end

		-- check the terminal is wezterm (use wezterm for following image)
		if os.getenv('WEZTERM_PANE') ~= nil then
			vim.api.nvim_command('silent !wezterm cli split-pane --horizontal -- powershell wezterm imgcat ' .. '\'' ..  filepath .. '\'' .. ' ; pause')
		else
			os.execute(config.image_opener .. ' "' .. filepath .. '"') -- use default open tool for windows
		end
	else
		if config.file_opener then
			vim.cmd(config.file_opener)
		end
		vim.lsp.buf.definition() -- open buffer using marksman lsp
	end
end

return M
