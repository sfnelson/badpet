if not BadPet then
   BadPet = { debug = false, history = {} }
end
local lib = BadPet

lib.ChatFrame = DEFAULT_CHAT_FRAME;
lib.Options = {
   start = function (params) BadPet.Start(params) end,
   stop = function (params) BadPet.Stop(params) end,
   state = function (params) BadPet.State(params) end,
   party = function (params) BadPet.SetFrame("party", params) end,
   private = function (params) BadPet.SetFrame("private", params) end,
   test = function (params) BadPet.Test(params) end
};

lib.Events = {
   COMBAT_LOG_EVENT_UNFILTERED = function (...) lib.CombatLogEvent(...) end,
   PLAYER_ENTERING_WORLD = function (...) lib.CheckInstance(...) end,
   ADDON_LOADED = function (...) lib.AddonLoaded(...) end
};

function lib.AddonLoaded(...)
   if not BadPet_State then
      BadPet_State = "running";
      BadPet_Frame = "private";
   end
   
   lib.CheckInstance();
end

function lib.CombatLogEvent(...)
   local _, ttype, sGUID, sName, sFlags, dGUID, dName, _, spellid, spellname = select(1, ...);
   
   if (ttype == "SPELL_CAST_SUCCESS")
   and (
      -- growl (generic hunter pet)
      (spellid == 2649)
      -- suffering (voidwalker)
      or (spellid == 17735)
   )
   and (bit.band(COMBATLOG_OBJECT_TYPE_MASK, sFlags) == COMBATLOG_OBJECT_TYPE_PET)
   and (bit.band(COMBATLOG_OBJECT_AFFILIATION_MASK, sFlags) <= COMBATLOG_OBJECT_AFFILIATION_RAID)
   then
      BadPet.Growl(sName, spellid, dName, sGUID, dGUID);
   end
end

function lib.CheckInstance()
   if BadPet_State ~= "running" then
      return
   end
   
   inInstance, instanceType = IsInInstance();
   if inInstance and (instanceType == "party" or instanceType == "raid") then
      BadPetFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
   else
      BadPetFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
   end
end

function lib.Message(msg)
   lib.ChatFrame:AddMessage(msg);
end

function lib.Start()
   BadPet_State = "running";
   lib.CheckInstance();
   lib.State();
end

function lib.Stop()
   BadPetFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
   BadPet_State = "stopped";
   lib.State();
end

function lib.SetFrame(frame)
   BadPet_Frame = frame;
   lib.State();
end

function lib.Test()
   lib.Growl("testPet", 2649, "testTarget");
end

function lib.GetPlayerName(guid)
   local pet;
   for i = 1, GetNumRaidMembers() do
      pet = UnitGUID("raidpet"..i);
      if (pet and pet == guid) then
         return UnitName("raid"..i);
      end
   end
   for i = 1,4 do
      pet = UnitGUID("partypet"..i);
      if (pet and pet == guid) then
         return UnitName("party"..i);
      end
   end
   pet = UnitGUID("pet");
   if (pet and pet == guid) then
      return UnitName("player");
   end
end

function lib.Growl(pet, spell, target, srcId, dstId)
   
   -- avoid repeating message multiple times for the same mob
   if lib.history[srcId] and (lib.history[srcId] == dstId) then
      return;
   end
   
   -- get player name from pet's guid
   local player, realm;
   if srcId then
      player, realm = lib.GetPlayerName(srcId);
   end
   
   -- store history to prevent spam
   if srcId then
      lib.history[srcId] = dstId;
   end
   
   -- construct message
   local message;
   if (player) then
      message = player.."'s pet, "..pet..",";
   else
      message = pet;
   end
   message = message.." used "..GetSpellLink(spell).." to taunt "..target;
   
   -- send message to party
   if (BadPet_Frame == "party") then
      if UnitInRaid("player") then
         SendChatMessage(message, "RAID");
         return;
      elseif GetNumPartyMembers() > 0 then
         SendChatMessage(message, "PARTY");
         return;
      end
   end
   
   -- fail through case: not in party or reporting set to private
   lib.Message("|cffffff00BadPet:|r "..message);
end

function lib.State()
   local message = "|cffffff00BadPet|r "..BadPet_State..", reporting to "..BadPet_Frame;
   if lib.debug then
      local _, itype = IsInInstance();
      message = message.." (instance: "..itype..")"
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
   lib.Message("|cffffff00  Usage:|r /badpet, /bp\n|cffffff00Options:|r "..table.concat(options, ", "));
end

SLASH_BADPET1, SLASH_BADPET2 = "/badpet", "/bp";
SlashCmdList["BADPET"] = function (m,f) BadPet.Main(m, f) end

function BadPetFrame_OnLoad()
   BadPetFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
   BadPetFrame:RegisterEvent("ADDON_LOADED");
end

function BadPetFrame_OnEvent(event, ...)
   BadPet.Events[event](...);
end
