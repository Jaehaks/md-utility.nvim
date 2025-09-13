---@meta _

-- configuration ------------------------------------------
---@class md-utility.config
---@field file_picker md-utility.config.file_picker
---@field paste md-utility.config.paste

---@class md-utility.config.file_picker
---@field ignore string[]

---@class md-utility.config.paste
---@field image_path fun(ctx:md-utility.config.paste.formatctx):string

---@class md-utility.config.paste.formatctx
---@field root_dir string root dir of lsp. It ends with slash
---@field cur_dir string directory of current focused buffer. It ends with slash


-- file_picker --------------------------------------------
---@class file_picker.picker_item
---@field text string raw data shown in picker
---@field file string related absolute file path to preview
---@field pos table<number, number> cursor position
---@field filename string related file name
---@field link string markdown link format
---@field textlen number the number of link
---@field str string raw data of anchor
