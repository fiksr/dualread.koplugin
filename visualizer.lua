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
    for match in (str .. sep):gmatch("(.-)" .. sep) do
        table.insert(parts, match)
    end
    return parts
end

local function stripMarkdown(s)
    if not s then return "" end
    local clean = s:gsub("[\240-\244][\128-\191][\128-\191][\128-\191]", "")
    clean = clean:gsub("\239\184[\144-\159]", "")
    clean = clean:gsub("%*%*", ""):gsub("%*", ""):gsub("^[#%s]+", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return clean
end

function Visualizer.formatDualReadCard(original_text, raw_ai_text, target_lang_name)
    local out = {}
    table.insert(out, "==================================================")
    table.insert(out, "DUALREAD: BILINGUAL TRANSLATION")
    table.insert(out, "Target Language: " .. (target_lang_name or "Serbian (Latin)"))
    table.insert(out, "==================================================\n")

    table.insert(out, "--- ORIGINAL TEXT ---")
    local orig_lines = cleanLines(original_text)
    for _, l in ipairs(orig_lines) do
        table.insert(out, l)
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
            if #parts >= 2 then
                local first_lower = parts[1]:lower()
                if first_lower ~= "word" and first_lower ~= "original" and first_lower ~= "term" then
                    local extra = parts[3] and (" (" .. parts[3] .. ")") or ""
                    table.insert(out, string.format("• %s ➔ %s%s", parts[1], parts[2], extra))
                end
            end
        elseif l:find("^[#%*%-]*%s*[A-Z%s/&]+:") or (l:find("^[A-Z]") and #l < 40 and not l:find("%.")) then
            local header = stripMarkdown(l):gsub(":$", "")
            table.insert(out, "\n--- " .. header:upper() .. " ---\n")
        elseif l:find("^[•%-%*]") then
            local item = stripMarkdown(l:gsub("^[•%-%*]%s*", ""))
            table.insert(out, "• " .. item)
        else
            table.insert(out, (stripMarkdown(l)))
        end
    end

    return table.concat(out, "\n")
end

return Visualizer
