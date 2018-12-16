---------- CONSTANTS

local TR_DEBUG = false

-- TR_FACTION_RANK_MIN and TR_FACTION_RANK_MAX should match the indices in _G["FACTION_STANDING_LABEL"] (and thus TR_FACTION_RANK_NAMES) and TR_COLOR_RANKS.
-- TR_FACTION_RANK_MIN applies to both standard factions and friendships.
-- The other constants only apply to standard factions.
local TR_FACTION_RANK_MIN = 1
local TR_FACTION_RANK_MAX = 8
local TR_FACTION_REP_MAX = 3000 + 6000 + 12000 + 21000
local TR_FACTION_RANK_NAMES = {}
for index = TR_FACTION_RANK_MIN, TR_FACTION_RANK_MAX do TR_FACTION_RANK_NAMES[index] = _G["FACTION_STANDING_LABEL" .. index] end

-- Rank colors taken from http://www.wow-pro.com/general_guides/colour_guide.
local TR_COLOR_RANKS = {"|cffcc0000", "|cffff0000", "|cfff26000", "|cffe4e400", "|cff33ff33", "|cff5fe65d", "|cff53e9bc", "|cff2ee6e6"}
local TR_COLOR_NAME = "|cffffff78"
local TR_COLOR_NR = "|cffff7831"
local TR_COLOR_RESUME = "|r"



---------- HELPER FUNCTIONS

-- Format the given message and extra parameters (effectively using string.format) in the given color.
local function FormatColor(color, message, ...)
    return color .. string.format(message, ...) .. TR_COLOR_RESUME
end

-- Format the given name using the corresponding color.
local function FormatName(name)
    return FormatColor(TR_COLOR_NAME, name)
end

-- Format the given number using the given number format (effectively using string.format) using the corresponding color. If format is not given, "%d" is used.
local function FormatNr(nr, format)
    local format = format or "%d"
    return FormatColor(TR_COLOR_NR, format, nr)
end

-- Formats the given message and extra parameters and logs it to the default frame.
local function Log(message, ...)
    print(string.format(message, ...))
end

-- Formats the given message and extra parameters and logs it to the default frame. A prefix is used to indicate it is debug logging for this addon. If TR_DEBUG is false, nothing is done.
local function LogDebug(message, ...)
    if TR_DEBUG then
        Log("[ThorRep][DBG] " .. message, ...)
    end
end

-- Clamps the given value between min and max.
local function Clamp(value, min, max)
    if value < min then return min
    elseif value > max then return max
    end
    return value
end

-- Gets the color for the given faction rank.
local function GetFactionRankColor(rank)
    local rank = Clamp(rank, TR_FACTION_RANK_MIN, TR_FACTION_RANK_MAX)
    return TR_COLOR_RANKS[rank]
end

-- Gets the colored rank name for the given standard faction rank.
local function GetFactionRankName(rank)
    local rank = Clamp(rank, TR_FACTION_RANK_MIN, TR_FACTION_RANK_MAX)
    return FormatColor(GetFactionRankColor(rank), TR_FACTION_RANK_NAMES[rank])
end



---------- CLASSES

-- Faction class
Faction = {}
Faction.__index = Faction

function Faction:Create(factionID)
    local object = {}
    setmetatable(object, Faction)
    object.factionID_ = factionID

    local name, _, rank, _, _, repNew = GetFactionInfoByID(factionID)
    object.name_ = name
    object.rank_ = rank
    object.rep_ = repNew

    local friendID, _, friendMaxRep = GetFriendshipReputation(factionID)
    if friendID ~= nil then
        object.isFriendship_ = true
        object.maxRep_ = friendMaxRep
    else
        object.isFriendship_ = false
        object.maxRep_ = TR_FACTION_REP_MAX
    end

    object.isParagon_ = C_Reputation.IsFactionParagon(factionID)
    object.paragonRep_ = object.isParagon_ and C_Reputation.GetFactionParagonInfo(factionID) or 0

    return object
end

function Faction:IsRankMax_()
    if self.isFriendship_ then
        return select(9, GetFriendshipReputation(self.factionID_)) == nil
    end

    return self.rank_ >= TR_FACTION_RANK_MAX
end

function Faction:IsNextRankMax_()
    if self.isFriendship_ then
        return not self:IsRankMax_() and (select(9, GetFriendshipReputation(self.factionID_)) >= self.maxRep_)
    end

    return self.rank_ + 1 >= TR_FACTION_RANK_MAX
end

function Faction:GetCurrentRankName_()
    if self.isFriendship_ then
        return FormatColor(GetFactionRankColor(TR_FACTION_RANK_MAX - 2), select(7, GetFriendshipReputation(self.factionID_)))
    end

    return GetFactionRankName(self.rank_)
end

function Faction:GetNextRankName_()
    if self.isFriendship_ then
        return FormatColor(GetFactionRankColor(TR_FACTION_RANK_MAX - 1), "next rank")
    end

    return GetFactionRankName(self.rank_ + 1)
end

function Faction:GetNextParagonName_()
    return FormatColor(GetFactionRankColor(TR_FACTION_RANK_MAX), "next paragon")
end

function Faction:GetMaxRankName_()
    if self.isFriendship_ then
        return FormatColor(GetFactionRankColor(TR_FACTION_RANK_MAX), "max rank")
    end

    return GetFactionRankName(TR_FACTION_RANK_MAX)
end

function Faction:UpdateInternal_()
    local _, _, rankNew, curRankAt, nextRankAt, repNew = GetFactionInfoByID(self.factionID_)
    local repDelta = repNew - self.rep_

    if repDelta ~= 0 then
        self.rep_ = repNew
        self.rank_ = rankNew
        self.maxRep_ = math.max(self.maxRep_, nextRankAt)
    end

    return repDelta, curRankAt, nextRankAt
end

function Faction:UpdateInternalParagon_()
    self.isParagon_ = C_Reputation.IsFactionParagon(self.factionID_)

    if not self.isParagon_ then return 0, false end

    local paragonRep, paragonThreshold = C_Reputation.GetFactionParagonInfo(self.factionID_)
    local paragonDelta = paragonRep - self.paragonRep_

    self.paragonRep_ = paragonRep

    return paragonDelta, true, paragonThreshold
end

function Faction:GetGoalString_(rank_name, rep, reps)
    return string.format(", %s @ %s (%sx)", rank_name, FormatNr(rep), FormatNr(reps))
end

function Faction:Update()
    local repDelta, curRankAt, nextRankAt = self:UpdateInternal_()
    local paragonDelta, isParagon, paragonThreshold = self:UpdateInternalParagon_()
    local totalDelta = repDelta + paragonDelta

    if totalDelta == 0 then return end

    local cur_rep = isParagon and (self.paragonRep_ % paragonThreshold) or (self.rep_ - curRankAt)
    local max_rep = isParagon and paragonThreshold or (nextRankAt - curRankAt)

    local message = string.format("%s %s (%s %s/%s)", FormatName(self.name_), FormatNr(totalDelta, "%+d"), self:GetCurrentRankName_(), FormatNr(cur_rep), FormatNr(max_rep))

    if (totalDelta > 0) and (self.rep_ < self.maxRep_) then
        local nextRankStr
        if not self:IsRankMax_() then
            nextRankStr = self:GetNextRankName_()
        else
            nextRankStr = "full " .. self:GetMaxRankName_()
        end

        local togoNext = nextRankAt - self.rep_
        local repsNext = math.ceil(togoNext / math.abs(totalDelta))

        message = message .. self:GetGoalString_(nextRankStr, togoNext, repsNext)

        if not self:IsNextRankMax_() then
            local togoTotal = self.maxRep_ - self.rep_
            local repsTotal = math.ceil(togoTotal / math.abs(totalDelta))

            message = message .. self:GetGoalString_(self:GetMaxRankName_(), togoTotal, repsTotal)
        end
    end

    if (totalDelta > 0) and isParagon then
        local togoNext = paragonThreshold - (self.paragonRep_ % paragonThreshold)
        local repsNext = math.ceil(togoNext / math.abs(totalDelta))

        message = message .. self:GetGoalString_(self:GetNextParagonName_(), togoNext, repsNext)
    end

    Log(message)
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
    local maxIndex = GetNumFactions()
    for index = 1, maxIndex do
        local _, _, _, _, _, _, _, _, isHeader, _, hasRep, _, _, factionID = GetFactionInfo(index)
        if (not isHeader or hasRep) then

            if self.factions_[factionID] == nil then
                self.factions_[factionID] = Faction:Create(factionID)
                self.size_ = self.size_ + 1
            end
        end
    end
    self.indexed_ = maxIndex
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



---------- STATE

local factions = Factions:Create()



---------- EVENT HANDLERS

local function HandleFactionUpdate()
    if factions:ShouldScan() then factions:Scan() end

    factions:Update()
end

local function HandleEvent(self, event, ...)
    if (event == "UPDATE_FACTION") then
        HandleFactionUpdate()
    end
end



---------- SETUP

local frame = CreateFrame("FRAME", nil, UIParent)
frame:RegisterEvent("UPDATE_FACTION")
frame:SetScript("OnEvent", HandleEvent)
