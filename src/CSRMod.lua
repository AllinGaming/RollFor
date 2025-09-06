CSRModData = {}

-- Utility to split a line by tab using string.find/sub (no string.match)
local function ParseLine(line)
    local words = {}
    local lastPos = 1
    while true do
        local startPos, endPos = string.find(line, "[ \t]+", lastPos)
        if not startPos then
            table.insert(words, string.sub(line, lastPos))
            break
        end
        table.insert(words, string.sub(line, lastPos, startPos - 1))
        lastPos = endPos + 1
    end

    if table.getn(words) < 3 then return nil end

    -- Rebuild the item name from everything except last two elements
    local item = table.concat(words, " ", 1, table.getn(words) - 2)
    local player = words[table.getn(words) - 1]
    local count = tonumber(words[table.getn(words)])

    if not item or not player or not count then return nil end

    return item, player, count
end


-- UI for paste input
local function CreateImportWindow()
    if CSRModFrame then
        if CSRModFrame:IsShown() then
            CSRModFrame:Hide()
        else
            CSRModFrame:Show()
        end
        return
    end

    local f = CreateFrame("Frame", "CSRModFrame", UIParent)
    f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", tile = true, tileSize = 16})
    f:SetBackdropColor(0, 0, 0, 0.8)
    f:SetWidth(500)
    f:SetHeight(400)
    f:SetPoint("CENTER", UIParent)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -10)
    f.title:SetText("Paste CSRMod Data")

    local scrollFrame = CreateFrame("ScrollFrame", "CSRModScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 16, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 45)

    local editBox = CreateFrame("EditBox", "CSRModEditBox", scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(440)
    editBox:SetHeight(1000)
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)

    scrollFrame:SetScrollChild(editBox)

    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetWidth(100)
    importBtn:SetHeight(22)
    importBtn:SetText("Import")
    importBtn:SetPoint("BOTTOM", 0, 10)

    importBtn:SetScript("OnClick", function()
        local newData = {}
    
        local text = editBox:GetText() or ""
        for line in string.gfind(text, "[^\r\n]+") do
            local item, player, count = ParseLine(line)
            if item and player and count then
                if not newData[item] then
                    newData[item] = {}
                end
                newData[item][player] = count
            end
        end
    
        CSRModData = newData
        DEFAULT_CHAT_FRAME:AddMessage("CSRMod: Data imported and saved.")
        f:Hide()
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetWidth(60)
    closeBtn:SetHeight(20)
    closeBtn:SetText("Close")
    closeBtn:SetPoint("TOPRIGHT", -10, -10)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f.editBox = editBox
end

function CSRMod_ImportHandler(msg)
    CreateImportWindow()
end
local function ExtractFirstItemName(msg)
    local startPos, endPos = string.find(msg, "|c%x+|Hitem:%d+[:%d]*|h%[.-%]|h|r")
    if not startPos then return nil end
    local itemLink = string.sub(msg, startPos, endPos)
    local itemNameStart, itemNameEnd = string.find(itemLink, "%[(.-)%]")
    if not itemNameStart then return nil end
    return string.sub(itemLink, itemNameStart + 1, itemNameEnd - 1)
end

local function OnOwnChatMessage()
    if arg2 ~= UnitName("player") then
        return -- Only handle messages you sent
    end

    if not arg1 then return end

    -- Check if message contains "sr by" (case-insensitive)
    if not string.find(string.lower(arg1), "sr by") then
        return -- Ignore messages without "roll"
    end

    local itemName = ExtractFirstItemName(arg1)
    if itemName then
        CSRMod_QueryHandler(itemName)
    end
end

local chatListener = CreateFrame("Frame")
chatListener:RegisterEvent("CHAT_MSG_SAY")
chatListener:RegisterEvent("CHAT_MSG_PARTY")
chatListener:RegisterEvent("CHAT_MSG_PARTY_LEADER")
chatListener:RegisterEvent("CHAT_MSG_RAID")
chatListener:RegisterEvent("CHAT_MSG_RAID_LEADER")
chatListener:RegisterEvent("CHAT_MSG_RAID_WARNING")  -- add this line
chatListener:RegisterEvent("CHAT_MSG_GUILD")
chatListener:RegisterEvent("CHAT_MSG_OFFICER")
chatListener:SetScript("OnEvent", OnOwnChatMessage)

function CSRMod_QueryHandler(msg)
    local itemName = msg

    local openBracket = string.find(msg, "[", 1, true)
    local closeBracket = openBracket and string.find(msg, "]", openBracket + 1, true)
    
    local itemName = msg
    if openBracket and closeBracket then
        itemName = string.sub(msg, openBracket + 1, closeBracket - 1)
    end

    if not itemName or itemName == "" then
        DEFAULT_CHAT_FRAME:AddMessage("Usage: /csrmod [Item Link or Name]")
        return
    end

    local results = {}
    local itemData = CSRModData[itemName]
    if not itemData then
        DEFAULT_CHAT_FRAME:AddMessage("No data found for item: " .. itemName)
        return
    end

    for i = 1, GetNumRaidMembers() do
        local name = GetRaidRosterInfo(i)
        if itemData[name] and itemData[name] > 0 then
            table.insert(results, name .. "(+" .. itemData[name] .. ")")
        end
    end

    if table.getn(results) == 0 then
        SendChatMessage("No entries found for " .. itemName, "RAID")
    else
        local message = table.concat(results, ", ")
        SendChatMessage(itemName .. ": " .. message, "RAID")
    end
end

SLASH_CSRMODIMPORT1 = "/importcsrmod"
SLASH_CSRMODQUERY1 = "/csrmod"
SlashCmdList = SlashCmdList or {}
SlashCmdList["CSRMODIMPORT"] = CSRMod_ImportHandler
SlashCmdList["CSRMODQUERY"] = CSRMod_QueryHandler
