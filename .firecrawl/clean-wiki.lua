-- clean-wiki.lua — pandoc Lua filter for offline, LLM-friendly wiki Markdown.
--
-- Runs on the parsed AST *before* the Markdown writer. Pandoc applies these
-- element functions bottom-up (children before parents), so by the time the
-- Table filter flattens a cell, the images inside it are already stripped and
-- its links already rewritten.
--
--   1. Raw HTML (RawBlock/RawInline) is removed.
--   2. MediaWiki page chrome (edit links, nav boxes, TOC, ...) is dropped by class.
--   3. Sprite/icon images are stripped; the now-empty icon links are dropped.
--   4. Internal wiki links are rewritten to local "<Title>.md" navigation
--      (handles /w/, /wiki/, /index.php, ?title=, and -f mediawiki wikilinks).
--   5. Non-breaking spaces are normalized to regular spaces.
--   6. Table cells are flattened to inline so the table renders as a pipe table
--      (in-cell bullet lists are joined with "; ").

-- ---- helpers -------------------------------------------------------------

local function urldecode(s)
  s = s:gsub('+', ' ')
  s = s:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
  return s
end

-- Returns "<Title>.md[#anchor]" for an internal wiki page, or nil to leave the
-- link unchanged (external links, or namespaced pages like File:/Category: that
-- cannot be a valid local filename on Windows).
local function to_local(raw)
  local anchor = ''
  local h = raw:find('#', 1, true)
  if h then anchor = raw:sub(h + 1); raw = raw:sub(1, h - 1) end

  local title = urldecode(raw)
  if title == '' then return nil end
  if title:find(':') then return nil end           -- File:/Category:/Special:/...
  title = title:gsub(' ', '_')

  local out = title .. '.md'
  if anchor ~= '' then out = out .. '#' .. anchor end
  return out
end

local function append_all(dst, src)
  for _, x in ipairs(src) do dst[#dst + 1] = x end
end

-- Squash a cell's block content into a single inline sequence. Bullet/ordered
-- list items are separated with "; "; other blocks with a space.
local function flatten_blocks(blocks)
  local out = {}
  local first = true
  local function sep()
    if first then first = false
    else out[#out + 1] = pandoc.Str(';'); out[#out + 1] = pandoc.Space() end
  end
  for _, b in ipairs(blocks) do
    if b.t == 'BulletList' or b.t == 'OrderedList' then
      for _, item in ipairs(b.content) do
        sep()
        append_all(out, pandoc.utils.blocks_to_inlines(item, { pandoc.Space() }))
      end
    else
      sep()
      append_all(out, pandoc.utils.blocks_to_inlines({ b }, { pandoc.Space() }))
    end
  end
  -- pipe tables cannot contain line breaks; collapse them to spaces
  for i, x in ipairs(out) do
    if x.t == 'LineBreak' or x.t == 'SoftBreak' then out[i] = pandoc.Space() end
  end
  return out
end

-- ---- 1. raw HTML removal -------------------------------------------------

function RawBlock(el)
  if el.format:match('^html') then return {} end
  return el
end

function RawInline(el)
  if el.format:match('^html') then return {} end
  return el
end

-- ---- 2. MediaWiki chrome removal (by CSS class) --------------------------

local DROP = {
  ['mw-editsection']     = true,  -- the "[edit]" links next to headings
  ['mw-jump-link']       = true,
  ['toc']                = true,  -- table of contents block
  ['navbox']             = true,  -- bottom navigation boxes
  ['noprint']            = true,
  ['metadata']           = true,  -- hatnotes / ambox notices
  ['printfooter']        = true,
  ['catlinks']           = true,  -- category footer
  ['mw-references-wrap'] = true,
  ['reference']          = true,  -- inline [1]-style citation markers
}

local function drops(attr)
  for _, c in ipairs(attr.classes) do
    if DROP[c] then return true end
  end
  return false
end

-- Drop chrome by class; otherwise unwrap the wrapper (keep its content) so no
-- fenced-div / bracketed-span markup leaks into the Markdown.
function Div(el)  if drops(el.attr) then return {} end return el.content end
function Span(el) if drops(el.attr) then return {} end return el.content end

-- ---- 3. strip sprite/icon images -----------------------------------------

function Image(_) return {} end

-- ---- 4. non-breaking space normalization ---------------------------------

function Str(el)
  if el.text:find('\194\160', 1, true) then          -- U+00A0 in UTF-8
    el.text = el.text:gsub('\194\160', ' ')
  end
  return el
end

-- ---- 5. internal link rewriting ------------------------------------------

function Link(el)
  -- Drop links with no visible text (e.g. icon-only links emptied by Image strip).
  if pandoc.utils.stringify(el.content):match('^%s*$') then return {} end
  el.attr = pandoc.Attr()   -- drop stray link classes like {.mw-redirect}

  -- Wikilinks from the `-f mediawiki` reader (action=raw source) carry title "wikilink".
  if el.title == 'wikilink' then
    local loc = to_local(el.target)
    if loc then el.target = loc; el.title = '' end
    return el
  end

  -- Internal links from the HTML (action=render) source. This wiki uses /w/ short URLs.
  local internal = el.target:match('[?&]title=([^&#]+)')
                or el.target:match('/index%.php/([^?#]+)')
                or el.target:match('/wiki/([^?#]+)')
                or el.target:match('/w/([^?#]+)')
  if internal then
    local anchor = el.target:match('#(.*)$')
    if anchor then internal = internal .. '#' .. anchor end
    local loc = to_local(internal)
    if loc then el.target = loc; el.title = '' end
  end
  return el
end

-- ---- 6. expand merged cells + flatten so tables render as pipe tables -------

-- Expand a row list into a full ncols grid, resolving rowspan/colspan by
-- forward-filling the merged value into every covered cell. Pipe tables cannot
-- express merged cells, and forward-filling also makes each row self-contained.
local function expand_rows(rows, ncols)
  local out = {}
  local carry = {}                 -- carry[col] = { n, contents, align, attr }
  for _, row in ipairs(rows) do
    local cells = {}
    local col, si = 1, 1
    while col <= ncols do
      local c = carry[col]
      if c and c.n > 0 then
        cells[col] = pandoc.Cell(c.contents, c.align, 1, 1, c.attr)
        c.n = c.n - 1
        if c.n == 0 then carry[col] = nil end
        col = col + 1
      else
        local cell = row.cells[si]; si = si + 1
        if not cell then
          cells[col] = pandoc.Cell({})
          col = col + 1
        else
          local cs = math.max(cell.col_span or 1, 1)
          local rs = math.max(cell.row_span or 1, 1)
          for k = 0, cs - 1 do
            local cc = col + k
            if cc <= ncols then
              cells[cc] = pandoc.Cell(cell.contents, cell.alignment, 1, 1, cell.attr)
              if rs > 1 then
                carry[cc] = { n = rs - 1, contents = cell.contents,
                              align = cell.alignment, attr = cell.attr }
              end
            end
          end
          col = col + cs
        end
      end
    end
    out[#out + 1] = pandoc.Row(cells)
  end
  return out
end

function Table(tbl)
  -- Drop navigation-footer tables (the site-wide navbox re-lists every page and
  -- carries no facts not already in the page's own tables).
  for _, c in ipairs(tbl.attr.classes) do
    if c:find('navbox') then return {} end
  end
  -- Drop explicit column widths (style="width:N%"); pipe tables cannot encode
  -- widths, and their presence forces grid tables.
  for i, spec in ipairs(tbl.colspecs) do
    tbl.colspecs[i] = { spec[1], pandoc.ColWidthDefault }
  end
  local ncols = #tbl.colspecs

  local function process(rows)
    local expanded = expand_rows(rows, ncols)
    for _, row in ipairs(expanded) do
      for _, cell in ipairs(row.cells) do
        cell.contents = { pandoc.Plain(flatten_blocks(cell.contents)) }
      end
    end
    return expanded
  end

  tbl.head.rows = process(tbl.head.rows)
  for _, b in ipairs(tbl.bodies) do
    b.head = process(b.head)
    b.body = process(b.body)
  end
  tbl.foot.rows = process(tbl.foot.rows)
  return tbl
end

-- ---- 7. drop non-content sections (heading + everything under it) ---------

-- Heading titles (lower-cased) whose whole section is boilerplate, not facts.
local DROP_SECTIONS = {
  ['external links'] = true,
  ['update history'] = true,
  ['trivia']         = true,
  ['tips']           = true,
  ['gallery']        = true,
}

function Pandoc(doc)
  local out = {}
  local skip_level = nil          -- when set, skip until a header of level <= this
  for _, blk in ipairs(doc.blocks) do
    if blk.t == 'Header' then
      if skip_level and blk.level <= skip_level then skip_level = nil end
      if not skip_level then
        local title = pandoc.utils.stringify(blk):lower():gsub('^%s+', ''):gsub('%s+$', '')
        if DROP_SECTIONS[title] then skip_level = blk.level end
      end
    end
    if not skip_level then out[#out + 1] = blk end
  end
  doc.blocks = out
  return doc
end
