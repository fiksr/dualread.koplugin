--[[--
DualRead Visualizer.
Formats bilingual passages, translations, and vocabulary cards into clean, high-contrast E-Ink typography.
Zero broken markdown tables, zero missing emoji boxes.
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

local function splitByChar(str, sep)
    local parts = {}
    for match in (str .. sep):gmatch("(.-)".. sep) do
        table.insert(parts, match)
    end
    return parts
end

local function stripMarkdown(s)
    if not s then return "" end
    local clean = s:gsub("%*%*", ""):gsub("%*", ""):gsub("^[#%s]+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return clean
end

function Visualizer.formatDualReadCard(original_text, raw_ai_text, target_lang_name)
    local out = {}
    table.insert(out, "==================================================")
    table.insert(out, "DUALREAD: BILINGUAL TRANSLATION")
    table.insert(out, "Target Language: ".. (target_lang_name or "Serbian (Latin)"))
    table.insert(out, "==================================================\n")

    table.insert(out, "--- ORIGINAL TEXT ---")
    local orig_lines = cleanLines(original_text)
    for _, l in ipairs(orig_lines) do
        table.insert(out, "".. l)
    end
    table.insert(out, "")

    local lines = cleanLines(raw_ai_text)
    for idx, l in ipairs(lines) do
        if l:find("^|%s*%-") or l:find("^|%s*:") then
            -- skip table separator
        elseif l:sub(1, 1) == "|" and l:sub(-1) == "|" then
            local raw_parts = splitByChar(l:sub(2, -2), "|")
            local parts = {}
            for _, p in ipairs(raw_parts) do
                local clean = stripMarkdown(p)
                if #clean > 0 then table.insert(parts, clean) end
            end
            local first_lower = parts[1] and parts[1]:lower() or ""
            if first_lower ~= "element" and first_lower ~= "word" and first_lower ~= "term" and first_lower ~= "original" then
                if #parts >= 3 then
                    table.insert(out, string.format("• %s: %s\n  %s\n", parts[1], parts[2], parts[3]))
                elseif #parts == 2 then
                    table.insert(out, string.format("• %s\n  %s\n", parts[1], parts[2]))
                end
            end
        elseif l:find("^[#%*%-]*%s*TRANSLATION") or l:find("^[#%*%-]*%s*PREVOD") or l:find("^%*%*TRANSLATION") then
            table.insert(out, "\n--- TRANSLATION ---\n")
        elseif l:find("^[#%*%-]*%s*VOCABULARY") or l:find("^[#%*%-]*%s*REČNIK") or l:find("^%*%*VOCABULARY") or l:find("IDIOMS") then
            table.insert(out, "\n--- VOCABULARY & IDIOMS ---\n")
        elseif l:find("^[•%-%*]") then
            local item = stripMarkdown(l:gsub("^[•%-%*]%s*", ""))
            local k, v = item:match("^(.-):%s*(.+)$")
            if k and v then
                table.insert(out, string.format("• %s:\n  %s\n", k, v))
            else
                table.insert(out, "• ".. item)
            end
        else
            table.insert(out, (stripMarkdown(l)))
        end
    end

    return table.concat(out, "\n")
end

function Visualizer.formatGrammarCard(phrase, raw_ai_text, target_lang_name)
    local out = {}
    table.insert(out, "==================================================")
    table.insert(out, "LINGUISTIC BREAKDOWN: ".. phrase:upper())
    table.insert(out, "Language: ".. (target_lang_name or "Serbian (Latin)"))
    table.insert(out, "==================================================\n")

    local lines = cleanLines(raw_ai_text)
    for idx, l in ipairs(lines) do
        if l:find("^|%s*%-") or l:find("^|%s*:") then
            -- skip
        elseif l:sub(1, 1) == "|" and l:sub(-1) == "|" then
            local raw_parts = splitByChar(l:sub(2, -2), "|")
            local parts = {}
            for _, p in ipairs(raw_parts) do
                local clean = stripMarkdown(p)
                if #clean > 0 then table.insert(parts, clean) end
            end
            local first_lower = parts[1] and parts[1]:lower() or ""
            if first_lower ~= "element" and first_lower ~= "word" and first_lower ~= "item" then
                if #parts >= 3 then
                    table.insert(out, string.format("• %s (%s):\n  %s\n", parts[1], parts[2], parts[3]))
                elseif #parts == 2 then
                    table.insert(out, string.format("• %s:\n  %s\n", parts[1], parts[2]))
                end
            end
        elseif l:find("^[#%*%-]*%s*[A-Z%s/&]+:") or l:find("^%*%*") then
            local header = stripMarkdown(l):gsub(":$", "")
            table.insert(out, "\n--- ".. header:upper() .. "---\n")
        elseif l:find("^[•%-%*]") then
            local item = stripMarkdown(l:gsub("^[•%-%*]%s*", ""))
            table.insert(out, "• ".. item)
        else
            table.insert(out, (stripMarkdown(l)))
        end
    end

    return table.concat(out, "\n")
end

return Visualizer
