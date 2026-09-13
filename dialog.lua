--[[--
DualRead Dialog Presentation.
Presents bilingual translations and vocabulary cards using KOReader's native TextViewer.
--]]--

local InfoMessage = require("ui/widget/infomessage")
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Dialog = {}

function Dialog.showLoading(msg)
    local info = InfoMessage:new{
        text = msg or _("Translating passage..."),
    }
    UIManager:show(info)
    return info
end

function Dialog.closeLoading(info_widget)
    if info_widget then
        UIManager:close(info_widget)
    end
end

function Dialog.showTranslationCard(title, text)
    local viewer = TextViewer:new{
        title = title or _("DualRead: Translation"),
        text = text,
        text_type = "general",
    }
    UIManager:show(viewer)
end

function Dialog.showGrammarCard(title, text)
    local viewer = TextViewer:new{
        title = title or _("DualRead: Grammar Breakdown"),
        text = text,
        text_type = "general",
    }
    UIManager:show(viewer)
end

return Dialog
