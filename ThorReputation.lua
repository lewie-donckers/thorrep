-- CONSTANTS

local ADDON_NAME = "ThorReputation"
local ADDON_VERSION = "9.0.0"
local ADDON_AUTHOR = "Thorinsøn"


-- FACTION_RANK_MIN and FACTION_RANK_MAX should match the indices in _G["FACTION_STANDING_LABEL"] (and thus FACTION_RANK_NAMES) and COLOR_RANKS.
local FACTION_RANK_MIN = 1
local FACTION_RANK_MAX = 8
local FACTION_REP_MAX = 3000 + 6000 + 12000 + 21000
local FACTION_RANK_NAMES = {}
for index = FACTION_RANK_MIN, FACTION_RANK_MAX do FACTION_RANK_NAMES[index] = _G["FACTION_STANDING_LABEL" .. index] end

-- Rank colors taken from http://www.wow-pro.com/general_guides/colour_guide.
local COLOR_RANKS = {"|cffcc0000", "|cffff0000", "|cfff26000", "|cffe4e400", "|cff33ff33", "|cff5fe65d", "|cff53e9bc", "|cff2ee6e6"}
local COLOR_NAME = "|cffffff78"
local COLOR_NR = "|cffff7831"
local COLOR_LOG = "|cffff7f00"
local COLOR_RESUME = "|r"


-- FUNCTIONS

local function FormatColor(color, message, ...)
    return color .. string.format(message, ...) .. COLOR_RESUME
end

local function FormatColorClass(class, message, ...)
    local _, _, _, color = GetClassColor(class)
    return FormatColor("|c" .. color, message, ...)
end

local function FormatName(name)
    return FormatColor(COLOR_NAME, name)
end

local function FormatNr(nr, format)
    local format = format or "%d"
    return FormatColor(COLOR_NR, format, nr)
end

local function LogPlain(message, ...)
    print(string.format(message, ...))
end

local function Log(message, ...)
    print(FormatColor(COLOR_LOG, "[" .. ADDON_NAME .. "] " .. message, ...))
end

local function LogDebug(message, ...)
    -- LogInfo("[DBG] " .. message, ...)
end

local function Clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    end
    return value
end

local function GetFactionRankColor(rank)
    local rank = Clamp(rank, FACTION_RANK_MIN, FACTION_RANK_MAX)
    return COLOR_RANKS[rank]
end

local function GetFactionRankName(rank)
    local rank = Clamp(rank, FACTION_RANK_MIN, FACTION_RANK_MAX)
    return FormatColor(GetFactionRankColor(rank), FACTION_RANK_NAMES[rank])
end


----- CLASS - Faction

local Faction = {}
function Faction:New(factionID)
    local result = {}
    setmetatable(result, self)
    self.__index = self
    result.factionID_ = factionID

    local name, _, rank, _, _, repNew = GetFactionInfoByID(factionID)
    result.name_ = name
    result.rank_ = rank
    result.rep_ = repNew
    result.maxRep_ = FACTION_REP_MAX

    return result
end

function Faction:IsRankMax_()
    return self.rank_ >= FACTION_RANK_MAX
end

function Faction:IsNextRankMax_()
    return self.rank_ + 1 >= FACTION_RANK_MAX
end

function Faction:GetCurrentRankName_()
    return GetFactionRankName(self.rank_)
end

function Faction:GetNextRankName_()
    return GetFactionRankName(self.rank_ + 1)
end

function Faction:GetMaxRankName_()
    return GetFactionRankName(FACTION_RANK_MAX)
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

function Faction:GetGoalString_(rank_name, rep, reps)
    return string.format(" | %s at %s (%sx)", rank_name, FormatNr(rep), FormatNr(reps))
end

function Faction:Update()
    local repDelta, curRankAt, nextRankAt = self:UpdateInternal_()

    if repDelta == 0 then
        return
    end

    local curRep = self.rep_ - curRankAt
    local maxRep = nextRankAt - curRankAt

    local message = string.format("%s %s | %s %s/%s", FormatName(self.name_), FormatNr(repDelta, "%+d"), self:GetCurrentRankName_(), FormatNr(curRep), FormatNr(maxRep))

    if (repDelta > 0) and (self.rep_ < self.maxRep_) then
        local nextRankStr
        if not self:IsRankMax_() then
            nextRankStr = self:GetNextRankName_()
        else
            nextRankStr = "full " .. self:GetMaxRankName_()
        end

        local togoNext = nextRankAt - self.rep_
        local repsNext = math.ceil(togoNext / math.abs(repDelta))

        message = message .. self:GetGoalString_(nextRankStr, togoNext, repsNext)

        if not self:IsNextRankMax_() then
            local togoTotal = self.maxRep_ - self.rep_
            local repsTotal = math.ceil(togoTotal / math.abs(repDelta))

            message = message .. self:GetGoalString_(self:GetMaxRankName_(), togoTotal, repsTotal)
        end
    end

    LogPlain(message)
end


----- CLASS - ThorReputation

local ThorReputation = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0")

function ThorReputation:Scan()
    local maxIndex = GetNumFactions()
    LogDebug("Scanning %d factions...", maxIndex)
    for index = 1, maxIndex do
        local _, _, _, _, _, _, _, _, isHeader, _, hasRep, _, _, factionID = GetFactionInfo(index)
        if (not isHeader or hasRep) then
            if self.factions_[factionID] == nil then
                self.factions_[factionID] = Faction:New(factionID)
                self.size_ = self.size_ + 1
            end
        end
    end
    self.indexed_ = maxIndex
    LogDebug("Found %d factions", self.size_)
end

function ThorReputation:ShouldScan()
    return self.indexed_ < GetNumFactions()
end

function ThorReputation:Update()
    for _, faction in pairs(self.factions_) do
        faction:Update()
    end
end

function ThorReputation:OnUpdateFaction()
    LogDebug("OnUpdateFaction")

    if self:ShouldScan() then
        self:Scan()
    end

    self:Update()
end

function ThorReputation:OnEnable()
    LogDebug("OnEnable")

    self.factions_ = {}
    self.size_ = 0
    self.indexed_ = 0

    self:RegisterEvent("UPDATE_FACTION", "OnUpdateFaction")

    self:Scan()
    self:Update()

    Log("version " .. ADDON_VERSION .. " by " .. FormatColorClass("HUNTER", ADDON_AUTHOR) ..  " initialized")
end
