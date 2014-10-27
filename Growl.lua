--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    Data.lua
-- Author:  @project-author@
-- License: LICENSE.txt
--------------------------------------------------------------------------------

local ADDON_PREFIX = "BadPet";
local REPORT_DELAY = 1;
local STATE_QUIET = "quiet";
local STATE_NOISY = "noisy";
local FRAME_PRIVATE = "private";
local FRAME_WHISPER = "whisper";
local FRAME_PARTY = "party";
local IS_ME_PRIORITY = 10000;
local MAX_PRIORITY = IS_ME_PRIORITY - 1;
local L = BadPetI18N[GetLocale()];

--------------------------------------------------------------------------------
-- Event Generation: Find the owner of a pet or guardian
--------------------------------------------------------------------------------

local function UnitToStruct(unit)
    return UnitExists(unit)
            and
            {
                id = UnitGUID(unit),
                name = GetUnitName(unit, true),
                unit = unit
            }
end

local function PlayerOwner(subject)
    return UnitGUID("pet") == subject and UnitToStruct("player")
end

local function GroupOwner(subject)
    local owner
    for i = 1, 4 do
        local id = UnitGUID("partypet" .. i)
        if (id and id == subject) then
            owner = UnitToStruct("party" .. i);
            break;
        end
    end
    return owner;
end

local function RaidOwner(subject)
    local owner;
    for i = 1, GetNumGroupMembers() do
        local id = UnitGUID("raidpet" .. i)
        if (id and id == subject) then
            owner = UnitToStruct("raid" .. i);
            break;
        end
    end
    return owner;
end

local function GuardianDescription(guid)
    local tip = CreateFrame('GameTooltip', 'GuardianOwnerTooltip', nil, 'GameTooltipTemplate')
    tip:SetOwner(WorldFrame, 'ANCHOR_NONE')
    tip:SetHyperlink('unit:' .. guid or '')
    local text = GuardianOwnerTooltipTextLeft3;
    return GuardianOwnerTooltipTextLeft3 and text:GetText()
end

local function DescrToName(descr, pattern)
    return descr and string.match(descr, pattern)
end

local PET_PATTERN = string.format(UNITNAME_TITLE_PET, "(.+)");
local GUARDIAN_PATTERN = string.format(UNITNAME_TITLE_GUARDIAN, "(.+)");

local function TooltipOwner(guid)
    local descr = GuardianDescription(guid)
    local name = DescrToName(descr, PET_PATTERN) or DescrToName(descr, GUARDIAN_PATTERN)
    if name then
        return { name = name }
    end
end

local function GetOwner(subject)
    return PlayerOwner(subject)
            or GroupOwner(subject)
            or RaidOwner(subject)
            or TooltipOwner(subject)
end

--- Find the owner of a particular pet and add their details to the report.
-- @param report: an event report
local function AddOwner(report)
    local subject = report.pet and report.pet.id;
    local owner = subject and GetOwner(subject);
    if owner then
        report.owner = owner;
    end
    return report;
end

--------------------------------------------------------------------------------
-- Respond to a combat log event by generating a message
--------------------------------------------------------------------------------

--- Respond to a pet growl event in combat log.
-- Update history for that pet/owner.
-- Check settings and history to work out whether to send a message or not.
function BadPet:Growl(report)
    local history, queue, reset;
    local player, targetText, spellText;
    local report = AddOwner(report);

    history = self.history[report.pet.id][report.spell.id];
    reset = self.history.reset;

    -- decide whether we will report this event
    if history.time < self.history.reset -- no reports since combat started
            or self.db.profile.state == STATE_NOISY then -- we report everything
        history.time = report.time;
        history.count = history.count + 1;

        if history.count > self.db.profile.grace then
            history.count = 0;
            self:SendReport(report);
        end
    end
end

--- Process sending a report.
function BadPet:SendReport(report)
    local previous;

    -- if we're set to noisy don't check with others, send the report now
    if self.db.profile.state == NOISY then
        self:SendMessage(report);
        report.sent = UnitName("player");
        self:BroadcastReport(report);
        return;
    end

    previous = self.queue[report.pet.id][report.spell.id];

    -- check for a report already on the queue, or queue this one
    if previous and previous.time + REPORT_DELAY > report.time then
        -- someone else has already reported this recently
        return
    else
        -- queue this report and broadcast it to others
        report.priority = math.random(MAX_PRIORITY);

        if UnitGUID("pet") == report.pet then
            report.priority = IS_ME_PRIORITY;
        end

        self.queue[report.pet.id][report.spell.id] = report;
        self:BroadcastReport(report);
        self:ScheduleTimer("CheckQueue", REPORT_DELAY, report);
    end
end

--- Broadcast this report to other players in our party.
function BadPet:BroadcastReport(report)
    local distribution;
    if UnitInRaid("player") then -- we're in a raid
        distribution = "RAID";
    elseif GetNumGroupMembers() > 0 then -- we're in a party
        distribution = "PARTY";
    else -- not in a group, swallow the message
        return
    end

    local msg = self:Serialize(report)
    self:SendCommMessage(ADDON_PREFIX, msg, distribution);
end

--- Process a report received from another player.
function BadPet:OnCommReceived(prefix, msg, distribution, sender)
    local success, received, ours, history;

    if not (prefix == ADDON_PREFIX) then
        return;
    end

    success, received = self:Deserialize(msg);
    if not success then
        self:Debug("error deserializing message: " .. msg);
        return;
    end

    history = self.history[received.pet.id][received.spell.id];
    ours = self.queue[received.pet.id][received.spell.id];

    if ours then
        if received.sent then -- already been sent
            ours.sent = sender;
            self:Debugf("supressed report, %s has already sent it", sender);
        elseif received.priority > ours.priority then -- theirs wins, they'll send it
            ours.sent = sender;
            self:Debugf("supressed report, %s has priority (%d vs %d)",
                sender, received.priority, ours.priority);
        end -- otherwise ignore, we'll still send ours
    else -- they saw something we didn't see or don't care about
        received.sent = sender;
        self.queue[received.pet.id][received.spell.id] = received;
        self:Debugf("receieved a previously unseen warning from %s", sender);

        -- message has been set, update history accordingly.
        history.time = time();
        history.count = 0;
    end
end

--- Dispatch a previously queued report.
function BadPet:CheckQueue(report)
    local time = time();

    self:SendMessage(report);

    if self.queue[report.pet] then
        self.queue[report.pet][report.spell] = nil;
    end
end

--- Send a warning message to the appropriate frame.
function BadPet:SendMessage(report)
    local frame, me, owner;

    frame = self.db.profile.frame;
    me = UnitGUID("pet") == report.pet.id;
    owner = report.owner;

    if report.sent or me or not owner then
        frame = FRAME_PRIVATE;
    end

    local message = self:DescribeEvent(report, frame);

    if frame == FRAME_PRIVATE then
        self:Print(message);
        if report.sent then
            self:Debugf("(reported by %s)", report.sent);
        end
    elseif frame == FRAME_WHISPER then
        SendChatMessage(message, "WHISPER", GetDefaultLanguage("player"), owner.name);
    elseif frame == FRAME_PARTY then
        message = "BadPet: " .. message;
        if GetNumGroupMembers(LE_PARTY_CATEGORY_INSTANCE) > 0 then
            SendChatMessage(message, "INSTANCE_CHAT");
        elseif UnitInRaid("player") then
            SendChatMessage(message, "RAID");
        elseif GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) > 0 then
            SendChatMessage(message, "PARTY");
        end
    end
end

--------------------------------------------------------------------------------
-- Event reporting: describe attributes of the event
--------------------------------------------------------------------------------

--- Describe an action
-- @param report spell report to describe
-- @param frame destination for the report (e.g. private, whisper, party)
-- @return string describing the event
function BadPet:DescribeEvent(report, frame)
    local subject, target, spell, message;

    subject = self:DescribePet(report, frame);
    target = report.target.name;
    spell = GetSpellLink(report.spell.id) or report.spell.name;

    if target then
        message = (L["%s used %s on %s"]):format(subject, spell, target);
    else
        message = (L["%s used %s"]):format(subject, spell, target);
    end

    return message;
end

--- Describe a pet
-- @param report spell report containing the pet to describe
-- @param frame destination for the report (e.g. private, whisper, party)
-- @return string describing the pet
function BadPet:DescribePet(report, frame)
    local owner, pet, me, message;

    if not report.owner then
        self:AddOwner(report);
    end

    owner = report.owner and report.owner.name;
    pet = report.pet and report.pet.name;
    me = report.owner and report.owner.id == UnitGUID("player");

    if me then
        if pet then
            message = (L["My pet, %s,"]):format(pet);
        else
            message = L["My pet"];
        end
    elseif owner and frame == FRAME_WHISPER then
        if pet then
            message = (L["Your pet, %s,"]):format(pet);
        else
            message = L["Your pet"];
        end
    elseif owner then
        if pet and owner then
            message = (L["%s's pet, %s,"]):format(owner, pet);
        elseif haveOwner then
            message = (L["%s's pet"]):format(owner);
        else
            message = L["An unknown pet"];
        end
    else
        if pet then
            message = (L["An unknown pet, %s,"]):format(pet);
        else
            message = L["An unknown pet"];
        end
    end

    return message;
end
