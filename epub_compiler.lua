--[[--
DualRead Parallel EPUB Compiler.
Compiles a dual-language, interleaved bilingual EPUB from translated paragraphs.
--]]--

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

local EpubCompiler = {}
EpubCompiler.__index = EpubCompiler

local function escapeXml(str)
    if not str then return "" end
    return str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
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
    local epub_path = out_dir .. "/" .. epub_filename

    local build_dir = "/tmp/dualread_build"
    if lfs.attributes("/tmp", "mode") ~= "directory" then
        build_dir = DataStorage:getFullDataDir() .. "/cache/dualread_build"
        pcall(lfs.mkdir, DataStorage:getFullDataDir() .. "/cache")
    end

    pcall(os.execute, "rm -rf '" .. build_dir .. "'")
    pcall(lfs.mkdir, build_dir)
    pcall(lfs.mkdir, build_dir .. "/META-INF")
    pcall(lfs.mkdir, build_dir .. "/OEBPS")

    -- 1. mimetype (first, uncompressed)
    local f_mime = io.open(build_dir .. "/mimetype", "w")
    if f_mime then
        f_mime:write("application/epub+zip")
        f_mime:close()
    end

    -- 2. container.xml
    local f_cont = io.open(build_dir .. "/META-INF/container.xml", "w")
    if f_cont then
        f_cont:write([[<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>]])
        f_cont:close()
    end

    -- 3. style.css
    local f_css = io.open(build_dir .. "/OEBPS/style.css", "w")
    if f_css then
        f_css:write(CSS_STYLE)
        f_css:close()
    end

    -- 4. chapter_1.xhtml
    local ch_html = string.format([[<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>%s (Bilingual Edition)</title>
  <link rel="stylesheet" type="text/css" href="style.css"/>
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

    local f_ch = io.open(build_dir .. "/OEBPS/chapter_1.xhtml", "w")
    if f_ch then
        f_ch:write(ch_html)
        f_ch:close()
    end

    -- 5. toc.ncx
    local ncx = string.format([[<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="urn:uuid:dualread-%s"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle><text>%s (Bilingual)</text></docTitle>
  <navMap>
    <navPoint id="np-1" playOrder="1">
      <navLabel><text>Bilingual Text</text></navLabel>
      <content src="chapter_1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>]], clean_title, escapeXml(book_title))

    local f_ncx = io.open(build_dir .. "/OEBPS/toc.ncx", "w")
    if f_ncx then
        f_ncx:write(ncx)
        f_ncx:close()
    end

    -- 6. content.opf
    local opf = string.format([[<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookID" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>%s (Bilingual Parallel Edition)</dc:title>
    <dc:creator>DualRead for KOReader</dc:creator>
    <dc:language>mul</dc:language>
    <dc:identifier id="BookID">urn:uuid:dualread-%s</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="style" href="style.css" media-type="text/css"/>
    <item id="ch1" href="chapter_1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="ch1"/>
  </spine>
</package>]], escapeXml(book_title), clean_title)

    local f_opf = io.open(build_dir .. "/OEBPS/content.opf", "w")
    if f_opf then
        f_opf:write(opf)
        f_opf:close()
    end

    -- 7. Zip into EPUB
    pcall(os.remove, epub_path)
    local zip_cmd = string.format(
        "cd '%s' && zip -q -0 -X '%s' mimetype && zip -q -9 -r '%s' META-INF OEBPS",
        build_dir, epub_path, epub_path
    )
    os.execute(zip_cmd)
    pcall(os.execute, "rm -rf '" .. build_dir .. "'")

    if lfs.attributes(epub_path, "mode") == "file" then
        return true, epub_path
    else
        return false, "Failed to compile EPUB"
    end
end

return EpubCompiler
