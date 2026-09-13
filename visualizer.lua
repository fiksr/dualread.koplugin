--[[--
DualRead Visualizer.
Formats bilingual passages, translations, and vocabulary cards into clean, high-contrast E-Ink Unicode cards.
--]]--

local Visualizer = {}

local function cleanLines(text)
    local lines = {}
    for l in (text or ""):gmatch("[^\r\n]+") do
        local trimmed = l:gsub("^%s+", ""):gsub("%s+$", "")
        if #trimmed > 0 then
            table.insert(lines, trimmed)
        end
    end
    return lines
end

function Visualizer.formatDualReadCard(original_text, raw_ai_text, target_lang_name)
    local out = {}
    table.insert(out, "┌──────────────────────────────────────────────────────────┐")
    table.insert(out, "│  🌐 DUALREAD: BILINGUAL TRANSLATION                      │")
    table.insert(out, string.format("│  🎯 Target: %s", target_lang_name or "Serbian (Latin)"))
    table.insert(out, "└──────────────────────────────────────────────────────────┘\n")

    table.insert(out, "📖 ━━━━ ORIGINAL TEXT ━━━━")
    local orig_lines = cleanLines(original_text)
    for _, l in ipairs(orig_lines) do
        table.insert(out, "  " .. l)
    end
    table.insert(out, "")

    local lines = cleanLines(raw_ai_text)
    for idx, l in ipairs(lines) do
        if l:find("^[#%*%-]*%s*TRANSLATION") or l:find("^[#%*%-]*%s*PREVOD") or l:find("^%*%*TRANSLATION") then
            table.insert(out, "\n🌐 ━━━━ TRANSLATION ━━━━")
        elseif l:find("^[#%*%-]*%s*VOCABULARY") or l:find("^[#%*%-]*%s*REČNIK") or l:find("^%*%*VOCABULARY") or l:find("IDIOMS") then
            table.insert(out, "\n🔤 ━━━━ VOCABULARY & IDIOMS ━━━━")
        elseif l:find("^[•%-%*]") then
            local item = l:gsub("^[•%-%*]%s*", ""):gsub("%*%*", "")
            table.insert(out, "  • " .. item)
        else
            table.insert(out, "  " .. (l:gsub("%*%*", "")))
        end
    end

    return table.concat(out, "\n")
end

function Visualizer.formatGrammarCard(phrase, raw_ai_text, target_lang_name)
    local out = {}
    table.insert(out, "┌──────────────────────────────────────────────────────────┐")
    table.insert(out, string.format("│  🔍 LINGUISTIC BREAKDOWN: %s", phrase:upper()))
    table.insert(out, string.format("│  🎯 Language: %s", target_lang_name or "Serbian (Latin)"))
    table.insert(out, "└──────────────────────────────────────────────────────────┘\n")

    local lines = cleanLines(raw_ai_text)
    for idx, l in ipairs(lines) do
        if l:find("^[#%*%-]*%s*[A-Z%s/&]+:") or l:find("^%*%*") then
            local header = l:gsub("^[#%*%-]+%s*", ""):gsub("%*+", ""):gsub(":$", "")
            table.insert(out, "\n━━━━ " .. header .. " ━━━━")
        elseif l:find("^[•%-%*]") then
            local item = l:gsub("^[•%-%*]%s*", ""):gsub("%*%*", "")
            table.insert(out, "  • " .. item)
        else
            table.insert(out, "  " .. (l:gsub("%*%*", "")))
        end
    end

    return table.concat(out, "\n")
end

return Visualizer
