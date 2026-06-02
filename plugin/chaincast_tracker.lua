-- ==============================================================
-- chaincast_tracker.lua  (class mechanics tracker)
-- Submitted by @Mupki  (https://github.com/Mupki/farever-toolset)
-- Tested against farever-mod v1.1.2
-- License: MIT
--
-- A small, curated, MOVABLE overlay for mechanics the game under-surfaces
-- (Chaincast stacks, a passive's hidden cooldown). Pick your pip SHAPE, size,
-- and whether to show text labels, then drag the window where your eye wants
-- it and lock the layout. Inactive modules hold their slot (no reflow / no
-- flicker) so it reads steady at a glance.
--
-- Graphics use the v0.5.6 animation surface (draw_rect_filled / triangle /
-- circle) with graceful fallback to text. Reads only farever.player.statuses()
-- and weapon_kind. No logger dependency, no os/io/network.
-- ==============================================================

-- ================= USER SETTINGS =================
local STYLE       = "square"  -- "square" | "circle" | "diamond" | "bar"
local FONT        = 1.3       -- text size multiplier
local PIP         = 22        -- pip size in px (bump for bigger)
local PIP_GAP     = 6         -- gap between pips
local BAR_W       = 200       -- fill-bar width
local BAR_H       = 16        -- fill-bar height
local SHOW_LABELS = true      -- false = shapes only (clean locked-down look)
local DIAG        = false     -- true = dump active status ids
-- 3-stage color scheme: building -> full -> ready
-- (swap COL.yellow for COL.orange in the FULL states if you prefer orange)
-- =================================================

local MODULES = {
  {
    on = true, label = "Chaincast", type = "stoplight", gate = "",
    accum = "Mage_Talent_Chaincast_Accum_Status",
    proc  = "Mage_Talent_Chaincast_Status",
    max_stacks = 4, window = 15.0,
  },
  {
    on = true, label = "Uppercut stacks", type = "stacks", gate = "Fists",
    accum = "Fists_WaterUppercut_S3",
    max_stacks = 10,
  },
  {
    on = true, label = "Wingsaber passive", type = "cooldown_est", gate = "DS",
    proc = "DS_Bladeleaf_Passive_Status",
    cd = 20.0,   -- rank2 = 20s (rank1 = 30s)
  },
}

local COL = {
  red    = {0.95, 0.30, 0.25, 1.0},
  orange = {1.00, 0.55, 0.15, 1.0},
  yellow = {1.00, 0.82, 0.15, 1.0},
  green  = {0.35, 0.92, 0.45, 1.0},
  blue   = {0.45, 0.70, 1.00, 1.0},
  grey   = {0.40, 0.40, 0.44, 1.0},
  white  = {0.92, 0.92, 0.92, 1.0},
  track  = {0.16, 0.16, 0.19, 1.0},
}

-- ---- drawing helpers (graceful fallback to text) ----
local has_draw = nil
local function can_draw()
  if has_draw == nil then
    has_draw = (imgui.draw_rect_filled ~= nil and imgui.cursor_pos ~= nil and imgui.dummy ~= nil)
  end
  return has_draw
end
local function ctext(c, s)
  if not SHOW_LABELS then return end
  if imgui.text_colored then imgui.text_colored(c[1], c[2], c[3], c[4], s)
  else imgui.text(s) end
end

-- draw a single pip of the chosen shape at top-left (x,y), size s, color c
local function draw_shape(x, y, s, c)
  local r, g, b, a = c[1], c[2], c[3], c[4]
  if STYLE == "circle" and imgui.draw_circle_filled then
    local rad = s / 2
    imgui.draw_circle_filled(x + rad, y + rad, rad, r, g, b, a)
  elseif STYLE == "diamond" and imgui.draw_triangle_filled then
    local cx, cy = x + s/2, y + s/2
    -- two triangles forming a diamond
    imgui.draw_triangle_filled(cx, y,  x + s, cy,  cx, y + s, r, g, b, a)  -- right half
    imgui.draw_triangle_filled(cx, y,  x,     cy,  cx, y + s, r, g, b, a)  -- left half
  else -- square (default / fallback)
    imgui.draw_rect_filled(x, y, x + s, y + s, r, g, b, a)
  end
end

-- a row of pips (filled = count, in color c; empties in track color)
local function draw_pips(count, maxn, c)
  if not can_draw() then
    local s = ""
    for i = 1, maxn do s = s .. (i <= count and "[#]" or "[ ]") end
    if SHOW_LABELS or true then
      if imgui.text_colored then imgui.text_colored(c[1],c[2],c[3],c[4],s) else imgui.text(s) end
    end
    return
  end
  local x, y = imgui.cursor_pos()
  for i = 1, maxn do
    local px = x + (i - 1) * (PIP + PIP_GAP)
    draw_shape(px, y, PIP, (i <= count) and c or COL.track)
  end
  imgui.dummy(maxn * (PIP + PIP_GAP), PIP)
end

-- a fill bar (frac 0..1) in color c with a dark track
local function draw_bar(frac, c)
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
  if not can_draw() then
    if imgui.progress_bar then imgui.progress_bar(frac, "") end
    return
  end
  local x, y = imgui.cursor_pos()
  imgui.draw_rect_filled(x, y, x + BAR_W, y + BAR_H, COL.track[1], COL.track[2], COL.track[3], COL.track[4])
  if frac > 0 then
    imgui.draw_rect_filled(x, y, x + BAR_W * frac, y + BAR_H, c[1], c[2], c[3], c[4])
  end
  imgui.dummy(BAR_W, BAR_H)
end

local function statuses()
  if not (farever.player and farever.player.statuses) then return {} end
  local ok, list = pcall(farever.player.statuses)
  if ok and type(list) == "table" then return list end
  return {}
end
local function find(list, kind)
  if not kind or kind == "" then return nil end
  for _, st in ipairs(list) do if st and st.kind == kind then return st end end
  return nil
end
local function weapon_prefix()
  if not (farever.player and farever.player.weapon_kind) then return "" end
  local ok, wk = pcall(farever.player.weapon_kind)
  if ok and type(wk) == "string" then return (wk:match("^(%a+)") or "") end
  return ""
end

-- STABLE VISIBILITY: once shown, a module keeps its slot for the session so
-- rows never appear/disappear (fixes GCD flicker / jumpiness).
local shown_once = {}
local function should_show(m, list, wprefix)
  if shown_once[m.label] then return true end
  local relevant =
    (m.gate == "") or
    (wprefix ~= "" and m.gate == wprefix) or
    (m.accum and find(list, m.accum) ~= nil) or
    (m.proc  and find(list, m.proc)  ~= nil)
  if relevant then shown_once[m.label] = true end
  return relevant
end

local est = {}
function on_init() shown_once = {}; est = {} end

function on_render()
  if imgui.font_scale then imgui.font_scale(FONT) end
  local list = statuses()
  local wprefix = weapon_prefix()

  if DIAG then
    imgui.text("-- active statuses (diag) --")
    for _, st in ipairs(list) do
      if st and st.kind then
        imgui.text(string.format("%s  d=%.1f s=%d", tostring(st.kind), st.duration or 0, st.stacks or 0))
      end
    end
    imgui.separator()
  end

  local shown = 0
  for _, m in ipairs(MODULES) do
    if m.on and should_show(m, list, wprefix) then
      shown = shown + 1
      if shown > 1 and SHOW_LABELS then imgui.separator() end

      if m.type == "stoplight" then
        local proc  = find(list, m.proc)
        local accum = find(list, m.accum)
        local stacks = (accum and accum.stacks) or 0
        if proc then
          local rem = proc.duration or 0
          ctext(COL.green, m.label .. "  READY")
          draw_pips(m.max_stacks, m.max_stacks, COL.green)
        elseif stacks >= m.max_stacks then
          ctext(COL.yellow, m.label .. "  FULL - trigger")
          draw_pips(m.max_stacks, m.max_stacks, COL.yellow)
        else
          ctext(COL.red, string.format("%s  %d/%d", m.label, stacks, m.max_stacks))
          draw_pips(stacks, m.max_stacks, COL.red)
        end

      elseif m.type == "stacks" then
        local accum = find(list, m.accum)
        local stacks = (accum and accum.stacks) or 0
        local full = stacks >= m.max_stacks
        local c = full and COL.yellow or COL.blue
        ctext(c, string.format("%s  %d/%d", m.label, stacks, m.max_stacks))
        draw_pips(stacks, m.max_stacks, c)

      elseif m.type == "cooldown_est" then
        local now = farever.now()
        local s = est[m.label]
        if not s then s = {was_present=false, started=nil, last_seen=nil}; est[m.label] = s end
        local present = find(list, m.proc) ~= nil
        if present then s.started = nil; s.last_seen = now
        elseif s.was_present then s.started = now end
        s.was_present = present
        if present then
          ctext(COL.green, m.label .. "  ACTIVE")
          draw_bar(1, COL.green)
        elseif s.started then
          local elapsed = now - s.started
          local rem = m.cd - elapsed
          if rem > 0 then
            ctext(COL.red, string.format("%s  ~%.0fs (est)", m.label, rem))
            draw_bar(1 - (elapsed / m.cd), COL.red)
          else
            ctext(COL.green, m.label .. "  ready?")
            draw_bar(1, COL.green)
          end
        elseif s.last_seen and (now - s.last_seen) > (m.cd + 5.0) then
          ctext(COL.green, m.label .. "  ready?")
          draw_bar(1, COL.green)
        else
          ctext(COL.grey, m.label .. "  --")
          draw_bar(0, COL.grey)
        end
      end
    end
  end

  if shown == 0 and SHOW_LABELS then
    ctext(COL.grey, "(no tracked mechanics for this build)")
  end

  if imgui.font_scale then imgui.font_scale(1.0) end
end
