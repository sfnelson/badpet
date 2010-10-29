if not BadPet then
   BadPet = {}
end
local lib = BadPet;

if not LibStub then
   return;
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true);
if not ldb then
   return
end

local qtip = LibStub:GetLibrary("LibQTip-1.0", true);
if not qtip then
   return
end

if not lib.ldbdata then
   lib.ldbdata = ldb:NewDataObject("Bat Pet", {type = "data source", text = "Bad Pet"});
end

local red = CreateFont("BadPetRedFont");
red:SetFont(GameTooltipText:GetFont());
red:SetTextColor(1,0,0);

local green = CreateFont("BadPetGreenFont");
green:SetFont(GameTooltipText:GetFont());
green:SetTextColor(0,1,0);

function lib.ldbdata:OnEnter()
   local tooltip = qtip:Acquire("BadPetTooltip", 2, "LEFT", "RIGHT");
   self.tooltip = tooltip;
   
   local inInstance = lib.GetInInstance();
   local instance = "no";
   if inInstance then instance = "yes" end
   
   tooltip:AddHeader("|cffffff00Bad Pet|r");
   tooltip:AddLine("State", BadPet_State);
   tooltip:AddLine("Frame", BadPet_Frame);
   tooltip:AddLine("Instance", instance);
   
   if BadPet_Debug then
      tooltip:AddLine("Debug", BadPet_Debug);
   end
   
   tooltip:AddLine(" ");
   
   local pet = GetUnitName("pet");
   if not pet then
      tooltip:AddLine("You do not have a pet");
   else
      tooltip:AddHeader("|cffffff00"..pet.."|r");
      
      local inInstance = lib.GetInInstance();
      for spell,id in pairs(lib.Spells) do
         local castable, state = GetSpellAutocast(spell, BOOKTYPE_PET);
         local font;
         if castable then
            if state and inInstance or not state and not inInstance then
               font = red;
            else
               font = green;
            end
            
            if state then
               state = "on"
            else
               state = "off"
            end
            
            local line = tooltip:AddLine(spell);
            tooltip:SetCell(line, 2, state, font);
         end
      end
   end
   
   tooltip:SmartAnchorTo(self);
   tooltip:Show();
end

function lib.ldbdata:OnLeave()
   qtip:Release(self.tooltip);
   self.tooltip = nil;
end

function lib.UpdateLDB()
   local pet = GetUnitName("pet");
   local color;
   
   local inInstance = lib.GetInInstance();
   for name,id in pairs(lib.Spells) do
      local castable,state = GetSpellAutocast(name, BOOKTYPE_PET);
      if castable then
         if state and inInstance or not state and not inInstance then
            color = "|cffff0000"
         end
      end
   end
   
   if not color then
      color = "|cff00ff00"
   end
   
   if pet then
      lib.ldbdata.text = color..pet.."|r";
   else
      lib.ldbdata.text = "Bad Pet"
   end
end
