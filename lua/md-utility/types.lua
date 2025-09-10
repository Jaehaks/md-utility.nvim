---@meta _

-- configuration ------------------------------------------
---@class md-utility.config
---@field link_picker md-utility.config.link_picker

---@class md-utility.config.link_picker
---@field ignore string[]


-- link_picker --------------------------------------------
---@class link_picker.picker_item
---@field text string raw data shown in picker
---@field file string related absolute file path to preview
---@field pos table<number, number> cursor position
---@field filename string related file name
---@field link string markdown link format
---@field textlen number the number of link
---@field str string raw data of anchor
