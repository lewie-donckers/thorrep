-- change frame to what TR_CHATFRAME output is desired
local frame = 1
--

local factionVars = {}


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

local init = 0
local factions = 0

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

local function ScanFactions()
    LogDebug("Scanning factions...")
    local nr_total = 0
    local nr_inactive = 0
    for i = 1, GetNumFactions() do
        local name, _, standingID, _, _, barValue, _, _, isHeader, _, hasRep, _, _, factionID = GetFactionInfo(i)
        if ((not isHeader or hasRep) and name) then
            factionVars[name] = {}
            factionVars[name].Standing = standingID
            factionVars[name].Value = barValue

            nr_total = nr_total + 1
            if IsFactionInactive(i) then
                nr_inactive = nr_inactive + 1
            end

            local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionID)
            if friendID then
                LogDebug("%s seems to be a friendship", name)
            end
        end
    end
    LogDebug("Found %d factions (%d inactive)", nr_total, nr_inactive)
end

local function Report() 
    local tempfactions = GetNumFactions()
    if (tempfactions ~= 0 and init == 0) then
        ScanFactions()
        init = 1
        factions = tempfactions
        return
    end
    if (tempfactions > factions) then
        ScanFactions()
        factions = tempfactions
    end
    for factionIndex = 1, GetNumFactions() do
        local name, _, standingID, barMin, barMax, barValue, _, _, isHeader, _, hasRep = GetFactionInfo(factionIndex)

        if (not isHeader or hasRep) and factionVars[name] then
            local diff = barValue - factionVars[name].Value
            if diff ~= 0 then
                if standingID ~= factionVars[name].Standing then
                    local newfaction = _G["FACTION_STANDING_LABEL" .. standingID]
                    local newstandingtext =
                        "New standing with " .. TR_COLOR_NAME .. name .. TR_COLOR_RESUME .. " is " .. TR_COLOR_NAME .. newfaction .. TR_COLOR_RESUME .. "!"

                    TR_CHATFRAME:AddMessage(newstandingtext)
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

                local change = math.abs(barValue - factionVars[name].Value)
                local repetitions = math.ceil(remaining / change)

                local togo_total = TR_EXALTED_AT - barValue
                local reps_total = math.ceil(togo_total / math.abs(diff))

                local newvaluetext = string.format(
                    "[ThorRep] %s %s, %s to %s (%s reps), %s to %s (%s reps)",
                    FormatColor(TR_COLOR_NR, "%+d", change),
                    FormatColor(TR_COLOR_NAME, name),
                    FormatColor(TR_COLOR_NR, "%d", remaining),
                    nextstanding,
                    FormatColor(TR_COLOR_NR, "%d", repetitions),
                    FormatColor(TR_COLOR_NR, "%d", togo_total),
                    GetColoredRepLevelName(0, TR_REP_LEVEL_MAX),
                    FormatColor(TR_COLOR_NR, "%d", reps_total)
                )

                TR_CHATFRAME:AddMessage(newvaluetext)

                factionVars[name].Value = barValue
                factionVars[name].Standing = standingID
            end
        end
    end
end

local function eventHandler(self, event, ...)
    if (event == "UPDATE_FACTION") then
        Report()
    end
end

local frame = CreateFrame("FRAME", nil, UIParent)
frame:RegisterEvent("UPDATE_FACTION")
frame:SetScript("OnEvent", eventHandler)
