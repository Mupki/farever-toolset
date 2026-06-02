-- ==============================================================
-- class_mechanics_tracker.lua  (was chaincast_tracker)
-- Submitted by @Mupki  (https://github.com/Mupki/farever-toolset)
-- Tested against farever-mod v1.1.2
-- License: MIT
--
-- A SMALL, curated tracker for mechanics the game under-surfaces: things
-- that are mechanically pivotal but only visible behind the character sheet
-- (passive cooldowns) or shown as a generic buff icon when they are really a
-- core class mechanic (Chaincast stacks, weapon recast windows, etc.).
--
-- This is deliberately NOT a free-form aura system. Each tracked mechanic is
-- a hand-curated MODULE below. To enable/disable one, flip its `on` flag.
-- All enabled modules show; inactive ones are greyed out.
--
-- DISPLAY TYPES:
--   "stoplight" - building (red) -> full (yellow) -> active window (green)
--   "stacks"    - N / max pips (e.g. uppercut stacks up to 10)
--   "countdown" - a single duration bar (e.g. a recast window)
--
-- Reads only farever.player.statuses() (and weapon_kind for gating). No
-- logger dependency, no os/io/network. Movable imgui window.
-- ==============================================================

-- ---------------- CURATED MODULES (edit `on` to toggle) ----------------
-- accum/proc: status ids. max_stacks/window: for the display math.
-- gate: a weapon-prefix the module is relevant to, or "" for always.
local MODULES = {
  {
    on = true, label = "Chaincast", type = "stoplight", gate = "",
    accum = "Mage_Talent_Chaincast_Accum_Status",  -- stacks 1..max
    proc  = "Mage_Talent_Chaincast_Status",         -- empowered window
    max_stacks = 4, window = 15.0,
  },
  {
    on = true, label = "Uppercut stacks", type = "stacks", gate = "Fists",
    accum = "Fists_WaterUppercut_S3",
    max_stacks = 10,
  },
  {
    on = true, label = "Wingsaber recast", type = "countdown", gate = "DS",
    proc = "DS_Bladeleaf_Skill_1Recast",
    window = 4.0,
  },
  {
    -- Self-timed cooldown ESTIMATE for a passive that has no readable CD.
    -- We start the timer when the passive's proc flag appears, count down our
    -- best-guess `cd`, and show "ready?" when it expires (it's an estimate, not
    -- the game's real timer - tune `cd` as you learn the true value; CDR will
    -- make the real cooldown shorter than this fixed guess).
    on = true, label = "Wingsaber passive", type = "cooldown_est", gate = "DS",
    proc = "DS_Bladeleaf_Passive_Status",
    cd = 20.0,   -- rank2 = 20s (rank1 = 30s); edit to match your rank
  },
}

-- Diagnostic: lists every active status (kind/dur/stacks) so you can capture
-- ids for new modules. Set false for normal use.
local DIAG = false
-- --------------------------------------------------------------------------

local function statuses()
  if not (farever.player and farever.player.statuses) then return {} end
  local ok, list = pcall(farever.player.statuses)
  if ok and type(list) == "table" then return list end
  return {}
end

local function find(list, kind)
  if not kind or kind == "" then return nil end
  for _, st in ipairs(list) do
    if st and st.kind == kind then return st end
  end
  return nil
end

local function weapon_prefix()
  if not (farever.player and farever.player.weapon_kind) then return "" end
  local ok, wk = pcall(farever.player.weapon_kind)
  if ok and type(wk) == "string" then return (wk:match("^(%a+)") or "") end
  return ""
end

-- A module is "relevant" if its gate matches the equipped weapon, or it has
-- no gate, or its status is currently active (covers talents/trinkets).
local function relevant(m, list, wprefix)
  if m.gate == "" then return true end
  if wprefix == "" then return true end           -- unknown weapon: show anyway
  if m.gate == wprefix then return true end
  if m.accum and find(list, m.accum) then return true end
  if m.proc and find(list, m.proc) then return true end
  return false
end

local function bar(frac, label)
  if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
  if imgui.progress_bar then imgui.progress_bar(frac, label or "")
  else imgui.text(label or "") end
end

-- Persistent state for cooldown_est modules: tracks whether the proc flag was
-- present last frame (for edge detection) and when the cooldown last started.
local est = {}   -- [label] = { was_present=bool, started=mono_time }

function on_init() end

function on_render()
  local list = statuses()

  if DIAG then
    imgui.text("-- active statuses (diag) --")
    for _, st in ipairs(list) do
      if st and st.kind then
        imgui.text(string.format("%s  d=%.1f s=%d",
          tostring(st.kind), st.duration or 0, st.stacks or 0))
      end
    end
    imgui.separator()
  end

  local wprefix = weapon_prefix()
  local shown = 0

  for _, m in ipairs(MODULES) do
    if m.on and relevant(m, list, wprefix) then
      shown = shown + 1
      if shown > 1 then imgui.separator() end

      if m.type == "stoplight" then
        local proc  = find(list, m.proc)
        local accum = find(list, m.accum)
        local stacks = (accum and accum.stacks) or 0
        if proc then
          local rem = proc.duration or 0
          imgui.text(m.label .. "  READY")
          bar(rem / m.window, string.format("%.1fs", rem))
        else
          local tag = stacks >= m.max_stacks and "[full - trigger]"
                      or string.format("[building %d/%d]", stacks, m.max_stacks)
          imgui.text(m.label .. "  " .. tag)
          local pips = ""
          for i = 1, m.max_stacks do pips = pips .. (i <= stacks and "[#]" or "[ ]") end
          imgui.text(pips)
        end

      elseif m.type == "stacks" then
        local accum = find(list, m.accum)
        local stacks = (accum and accum.stacks) or 0
        imgui.text(string.format("%s  %d/%d", m.label, stacks, m.max_stacks))
        local pips = ""
        for i = 1, m.max_stacks do pips = pips .. (i <= stacks and "#" or ".") end
        imgui.text(pips)

      elseif m.type == "countdown" then
        local st = find(list, m.proc)
        if st then
          local rem = st.duration or 0
          imgui.text(string.format("%s  %.1fs", m.label, rem))
          bar(rem / m.window, "")
        else
          imgui.text(m.label .. "  --")   -- greyed/inactive
        end

      elseif m.type == "cooldown_est" then
        -- ESTIMATE: the proc flag is PRESENT while the passive charge is up. Any
        -- magic damage consumes it, so the active window can be very brief. The
        -- cooldown starts when it ENDS (falling edge: present -> absent). Fixed
        -- cd guess, not the game's real timer.
        -- SAFETY: if too long passes with no flag at all (we likely missed the
        -- active blink between samples), snap to ready? rather than stay stuck.
        local now = farever.now()
        local s = est[m.label]
        if not s then s = {was_present=false, started=nil, last_seen=nil}; est[m.label] = s end
        local present = find(list, m.proc) ~= nil
        if present then
          s.started = nil; s.last_seen = now   -- charge up now: not on CD
        elseif s.was_present then
          s.started = now                       -- falling edge: just consumed, CD begins
        end
        s.was_present = present
        if present then
          imgui.text(m.label .. "  ACTIVE")
        elseif s.started then
          local elapsed = now - s.started
          local rem = m.cd - elapsed
          if rem > 0 then
            imgui.text(string.format("%s  ~%.0fs (est)", m.label, rem))
            bar(1 - (elapsed / m.cd), "")
          else
            imgui.text(m.label .. "  ready?")
          end
        elseif s.last_seen and (now - s.last_seen) > (m.cd + 5.0) then
          -- never caught a clean falling edge but it's been ages: assume ready
          imgui.text(m.label .. "  ready?")
        else
          imgui.text(m.label .. "  --")
        end
      end
    end
  end

  if shown == 0 then
    imgui.text("(no tracked mechanics for this build)")
  end
end
