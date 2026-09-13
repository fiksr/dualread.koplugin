--[[--
DualRead AI Translation & Linguistics Engine.
Handles literary paragraph translations, vocabulary extraction, and grammar breakdowns.
--]]--

local API = {}
API.__index = API

local json = nil
local ok, mod = pcall(require, "json")
if ok and mod and mod.decode then json = mod
else
    ok, mod = pcall(require, "rapidjson")
    if ok and mod and mod.decode then json = mod end
end

local function encodeJSON(val)
    if json and json.encode then return json.encode(val) end
    if type(val) == "string"then
        return string.format('"%s"', val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', ''))
    elseif type(val) == "number"or type(val) == "boolean"then
        return tostring(val)
    elseif type(val) == "table"then
        local is_array = (#val > 0)
        local parts = {}
        if is_array then
            for idx, v in ipairs(val) do
                table.insert(parts, encodeJSON(v))
            end
            return "[".. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(val) do
                table.insert(parts, string.format('"%s":%s', k, encodeJSON(v)))
            end
            return "{".. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function decodeJSON(str)
    if json and json.decode then
        local ok_dec, res = pcall(json.decode, str)
        if ok_dec and res then return res end
    end
    return nil
end

function API:new(settings)
    local o = setmetatable({}, self)
    o.settings = settings
    return o
end

function API:sendChat(messages, system_prompt, max_tokens)
    local provider = self.settings:getProvider()
    local api_key = self.settings:getApiKey(provider)
    local model = self.settings:getModel()
    max_tokens = max_tokens or 650

    if provider ~= "ollama"and #api_key == 0 then
        return nil, string.format("API Key for %s is not set", provider:upper())
    end

    local url
    local headers = { "Content-Type: application/json"}
    local all_messages = {}

    if system_prompt and #system_prompt > 0 then
        table.insert(all_messages, { role = "system", content = system_prompt })
    end
    for idx, m in ipairs(messages) do
        table.insert(all_messages, m)
    end

    if provider == "groq"then
        url = "https://api.groq.com/openai/v1/chat/completions"
        table.insert(headers, "Authorization: Bearer ".. api_key)
    elseif provider == "gemini"then
        url = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
        table.insert(headers, "Authorization: Bearer ".. api_key)
    elseif provider == "openai"then
        url = "https://api.openai.com/v1/chat/completions"
        table.insert(headers, "Authorization: Bearer ".. api_key)
    elseif provider == "deepseek"then
        url = "https://api.deepseek.com/chat/completions"
        table.insert(headers, "Authorization: Bearer ".. api_key)
    elseif provider == "ollama"then
        local base = self.settings:getOllamaUrl()
        url = base .. "/v1/chat/completions"
    end

    local payload = {
        model = model,
        messages = all_messages,
        temperature = 0.2,
        max_tokens = max_tokens,
    }

    local body_str = encodeJSON(payload)
    local safe_body = body_str:gsub("'", "'\\''")
    local header_args = ""
    for idx, h in ipairs(headers) do
        header_args = header_args .. string.format(' -H "%s"', h)
    end

    local cmd = string.format("curl -s -k -m 20 -X POST %s -d '%s' '%s' 2>/dev/null", header_args, safe_body, url)
    local handle = io.popen(cmd)
    if not handle then return nil, "Network execution failed"end
    local raw = handle:read("*a")
    handle:close()

    if not raw or #raw == 0 then return nil, "No response from AI server"end
    local res = decodeJSON(raw)
    if not res then return nil, "Invalid JSON received from server"end
    if res.error then
        local msg = (type(res.error) == "table"and res.error.message) or tostring(res.error)
        return nil, msg
    end
    if res.choices and res.choices[1] and res.choices[1].message then
        return res.choices[1].message.content
    end
    return nil, "Unexpected response format"
end

-- 1. Full Literary Translation + Vocabulary Extraction
function API:translateAndLearn(original_text, book_title)
    local target_lang = self.settings:getTargetLanguageInstruction()

    local system_prompt = string.format([[
You are a master literary translator and language tutor assisting a reader with the book "%s".
Translate the given passage faithfully into %s.

CRITICAL TRANSLATION GUIDELINES:
1. Provide a fluent, natural literary translation that preserves the original tone, mood, and nuance.
2. If translating to Serbian, strictly use the Latin alphabet (latinica) with natural phrasing.
3. Extract 2 to 4 challenging words, idioms, or collocations from the passage that are beneficial for language learners.

STRUCTURE YOUR OUTPUT CLEARLY WITH THESE HEADINGS:
- TRANSLATION: The complete, natural translation of the passage.
- VOCABULARY & IDIOMS:
  • [Original word/phrase] ([part of speech]) ── [Translation & context definition]
]], book_title or "Current Book", target_lang)

    local user_prompt = string.format("Passage to translate:\n\n%s", original_text:sub(1, 2000))
    return self:sendChat({ { role = "user", content = user_prompt } }, system_prompt, 750)
end

-- 2. Grammar & Idiom Deep Dive
function API:explainGrammarAndNuance(selected_phrase, sentence_context, book_title)
    local target_lang = self.settings:getTargetLanguageInstruction()

    local system_prompt = string.format([[
You are an expert language teacher and linguist assisting a reader reading "%s".
Explain the linguistic nuance, grammar structure, and meaning of the highlighted phrase in %s.

STRUCTURE YOUR OUTPUT:
- MEANING: Literal vs. idiomatic meaning in context.
- GRAMMAR & NUANCE: Brief breakdown of tense, tone, or grammatical construction.
- EXAMPLE: 1 simple example sentence using this phrase in the target language.
]], book_title or "Current Book", target_lang)

    local user_prompt = string.format("Phrase: %s\nFull Context Sentence: %s", selected_phrase, sentence_context or selected_phrase)
    return self:sendChat({ { role = "user", content = user_prompt } }, system_prompt, 550)
end

return API
