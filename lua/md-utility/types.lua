---@meta _

-- configuration ------------------------------------------
---@class md-utility.config
---@field file_picker md-utility.config.file_picker
---@field paste md-utility.config.paste
---@field autolist md-utility.config.autolist
---@field follow_link md-utility.config.follow_link




-- file_picker --------------------------------------------
---@class md-utility.config.file_picker
---@field ignore string[]

---@class file_picker.picker_item
---@field text string raw data shown in picker
---@field file string related absolute file path to preview
---@field pos table<number, number> cursor position
---@field filename string related file name
---@field link string markdown link format
---@field textlen number the number of link
---@field str string raw data of anchor



-- paste --------------------------------------------
---@class md-utility.config.paste
---@field image_path fun(ctx:md-utility.config.paste.formatctx):string

---@class md-utility.config.paste.formatctx
---@field root_dir string root dir of lsp. It ends with slash
---@field cur_dir string directory of current focused buffer. It ends with slash



-- paste --------------------------------------------
---@class md-utility.config.autolist
---@field patterns md-utility.config.autolist.list_patterns
---@field autoremove_cr boolean
---@field autoguess_tab boolean

---@class md-utility.config.autolist.list_patterns
---@field bullet string
---@field digit string
---@field checkbox string

-- follow_link --------------------------------------------
---@class md-utility.config.follow_link
---@field image_opener string
---@field web_opener string
---@field file_opener string



-- link_picker --------------------------------------------
---@class link_picker.item_components
---@field is_image boolean
---@field title string?
---@field link string?
---@field category string
---@field icon string
---@field maxlen number the maximum length of link title among items

---@class link_picker.picker_item
---@field data link_picker.item_components
---@field text string
---@field file string
---@field pos number[]
