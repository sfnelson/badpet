--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    BadPet.lua
-- Author:  @project-author@
-- License: LICENSE.txt
--------------------------------------------------------------------------------

if not BadPet then
  local AceAddon = LibStub("AceAddon-3.0");
  BadPet = AceAddon:NewAddon("BadPet", "AceConsole-3.0", "AceEvent-3.0",
    "AceComm-3.0", "AceSerializer-3.0", "AceTimer-3.0");
end
local BadPet = BadPet;

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

------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

--- Spells which the addon tracks.
BadPet.addonSpells = {
   Growl        = 2649,     -- growl (generic hunter pet - increases threat)
   Taunt        = 53477,    -- taunt (hunter pet talent - true taunt)
   Thunderstomp = 63900,    -- thunderstomp (hunter pet talent - damage+threat)
   Suffering    = 17735,    -- suffering (voidwalker - true taunt)
   TwinHowl     = 58857,    -- twin howl (spirit wolves - true taunt)
};

BadPet.spells = {};

--- Structures for event tracking.
BadPet.history = { reset = 0 };
BadPet.queue = {};

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
  name = "BadPet",
  type = 'group',
  handler = BadPet,
  set = "SetOption",
  get = "GetOption",
  args = {
    enable = {
      name = "Enable",
      desc = "Enables / disables the addon.",
      type = "toggle",
      order = 1,
    },
    general = {
      name = "General",
      type = "group",
      order = 2,
      handler = BadPet,
      set = "SetOption",
      get = "GetOption",
      args = {
        state = {
          name = "Report Frequency",
          desc = "Report every time a pet taunts (noisy)"..
            " or once per combat (quiet).",
          type = "select",
          values = { STATE_QUIET, STATE_NOISY },
          style = "radio",
          order = 20,
        },
        frame = {
          name = "Report Destination",
          desc = "Report to private, whisper, or party.",
          type = "select",
          values = { FRAME_PRIVATE, FRAME_WHISPER, FRAME_PARTY },
          style = "radio",
          order = 30,
        },
        ignore = {
          name = "Spells to ignore",
          type = "group",
          handler = BadPet,
          set = "SetSpellState",
          get = "GetSpellState",
          order = 40,
        },
        add = {
          name = "Extra Spells",
          type = "group",
          handler = BadPet,
          set = "SetSpellState",
          get = "GetSpellState",
          order = 50,
        },
        melee = {
          name = "Show melee hits on pets",
          type = "toggle",
          order = 60,
        },
        test = {
          name = "Test",
          type = "execute",
          func = "Test",
          order = 70,
        },
        debug = {
          name = "Debug",
          type = "toggle",
          hidden = true,
        },
      },
    },
    cmd = {
      name = "Commandline Options",
      type = "group",
      order = 3,
      handler = BadPet,
      set = "SetOption",
      get = "GetOption",
      hidden = true,
      args = {
        enable = {
          name = "Enable Addon",
          type = "execute",
          func = function () BadPet:Enable(); end,
          order = 10;
        },
        disable = {
          name = "Disable Addon",
          type = "execute",
          func = function () BadPet:Disable(); end,
          order = 20;
        },
        status = {
          name = "Show Status",
          type = "execute",
          func = function () BadPet:Status(); end,
          order = 30;
        },
        test = {
          name = "Print a test report",
          type = "execute",
          func = function () BadPet:Test(); end,
          order = 40;
          hidden = true;
          width = "half",
        },
        quiet = {
          name = "Limit reports to once per combat",
          type = "execute",
          func = function () BadPet:SetProperty("state", STATE_QUIET); end,
          order = 50;
        },
        noisy = {
          name = "Report all taunts",
          type = "execute",
          func = function () BadPet:SetProperty("state", STATE_NOISY); end,
          order = 60;
        },
        private = {
          name = "Report only in the chat frame",
          type = "execute",
          func = function () BadPet:SetProperty("frame", FRAME_PRIVATE); end,
          order = 70;
        },
        whisper = {
          name = "Report as a whisper",
          type = "execute",
          func = function () BadPet:SetProperty("frame", FRAME_WHISPER); end,
          order = 80;
        },
        party = {
          name = "Report to party/raid",
          type = "execute",
          func = function () BadPet:SetProperty("frame", FRAME_PARTY); end,
          order = 90;
        },
        config = {
          name = "Open Config",
          type = "execute",
          func = function ()
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
    for k,v in pairs(info.option.values) do
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

  if self.db.profile.debug then
    self:Print(option .. " set to " .. tostring(self.db.profile[option]));
  end

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

  if self.db.profile.debug then
    self:Print(option .. " set to " .. tostring(self.db.profile[option]));
  end

  self:Status();
end

--- Generate a growl event to test the addon in response to a user request.
function BadPet:Test()
  self.history = {};
  self.history.reset = time();
  self.queue = {};
  local src,dst = UnitGUID("pet"),UnitGUID("player");
  local sName, dName = UnitName("pet"),UnitName("player");
  local record = {
    pet = src or 0,
    petname = sName or "FakePet",
    target = dst,
    targetName = dName;
    spell = 2649,
    time = time(),
  };
  self:Growl(record);
end

--------------------------------------------------------------------------------
-- Configure Spells Options
--------------------------------------------------------------------------------

--- Recreate the spells option page
function BadPet:RefreshSpells()
  self.spells = {};

  local ignore = self.db.profile.ignore;

  if not ignore then
    ignore = {};
  end

  for spell,id in pairs(self.addonSpells) do
    if not ignore[id] then
      self.spells[spell] = id;
    end
  end

  if self.db.profile.spells then
    for id,_ in pairs(self.db.profile.spells) do
      local spell = GetSpellInfo(id);
      if spell then
        self.spells[spell] = id;
      end
    end
  end

  local toIgnore = self.options.args.general.args.ignore;

  toIgnore.args = {};

  for spell,id in pairs(self.addonSpells) do
    local c = {}
    c.name = spell;
    c.type = "toggle";
    toIgnore.args[tostring(id)] = c;
  end

  local toAdd = self.options.args.general.args.add;

  toAdd.args = {};

  if self.db.profile.spells then
    for id,_ in pairs(self.db.profile.spells) do
      local spell = GetSpellInfo(id);
      if spell then
        local c = {}
        c.name = spell;
        c.type = "toggle";
        toAdd.args[tostring(id)] = c;
      end
    end
  end

  local add = {};
  add.name = "Add SpellId";
  add.type = "input";
  add.desc = "Enter a spell id to add to the watch list (pet spells only)";
  toAdd.args["add"] = add;

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

--- Set the state of a spell in the spells option table
function BadPet:SetSpellState(info, value)
  local id;

  if info[#info] == "add" then
    id = tonumber(value);
    if tostring(id) == value then
      value = id;
    end
    local name = GetSpellInfo(value);
    if name then
      if not self.db.profile.spells then
        self.db.profile.spells = {};
      end
      self.db.profile.spells[id] = name;
    end
  else
    id = tonumber(info[#info]);
    local name = GetSpellInfo(id);
    if not name then
      return;
    elseif self.addonSpells[name] then
      if not self.db.profile.ignore then
        self.db.profile.ignore = {};
      end
      self.db.profile.ignore[id] = value;
    elseif self.db.profile.spells and self.db.profile.spells[id] then
      self.db.profile.spells = table.remove(self.db.profile.spells, id);
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

  -- Migrate users who are upgrading from old addon versions.
  self:MigrateDepricatedSettings();

  -- Register handlers for responding to profile changes.
  self.db.RegisterCallback(self, "OnProfileChanged", "RefreshProfile");
  self.db.RegisterCallback(self, "OnProfileCopied", "RefreshProfile");
  self.db.RegisterCallback(self, "OnProfileReset", "RefreshProfile");

  -- Get profile configuration page for the stored variables.
  self.options.args.profiles
    = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db);
  self.options.args.profiles.order = 100;

  -- Register configuration page and slash commands.
  local conf = LibStub("AceConfig-3.0");
  conf:RegisterOptionsTable("BadPet", self.options);
  conf:RegisterOptionsTable("BadPet: Cmd",
      self.options.args.cmd, {'badpet','bp'});
  conf:RegisterOptionsTable("BadPet: General", self.options.args.general);
  conf:RegisterOptionsTable("BadPet: Profiles", self.options.args.profiles);

  local dialog = LibStub("AceConfigDialog-3.0");
  dialog:AddToBlizOptions("BadPet", "BadPet");
  self.config = dialog:AddToBlizOptions("BadPet: General", "General", "BadPet");
  dialog:AddToBlizOptions("BadPet: Profiles", "Profiles", "BadPet");

  self:RegisterComm(ADDON_PREFIX);
end

--- Called by framework when addon is enabled.
function BadPet:OnEnable()
  self.db.profile.enable = true;

  self:RegisterEvent("PLAYER_ENTERING_WORLD", "ZoneIn");
  self:Refresh();
end

--- Called by framework when addon is disabled.
function BadPet:OnDisable()
  self.db.profile.enable = false;

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

function BadPet:ZoneIn()
  self.history = {};
  self.history.reset = time();
  self.queue = {};
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
  local ttype, _, sGUID, sName, sFlags, _, dGUID, dName, dFlags, _, spellid, spellname
    = select(3, ...);

  if
    (ttype == "SPELL_CAST_SUCCESS")
  and
    (bit.band(COMBATLOG_OBJECT_TYPE_MASK, sFlags) == COMBATLOG_OBJECT_TYPE_PET)
  and
    (bit.band(COMBATLOG_OBJECT_AFFILIATION_MASK, sFlags)
      <= COMBATLOG_OBJECT_AFFILIATION_RAID)
  and
    self.spells[spellname] and self.spells[spellname] == spellid
  then
    local report = {
      pet = sGUID,
      petname = sName,
      target = dGUID,
      targetname = dName,
      spell = spellid,
      spellname = spellname,
      time = time(),
    };
    self:Growl(report);
  elseif
    (ttype == "SWING_DAMAGE" or ttype == "SWING_MISS")
  and
    (bit.band(COMBATLOG_OBJECT_TYPE_MASK, dFlags) == COMBATLOG_OBJECT_TYPE_PET)
  and
    (bit.band(COMBATLOG_OBJECT_AFFILIATION_MASK, dFlags)
      <= COMBATLOG_OBJECT_AFFILIATION_RAID)
  and
    self.db.profile.melee
  then
    local hit = "hit";
    if (ttype == "SWING_MISS") then
      hit = "miss"
    end
    local report = {
      pet = dGUID,
      petname = dName,
      target = sGUID,
      targetname = sName,
      spell = 1,
      spellname = "melee",
      hittype = hit,
      time = time(),
    };
    self:Growl(report);
  end
end

--- Player left combat.
-- Leaving combat resets the 'quiet' filter.
function BadPet:PLAYER_REGEN_ENABLED(...)
   self.history.reset = time();
   if self.db.profile.debug then
      self:Print("Left combat, warnings reset");
   end
end

--- Respond to a pet growl event in combat log.
-- Update history for that pet/owner.
-- Check settings and history to work out whether to send a message or not.
function BadPet:Growl(report)
  local player, targetText, spellText;

  -- record the event
  if not self.history[report.pet] then
    self.history[report.pet] = {}
  end

  local last = self.history[report.pet][report.spell]
  if not last then
    last = { time = 0, count = 0 };
    self.history[report.pet][report.spell] = last;
  end

  local last = self.history[report.pet][report.spell];

  -- decide whether we will report this event
  if self.db.profile.state == "noisy" -- we report everything
  or last.time < self.history.reset then  -- no reports since combat started

    last.time = report.time;
    last.count = last.count + 1;

    if last.count > self.db.profile.grace then
      last.count = 0;
      self:SendReport(report);
    end
  end
end

--- Process sending a report.
function BadPet:SendReport(report)

  -- if we're set to noisy don't check with others, send the report now
  if self.db.profile.state == NOISY then
    self:SendMessage(report);
    report.sent = UnitName("player");
    self:BroadcastReport(report);
    return;
  end

  if not self.queue[report.pet] then
    self.queue[report.pet] = {}
  end

  -- check for a report already on the queue, or queue this one
  if self.queue[report.pet][report.spell]
  and self.queue[report.pet][report.spell].time + REPORT_DELAY > report.time
  then
    -- someone else has already reported this recently
    return
  else
    -- queue this report and broadcast it to others
    report.priority = math.random(MAX_PRIORITY);

    if UnitGUID("pet") == report.pet then
      report.priority = IS_ME_PRIORITY;
    end

    self.queue[report.pet][report.spell] = report;
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
  if not (prefix == ADDON_PREFIX) then
    return;
  end

  local debug = self.db.profile.debug;

  local success,report = self:Deserialize(msg);
  if not success then
    if debug then
      self:Print("error deserializing message: "..msg);
    end
    return;
  end

  if not self.queue[report.pet] then
    self.queue[report.pet] = {};
  end

  if self.queue[report.pet][report.spell] then
    local ours = self.queue[report.pet][report.spell];
    if report.sent then -- already been sent
      ours.sent = sender;
      if debug then self:Print("supressed, they already sent it"); end
    elseif report.priority > ours.priority then -- theirs wins, they'll send it
      ours.sent = sender;
      if debug then
        self:Print("supressed, they've got priority ("
          ..report.priority..":"..ours.priority..")");
      end
    end -- otherwise ignore, we'll still send ours
  else -- they saw something we didn't, or don't care about
    report.sent = sender;
    self.queue[report.pet][report.spell] = report;
    if debug then
      self:Print("receieved a warning that we didn't see");
    end

    if not self.history[report.pet] then
      self.history[report.pet] = {};
    end

    if not self.history[report.pet][report.spell] then
      self.history[report.pet][report.spell] = {};
    end

    -- message has been set, update history accordingly.
    self.history[report.pet][report.spell].time = time();
    self.history[report.pet][report.spell].count = 0;
  end
end

--- Iterate through the queue and send reports if the delay has elapsed.
-- Removes reports which have already been sent silently.
function BadPet:CheckQueue(report)
  local time = time();

  self:SendMessage(report);

  if self.queue[report.pet] then
  	self.queue[report.pet][report.spell] = nil;
  end
end

--- Send a warning message to the appropriate frame.
function BadPet:SendMessage(report)
  local targetText, spellText;
  local playername = self:GetOwnerName(report.pet);
  local bp = ADDON_PREFIX..": ";

  -- construct pet message
  targetText = playername.."'s pet, "..report.petname..",";

  -- construct spell message
  if report.spell == 1 then
    spellText = " was " .. report.hittype .. " by "
     .. report.targetname;
  elseif report.targetname then
    spellText = " used " .. GetSpellLink(report.spell)
      .. " on " .. report.targetname;
  else
    spellText = " used " .. GetSpellLink(report.spell).." (aoe)"
  end

  -- send message
  if report.sent then
    spellText = spellText .. " (reported by " .. report.sent .. ")";
  elseif UnitGUID("pet") == report.pet then
    targetText = "Your pet, "..report.petname..",";
  elseif self.db.profile.frame == FRAME_PARTY then
    if UnitInRaid("player") then
      SendChatMessage(bp..targetText..spellText, "RAID");
      return;
    elseif GetNumGroupMembers() > 0 then
      SendChatMessage(bp..targetText..spellText, "PARTY");
      return;
    end
  elseif self.db.profile.frame == FRAME_WHISPER then
    targetText = bp.."Your pet, "..report.petname..",";
    SendChatMessage(targetText..spellText, "WHISPER",
        GetDefaultLanguage("player"), playername);
    return;
  end

  -- fall through case
  self:Print(targetText..spellText);
end

--------------------------------------------------------------------------------
-- Utility Methods
--------------------------------------------------------------------------------

--- Returns true if the player is in a dungeon or raid instance.
function BadPet:GetInInstance()
  local inInstance, instanceType = IsInInstance();
  return inInstance and (instanceType == "party" or instanceType == "raid");
end

--- Work out the name of the owner of a particular pet.
-- @param petGUID the pet's
function BadPet:GetOwnerName(petGUID)
  local pet;
  for i = 1, GetNumGroupMembers() do
    pet = UnitGUID("raidpet"..i);
    if (pet and pet == petGUID) then
      return (GetUnitName("raid"..i,true)or""):gsub(" ","");
    end
  end
  for i = 1,4 do
    pet = UnitGUID("partypet"..i);
    if (pet and pet == petGUID) then
      return (GetUnitName("party"..i,true)or""):gsub(" ","");
    end
  end
  pet = UnitGUID("pet");
  if (pet and pet == petGUID) then
    return UnitName("player");
  else
    return "Unknown";
  end
end

--- Print the current state of the addon to the default chat frame.
function BadPet:Status()
  local message;
  if not self.db.profile.enable then
    message = "disabled";
  else
    message = self.db.profile.state .. ", ";
    message = message .. "reporting to " .. self.db.profile.frame;

    if self.db.profile.debug then
      local _, itype = IsInInstance();
      message = message .. " in debug mode (instance: "..itype..")";
    end
  end

  self:Print(message);
end

--------------------------------------------------------------------------------
-- Methods for handling compatability with old versions
--------------------------------------------------------------------------------

--- Checks for depricated settings and stores then in the new db format.
function BadPet:MigrateDepricatedSettings()
  if BadPet_State then
    if BadPet_State == "stopped" then
      self.db.profile.enabled = false;
    else
      self.db.profile.state = BadPet_State
    end
    BadPet_State = nil;
  end
  if BadPet_Frame then
    self.db.profile.frame = BadPet_Frame;
    BadPet_Frame = nil;
  end
  if BadPet_Debug then
    self.db.profile.debug = BadPet_Debug;
    BadPet_Debug = nil;
  end
  if self.db.profile.fixer == nil then
    self.db.profile.fixer = true;
  end
  if self.db.profile.grace == nil then
    self.db.profile.grace = 0;
  end
end

