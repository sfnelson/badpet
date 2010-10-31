--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    BadPet.lua
-- Author:  @project-author@
-- License: LICENSE.txt
--------------------------------------------------------------------------------

if not BadPet then
  local AceAddon = LibStub("AceAddon-3.0");
  BadPet = AceAddon:NewAddon("BadPet", "AceConsole-3.0", "AceEvent-3.0");
end
local BadPet = BadPet;

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

--- Spells which the addon tracks.
BadPet.addonSpells = {
   Growl        = 2649,     -- growl (generic hunter pet - increases threat)
   Taunt        = 53477,    -- taunt (hunter pet talent - true taunt)
   Thunderstomp = 63900,    -- thunderstomp (hunter pet talent - damage+threat)
   Suffering    = 17735,    -- suffering (voidwalker - true taunt)
};

BadPet.spells = {};

--- Structure for event tracking.
BadPet.history = {};

--- Default settings for BadPetDB.
local defaults = {
  profile = {
    enable = true,
    state = "quiet",
    frame = "whisper",
    debug = false,
    fixer = true;

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
          values = { "quiet", "noisy" },
          style = "radio",
          order = 20,
        },
        frame = {
          name = "Report Destination",
          desc = "Report to private, whisper, or party.",
          type = "select",
          values = { "private", "whisper", "party" },
          style = "radio",
          order = 30,
        },
        test = {
          name = "Test",
          type = "execute",
          func = "Test",
          order = 50,
        },
        debug = {
          name = "Debug",
          type = "toggle",
          hidden = true,
        },
        ignore = {
          name = "Spells to ignore",
          type = "group",
          handler = BadPet,
          set = "SetSpellState",
          get = "GetSpellState",
          order = 60;
        },
        add = {
          name = "Extra Spells",
          type = "group",
          handler = BadPet,
          set = "SetSpellState",
          get = "GetSpellState",
          order = 70;
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
          func = function () BadPet:SetProperty("state", "quiet"); end,
          order = 50;
        },
        noisy = {
          name = "Report all taunts",
          type = "execute",
          func = function () BadPet:SetProperty("state", "noisy"); end,
          order = 60;
        },
        private = {
          name = "Report only in the chat frame",
          type = "execute",
          func = function () BadPet:SetProperty("frame", "private"); end,
          order = 70;
        },
        whisper = {
          name = "Report as a whisper",
          type = "execute",
          func = function () BadPet:SetProperty("frame", "whisper"); end,
          order = 80;
        },
        party = {
          name = "Report to party/raid",
          type = "execute",
          func = function () BadPet:SetProperty("frame", "party"); end,
          order = 90;
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
   local src,dst = UnitGUID("pet"),UnitGUID("player");
   if src then
      self:Growl(GetUnitName("pet"), 2649, GetUnitName("player"), src, dst);
   else
      self:Growl("TestPet", 2649, "TestTarget");
   end
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
end

--- Called by framework when addon is enabled.
function BadPet:OnEnable()
  self.db.profile.enable = true;

  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh");
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
  local ttype, sGUID, sName, sFlags, dGUID, dName, _, spellid, spellname
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
    self:Growl(sName, spellid, dName, sGUID, dGUID);
  end
end

--- Player left combat.
-- Leaving combat resets the 'quiet' filter.
function BadPet:PLAYER_REGEN_ENABLED(...)
   self.history = {};
   if self.db.profile.debug then
      self:Print("Left combat, warnings reset");
   end
end

--- Respond to a pet growl event in combat log.
-- Update history for that pet/owner.
-- Check settings and history to work out whether to print a message or not.
function BadPet:Growl(pet, spell, target, srcId, dstId)
  local bp = "BadPet: ";
  local player, targetText, spellText;

  -- avoid repeating message multiple times for the same combat period
  if self.db.profile.state ~= "noisy" and self.history[srcId] then
    return;
  end

  -- record this abuse
  if srcId then
    self.history[srcId] = (self.history[srcId] or 0) + 1;
  end

  -- get player name from pet's guid
  if srcId then
    player = self:GetOwnerName(srcId);
  else
    -- if we don't have a player name, use our name (testing)
    player = GetUnitName("player");
  end

  -- construct pet message
  if (player) then
    targetText = player.."'s pet, "..pet..",";
  else
    targetText = pet;
  end

  -- construct spell message
  if target then
    spellText = " used " .. GetSpellLink(spell) .. " to taunt " .. target;
  else
    spellText = " used " .. GetSpellLink(spell).." (taunt)"
  end

  -- send message
  if player and (self.db.profile.frame == "party") then
    if UnitInRaid("player") then
      SendChatMessage(bp..targetText..spellText, "RAID");
      return;
    elseif GetNumPartyMembers() > 0 then
      SendChatMessage(bp..targetText..spellText, "PARTY");
      return;
    end
  elseif player and (self.db.profile.frame == "whisper") then
    targetText = "Your pet, "..pet..",";
    SendChatMessage(bp..targetText..spellText, "WHISPER",
        GetDefaultLanguage("player"), player);
    return;
  end

  -- fall through case: not in party or reporting set to private
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
  for i = 1, GetNumRaidMembers() do
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
end
