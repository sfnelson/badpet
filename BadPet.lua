if not BadPet then
   BadPet = { debug = false, history = {} }
end
local lib = BadPet

lib.ChatFrame = DEFAULT_CHAT_FRAME;
lib.Options = {
   -- print state
   state = function (params) BadPet.State(params) end,
   -- set state
   stop = function (params) BadPet.SetState("stopped", params) end,
   quiet = function (params) BadPet.SetState("quiet", params) end,
   noisy = function (params) BadPet.SetState("noisy", params) end,
   -- set reporting
   party = function (params) BadPet.SetFrame("party", params) end,
   private = function (params) BadPet.SetFrame("private", params) end,
   whisper = function (params) BadPet.SetFrame("whisper", params) end,
   -- misc
   test = function (params) BadPet.Test(params) end,
   debug = function (params) BadPet.Debug(params) end
};

lib.Events = {
   COMBAT_LOG_EVENT_UNFILTERED = function (...) lib.CombatLogEvent(...) end,
   PLAYER_ENTERING_WORLD = function (...) lib.CheckInstance(...) end,
   ADDON_LOADED = function (...) lib.AddonLoaded(...) end,
   PLAYER_REGEN_ENABLED = function (...) lib.LeftCombat(...) end,
   CHAT_MSG_PET_INFO = function (...) lib.PetInfoChanged(...) end,
   PET_BAR_UPDATE = function (...) lib.PetInfoChanged(...) end
};

lib.Spells = {
   Growl        = 2649,   -- growl (generic hunter pet - increases threat)
   Taunt        = 53477,  -- taunt (hunter pet talent - true taunt)
   Thunderstomp = 63900,  -- thunderstomp (hunter pet talent - damage + threat)
   Suffering    = 17735   -- suffering (voidwalker - true taunt)
}

function lib.AddonLoaded(...)
   if not BadPet_State or BatPet_State == "running" then
      BadPet_State = "quiet";
   end
   if not BadPet_Frame then
      BadPet_Frame = "private";
   end
   if not BadPet_Debug then
      BadPet_Debug = false;
   end
   
   lib.CheckInstance();
end

function lib.CombatLogEvent(...)
   local _, ttype, sGUID, sName, sFlags, dGUID, dName, _, spellid, spellname = select(1, ...);
   
   if (ttype == "SPELL_CAST_SUCCESS")
   and (bit.band(COMBATLOG_OBJECT_TYPE_MASK, sFlags) == COMBATLOG_OBJECT_TYPE_PET)
   and (bit.band(COMBATLOG_OBJECT_AFFILIATION_MASK, sFlags) <= COMBATLOG_OBJECT_AFFILIATION_RAID)
   and lib.Spells[spellname] and lib.Spells[spellname] == spellid
   then
      BadPet.Growl(sName, spellid, dName, sGUID, dGUID);
   end
end

function lib.LeftCombat(...)
   lib.history = {};
   if BadPet_Debug then
      lib.Message("|cffffff00BadPet:|r Left combat, warnings reset");
   end
end

function lib.PetInfoChanged(...)
   if lib.UpdateLDB then
      lib.UpdateLDB(...);
   end
end

function lib.GetInInstance()
   local inInstance, instanceType = IsInInstance();
   return inInstance and (instanceType == "party" or instanceType == "raid");
end

function lib.CheckInstance()
   local register = lib.GetInInstance();
   
   if BadPet_Debug then
      register = true;
   end
   
   if BadPet_State == "stopped" then
      register = false;
   end
   
   if register then
      BadPetFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
      BadPetFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
   else
      BadPetFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
      BadPetFrame:UnregisterEvent("PLAYER_REGEN_ENABLED");
   end
end

function lib.Message(msg)
   lib.ChatFrame:AddMessage(msg);
end

function lib.SetState(state)
   BadPet_State = state;
   lib.CheckInstance();
   lib.State();
end

function lib.Debug()
   BadPet_Debug = not BadPet_Debug;
   lib.CheckInstance();
   lib.State();
end

function lib.SetFrame(frame)
   BadPet_Frame = frame;
   lib.State();
end

function lib.Test()
   lib.history = {};
   local src,dst = UnitGUID("pet"),UnitGUID("player");
   if src then
      lib.Growl(GetUnitName("pet"), 2649, GetUnitName("player"), src, dst);
   else 
      lib.Growl("TestPet", 2649, "TestTarget");
   end
end

function lib.GetPlayerName(guid)
   local pet;
   for i = 1, GetNumRaidMembers() do
      pet = UnitGUID("raidpet"..i);
      if (pet and pet == guid) then
         return (GetUnitName("raid"..i,true)or""):gsub(" ","");
      end
   end
   for i = 1,4 do
      pet = UnitGUID("partypet"..i);
      if (pet and pet == guid) then
         return (GetUnitName("party"..i,true)or""):gsub(" ","");
      end
   end
   pet = UnitGUID("pet");
   if (pet and pet == guid) then
      return UnitName("player");
   end
end

function lib.Growl(pet, spell, target, srcId, dstId)
   local bp = "Bad Pet: ";
   local player, targetText, spellText;
   
   -- avoid repeating message multiple times for the same mob
   if BadPet_State ~= "noisy" and lib.history[srcId] then
      return;
   end
   
   -- get player name from pet's guid
   if srcId then
      player = lib.GetPlayerName(srcId);
   else 
      -- this should only happen when testing
      player = GetUnitName("player");
   end
   
   -- record this report to prevent spam
   if srcId then
      lib.history[srcId] = dstId;
   end
   
   -- construct pet message
   if (player) then
      targetText = player.."'s pet, "..pet..",";
   else
      targetText = pet;
   end
   
   -- construct spell message
   spellText = " used "..GetSpellLink(spell).." to taunt "..target;
   
   -- send message
   if player and (BadPet_Frame == "party") then
      if UnitInRaid("player") then
         SendChatMessage(bp..targetText..spellText, "RAID");
         return;
      elseif GetNumPartyMembers() > 0 then
         SendChatMessage(bp..targetText..spellText, "PARTY");
         return;
      end
   elseif player and (BadPet_Frame == "whisper") then
      targetText = "Your pet, "..pet..",";
      SendChatMessage(bp..targetText..spellText, "WHISPER", 
         GetDefaultLanguage("player"), player);
      return;
   end
   
   -- fall through case: not in party or reporting set to private
   lib.Message("|cffffff00BadPet:|r "..targetText..spellText);
end

function lib.State()
   local message = "|cffffff00BadPet:|r "..BadPet_State..", reporting to "..BadPet_Frame;
   if BadPet_Debug then
      local _, itype = IsInInstance();
      message = message.." in debug mode (instance: "..itype..")"
   end
   lib.Message(message);
end

function lib.Main(msg, frame)
   local command, rest = (msg or ""):match("^(%S*)%s*(.-)$");
   
   if command then
      for k,v in pairs(lib.Options) do
         if k==command then
            v(); return;
         end
      end
   end
   
   local options = {}
   for k,_ in pairs(lib.Options) do
      options[#options+1] = k;
   end
   
   lib.State();
   lib.Message("|cffffff00  Usage:|r /badpet, /bp\n|cffffff00Options:|r "
      ..table.concat(options, ", "));
end

SLASH_BADPET1, SLASH_BADPET2 = "/badpet", "/bp";
SlashCmdList["BADPET"] = function (m,f) BadPet.Main(m, f) end

function BadPetFrame_OnLoad()
   BadPetFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
   BadPetFrame:RegisterEvent("ADDON_LOADED");
   BadPetFrame:RegisterEvent("PET_BAR_UPDATE");
end

function BadPetFrame_OnEvent(event, ...)
   BadPet.Events[event](...);
end
