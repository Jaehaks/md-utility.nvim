local M = {}
local Config = require('md-utility.config').get()

local CELL_WIDTH = 10 -- average value of pixels for some font width
local CELL_HEIGHT = 20 -- average value of pixels for some font height

---@class md-utility.norm_size
---@field w integer normalized pixel width of image to current terminal
---@field h integer normalized pixel height of image to current terminal
---@field col integer converted from w to neovim col size
---@field row integer converted from w to neovim col size

---@class md-utility.image_cache
---@field buf integer? buffer id to draw image
---@field win integer? window id to draw image
---@field path string? Absolute path of image file
---@field norm_size md-utility.norm_size
---@field data string?
---@field x integer coordinate of x pixel of image
---@field y integer coordinate of y pixel of image
---@field is_rendered boolean whether the image is rendered to terminal
local DEFAULT_IMAGE_CACHE = {
	buf = nil,
	win = nil,
	path = nil,
	norm_size = {0,0,0,0},
	data = nil,
	x = 0,
	y = 0,
	is_rendered = false,
}
local image_cache = vim.deepcopy(DEFAULT_IMAGE_CACHE)

local function clear_image()
	image_cache = vim.deepcopy(DEFAULT_IMAGE_CACHE)
	vim.cmd('redraw!')
end

--- get original pixel size of image with {width, height} form
---@param image_path string absolute path of image
---@return integer[]? {width heigth}
local function get_origin_size(image_path)
	local cmd = {'magick', 'identify', '-format', '"%w %h"', image_path}
	local result = vim.system(cmd, {text = true}):wait()
	if result.code ~= 0 or not result.stdout then
		return
	end

	local w, h = string.match(result.stdout, "(%d+) (%d+)")
	local origin_size = {tonumber(w), tonumber(h)}
	return origin_size
end

--- get normalized pixel size to current terminal
---@param origin_size integer[] {width, height}
---@return md-utility.norm_size
local function get_normalized_size(origin_size)
	local orig_w, orig_h = unpack(origin_size)          -- get original size of image (pixels)
	local term_max_cols = vim.o.columns - 4             -- get current terminal size considering margin 4
	local term_max_lines = vim.o.lines - 4

	-- limit max size according to users config
	local user_max_cols = Config.image.max_size and Config.image.max_size[1] or term_max_cols
	local user_max_lines = Config.image.max_size and Config.image.max_size[2] or term_max_lines
	local max_cols = math.min(term_max_cols, user_max_cols)
	local max_lines = math.min(term_max_lines, user_max_lines)

	local max_pixel_w = max_cols * CELL_WIDTH           -- convert current terminal size with pixel form
	local max_pixel_h = max_lines * CELL_HEIGHT

	local scale_w = max_pixel_w / orig_w
	local scale_h = max_pixel_h / orig_h
	local scale = math.min(1.0, scale_w, scale_h)       -- check original image size can be shown in current terminal size

	local norm_size = {}
	norm_size.w = math.floor(orig_w * scale)            -- get normalized pixel size fitted under current terminal
	norm_size.h = math.floor(orig_h * scale)
	norm_size.col = math.max(1, math.ceil(norm_size.w / CELL_WIDTH)) -- convert pixel to neovim col/row size
	norm_size.row = math.max(1, math.ceil(norm_size.h / CELL_HEIGHT))
	return norm_size
end

--- get terminal sequence string from sixel data
---@param sixel_data string sixel data result from magick
---@param x integer x-coordinate to render image
---@param y integer y-coordinate to render image
---@return string
local function get_image_sequence(sixel_data, x, y)
    if not sixel_data:match("^\27P") and not sixel_data:match("^\155") then
        sixel_data = "\27P0;1;0q" .. sixel_data
    end
    if not sixel_data:match("\27\\$") and not sixel_data:match("\156$") then
        sixel_data = sixel_data .. "\27\\"
    end

    local sequence = ""
	-- sequence = sequence .. "\27[?25l"                                -- 1. 터미널 커서를 숨겨서 렌더링 중 깜박임(파먹힘) 방지
    sequence = sequence .. "\27[s"                                   -- [ANSI] 현재 커서 위치 저장
    sequence = sequence .. string.format("\27[%d;%dH", y + 1, x + 1) -- [ANSI] 좌표 이동
    sequence = sequence .. sixel_data                                -- Sixel 본문
    sequence = sequence .. "\27[u"                                   -- [ANSI] 커서 위치 원상복구
	-- sequence = sequence .. "\27[?25h"                                -- 6. 렌더링이 완전히 끝났으므로 커서 가시성 복원

	return sequence
end

--- send sequence to terminal to draw image
---@param sequence string
local function send_data(sequence)
    pcall(function()
        vim.api.nvim_chan_send(vim.v.stderr, sequence)
    end)
end

--- render_image to terminal
---@param engine string graphic engine
---@param force boolean if true, redraw image even though the location is not changed
local function render_image(engine, force)
	if not image_cache.win or not vim.api.nvim_win_is_valid(image_cache.win) then return end
	if not image_cache.data then return end

	--- get image location with pixel form from window where the image is shown.
	--- remove existing image if the new location is different with cache
	local win_pos = vim.api.nvim_win_get_position(image_cache.win)
	local has_border = Config.image.win_opts.border and Config.image.win_opts.border ~= "none"
	local border_offset = has_border and 1 or 0
	local x = win_pos[2] + border_offset
	local y = win_pos[1] + border_offset

	if not force and image_cache.is_rendered and image_cache.x == x and image_cache.y == y then
		return
	end

	-- clean image and redraw
	vim.cmd('redraw!')
	image_cache.x = x
	image_cache.y = y

	local seq = ''
	if engine == 'sixel' then
		seq = get_image_sequence(image_cache.data, x, y)
	end
	send_data(seq)
	image_cache.is_rendered = true
end

--- draw image asynchronously
---@param image_info md-utility.image_cache
local function draw_image_async(image_info)
	local size = image_info.norm_size
	local resize_arg = string.format('%dx%d', size.w, size.h)
	local cmd = { 'magick', image_info.path, '-resize', resize_arg, 'sixel:-' }
	vim.system( cmd , {text = true}, function (out)
		if out.code ~= 0 or not out.stdout or out.stdout == '' then
			vim.notify('[md-utility] Failed to get sixel data', vim.log.levels.ERROR)
			return
		end

		vim.schedule(function () -- do it after showing floating window is completed
			if image_info.win and vim.api.nvim_win_is_valid(image_info.win) then
				image_info.data = out.stdout
				render_image(Config.image.engine, true)
			end
		end)
	end)
end


--- get absolute path of image file from link under cursor
---@return string?
local function get_image_path()
	local Links = require('md-utility.links')
	local Utils = require('md-utility.utils')

	-- get full link format
	local raw, style = Links.check_link()
	if not raw or not style then
		return
	end
	-- get only link pattern from full link
	local path = Links.get_linkpath(raw, style)
	path = path:gsub('%%20', ' ') -- decode %20 to white space

	-- check path is valid image file
	if not Utils.is_image(path) then
		vim.notify('[md-utility] File extension must be in {png/bmp/gif/svg/webp/jpg/jpeg/tiff/tif/row}', vim.log.levels.ERROR)
		return
	end

	-- check the file is valid image file
	local rootdir = Utils.get_rootdir(0)
	local filepath = Links.get_absolutefile(rootdir, path)
	if not filepath then
		vim.notify('[md-utility] This image file cannot be found in rootdir (' .. rootdir .. ')', vim.log.levels.ERROR)
		return
	end

	return filepath
end

--- redraw every times to remain image in buffer
---@type uv.uv_timer_t?
local timer = nil
local pending_force = false -- prevent to overwrite force state while defer_fn() is executed by autocmd
---@param force boolean if true, redraw image even though the location is not changed
local function schedule_redraw(force)
	pending_force = pending_force or force

	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end

	timer = vim.defer_fn(function()
		timer = nil
		local current_force = pending_force
		pending_force = false
		render_image(Config.image.engine, current_force)
	end, 50)
end

--- show preview of image link under cursor
M.preview_image = function()

	--- get image file path under cursor
	local image_path = get_image_path()
	if not image_path then
		return
	end
	image_cache.path = image_path

	--- get normalized size of image to determine floating window size automatically
	local image_size = get_origin_size(image_path)
	if not image_size then
		vim.notify('[md-utility] Image size cannot be detected : ' .. image_path, vim.log.levels.ERROR)
		return
	end
	local norm_size = get_normalized_size(image_size)
	image_cache.norm_size = norm_size

	--- if floating window is remained, close it (only one preview)
	if image_cache.win and vim.api.nvim_win_is_valid(image_cache.win) then
		vim.api.nvim_win_close(image_cache.win, true)
	end

	--- create window ----------------------------------------------------
	-- smart position setting
	local cur_pos = vim.api.nvim_win_get_cursor(0)
	local screen_pos = vim.fn.screenpos(0, cur_pos[1], cur_pos[2])

	-- 1) row positioning
	local win_row = 1 -- below 1 line under cursor as default
	if screen_pos.row + win_row + image_cache.norm_size.row > vim.o.lines then -- show image above cursor
		win_row = -image_cache.norm_size.row
	end

	-- 2) col positioning
	local win_col = 0
	if screen_pos.col + win_col + image_cache.norm_size.col > vim.o.columns then -- show image above cursor
		win_col = vim.o.columns - (screen_pos.col + image_cache.norm_size.col)
	end

	local win_size = {
		width = image_cache.norm_size.col,
		height = image_cache.norm_size.row,
		row = win_row,
		col = win_col,
	}
	---@type vim.api.keyset.win_config
	local win_opts = vim.tbl_deep_extend('force', win_size, Config.image.win_opts)
	image_cache.buf = vim.api.nvim_create_buf(false, true)
	image_cache.win = vim.api.nvim_open_win(image_cache.buf, false, win_opts)

	--- draw image to terminal ----------------------------------------------------
	image_cache.data = nil
	draw_image_async(image_cache)

	--- redraw every time
	local augroup = vim.api.nvim_create_augroup('md-utility-preview-image', {clear = true})
	vim.api.nvim_create_autocmd({ "WinScrolled", "VimResized"}, {
		group = augroup,
		callback = function()
			if not image_cache.win or not vim.api.nvim_win_is_valid(image_cache.win) then
				return
			end
			-- redraw
			schedule_redraw(true)
		end
	})

	vim.api.nvim_create_autocmd({'DiagnosticChanged', 'SafeState'}, {
		group = augroup,
		callback = function()
			if not image_cache.win or not vim.api.nvim_win_is_valid(image_cache.win) then
				return
			end
			schedule_redraw(false)
		end
	})

	-- close preview image automatically
	vim.api.nvim_create_autocmd('CursorMoved', {
		group = augroup,
		callback = function()
			pcall(vim.api.nvim_win_close, image_cache.win, true)
		end
	})

	--- wipe image after winclosed
	vim.api.nvim_create_autocmd('WinClosed', {
		group = augroup,
		pattern = tostring(image_cache.win),
		once = true,
		callback = function ()
			clear_image()
			vim.api.nvim_del_augroup_by_id(augroup)
			pcall(vim.api.nvim_buf_delete, image_cache.buf, {force = true})
		end
	})

	vim.keymap.set('n', 'q', '<Cmd>close<CR>', {buf = image_cache.buf})
end



return M
