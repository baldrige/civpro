-- Layout fixes for the PDF (LaTeX) output only.
--
-- 1. Margin portraits. Move the citation aside on the author line into the
--    portrait's margin note, so the two are one note and can't be separated.
--    Before a case heading (or a separate opinion's author line) with a
--    portrait, start a new page if the portrait won't fit. Otherwise a heading
--    near the bottom of a page leaves its portrait running off the page or
--    pushed up beside the previous section.
--
-- 2. Multi-page scans. A figure whose pages are stacked in one column (e.g. the
--    Avista orders) is taller than a page and cannot break, so it runs off the
--    bottom. Split it into one figure per page.
--
-- 3. Links whose text is itself a URL. LaTeX sets that text as one unbreakable
--    word, which runs past the narrow margin column. Typeset it with
--    \nolinkurl so it can break at slashes and dots like other URLs.
--
-- 4. Self-check answers move to a key at the end of each chapter (below).

if not quarto.doc.is_format("latex") then
  return {}
end

local PORTRAIT_WIDTH_IN = 150 / 96 -- {width=150} is in px at 96 dpi
local DEFAULT_ASPECT = 1.4         -- height / width when the file can't be read
local CITATION_IN = 0.4            -- citation aside stacked above the portrait
local HEADING_IN = 0.5             -- a heading between the break and the portrait

-- Height / width of a PNG or JPEG, read from the file header.
local function aspect(path)
  local f = io.open(path, "rb")
  if not f then return DEFAULT_ASPECT end
  local data = f:read(65536) or ""
  f:close()
  local function be(s, i, n)
    local v = 0
    for k = i, i + n - 1 do v = v * 256 + s:byte(k) end
    return v
  end
  if data:sub(1, 8) == "\137PNG\r\n\26\n" then
    return be(data, 21, 4) / be(data, 17, 4)
  end
  local i = 3 -- JPEG: scan segments for a start-of-frame marker
  while i + 8 <= #data and data:byte(i) == 0xFF do
    local marker = data:byte(i + 1)
    if marker >= 0xC0 and marker <= 0xCF and marker ~= 0xC4 and marker ~= 0xC8 and marker ~= 0xCC then
      return be(data, i + 5, 2) / be(data, i + 7, 2)
    end
    i = i + 2 + be(data, i + 2, 2)
  end
  return DEFAULT_ASPECT
end

local function margin_image(block)
  if block.t ~= "Div" or not block.classes:includes("column-margin") then
    return nil
  end
  local src
  block:walk({ Image = function(img) src = src or img.src end })
  return src
end

-- \portraitspace (defined in _quarto.yml) starts a new page when less than
-- the given height is left. Unlike \needspace it adds no favored break point.
local function portraitspace(inches)
  return pandoc.RawBlock("latex", string.format("\\portraitspace{%.2fin}", inches))
end

-- Remove a citation aside (a [..]{.aside} span) from an author-line paragraph
-- and return its content, or nil if there isn't one.
local function take_aside(para)
  if para.t ~= "Para" and para.t ~= "Plain" then return nil end
  for i, inline in ipairs(para.content) do
    if inline.t == "Span" and inline.classes:includes("aside") then
      para.content:remove(i)
      if i > 1 and para.content[i - 1].t == "Space" then
        para.content:remove(i - 1)
      end
      return inline.content
    end
  end
  return nil
end

local function reserve_portrait_space(blocks)
  local out = pandoc.List()
  for _, block in ipairs(blocks) do
    local src = margin_image(block)
    if src then
      local cite = #out >= 1 and take_aside(out[#out])
      if cite then
        block.content:insert(1, pandoc.Para(cite))
      end
      local need = CITATION_IN + PORTRAIT_WIDTH_IN * aspect(src)
      -- The portrait is anchored to the preceding author line; if a heading
      -- comes just before that, keep the heading with them too.
      local at = #out
      if at >= 2 and out[at - 1].t == "Header" then
        at = at - 1
        need = need + HEADING_IN
      end
      if at >= 1 then
        out:insert(at, portraitspace(need))
      end
    end
    out:insert(block)
  end
  return out
end

-- Images (as Figure blocks or bare Image paragraphs) directly inside a figure div.
local function figure_images(div)
  local images = pandoc.List()
  for _, b in ipairs(div.content) do
    if b.t == "Figure" then
      b:walk({ Image = function(img) images:insert(img) end })
    elseif (b.t == "Para" or b.t == "Plain") and #b.content == 1 and b.content[1].t == "Image" then
      images:insert(b.content[1])
    end
  end
  return images
end

local function split_stacked_figure(div)
  if not div.identifier:match("^fig%-") then return nil end
  local ncol = div.attributes["layout-ncol"]
  if ncol ~= nil and ncol ~= "1" then return nil end
  local images = figure_images(div)
  if #images < 2 then return nil end
  local caption = div.content[#div.content]
  if caption.t ~= "Para" then return nil end

  local out = pandoc.List()
  for k, img in ipairs(images) do
    local cap = caption.content:clone()
    cap:insert(pandoc.Str(string.format(" (page %d of %d)", k, #images)))
    local id = k == 1 and div.identifier or string.format("%s-%d", div.identifier, k)
    out:insert(pandoc.Div({
      pandoc.Para({ pandoc.Image({}, img.src, "", img.attr) }),
      pandoc.Para(cap),
    }, pandoc.Attr(id)))
  end
  return out
end

local function breakable_url_text(link)
  local text = pandoc.utils.stringify(link.content)
  -- Skip text with characters \nolinkurl would need escaped.
  if not text:match("^https?://%S+$") or text:find("[%%#{}\\^~]") then
    return nil
  end
  link.content = { pandoc.RawInline("latex", "\\nolinkurl{" .. text .. "}") }
  return link
end

-- 4. Self-check answers. On the website each "Check Your Understanding" box
--    hides its answer in a collapsed callout, but a printed page can't
--    collapse. Move each answer to a key at the end of its chapter, leaving
--    "Answer on page N" in the box and a link back to the question's page.

local function rawtex(s) return pandoc.RawInline("latex", s) end

-- The case name from "Check Your Understanding: *Case*".
local function self_check_case(div)
  local h = div.content[1]
  if not h or h.t ~= "Header" then return {} end
  local case, seen = pandoc.List(), false
  for _, il in ipairs(h.content) do
    if seen then
      if not (#case == 0 and il.t == "Space") then case:insert(il) end
    elseif il.t == "Str" and il.text == "Understanding:" then
      seen = true
    end
  end
  return case
end

local function self_check_key(blocks)
  local out, key, chapter, n = pandoc.List(), pandoc.List(), 0, 0
  local function flush()
    if #key == 0 then return end
    out:insert(pandoc.Header(2, "Answers to Check Your Understanding",
      pandoc.Attr("", { "unnumbered", "unlisted" })))
    out:extend(key)
    key = pandoc.List()
  end
  for _, block in ipairs(blocks) do
    if block.t == "Header" and block.level == 1 then
      flush()
      chapter, n = chapter + 1, 0
    elseif block.t == "Div" and block.classes:includes("self-check") then
      local keep, answer = pandoc.List(), nil
      for _, b in ipairs(block.content) do
        if b.t == "Div" and b.attributes["collapse"] then answer = b else keep:insert(b) end
      end
      if answer then
        n = n + 1
        local id = string.format("selfcheck-%d-%d", chapter, n)
        keep:insert(pandoc.Para({ rawtex("\\label{" .. id .. "-q}"), pandoc.Emph({
          pandoc.Str("Answer"), pandoc.Space(), pandoc.Str("on"), pandoc.Space(),
          pandoc.Str("page"), pandoc.Space(), rawtex("\\pageref{" .. id .. "-a}"), pandoc.Str("."),
        }) }))
        block.content = keep
        local head = pandoc.List({ rawtex("\\label{" .. id .. "-a}") })
        head:insert(pandoc.Strong(self_check_case(block)))
        head:extend({ pandoc.Space(), pandoc.Str("(question"), pandoc.Space(), pandoc.Str("on"),
          pandoc.Space(), pandoc.Str("page"), pandoc.Space(), rawtex("\\pageref{" .. id .. "-q}"),
          pandoc.Str(")") })
        key:insert(pandoc.Para(head))
        for _, b in ipairs(answer.content) do
          if b.t ~= "Header" then key:insert(b) end
        end
      end
    end
    out:insert(block)
  end
  flush()
  return out
end

return {
  { Div = split_stacked_figure, Link = breakable_url_text },
  { Pandoc = function(doc)
      doc.blocks = self_check_key(reserve_portrait_space(doc.blocks))
      return doc
    end },
}
