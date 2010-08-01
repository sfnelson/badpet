if not BadHunterNo then
   BadHunterNo = { debug = false, history = {} }
end
local lib = BadHunterNo

lib.ChatFrame = DEFAULT_CHAT_FRAME;
lib.Options = {
   start = function (params) BadHunterNo.Start(params) end,
   stop = function (params) BadHunterNo.Stop(params) end,
   state = function (params) BadHunterNo.State(params) end,
   party = function (params) BadHunterNo.SetFrame("party", params) end,
   private = function (params) BadHunterNo.SetFrame("private", params) end,
   test = function (params) BadHunterNo.Test(params) end
};

lib.Events = {
   COMBAT_LOG_EVENT_UNFILTERED = function (...) lib.CombatLogEvent(...) end,
   PLAYER_ENTERING_WORLD = function (...) lib.CheckInstance(...) end,
   ADDON_LOADED = function (...) lib.AddonLoaded(...) end
};

function lib.AddonLoaded(...)
   if not BadHunterNo_State then
      BadHunterNo_State = "running";
      BadHunterNo_Frame = "private";
   end
   
   lib.CheckInstance();
end

function lib.CombatLogEvent(...)
   local _, ttype, sGUID, sName, sFlags, dGUID, dName, _, spellid, spellname = select(1, ...);
   
   if (ttype == "SPELL_CAST_SUCCESS")
   and (
      -- growl ranks 1-9
      (spellid == 2649) or (spellid == 14916) or (spellid == 14917) or (spellid == 14918)
      or (spellid == 14919) or (spellid == 14920) or (spellid == 14921) or (spellid == 27047)
      or (spellid == 61676)
      -- anguish ranks 1-4
      or (spellid == 33698) or (spellid == 33699) or (spellid == 33700)
      or (spellid == 47993)
      -- torment rangs 1-8
      or (spellid == 3716) or (spellid == 7809) or (spellid == 7810) or (spellid == 7811)
      or (spellid == 11774) or (spellid == 11775) or (spellid == 27270) or (spellid == 47984)
      -- for testing, ghoul's claw ability
      or (spellid == 47468 and lib.debug)
   )
   and (bit.band(COMBATLOG_OBJECT_TYPE_MASK, sFlags) == COMBATLOG_OBJECT_TYPE_PET)
   and (bit.band(COMBATLOG_OBJECT_AFFILIATION_MASK, sFlags) <= COMBATLOG_OBJECT_AFFILIATION_RAID)
   then
      BadHunterNo.Growl(sName, spellid, dName, sGUID, dGUID);
   end
end

function lib.CheckInstance()
   if BadHunterNo_State ~= "running" then
      return
   end
   
   inInstance, instanceType = IsInInstance();
   if inInstance and (instanceType == "party" or instanceType == "raid") then
      BadHunterNoFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
   else
      BadHunterNoFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
   end
end

function lib.Message(msg)
   lib.ChatFrame:AddMessage(msg);
end

function lib.Start()
   BadHunterNo_State = "running";
   lib.CheckInstance();
   lib.State();
end

function lib.Stop()
   BadHunterNoFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
   BadHunterNo_State = "stopped";
   lib.State();
end

function lib.SetFrame(frame)
   BadHunterNo_Frame = frame;
   lib.State();
end

function lib.Test()
   lib.Growl("testPet", 61676, "testTarget");
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
   if (BadHunterNo_Frame == "party") then
      if UnitInRaid("player") then
         SendChatMessage(message, "RAID");
         return;
      elseif GetNumPartyMembers() > 0 then
         SendChatMessage(message, "PARTY");
         return;
      end
   end
   
   -- fail through case: not in party or reporting set to private
   lib.Message("|cffffff00BadHunterNo:|r "..message);
end

function lib.State()
   local message = "|cffffff00BadHunterNo|r "..BadHunterNo_State..", reporting to "..BadHunterNo_Frame;
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
   lib.Message("|cffffff00  Usage:|r /badhunterno, /bhn\n|cffffff00Options:|r "..table.concat(options, ", "));
end

SLASH_BADHUNTERNO1, SLASH_BADHUNTERNO2 = "/badhunterno", "/bhn";
SlashCmdList["BADHUNTERNO"] = function (m,f) BadHunterNo.Main(m, f) end

function BadHunterNoFrame_OnLoad()
   BadHunterNoFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
   BadHunterNoFrame:RegisterEvent("ADDON_LOADED");
end

function BadHunterNoFrame_OnEvent(event, ...)
   BadHunterNo.Events[event](...);
end