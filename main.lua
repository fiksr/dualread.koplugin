--[[--
DualRead Main Plugin for KOReader.
Provides instant bilingual paragraph translation, idiom extraction, and parallel reading companions.
--]]--

local Device = require("device")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local _ = require("gettext")

-- Safe submodule loader
local plugin_dir = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or ""
local Settings = dofile(plugin_dir .. "settings.lua")
local API = dofile(plugin_dir .. "api.lua")
local Visualizer = dofile(plugin_dir .. "visualizer.lua")
local EpubCompiler = dofile(plugin_dir .. "epub_compiler.lua")
local Dialog = dofile(plugin_dir .. "dialog.lua")

-- Register into KOReader's menu order system
local function addToMenuOrder(module_path, section, name)
    local ok, order = pcall(require, module_path)
    if ok and order and order[section] then
        for idx, v in ipairs(order[section]) do
            if v == name then return end
        end
        table.insert(order[section], name)
    end
end
addToMenuOrder("ui/elements/reader_menu_order", "more_tools", "dualread")
addToMenuOrder("ui/elements/filemanager_menu_order", "more_tools", "dualread")

local DualRead = WidgetContainer:extend{
    name = "dualread",
    is_doc_only = false,
}


function DualRead:onDispatcherRegisterActions()
    Dispatcher:registerAction("dualread", {
        category = "none",
        event = "ShowDualRead",
        title = _("📖 DualRead"),
        general = true,
    })
    Dispatcher:registerAction("dualread_generate", {
        category = "none",
        event = "GenerateDualRead",
        title = _("✨ Generate Bilingual Edition"),
        general = true,
    })
end

function DualRead:onShowDualRead()
    local Menu = require("ui/widget/menu")
    local menu = Menu:new{
        title = _("📖 DualRead"),
        item_table = self:getSubMenuItems(),
        is_borderless = true,
    }
    UIManager:show(menu)
end

function DualRead:onGenerateDualRead()
    self:onGenerateBilingualBook()
end

function DualRead:init()
    self.settings = Settings:new()
    self.api = API:new(self.settings)
    self.compiler = EpubCompiler:new(self.settings)
    self:onDispatcherRegisterActions()

    if self.ui and self.ui.highlight then
        self:addToHighlightDialog()
    end

    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function DualRead:getBookTitle()
    local doc = self.ui and self.ui.document
    local props = (doc and doc.getProps and doc:getProps()) or (self.ui and self.ui.doc_props) or {}
    return props.display_title or props.title or (doc and doc.file and doc.file:match("([^/]+)%.%w+$")) or "Untitled Book"
end

function DualRead:addToHighlightDialog()
    self.ui.highlight:addToHighlightDialog("01_dualread_translate", function(this)
        return {
            text = _("DualRead: Translate"),
            callback = function()
                this:highlightFromHoldPos()
                if not (this.selected_text and this.selected_text.text) then return end

                local text = util.cleanupSelectedText(this.selected_text.text):gsub("^%s+", ""):gsub("%s+$", "")
                if #text == 0 then return end
                this:onClose(true)

                self:onTranslateText(text)
            end,
        }
    end)

    self.ui.highlight:addToHighlightDialog("02_dualread_grammar", function(this)
        return {
            text = _("DualRead: Grammar & Idiom"),
            callback = function()
                this:highlightFromHoldPos()
                if not (this.selected_text and this.selected_text.text) then return end

                local text = util.cleanupSelectedText(this.selected_text.text):gsub("^%s+", ""):gsub("%s+$", "")
                if #text == 0 then return end
                this:onClose(true)

                self:onExplainGrammar(text)
            end,
        }
    end)
end

function DualRead:onTranslateText(text)
    local target_lang = self.settings:getTargetLanguage()
    local book_title = self:getBookTitle()

    local cached = self.settings:getCachedTranslation(text, target_lang)
    if cached and #cached > 0 then
        Dialog.showTranslationCard(_("DualRead (Offline Cache)"), cached)
        return
    end

    local loading = Dialog.showLoading(_("Translating and extracting vocabulary..."))

    UIManager:scheduleIn(0.1, function()
        local raw_ai, err = self.api:translateAndLearn(text, book_title)
        Dialog.closeLoading(loading)

        if raw_ai and #raw_ai > 0 then
            local formatted = Visualizer.formatDualReadCard(text, raw_ai, self.settings:getTargetLanguageInstruction())
            self.settings:saveCachedTranslation(text, target_lang, formatted)
            Dialog.showTranslationCard(_("DualRead: Translation"), formatted)
        else
            UIManager:show(InfoMessage:new{
                text = string.format(_("Translation failed:\n%s"), tostring(err or "Unknown error")),
                timeout = 5,
            })
        end
    end)
end

function DualRead:onExplainGrammar(phrase)
    local target_lang = self.settings:getTargetLanguage()
    local book_title = self:getBookTitle()

    local loading = Dialog.showLoading(string.format(_("Analyzing grammar and idiom for '%s'..."), phrase:sub(1, 25)))

    UIManager:scheduleIn(0.1, function()
        local raw_ai, err = self.api:explainGrammarAndNuance(phrase, nil, book_title)
        Dialog.closeLoading(loading)

        if raw_ai and #raw_ai > 0 then
            local formatted = Visualizer.formatGrammarCard(phrase, raw_ai, self.settings:getTargetLanguageInstruction())
            Dialog.showGrammarCard(_("DualRead: Grammar Breakdown"), formatted)
        else
            UIManager:show(InfoMessage:new{
                text = string.format(_("Grammar analysis failed:\n%s"), tostring(err or "Unknown error")),
                timeout = 5,
            })
        end
    end)
end

function DualRead:showCustomTranslateDialog()
    local dialog
    dialog = InputDialog:new{
        title = _("Translate Custom Sentence or Paragraph"),
        input_hint = _("Paste or type foreign text here..."),
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function() UIManager:close(dialog) end,
                },
                {
                    text = _("Translate"),
                    is_enter_default = true,
                    callback = function()
                        local val = dialog:getInputText():gsub("^%s+", ""):gsub("%s+$", "")
                        UIManager:close(dialog)
                        if #val > 0 then
                            self:onTranslateText(val)
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function DualRead:addToMainMenu(menu_items)
    menu_items.dualread = {
        text = _("📖 DualRead"),
        sorting_hint = "more_tools",
        sub_item_table_func = function()
            return self:getSubMenuItems()
        end,
        sub_item_table = self:getSubMenuItems(),
    }
end

function DualRead:getSubMenuItems()
    local lang_items = {}
    local current_lang = self.settings:getTargetLanguage()

    for _, l in ipairs(self.settings:getLanguagesList()) do
        table.insert(lang_items, {
            text = l.name:gsub("^[%p%s]+", ""),
            checked_func = function() return self.settings:getTargetLanguage() == l.id end,
            callback = function() self.settings:setTargetLanguage(l.id) end,
        })
    end

    return {
        {
            text = _("Translate Custom Text / Phrase"),
            callback = function()
                self:showCustomTranslateDialog()
            end,
        },
        {
            text_func = function()
                local target = self.settings:getTargetLanguageInstruction()
                return string.format(_("Target Language: %s"), target)
            end,
            sub_item_table = lang_items,
        },
        {
            text = _("🔑 Import API Keys from Kindle Storage"),
            callback = function()
                local ok, imported, files = self.settings:importKeyFromFile()
                if ok then
                    local lines = { _("Keys imported successfully:") }
                    for prov, key in pairs(imported) do
                        local mask = #key > 8 and (key:sub(1, 4) .. "..." .. key:sub(-4)) or key
                        table.insert(lines, string.format("• %s: %s", prov:upper(), mask))
                    end
                    table.insert(lines, "\n" .. _("You can switch between Groq and Gemini anytime!"))
                    UIManager:show(InfoMessage:new{
                        text = table.concat(lines, "\n"),
                        timeout = 6,
                    })
                else
                    UIManager:show(InfoMessage:new{
                        text = _("No key files found on Kindle storage (/mnt/us/).\n\nYou can place groq_key.txt or gemini_key.txt via USB,\nthen tap this button again!"),
                        timeout = 8,
                    })
                end
            end,
        },
        {
            text_func = function()
                return string.format(_("AI Provider: %s (%s)"), self.settings:getProvider():upper(), self.settings:getModel())
            end,
            sub_item_table = {
                {
                    text = _("Groq (Free & Blazing Fast)"),
                    checked_func = function() return self.settings:getProvider() == "groq" end,
                    callback = function() self.settings:setProvider("groq") end,
                },
                {
                    text = _("Google Gemini"),
                    checked_func = function() return self.settings:getProvider() == "gemini" end,
                    callback = function() self.settings:setProvider("gemini") end,
                },
                {
                    text = _("OpenAI (GPT-4o-mini)"),
                    checked_func = function() return self.settings:getProvider() == "openai" end,
                    callback = function() self.settings:setProvider("openai") end,
                },
                {
                    text = _("DeepSeek (DeepSeek Chat)"),
                    checked_func = function() return self.settings:getProvider() == "deepseek" end,
                    callback = function() self.settings:setProvider("deepseek") end,
                },
                {
                    text = _("Local Ollama (100% Offline LAN)"),
                    checked_func = function() return self.settings:getProvider() == "ollama" end,
                    callback = function() self.settings:setProvider("ollama") end,
                },
            },
        },
        {
            text_func = function()
                return string.format(_("AI Model: %s"), self.settings:getModel())
            end,
            sub_item_table_func = function()
                local prov = self.settings:getProvider()
                if prov == "gemini" then
                    return {
                        {
                            text = _("Gemini 3.5 Flash-Lite (500 RPD Free)"),
                            checked_func = function() return self.settings:getModel() == "gemini-3.5-flash-lite" end,
                            callback = function() self.settings:setModel("gemini-3.5-flash-lite") end,
                        },
                        {
                            text = _("Gemini 2.5 Flash (20 RPD Free / Paid)"),
                            checked_func = function() return self.settings:getModel() == "gemini-2.5-flash" end,
                            callback = function() self.settings:setModel("gemini-2.5-flash") end,
                        },
                        {
                            text = _("Gemini 3.8 Flash"),
                            checked_func = function() return self.settings:getModel() == "gemini-3.8-flash" end,
                            callback = function() self.settings:setModel("gemini-3.8-flash") end,
                        },
                        {
                            text = _("Gemini 3.7 Flash"),
                            checked_func = function() return self.settings:getModel() == "gemini-3.7-flash" end,
                            callback = function() self.settings:setModel("gemini-3.7-flash") end,
                        },
                    }
                elseif prov == "groq" then
                    return {
                        {
                            text = _("GPT-OSS 120B (Recommended — 1K RPD, Best Quality)"),
                            checked_func = function() return self.settings:getModel() == "openai/gpt-oss-120b" end,
                            callback = function() self.settings:setModel("openai/gpt-oss-120b") end,
                        },
                        {
                            text = _("Qwen 3.8 27B (1K RPD — Strong Reasoning)"),
                            checked_func = function() return self.settings:getModel() == "qwen/qwen3.8-27b" end,
                            callback = function() self.settings:setModel("qwen/qwen3.8-27b") end,
                        },
                        {
                            text = _("GPT-OSS 20B (1K RPD — Fast & Lightweight)"),
                            checked_func = function() return self.settings:getModel() == "openai/gpt-oss-20b" end,
                            callback = function() self.settings:setModel("openai/gpt-oss-20b") end,
                        },
                    }
                end
                return {
                    {
                        text = string.format(_("Current: %s"), self.settings:getModel()),
                        enabled = false,
                    },
                }
            end,
        },
        {
            text_func = function()
                local prov = self.settings:getProvider()
                local cur_key = self.settings:getApiKey(prov)
                local status = (#cur_key > 0) and _("configured") or _("not set")
                return string.format(_("Edit %s Key (%s)"), prov:upper(), status)
            end,
            callback = function()
                local prov = self.settings:getProvider()
                local cur_key = self.settings:getApiKey(prov)
                local dialog
                dialog = InputDialog:new{
                    title = string.format(_("Enter %s API Key"), prov:upper()),
                    input = cur_key,
                    input_hint = prov == "groq" and "gsk_..." or (prov == "gemini" and "AIza..." or "API Key"),
                    buttons = {
                        {
                            {
                                text = _("Cancel"),
                                id = "close",
                                callback = function() UIManager:close(dialog) end,
                            },
                            {
                                text = _("Save"),
                                is_enter_default = true,
                                callback = function()
                                    local val = dialog:getInputText():gsub("[%s]+", "")
                                    self.settings:setApiKey(val, prov)
                                    UIManager:close(dialog)
                                    UIManager:show(InfoMessage:new{
                                        text = string.format(_("%s Key saved!"), prov:upper()),
                                        timeout = 2,
                                    })
                                end,
                            },
                        },
                    },
                }
                UIManager:show(dialog)
                dialog:onShowKeyboard()
            end,
        },
        {
            text = _("Browse Parallel Editions Archive"),
            callback = function()
                local out_dir = self.settings:getOutputDirectory()
                if self.ui and self.ui.onOpenFile then
                    self.ui:onOpenFile(out_dir)
                else
                    UIManager:show(InfoMessage:new{
                        text = string.format(_("DualRead editions are stored in:\n%s"), out_dir),
                        timeout = 5,
                    })
                end
            end,
        },
        {
            text = _("Clear Offline Translation Cache"),
            callback = function()
                self.settings:clearCache()
                UIManager:show(InfoMessage:new{ text = _("DualRead cache cleared."), timeout = 2 })
            end,
        },
    }
end

return DualRead
