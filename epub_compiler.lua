--[[--
DualRead Parallel EPUB Compiler.
Compiles a dual-language, interleaved bilingual EPUB from translated paragraphs.
Zero-dependency, pure-Lua ZIP implementation (works on all Kindle/Kobo devices without external zip binary).
--]]--

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

local bit = bit or require("bit")
local bxor = bit.bxor
local rshift = bit.rshift
local band = bit.band

local EpubCompiler = {}
EpubCompiler.__index = EpubCompiler

-- Precompute CRC32 lookup table
local crc_table = {}
for i = 0, 255 do
    local c = i
    for j = 1, 8 do
        if band(c, 1) ~= 0 then
            c = bxor(rshift(c, 1), 0xEDB88320)
        else
            c = rshift(c, 1)
        end
    end
    crc_table[i] = c
end

local function calc_crc32(str)
    local crc = 0xFFFFFFFF
    for i = 1, #str do
        local b = str:byte(i)
        local idx = band(bxor(crc, b), 0xFF)
        crc = bxor(rshift(crc, 8), crc_table[idx])
    end
    return bxor(crc, 0xFFFFFFFF)
end

local function pack16(n)
    return string.char(n % 256, math.floor(n / 256) % 256)
end

local function pack32(n)
    if n < 0 then n = n + 4294967296 end
    local b1 = n % 256
    local b2 = math.floor(n / 256) % 256
    local b3 = math.floor(n / 65536) % 256
    local b4 = math.floor(n / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end

local function writeZipFile(entries, output_path)
    local f, err = io.open(output_path, "wb")
    if not f then return false, err end

    local central_headers = {}
    local offset = 0

    for idx, e in ipairs(entries) do
        local filename = e[1]
        local data = e[2]
        local crc = calc_crc32(data)
        local size = #data

        local local_hdr = "PK\x03\x04"
            .. pack16(10)     -- version needed
            .. pack16(0)      -- flags
            .. pack16(0)      -- compression method: stored (0)
            .. pack16(0)      -- mod time
            .. pack16(0x5421) -- mod date
            .. pack32(crc)    -- crc32
            .. pack32(size)   -- comp size
            .. pack32(size)   -- uncomp size
            .. pack16(#filename)
            .. pack16(0)      -- extra len

        local local_offset = offset
        f:write(local_hdr)
        f:write(filename)
        f:write(data)

        local entry_size = #local_hdr + #filename + size
        offset = offset + entry_size

        local central_hdr = "PK\x01\x02"
            .. pack16(10)     -- ver made
            .. pack16(10)     -- ver need
            .. pack16(0)      -- flags
            .. pack16(0)      -- compression (0)
            .. pack16(0)      -- mod time
            .. pack16(0x5421) -- mod date
            .. pack32(crc)
            .. pack32(size)
            .. pack32(size)
            .. pack16(#filename)
            .. pack16(0)      -- extra len
            .. pack16(0)      -- comment len
            .. pack16(0)      -- disk start
            .. pack16(0)      -- int attr
            .. pack32(0)      -- ext attr
            .. pack32(local_offset)

        table.insert(central_headers, { central_hdr, filename })
    end

    local central_dir_offset = offset
    local central_dir_size = 0
    for idx, ch in ipairs(central_headers) do
        f:write(ch[1])
        f:write(ch[2])
        central_dir_size = central_dir_size + #ch[1] + #ch[2]
    end

    local num_entries = #entries
    local eocd = "PK\x05\x06"
        .. pack16(0) -- disk
        .. pack16(0) -- start disk
        .. pack16(num_entries)
        .. pack16(num_entries)
        .. pack32(central_dir_size)
        .. pack32(central_dir_offset)
        .. pack16(0) -- comment len

    f:write(eocd)
    f:close()
    return true
end

local function escapeXml(str)
    if not str then return "" end
    return (str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;"))
end

local CSS_STYLE = [[
@page { margin: 20px 25px; }
body {
    font-family: serif;
    line-height: 1.5;
    color: #000;
}
.masthead {
    text-align: center;
    border-bottom: 2px solid #000;
    padding-bottom: 12px;
    margin-bottom: 25px;
}
.masthead h1 {
    font-size: 2em;
    margin: 0 0 6px 0;
}
.bilingual-pair {
    margin-bottom: 20px;
    padding-bottom: 12px;
    border-bottom: 1px dotted #ccc;
}
.orig-para {
    font-size: 1.05em;
    margin-bottom: 6px;
}
.trans-para {
    font-size: 0.95em;
    color: #333;
    font-style: italic;
    background-color: #f7f7f7;
    padding: 6px 10px;
    border-left: 3px solid #666;
    margin-bottom: 6px;
}
.vocab-box {
    font-size: 0.85em;
    background: #eee;
    padding: 4px 8px;
    margin-top: 4px;
}
]]

function EpubCompiler:new(settings)
    local o = setmetatable({}, self)
    o.settings = settings
    return o
end

function EpubCompiler:compileBilingualEpub(book_title, author, pairs, target_lang)
    local out_dir = self.settings:getOutputDirectory()
    local clean_title = (book_title or "BilingualBook"):gsub("%W+", "_")
    local epub_filename = string.format("DualRead_%s_%s.epub", clean_title, os.date("%Y%m%d"))
    local epub_path = out_dir .. "/".. epub_filename

    local entries = {}

    -- 1. mimetype (first, uncompressed)
    table.insert(entries, { "mimetype", "application/epub+zip"})

    -- 2. META-INF/container.xml
    local container_xml = [[<?xml version="1.0"encoding="UTF-8"?>
<container version="1.0"xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf"media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>]]
    table.insert(entries, { "META-INF/container.xml", container_xml })

    -- 3. OEBPS/style.css
    table.insert(entries, { "OEBPS/style.css", CSS_STYLE })

    -- 4. OEBPS/chapter_1.xhtml
    local ch_html = string.format([[<?xml version="1.0"encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>%s (Bilingual Edition)</title>
  <link rel="stylesheet"type="text/css"href="style.css"/>
</head>
<body>
  <div class="masthead">
    <h1>%s</h1>
    <p><i>Bilingual Parallel Edition (%s)</i></p>
  </div>
]], escapeXml(book_title), escapeXml(book_title), escapeXml(target_lang or "Dual Language"))

    for idx, p in ipairs(pairs) do
        ch_html = ch_html .. string.format([[
  <div class="bilingual-pair">
    <div class="orig-para">%s</div>
    <div class="trans-para">%s</div>
  </div>
]], escapeXml(p.original), escapeXml(p.translation))
    end

    ch_html = ch_html .. "</body>\n</html>"
    table.insert(entries, { "OEBPS/chapter_1.xhtml", ch_html })

    -- 5. OEBPS/toc.ncx
    local ncx = string.format([[<?xml version="1.0"encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/"version="2005-1">
  <head>
    <meta name="dtb:uid"content="urn:uuid:dualread-%s"/>
    <meta name="dtb:depth"content="1"/>
    <meta name="dtb:totalPageCount"content="0"/>
    <meta name="dtb:maxPageNumber"content="0"/>
  </head>
  <docTitle><text>%s (Bilingual)</text></docTitle>
  <navMap>
    <navPoint id="np-1"playOrder="1">
      <navLabel><text>Bilingual Text</text></navLabel>
      <content src="chapter_1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>]], clean_title, escapeXml(book_title))
    table.insert(entries, { "OEBPS/toc.ncx", ncx })

    -- 6. OEBPS/content.opf
    local opf = string.format([[<?xml version="1.0"encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf"unique-identifier="BookID"version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>%s (Bilingual Parallel Edition)</dc:title>
    <dc:creator>DualRead for KOReader</dc:creator>
    <dc:language>mul</dc:language>
    <dc:identifier id="BookID">urn:uuid:dualread-%s</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx"href="toc.ncx"media-type="application/x-dtbncx+xml"/>
    <item id="style"href="style.css"media-type="text/css"/>
    <item id="ch1"href="chapter_1.xhtml"media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
  </spine>
</package>]], escapeXml(book_title), clean_title)
    table.insert(entries, { "OEBPS/content.opf", opf })

    -- 7. Write ZIP archive directly to destination
    pcall(os.remove, epub_path)
    local ok, err = writeZipFile(entries, epub_path)

    if ok and lfs.attributes(epub_path, "mode") == "file" then
        return true, epub_path
    else
        return false, tostring(err or "Failed to compile EPUB")
    end
end

return EpubCompiler
