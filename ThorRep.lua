-- change frame to what TR_CHATFRAME output is desired
local frame = 1
--

-- .Reputation--DEFAULT .Reputation-standing{color:#0f9601}
-- .Reputation--EXALTED .Reputation-standing{color:#28a687}
-- .Reputation--REVERED .Reputation-standing{color:#0f9601}
-- .Reputation--HONORED .Reputation-standing{color:#0f9601}
-- .Reputation--FRIENDLY .Reputation-standing{color:#0f9601}
-- .Reputation--NEUTRAL .Reputation-standing{color:#edba03}
-- .Reputation--UNFRIENDLY .Reputation-standing{color:#cc3609}
-- .Reputation--HOSTILE .Reputation-standing{color:#d90e03}
-- .Reputation--HATED .Reputation-standing{color:#d90e03}
-- .Reputation--STRANGER .Reputation-standing{color:#cc3609}
-- .Reputation--ACQUAINTANCE .Reputation-standing{color:#edba03}
-- .Reputation--BUDDY .Reputation-standing{color:#0f9601}
-- .Reputation--FRIEND .Reputation-standing{color:#0f9601}
-- .Reputation--GOOD_FRIEND .Reputation-standing{color:#0f9601}
-- .Reputation--BEST_FRIEND .Reputation-standing{color:#28a687}
-- .Reputation--BODYGUARD .Reputation-standing{color:#0f9601}
-- .Reputation--TRUSTED_BODYGUARD .Reputation-standing{color:#0f9601}
-- .Reputation--PERSONAL_WINGMAN .Reputation-standing{color:#0f9601}

-- TODO constants in ALL_CAPS

local TR_CHATFRAME = _G["ChatFrame" .. frame]
local TR_DEBUG = true

local TR_REP_LEVEL_MIN = 1
local TR_REP_LEVEL_MAX = 8
local TR_EXALTED_AT = 3000 + 6000 + 12000 + 21000
-- TODO colors taken from WoW Armory website. do not match in-game colors.
local TR_COLOR_REP_LEVELS = {[1] = "|cffd90e03", [2] = "|cffd90e03", [3] = "|cffcc3609", [4] = "|cffedba03", [5] = "|cff0f9601", [6] = "|cff0f9601", [7] = "|cff0f9601", [8] = "|cff28a687"}
local TR_COLOR_NAME = "|cffffff78"
local TR_COLOR_NR = "|cffff7831"
local TR_COLOR_RESUME = "|r"


local function FormatColor(color, message, ...)
    return color .. string.format(message, ...) .. TR_COLOR_RESUME
end

local function GetRepLevelColor(factionID, repLevel)
    -- TODO handle friends
    return TR_COLOR_REP_LEVELS[repLevel]
end

local function GetRepLevelName(factionID, repLevel)
    -- TODO handle friends
    return _G["FACTION_STANDING_LABEL" .. repLevel]
end

local function GetColoredRepLevelName(factionID, repLevel)
    return FormatColor(GetRepLevelColor(factionID, repLevel), GetRepLevelName(factionID, repLevel))
end


local function Log(message, ...)
    TR_CHATFRAME:AddMessage("[ThorRep] " .. string.format(message, ...))
end

local function LogDebug(message, ...)
    if TR_DEBUG then
        Log("[DEBUG] " .. message, ...)
    end
end




-- Faction class
Faction = {}
Faction.__index = Faction

function Faction:Create(factionID)
    local object = {}
    setmetatable(object, Faction)
    object.factionID = factionID

    local name, _, standingID, _, _, value = GetFactionInfoByID(factionID)
    object.name = name
    object.standingID = standingID
    object.value = value

    -- local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionID)
    -- if friendID then
    --     LogDebug("%s seems to be a friendship", name)
    -- end

    return object
end

function Faction:Update()
    local _, _, standingID, barMin, barMax, barValue = GetFactionInfoByID(self.factionID)

    local diff = barValue - self.value
    if diff ~= 0 then
        if standingID ~= self.standingID then
            local newfaction = _G["FACTION_STANDING_LABEL" .. standingID]
            local newstandingtext =
                "New standing with " .. TR_COLOR_NAME .. self.name .. TR_COLOR_RESUME .. " is " .. TR_COLOR_NAME .. newfaction .. TR_COLOR_RESUME .. "!"

            Log(newstandingtext)
        end

        local remaining, nextstanding, plusminus
        if diff > 0 then
            remaining = barMax - barValue
            if standingID < TR_REP_LEVEL_MAX then
                nextstanding = GetColoredRepLevelName(0, standingID + 1)
            else
                nextstanding = "End of " .. _G["FACTION_STANDING_LABEL" .. TR_REP_LEVEL_MAX]
            end
        else
            remaining = barValue - barMin
            if standingID > TR_REP_LEVEL_MIN then
                nextstanding = _G["FACTION_STANDING_LABEL" .. standingID - 1]
            else
                nextstanding = "Beginning of " .. _G["FACTION_STANDING_LABEL" .. TR_REP_LEVEL_MIN]
            end
        end

        local change = math.abs(barValue - self.value)
        local repetitions = math.ceil(remaining / change)

        local togo_total = TR_EXALTED_AT - barValue
        local reps_total = math.ceil(togo_total / math.abs(diff))

        local newvaluetext = string.format(
            "[ThorRep] %s %s, %s to %s (%s reps), %s to %s (%s reps)",
            FormatColor(TR_COLOR_NR, "%+d", change),
            FormatColor(TR_COLOR_NAME, self.name),
            FormatColor(TR_COLOR_NR, "%d", remaining),
            nextstanding,
            FormatColor(TR_COLOR_NR, "%d", repetitions),
            FormatColor(TR_COLOR_NR, "%d", togo_total),
            GetColoredRepLevelName(0, TR_REP_LEVEL_MAX),
            FormatColor(TR_COLOR_NR, "%d", reps_total)
        )

        Log(newvaluetext)

        self.value = barValue
        self.standingID = standingID
    end
end

-- end

-- Factions class
Factions = {}
Factions.__index = Factions

function Factions:Create()
    local object = {}
    setmetatable(object, Factions)
    object.factions_ = {}
    object.factionIDs_ = {}
    object.indexed_ = 0
    return object
end

function Factions:Scan()
    LogDebug("Scanning factions...")
    local to_index = GetNumFactions()
    for index = 1, to_index do
        local name, _, standingID, _, _, barValue, _, _, isHeader, _, hasRep, _, _, factionID = GetFactionInfo(index)
        if (not isHeader or hasRep) then

            if self.factions_[factionID] == nil then
                self.factions_[factionID] = Faction:Create(factionID)
                self.factionIDs_[#self.factionIDs_ + 1] = factionID
            end
        end
    end
    self.indexed_ = to_index
    LogDebug("Found %d factions", #self.factionIDs_)
end

function Factions:ShouldScan()
    return self.indexed_ < GetNumFactions()
end

function Factions:Update()
    for id, faction in pairs(self.factions_) do
        -- LogDebug("Updating %d...", id)
        faction:Update()
    end
end

-- end


local factions = Factions:Create()

local function HandleFactionUpdate()
    if factions:ShouldScan() then factions:Scan() end

    factions:Update()
end

local function HandleEvent(self, event, ...)
    if (event == "UPDATE_FACTION") then
        HandleFactionUpdate()
    end
end

local frame = CreateFrame("FRAME", nil, UIParent)
frame:RegisterEvent("UPDATE_FACTION")
frame:SetScript("OnEvent", HandleEvent)
