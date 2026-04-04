local ButtonDialog = require("ui/widget/buttondialog")
local Device = require("device")
local Geom = require("ui/geometry")
local ReaderUI = require("apps/reader/readerui")

local patch_dir = require("datastorage"):getDataDir() .. "/patches"
local package_path = package.path
package.path = patch_dir .. "/?.lua;" .. package.path
local BookMapWidget = require("2-end-bookmap/bookmapwidget")
package.path = package_path

ButtonDialog.new = (function(orig)
    return function(...)
        local ret = orig(...)
        if ret.name == "end_document" then
            ret.width = math.floor(Device.screen:getWidth() * 0.9)
            ret:reinit()

            local map_width = ret:getAddedWidgetAvailableWidth()
            local map_height = math.floor(Device.screen:getHeight() * 0.6)
            local book_map = BookMapWidget:new{
                ui = ReaderUI.instance,
                dimen = Geom:new{ w = map_width, h = map_height },
                overview_mode = true,
                clutter_free_mode = true,
            }
            book_map.not_focusable = true

            ret:addWidget(book_map)
        end
        return ret
    end
end)(ButtonDialog.new)
