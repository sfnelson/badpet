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
local STATE_QUIET = "quiet";
local STATE_NOISY = "noisy";
local FRAME_PRIVATE = "private";
local FRAME_WHISPER = "whisper";
local FRAME_PARTY = "party";
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
    local function SomePet()
        local id = UnitGUID("target")
        if id and string.match(id, "^Pet-") then
            return { id = id, name = UnitName("target") }
        elseif UnitExists("pet") then
            return { id = UnitGUID("pet"), name = UnitName("pet") }
        else
            return { id = 0, name = "FakePet" }
        end
    end

    self:Clear();
    local record = {
        time = time(),
        event = "SPELL_CAST_SUCCESS",
        pet = SomePet(),
        target = {
            id = UnitGUID("player"),
            name = UnitName("player"),
        },
        spell = {
            id = 2649,
            name = "Growl",
        },
    };
    self:Growl(record);
end

--------------------------------------------------------------------------------
-- Messaging Methods
--------------------------------------------------------------------------------

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
