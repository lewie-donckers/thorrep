local TR_DEBUG = true

-- These constants only apply to standard factions (not friendships)
local TR_FACTION_RANK_MIN = 1
local TR_FACTION_RANK_MAX = 8
local TR_FACTION_REP_MAX = 3000 + 6000 + 12000 + 21000
local TR_FACTION_RANK_NAMES = {}
for index = TR_FACTION_RANK_MIN, TR_FACTION_RANK_MAX do TR_FACTION_RANK_NAMES[index] = _G["FACTION_STANDING_LABEL" .. index] end

-- Rank colors taken from WoW Armory website.
local TR_COLOR_RANKS = {"|cffd90e03", "|cffd90e03", "|cffcc3609", "|cffedba03", "|cff0f9601", "|cff0f9601", "|cff0f9601", "|cff28a687"}
local TR_COLOR_NAME = "|cffffff78"
local TR_COLOR_NR = "|cffff7831"
local TR_COLOR_RESUME = "|r"


local function FormatColor(color, message, ...)
    return color .. string.format(message, ...) .. TR_COLOR_RESUME
end

local function Log(message, ...)
    print("[ThorRep] " .. string.format(message, ...))
end

local function LogDebug(message, ...)
    if TR_DEBUG then
        Log("[DEBUG] " .. message, ...)
    end
end

local function Clamp(value, min, max)
    if value < min then return min
    elseif value > max then return max
    end
    return value
end


-- Faction class
Faction = {}
Faction.__index = Faction

function Faction:Create(factionID)
    local object = {}
    setmetatable(object, Faction)
    object.factionID_ = factionID

    local name, _, standingID, _, _, barValue = GetFactionInfoByID(factionID)
    object.name_ = name
    object.rank_ = standingID
    object.rep_ = barValue

    local friendID, _, friendMaxRep = GetFriendshipReputation(factionID)
    if friendID ~= nil then
        object.isFriendship_ = true
        local _, maxRank = GetFriendshipReputationRanks(factionID)
        object.maxRank_ = maxRank
        object.maxRep_ = friendMaxRep
    else
        object.isFriendship_ = false
        object.maxRank_ = TR_FACTION_RANK_MAX
        object.maxRep_ = TR_FACTION_REP_MAX
    end

    return object
end

function Faction:GetRepLevelColor(rank)
    local offset = TR_FACTION_RANK_MAX - self.maxRank_
    local index = Clamp(rank + offset, TR_FACTION_RANK_MIN, TR_FACTION_RANK_MAX)
    return TR_COLOR_RANKS[index]
end

function Faction:GetRepLevelName(rank)
    local rank = Clamp(rank, TR_FACTION_RANK_MIN, self.maxRank_)
    if self.isFriendship_ then
        if rank == self.maxRank_ then return "max level"
        elseif rank == TR_FACTION_RANK_MIN then return "min level"
        elseif rank == self.rank_ + 1 then return "next level"
        elseif rank == self.rank_ - 1 then return "previous level"
        else return string.format("level %d", rank)
        end
    else
        return TR_FACTION_RANK_NAMES[rank]
    end
end

function Faction:GetColoredRepLevelName(rank)
    return FormatColor(self:GetRepLevelColor(rank), self:GetRepLevelName(rank))
end

function Faction:Update()
    local _, _, standingID, barMin, barMax, barValue = GetFactionInfoByID(self.factionID_)

    local diff = barValue - self.rep_

    if diff ~= 0 then
        self.rep_ = barValue

        if standingID ~= self.rank_ then
            self.rank_ = standingID
            Log("New standing with %s is %s!", FormatColor(TR_COLOR_NAME, self.name_), self:GetColoredRepLevelName(standingID))
        end

        local message = string.format("%s %s", FormatColor(TR_COLOR_NR, "%+d", diff), FormatColor(TR_COLOR_NAME, self.name_))

        if diff > 0 then
            if standingID < self.maxRank_ then
                next_rank = self:GetColoredRepLevelName(standingID + 1)
            else
                next_rank = "end of " .. self:GetColoredRepLevelName(self.maxRank_)
            end

            local togo_next = barMax - barValue
            local reps_next = math.ceil(togo_next / math.abs(diff))
    
            message = message .. string.format(", %s to %s (%s reps)", FormatColor(TR_COLOR_NR, "%d", togo_next), next_rank, FormatColor(TR_COLOR_NR, "%d", reps_next))

            if standingID < self.maxRank_ then
                local togo_total = self.maxRep_ - barValue
                local reps_total = math.ceil(togo_total / math.abs(diff))

                message = message .. string.format(", %s to %s (%s reps)", FormatColor(TR_COLOR_NR, "%d", togo_total), self:GetColoredRepLevelName(self.maxRank_), FormatColor(TR_COLOR_NR, "%d", reps_total))
            end
        end

        Log(message)
    end
end
-- end class

-- Factions class
Factions = {}
Factions.__index = Factions

function Factions:Create()
    local object = {}
    setmetatable(object, Factions)
    object.factions_ = {}
    object.size_ = 0
    object.indexed_ = 0
    return object
end

function Factions:Scan()
    LogDebug("Scanning factions...")
    local to_index = GetNumFactions()
    for index = 1, to_index do
        local _, _, _, _, _, _, _, _, isHeader, _, hasRep, _, _, factionID = GetFactionInfo(index)
        if (not isHeader or hasRep) then

            if self.factions_[factionID] == nil then
                self.factions_[factionID] = Faction:Create(factionID)
                self.size_ = self.size_ + 1
            end
        end
    end
    self.indexed_ = to_index
    LogDebug("Found %d factions", self.size_)
end

function Factions:ShouldScan()
    return self.indexed_ < GetNumFactions()
end

function Factions:Update()
    for _, faction in pairs(self.factions_) do
        faction:Update()
    end
end

function Factions:Size()
    return self.size_
end
-- end class

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
