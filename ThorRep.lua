-- TODO
-- - document more



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



---------- CLASSES

-- Faction class
Faction = {}
Faction.__index = Faction

function Faction:Create(factionID)
    local object = {}
    setmetatable(object, Faction)
    object.factionID_ = factionID

    local name, _, rank, _, _, rep_new = GetFactionInfoByID(factionID)
    object.name_ = name
    object.rank_ = rank
    object.rep_ = rep_new

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

function Faction:GetRankColor_(rank)
    local offset = TR_FACTION_RANK_MAX - self.maxRank_
    local index = Clamp(rank + offset, TR_FACTION_RANK_MIN, TR_FACTION_RANK_MAX)
    return TR_COLOR_RANKS[index]
end

function Faction:GetRankName_(rank)
    local rank = Clamp(rank, TR_FACTION_RANK_MIN, self.maxRank_)
    if self.isFriendship_ then
        if rank == self.rank_ then 
            local _, _, _, _, _, _, friendTextLevel = GetFriendshipReputation(self.factionID_)
            return friendTextLevel
        elseif rank == self.maxRank_ then return "max level"
        elseif rank == TR_FACTION_RANK_MIN then return "min level"
        elseif rank == self.rank_ + 1 then return "next level"
        elseif rank == self.rank_ - 1 then return "previous level"
        else return string.format("level %d", rank)
        end
    else
        return TR_FACTION_RANK_NAMES[rank]
    end
end

function Faction:GetColoredRankName_(rank)
    return FormatColor(self:GetRankColor_(rank), self:GetRankName_(rank))
end

function Faction:UpdateInternal_()
    local _, _, rank_new, _, next_rank_at, rep_new = GetFactionInfoByID(self.factionID_)

    rep_delta = rep_new - self.rep_

    if (rep_delta == 0) then return 0 end

    local rank_change = self.rank_ ~= rank_new

    self.rep_ = rep_new
    self.rank_ = rank_new
    self.maxRep_ = math.max(self.maxRep_, next_rank_at)

    return rep_delta, rank_change, next_rank_at
end

function Faction:GetGoalString_(rank_name, rep, reps)
    return string.format(", %s @ %s (%sx)", rank_name, FormatNr(rep), FormatNr(reps))
end

function Faction:Update()
    local rep_delta, rank_change, next_rank_at = self:UpdateInternal_()

    if rep_delta == 0 then return end

    local message = string.format("%s %s (%s)", FormatName(self.name_), FormatNr(rep_delta, "%+d"), self:GetColoredRankName_(self.rank_))

    if (rep_delta > 0) and (self.rep_ < self.maxRep_) then
        local next_rank_str
        if self.rank_ < self.maxRank_ then
            next_rank_str = self:GetColoredRankName_(self.rank_ + 1)
        else
            next_rank_str = "full " .. self:GetColoredRankName_(self.maxRank_)
        end

        local togo_next = next_rank_at - self.rep_
        local reps_next = math.ceil(togo_next / math.abs(rep_delta))

        message = message .. self:GetGoalString_(next_rank_str, togo_next, reps_next)

        if self.rank_ + 1 < self.maxRank_ then
            local togo_total = self.maxRep_ - self.rep_
            local reps_total = math.ceil(togo_total / math.abs(rep_delta))

            message = message .. self:GetGoalString_(self:GetColoredRankName_(self.maxRank_), togo_total, reps_total)
        end
    end

    Log(message)

    if rank_change then
        Log("New standing with %s is %s!", FormatName(self.name_), self:GetColoredRankName_(self.rank_))
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
