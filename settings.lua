--[[--
DualRead Settings & Cache Manager.
Manages target language, translation preferences, API keys, and offline translation cache.
--]]--

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

local Settings = {}
Settings.__index = Settings

local DEFAULT_MODELS = {
    groq = "openai/gpt-oss-120b",
    gemini = "gemini-3.5-flash-lite",
    openai = "gpt-4o-mini",
    deepseek = "deepseek-chat",
    ollama = "llama3:latest",
}

local TARGET_LANGUAGES = {
    { id = "serbian", name = "Serbian (Srpski - Latin)", instruction = "Serbian (Latin alphabet / latinica)"},
    { id = "english", name = "English", instruction = "English"},
    { id = "german", name = "German (Deutsch)", instruction = "German (Deutsch)"},
    { id = "spanish", name = "Spanish (Español)", instruction = "Spanish (Español)"},
    { id = "french", name = "French (Français)", instruction = "French (Français)"},
    { id = "italian", name = "Italian (Italiano)", instruction = "Italian (Italiano)"},
    { id = "russian", name = "Russian (Русский)", instruction = "Russian (Русский)"},
}

function Settings:new()
    local o = setmetatable({}, self)
    return o
end

function Settings:get(key, default)
    if not G_reader_settings then return default end
    local val = G_reader_settings:readSetting("dualread_".. key)
    if val ~= nil then return val end
    return default
end

function Settings:save(key, val)
    if not G_reader_settings then return end
    G_reader_settings:saveSetting("dualread_".. key, val)
end

function Settings:getTargetLanguage()
    return self:get("target_language", "serbian")
end

function Settings:setTargetLanguage(lang)
    self:save("target_language", lang)
end

function Settings:getTargetLanguageInstruction()
    local lang_id = self:getTargetLanguage()
    for _, l in ipairs(TARGET_LANGUAGES) do
        if l.id == lang_id then
            return l.instruction
        end
    end
    return "Serbian (Latin alphabet / latinica)"
end

function Settings:getLanguagesList()
    return TARGET_LANGUAGES
end

function Settings:getProvider()
    return self:get("provider", "groq")
end

function Settings:setProvider(p)
    self:save("provider", p)
end

function Settings:getModel()
    local prov = self:getProvider()
    return self:get("model_".. prov, DEFAULT_MODELS[prov] or "openai/gpt-oss-120b")
end

function Settings:setModel(m)
    local prov = self:getProvider()
    self:save("model_".. prov, m)
end

function Settings:getOllamaUrl()
    return self:get("ollama_url", "http://192.168.1.100:11434")
end

function Settings:setOllamaUrl(url)
    self:save("ollama_url", url)
end

function Settings:getApiKey(prov)
    prov = prov or self:getProvider()
    local val = self:get("api_key_".. prov, "")
    if val and #val > 0 then return val end

    -- Fallback to shared keys from bookrecap, mindmap, or morningpaper
    if G_reader_settings then
        local shared_br = G_reader_settings:readSetting("bookrecap_api_key_".. prov)
        if shared_br and #shared_br > 0 then return shared_br end

        local shared_mm = G_reader_settings:readSetting("mindmap_api_key_".. prov)
        if shared_mm and #shared_mm > 0 then return shared_mm end

        local shared_mp = G_reader_settings:readSetting("morningpaper_api_key_".. prov)
        if shared_mp and #shared_mp > 0 then return shared_mp end

        local legacy = G_reader_settings:readSetting("bookrecap_api_key")
        if legacy and #legacy > 0 then
            if prov == "groq"and legacy:sub(1, 4) == "gsk_"then return legacy end
            if prov == "gemini"and legacy:sub(1, 4) == "AIza"then return legacy end
        end
    end
    return ""
end

function Settings:setApiKey(key, prov)
    prov = prov or self:getProvider()
    self:save("api_key_".. prov, key)
end

function Settings:importKeyFromFile()
    local paths = {
        "/mnt/us/groq_key.txt",
        "/mnt/us/gemini_key.txt",
        "/mnt/us/ai_key.txt",
        DataStorage:getFullDataDir() .. "/groq_key.txt",
        DataStorage:getFullDataDir() .. "/gemini_key.txt",
    }
    local imported = {}
    local files_found = {}

    for idx, path in ipairs(paths) do
        if lfs.attributes(path, "mode") == "file"then
            local f = io.open(path, "r")
            if f then
                local content = f:read("*a")
                f:close()
                if content and #content > 0 then
                    content = content:gsub("[%s]+", "")
                    table.insert(files_found, path)
                    if path:match("groq") or content:sub(1, 4) == "gsk_"then
                        self:setApiKey(content, "groq")
                        imported["groq"] = content
                    elseif path:match("gemini") or content:sub(1, 4) == "AIza"then
                        self:setApiKey(content, "gemini")
                        imported["gemini"] = content
                    end
                end
            end
        end
    end

    return next(imported) ~= nil, imported, files_found
end

-- Cache management
function Settings:getCacheKey(text, target_lang)
    local hash = 0
    for i = 1, #text do
        hash = (hash * 31 + text:byte(i)) % 2147483647
    end
    return string.format("%s_%d", target_lang, hash)
end

function Settings:getCachedTranslation(text, target_lang)
    local cache = self:get("cache_translations", {})
    local key = self:getCacheKey(text, target_lang)
    return cache[key]
end

function Settings:saveCachedTranslation(text, target_lang, content)
    local cache = self:get("cache_translations", {})
    local key = self:getCacheKey(text, target_lang)
    cache[key] = content
    self:save("cache_translations", cache)
end

function Settings:clearCache()
    self:save("cache_translations", {})
end

function Settings:getOutputDirectory()
    local default_dir = "/mnt/us/documents/DualRead"
    if lfs.attributes("/mnt/us", "mode") == "directory"then
        pcall(lfs.mkdir, "/mnt/us/documents")
        pcall(lfs.mkdir, "/mnt/us/documents/DualRead")
        return default_dir
    end
    local data_dir = DataStorage:getFullDataDir() .. "/documents/DualRead"
    pcall(lfs.mkdir, DataStorage:getFullDataDir() .. "/documents")
    pcall(lfs.mkdir, data_dir)
    return data_dir
end

return Settings
