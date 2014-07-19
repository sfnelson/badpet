--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    BadPet.lua
-- Author:  @project-author@
-- License: LICENSE.txt
--------------------------------------------------------------------------------

local addon = BadPet;
if not addon then
    local AceAddon = LibStub("AceAddon-3.0");
    addon = AceAddon:NewAddon("BadPet", "AceConsole-3.0", "AceEvent-3.0",
        "AceComm-3.0", "AceSerializer-3.0", "AceTimer-3.0");
end
BadPet = addon;
local BadPet = addon;

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local ADDON_PREFIX = "BadPet";
local REPORT_DELAY = 2;
local STATE_QUIET = "quiet";
local STATE_NOISY = "noisy";
local FRAME_PRIVATE = "private";
local FRAME_WHISPER = "whisper";
local FRAME_PARTY = "party";
local IS_ME_PRIORITY = 10000;
local MAX_PRIORITY = IS_ME_PRIORITY - 1;

local L = BadPetI18N[GetLocale()];

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

--- Spells which the addon tracks.
BadPet.addonSpells = {}
BadPet.addonSpells[2649] = "Growl"; -- growl (generic hunter pet - increases threat)
BadPet.addonSpells[53477] = "Taunt"; -- taunt (hunter pet talent - true taunt)
BadPet.addonSpells[17735] = "Suffering"; -- suffering (voidwalker - true taunt)
--BadPet.addonSpells[63900] = "Thunderstomp"; -- thunderstomp (hunter pet talent - damage+threat)

BadPet.spells = {};

--- Default settings for BadPetDB.
local defaults = {
    profile = {
        enable = true,
        state = STATE_QUIET,
        frame = FRAME_WHISPER,
        debug = false,
        melee = false,
        fixer = true,
        grace = 0,
    },
};

--- Configuration options.
BadPet.options = {
    type = 'group',
    args = {
        general = {
            name = L["BadPet"],
            type = "group",
            order = 10,
            handler = BadPet,
            set = "SetOption",
            get = "GetOption",
            args = {
                enable = {
                    name = "Enable",
                    desc = "Enables / disables the addon.",
                    type = "toggle",
                    order = 10,
                    width = "half",
                },
                test = {
                    name = "Test",
                    desc = "Generates a fake growl notification (appears in chat from after a second)",
                    type = "execute",
                    func = "Test",
                    order = 20,
                    width = "half",
                },
                state = {
                    name = "Report Frequency",
                    desc = "Report every time a pet taunts (noisy)" ..
                            " or once per combat (quiet).",
                    type = "select",
                    values = { STATE_QUIET, STATE_NOISY },
                    style = "radio",
                    width = "half",
                    order = 30,
                },
                frame = {
                    name = "Report Destination",
                    desc = "Report to private, whisper, or party.",
                    type = "select",
                    values = { FRAME_PRIVATE, FRAME_WHISPER, FRAME_PARTY },
                    style = "radio",
                    width = "half",
                    order = 40,
                },
                add = {
                    name = "Extra Spells",
                    desc = "Allows you to add additional spells that BadPet should track",
                    type = "group",
                    handler = BadPet,
                    set = "SetSpellState",
                    get = "GetSpellState",
                    order = 50,
                },
                ignore = {
                    name = "Ignore Spells",
                    desc = "Allows you to prevent BadPet from tracking specific spells",
                    type = "group",
                    handler = BadPet,
                    set = "SetSpellState",
                    get = "GetSpellState",
                    order = 60,
                },
                melee = {
                    name = "Show melee hits on pets",
                    desc = "Send a message when a pet receives a melee attack.",
                    type = "toggle",
                    order = 70,
                    width = "full",
                },
                debug = {
                    name = "Debug",
                    type = "toggle",
                    hidden = function()
                        return not BadPet.db.profile.debug;
                    end
                },
            },
        },
        cmd = {
            name = "Commandline Options",
            type = "group",
            order = 20,
            handler = BadPet,
            set = "SetOption",
            get = "GetOption",
            hidden = true,
            args = {
                enable = {
                    name = "Enable Addon",
                    type = "execute",
                    func = function() BadPet:Enable(); end,
                    order = 10;
                },
                disable = {
                    name = "Disable Addon",
                    type = "execute",
                    func = function() BadPet:Disable(); end,
                    order = 20;
                },
                status = {
                    name = "Show Status",
                    type = "execute",
                    func = function() BadPet:Status(); end,
                    order = 30;
                },
                test = {
                    name = "Print a test report",
                    type = "execute",
                    func = function() BadPet:Test(); end,
                    order = 40;
                    hidden = true;
                },
                quiet = {
                    name = "Limit reports to once per combat",
                    type = "execute",
                    func = function() BadPet:SetProperty("state", STATE_QUIET); end,
                    order = 50;
                },
                noisy = {
                    name = "Report all taunts",
                    type = "execute",
                    func = function() BadPet:SetProperty("state", STATE_NOISY); end,
                    order = 60;
                },
                private = {
                    name = "Report only in the chat frame",
                    type = "execute",
                    func = function() BadPet:SetProperty("frame", FRAME_PRIVATE); end,
                    order = 70;
                },
                whisper = {
                    name = "Report as a whisper",
                    type = "execute",
                    func = function() BadPet:SetProperty("frame", FRAME_WHISPER); end,
                    order = 80;
                },
                party = {
                    name = "Report to party/raid",
                    type = "execute",
                    func = function() BadPet:SetProperty("frame", FRAME_PARTY); end,
                    order = 90;
                },
                config = {
                    name = "Open Config",
                    type = "execute",
                    func = function()
                        InterfaceOptionsFrame_OpenToCategory(BadPet.config);
                        InterfaceOptionsFrame_OpenToCategory(BadPet.config);
                    end,
                    hidden = true,
                },
                melee = {
                    name = "Show melee hits on pets",
                    type = "toggle",
                },
                debug = {
                    name = "Debug",
                    type = "toggle",
                    hidden = true,
                },
            },
        },
    },
};

--- Retrieve a configuration option.
function BadPet:GetOption(info)
    local option = info[#info];

    if info.type == "select" then
        local setting = self.db.profile[option];
        for k, v in pairs(info.option.values) do
            if v == setting then
                return k;
            end
        end
    end

    return self.db.profile[info[#info]];
end

--- Set a configuration option.
function BadPet:SetOption(info, value)
    local option = info[#info];

    if info.type == "select" then
        self.db.profile[option] = info.option.values[value];
    else
        self.db.profile[option] = value;
    end

    self:Debug(option .. " set to " .. tostring(self.db.profile[option]));

    if option == "enable" then
        if value then
            self:Enable();
        else
            self:Disable();
        end
    end

    if option == "fixer" then
        if value then
            self.Fixer:Enable();
        else
            self.Fixer:Disable();
        end
    end

    if option == "debug" then
        self:Refresh();
    end

    self:Status();
end

--- Set a configuration option (directly)
function BadPet:SetProperty(option, value)
    self.db.profile[option] = value;

    self:Debug(option .. " set to " .. tostring(self.db.profile[option]));

    self:Status();
end

--------------------------------------------------------------------------------
-- Configure Spells Options
--------------------------------------------------------------------------------

--- Recreate the spells option page
function BadPet:RefreshSpells()
    local ignore, extra, spells;

    -- rebuild tracked spells list
    ignore = self.db.profile.ignore or {};
    extra = self.db.profile.spells or {};
    spells = {};
    for id, name in pairs(self.addonSpells) do
        if not ignore[id] then
            spells[id] = name;
        end
    end
    for id, name in pairs(extra) do
        spells[id] = name;
    end
    if self.db.profile.debug then
        local tracked = "";
        for _, name in pairs(spells) do
            tracked = tracked .. " " .. name
        end
        self:Debug("Tracking the following spells:" .. tracked);
    end
    self.spells = spells;

    -- update ignored spells config
    local ignoreConfig = self.options.args.general.args.ignore;
    ignoreConfig.args = {};
    for id, name in pairs(self.addonSpells) do
        ignoreConfig.args[tostring(id)] = { name = name, desc = GetSpellInfo(id), type = "toggle" };
    end

    local extraConfig = self.options.args.general.args.add;
    extraConfig.args = {};
    for id, name in pairs(extra) do
        extraConfig.args[tostring(id)] = { name = name, type = "toggle", order = 1 };
    end
    local add = {
        name = "Add Spell ID",
        type = "input",
        desc = "Enter a spell id to add to the watch list (only pet spells will be tracked)",
        order = 100;
        width = "full";
    };
    extraConfig.args["add"] = add;

    LibStub("AceConfigRegistry-3.0"):NotifyChange("BadPet: General");
end

--- Get the state of a spell in the spells option table
function BadPet:GetSpellState(info)

    if info[#info] == "add" then
        return "";
    end

    local id = tonumber(info[#info]);

    if self.db.profile.ignore and self.db.profile.ignore[id] then
        return true;
    end

    if self.db.profile.spells and self.db.profile.spells[id] then
        return true;
    end

    return false;
end


local function extra(self)
    local extra = self.db.profile.spells;
    if type(extra) ~= "table" then
        extra = {};
        self.db.profile.spells = extra;
    end
    return extra;
end

local function ignore(self)
    local ignore = self.db.profile.ignore;
    if type(ignore) ~= "table" then
        ignore = {};
        self.db.profile.ignore = ignore;
    end
    return ignore;
end

--- Set the state of a spell in the spells option table
function BadPet:SetSpellState(info, value)
    local id, name;

    id = tonumber(value) or tonumber(info[#info]);
    name = id and GetSpellInfo(id);

    if info[#info] == "add" then
        local extra = extra(self);
        if id and name then
            extra[id] = name;
            self:Debugf("Enabled %s tracking (extra)", name);
        end
    elseif not self.addonSpells[id] then
        local extra = extra(self);
        if id and name then
            if value then
                extra[id] = name;
                self:Debugf("Enabled %s tracking (extra)", name);
            else
                extra[id] = nil;
                self:Debugf("Disabled %s tracking (extra)", name);
            end
        end
    else
        local ignore = ignore(self);
        if value then
            ignore[id] = name;
            self:Debugf("Disabled %s tracking (default)", name);
        else
            ignore[id] = nil;
            self:Debugf("Enabled %s tracking (default)", name);
        end
    end

    self:RefreshSpells();
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

--- Initializes the addon's configuration and registers hooks.
-- Called by Ace3 when the addon loads and saved variables are available.
function BadPet:OnInitialize()

    -- Get stored variables.
    self.db = LibStub("AceDB-3.0"):New("BadPetDB", defaults, true);

    -- Register handlers for responding to profile changes.
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshProfile");
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshProfile");
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshProfile");

    -- Get profile configuration page for the stored variables.
    self.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);
    self.options.args.profiles.order = 100;

    -- Register configuration page and slash commands.
    local conf = LibStub("AceConfig-3.0");
    conf:RegisterOptionsTable("BadPet", self.options);
    conf:RegisterOptionsTable("BadPet: Cmd", self.options.args.cmd, { 'badpet', 'bp' });
    conf:RegisterOptionsTable("BadPet: General", self.options.args.general);
    conf:RegisterOptionsTable("BadPet: Profiles", self.options.args.profiles);

    local dialog = LibStub("AceConfigDialog-3.0");
    self.config = dialog:AddToBlizOptions("BadPet: General", L["BadPet"]);
    dialog:AddToBlizOptions("BadPet: Profiles", "Profiles", L["BadPet"]);

    self:RegisterComm(ADDON_PREFIX);
end

--- Called by framework when addon is enabled.
function BadPet:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "ZoneIn");
    self:Refresh();
end

--- Called by framework when addon is disabled.
function BadPet:OnDisable()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD");
    self:Refresh();
end

--- Called when profile changes. Calls Refresh on this addon and children.
function BadPet:RefreshProfile()
    self:Refresh();
    if self.Fixer then
        self.Fixer:Refresh();
    end
end

function BadPet:Clear()
    local history, queue;
    history = self.history;

    -- clear history
    for pet in pairs(history) do
        history[pet] = nil;
    end
    self.history.reset = time();

    -- clear event queue
    queue = self.queue;
    for pet in pairs(queue) do
        queue[pet] = nil;
    end
end

function BadPet:ZoneIn()
    self:Clear();
    self:Refresh();
end

--- Refreshes this addon's settings using profile and world state.
function BadPet:Refresh()
    local register = self:GetInInstance();

    if self.db.profile.debug then
        register = true;
    end

    if not self.db.profile.enable then
        register = false;
    end

    if register then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
        self:RegisterEvent("PLAYER_REGEN_ENABLED");
    else
        self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
        self:UnregisterEvent("PLAYER_REGEN_ENABLED");
    end

    self:RefreshSpells();
end

--------------------------------------------------------------------------------
-- Event Handling
--------------------------------------------------------------------------------

--- Process combat event log
-- If the event is a successful spell cast, a pet event generated within
-- player's raid or party, and the spell is on our list of 'bad' spells,
-- then this event will trigger an addon event to report the pet.
function BadPet:COMBAT_LOG_EVENT_UNFILTERED(...)
    local _, time, event, _, sid, sname, sflags, _, tid, tname, tflags, _, spell, spellName = ...;
    if (event == "SPELL_CAST_SUCCESS")
            and self.spells[spell]
            and (bit.band(COMBATLOG_OBJECT_TYPE_MASK, sflags) == COMBATLOG_OBJECT_TYPE_PET)
            and (bit.band(COMBATLOG_OBJECT_AFFILIATION_MASK, sflags) <= COMBATLOG_OBJECT_AFFILIATION_RAID)
    then
        local report = {
            event = event,
            time = time,
            pet = { id = sid, name = sname },
            target = { id = tid, name = tname },
            spell = { id = spell, name = spellName },
        };
        self:Growl(report);
    elseif (event == "SWING_DAMAGE" or event == "SWING_MISS")
            and self.db.profile.melee
            and (bit.band(COMBATLOG_OBJECT_TYPE_MASK, tflags) == COMBATLOG_OBJECT_TYPE_PET)
            and (bit.band(COMBATLOG_OBJECT_AFFILIATION_MASK, tflags) <= COMBATLOG_OBJECT_AFFILIATION_RAID)
    then
        local report = {
            event = event,
            time = time,
            pet = { id = tid, name = tname },
            target = { id = sid, name = sname },
            spell = { id = 1, name = "melee" },
        };
        self:Growl(report);
    end
end

--- Player left combat.
-- Leaving combat resets the 'quiet' filter.
function BadPet:PLAYER_REGEN_ENABLED(...)
    self.history.reset = time();
    self:Debug("Leaving combat, warnings reset")
end

--- Generate a growl event to test the addon in response to a user request.
function BadPet:Test()
    self:Clear();
    local src, dst = UnitGUID("pet"), UnitGUID("player");
    local sName, dName = UnitName("pet"), UnitName("player");
    local record = {
        time = time(),
        event = "SPELL_CAST_SUCCESS",
        pet = {
            id = UnitGUID("pet") or 0,
            name = UnitName("pet") or "FakePet",
        },
        target = {
            id = UnitGUID("player"),
            name = UnitName("player"),
        },
        owner = {
            id = UnitGUID("target") or 0,
            name = UnitName("target") or "Hunter2",
        },
        spell = {
            id = 2649,
            name = "Growl",
        },
    };
    self:Growl(record);
end

--- Respond to a pet growl event in combat log.
-- Update history for that pet/owner.
-- Check settings and history to work out whether to send a message or not.
function BadPet:Growl(report)
    local history, queue, reset;
    local player, targetText, spellText;

    history = self.history[report.pet.id][report.spell.id];
    reset = self.history.reset;

    -- decide whether we will report this event
    if history.time < self.history.reset -- no reports since combat started
            or self.db.profile.state == "noisy" then -- we report everything
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

    self:AddOwner(report);

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
-- Utility Methods
--------------------------------------------------------------------------------

--- Find the owner of a particular pet and add their details to the report.
-- @param pet: a pet descriptor
function BadPet:AddOwner(report)
    local subject = report.pet and report.pet.id;
    local unit, owner;
    if subject == UnitGUID("pet") then
        unit = "player"
    elseif UnitPlayerOrPetInParty(subject) then
        for i = 1, 4 do
            local id = UnitGUID("partypet" .. i)
            if (id and id == subject) then
                unit = "party" .. i;
                break;
            end
        end
    elseif UnitPlayerOrPetInRaid(subject) then
        for i = 1, GetNumGroupMembers(), 1 do
            local id = UnitGUID("raidpet" .. i)
            if (id and id == subject) then
                unit = "raid" .. i;
                break;
            end
        end
    end

    if unit then
        report.owner = { id = UnitGUID(unit), name = GetUnitName(unit, true) };
    end
end

--- Returns true if the player is in a dungeon or raid instance.
function BadPet:GetInInstance()
    local inInstance, instanceType = IsInInstance();
    return inInstance and (instanceType == "party" or instanceType == "raid");
end

--- Format and print a message (using string.format)
function BadPet:Printf(...)
    self:Print(string.format(...))
end

--- Print a debugging message (only when debug is turned on)
function BadPet:Debug(message)
    if self.db.profile.debug then
        self:Print(message);
    end
end

--- Format and print a debugging message (only when debug is turned on)
function BadPet:Debugf(...)
    if self.db.profile.debug then
        self:Debug(string.format(...));
    end
end

--------------------------------------------------------------------------------
-- Messaging Methods
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

    if event == "SWING_DAMAGE" then
        message = (L["%s was hit by %s"]):format(subject, target);
    elseif event == "SWING_MISS" then
        message = (L["%s was missed by %s"]):format(subject, target);
    elseif target then
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

--- Print the current state of the addon to the default chat frame.
function BadPet:Status()
    local message;
    local state = self.db.profile.state;
    local frame = self.db.profile.frame;
    local _, itype = IsInInstance();

    if not self.db.profile.enable then
        message = L["disabled"];
    elseif not self.db.profile.debug then
        message = L["%s, reporting to %q"];
    else
        message = L["%s, reporting to %q in debug mode (instance: %s)"];
    end

    self:Printf(message, state, frame, itype);
end
