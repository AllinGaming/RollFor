RollFor         = RollFor or {}
local m         = RollFor
m.ReyWinners    = m.ReyWinners or {}

ReyWinnersDB    = ReyWinnersDB or {}  -- SavedVariables (declared in TOC)
local RW        = m.ReyWinners

-- -------- utils (1.12 safe) --------
local function trim(s)           return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
local function ucfirst(s)
  s = s or ""
  local a = string.sub(s, 1, 1)
  local b = string.sub(s, 2)
  return string.upper(a) .. string.lower(b)
end
local function normalize_name(name)
  name = trim(name)
  if name == "" then return nil end
  return ucfirst(name)  -- “Tijana”, “Bogrim”
end
local function has_name(name)
  local n = normalize_name(name)
  if not n then return false end
  return RW._set[n] and true or false
end
local function rebuild_set()
  RW._set = {}
  local t = ReyWinnersDB.names or {}
  for i = 1, (table.getn and table.getn(t) or (m.getn and m.getn(t)) or 0) do
    local n = t[i]
    if n and n ~= "" then RW._set[n] = true end
  end
end
local function persist()
  -- compact to array
  local out, k = {}, 0
  for n, v in pairs(RW._set) do
    if v then
      k = k + 1
      out[k] = n
    end
  end
  table.sort(out) -- stable deterministic order
  ReyWinnersDB.names = out
end
-- -----------------------------------

-- ---------- public API -------------
function RW.add_winner(name)
  local n = normalize_name(name)
  if not n then return false end
  if not RW._set[n] then
    RW._set[n] = true
    persist()
    RW.update_list_ui()
    return true
  end
  return false
end

function RW.remove_winner(name)
  local n = normalize_name(name)
  if not n then return false end
  if RW._set[n] then
    RW._set[n] = nil
    persist()
    RW.update_list_ui()
    return true
  end
  return false
end

function RW.clear()
  RW._set = {}
  persist()
  RW.update_list_ui()
end
-- -----------------------------------

-- -------------- UI -----------------
local frame, edit, addBtn, rmBtn, listText
local make  -- <- forward declaration so it's an upvalue
function RW.update_list_ui()
  if not frame or not listText then
    make() 
    if not frame or not listText then return end
  end
  local lines, i = "", 0
  for n, v in pairs(RW._set) do
    if v then
      if i == 0 then lines = n else lines = lines .. "\n" .. n end
      i = i + 1
    end
  end
  if lines == "" then lines = "|cff999999(none)|r" end
  listText:SetText(lines)
end

local function make_button(name, parent, label, x, y, onclick)
  local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
  b:SetWidth(70)
  b:SetHeight(20)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  b:SetText(label)
  b:SetScript("OnClick", onclick)
  return b
end

function make()
  if frame then return end

  -- frame
  frame = CreateFrame("Frame", "RollForReyWinnersFrame", UIParent)
  frame:SetWidth(260)
  frame:SetHeight(300)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetMovable(true); frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() this:StartMoving() end)
  frame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
  frame:RegisterForDrag("LeftButton")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
  })

  -- title
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText("Rey Winners")

  -- close
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

  -- edit box
  edit = CreateFrame("EditBox", "RollForReyWinnersEdit", frame, "InputBoxTemplate")
  edit:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -42)
  edit:SetWidth(160)
  edit:SetHeight(20)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(20)

  -- add/remove
  addBtn = make_button("RollForReyAddBtn", frame, "Add", 186, -42, function()
    RW.add_winner(edit:GetText())
    edit:SetText("")
  end)
  rmBtn = make_button("RollForReyRmBtn", frame, "Remove", 186, -66, function()
    RW.remove_winner(edit:GetText())
    edit:SetText("")
  end)

  -- scroll + list
  local scroll = CreateFrame("ScrollFrame", "RollForReyScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -100)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 20)

  local child = CreateFrame("Frame", "RollForReyScrollChild", scroll)
  child:SetWidth(200); child:SetHeight(1) -- height grows with text
  scroll:SetScrollChild(child)

  listText = child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  listText:SetJustifyH("LEFT"); listText:SetJustifyV("TOP")
  listText:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
  listText:SetText("")

  frame:Hide()
end

function RW.show()   make(); frame:Show();  RW.update_list_ui() end
function RW.hide()   if frame then frame:Hide() end end
function RW.toggle() if not frame or not frame:IsShown() then RW.show() else RW.hide() end end
-- -----------------------------------

-- --------- auto-hook helpers -------
-- Call this from your “winners found” path when lane == Rey.
function RW.add_winners_array(arr)
  if not arr then return end
  local n = (table.getn and table.getn(arr)) or (m.getn and m.getn(arr)) or 0
  for i = 1, n do
    local w = arr[i]
    local nm = (w and (w.name or (w.player and w.player.name)))
    if nm then RW.add_winner(nm) end
  end
end
-- -----------------------------------

-- ---------- Slash commands ----------
SLASH_REYWIN1 = "/rey"
SlashCmdList["REYWIN"] = function(msg)
  msg = trim(msg or "")
  if msg == "" or msg == "show" then RW.toggle(); return end
  if msg == "hide"      then RW.hide(); return end
  if msg == "clear"     then RW.clear(); return end

  local cmd, rest = string.match(msg, "^(%S+)%s*(.-)$")
  if cmd == "add" then
    RW.add_winner(rest)
    return
  elseif cmd == "rm" or cmd == "remove" or cmd == "del" then
    RW.remove_winner(rest)
    return
  elseif cmd == "list" then
    local out, k = "", 0
    for n, v in pairs(RW._set) do if v then
      k = k + 1
      if k == 1 then out = n else out = out .. ", " .. n end
    end end
    if out == "" then out = "(none)" end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Rey winners:|r " .. out)
    return
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cffffff00/rey|r show|hide|add <name>|rm <name>|list|clear")
end
-- ------------------------------------
-- ===== Floating toggle button (1.12-safe, persistent) =====
local toggleBtn

local function set_point_from_db(btn, db)
  local pt      = (db and db.point)     or "CENTER"
  local relName = (db and db.rel)       or "UIParent"
  local relPt   = (db and db.relPoint)  or pt
  local x       = (db and db.x)         or 0
  local y       = (db and db.y)         or 0
  local rel     = getglobal(relName) or UIParent
  btn:SetPoint(pt, rel, relPt, x, y)
end

local function save_btn_pos(btn)
  local pt, rel, relPt, x, y = btn:GetPoint()
  ReyWinnersDB.toggle = {
    point    = pt,
    rel      = (rel and rel:GetName()) or "UIParent",
    relPoint = relPt,
    x        = x, y = y
  }
end

local function make_toggle_button()
  if toggleBtn then return end
  toggleBtn = CreateFrame("Button", "RollForReyToggleBtn", UIParent, "UIPanelButtonTemplate")
  toggleBtn:SetWidth(48)
  toggleBtn:SetHeight(20)
  toggleBtn:SetText("Rey")
  set_point_from_db(toggleBtn, ReyWinnersDB and ReyWinnersDB.toggle)
  toggleBtn:SetMovable(true)
  toggleBtn:EnableMouse(true)
  toggleBtn:RegisterForDrag("LeftButton")

  -- 1.12 handlers use 'this'
  toggleBtn:SetScript("OnClick", function()
    if m and m.ReyWinners and m.ReyWinners.toggle then m.ReyWinners.toggle() end
  end)
  toggleBtn:SetScript("OnDragStart", function() this:StartMoving() end)
  toggleBtn:SetScript("OnDragStop",  function() this:StopMovingOrSizing(); save_btn_pos(this) end)
end
-- ==========================================================

-- init database -> set
if not ReyWinnersDB.names then ReyWinnersDB.names = {} end
local init = CreateFrame("Frame")
init:RegisterEvent("VARIABLES_LOADED")
init:RegisterEvent("PLAYER_LOGOUT")
init:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    ReyWinnersDB = ReyWinnersDB or {}
    if not ReyWinnersDB.names then ReyWinnersDB.names = {} end
    rebuild_set()
    make()               -- build UI once (hidden)
    RW.update_list_ui()
    make_toggle_button()
  elseif event == "PLAYER_LOGOUT" then
    -- make sure we write latest set to SV
    persist()
  end
end)
rebuild_set()
make()  -- build UI once; starts hidden
RW.update_list_ui()
