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

if not lib.fixer then
   lib.fixer = CreateFrame("Button", "BadPetFixer", UIParent, "SecureActionButtonTemplate");
end

lib.fixer:SetAttribute("type","macro");
lib.fixer:SetAttribute("macrotext","");

local cellPrototype = {
   SetupCell = function (frame, tooltip, value, align, font)
      local fs = frame.fontString;
      fs:SetFontObject(font or tooltip:GetFont());
      fs:SetJustifyH(align);

      frame.value = value;
      frame:RefreshCell();

      frame:SetAttribute("macrotext", "/petautocasttoggle "..value);

      frame:Show();
      return fs:GetStringWidth(), fs:GetStringHeight();
   end,
   RefreshCell = function (frame)
      local castable, state = GetSpellAutocast(frame.value, BOOKTYPE_PET);
      local inInstance = lib.GetInInstance();
      if not castable then
         frame.fontString:SetText("error");
      else
         if state and inInstance or not state and not inInstance then
            frame.fontString:SetTextColor(1, 0, 0);
         else
            frame.fontString:SetTextColor(0, 1, 0);
         end
         if state then
            frame.fontString:SetText("on");
         else
            frame.fontString:SetText("off");
         end
      end
   end,
   InitCell = function (frame)
      frame.fontString = frame:CreateFontString();
      frame.fontString:SetAllPoints(frame);
      frame:SetAttribute("type","macro");
      frame:SetAttribute("macrotext", "");
      frame:SetScript("PostClick", function (frame, ...)
            frame:RefreshCell();
         end
      );
   end,
   ResetCell = function (frame)
      frame.value = nil;
      frame.fontString:SetText("");
      frame.fontString:SetTextColor(frame.r, frame.g, frame.b);
      frame:SetAttribute("type","macro");
      frame:SetAttribute("macrotext", "");
   end
}

setmetatable(cellPrototype,
   { __index = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate") });

local cellProvider = {
   heap = {},
   cellPrototype = cellPrototype,
   cellMetatable = { __index = cellPrototype }
}

function cellProvider:AcquireCell(tooltip)
   local cell = table.remove(self.heap);

   if not cell then
      cell = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate");
      setmetatable(cell, self.cellMetatable);
      cell:InitCell();
   end

   return cell;
end

function cellProvider:ReleaseCell(cell)
   cell:ResetCell();
   table.insert(self.heap, cell);
end

function cellProvider:GetCellPrototype()
   return self.cellPrototype, self.cellMetatable;
end

function lib.ldbdata:OnEnter()
   local tooltip = qtip:Acquire("BadPetTooltip", 2, "LEFT", "RIGHT");
   self.tooltip = tooltip;

   tooltip:Clear();

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
            local line = tooltip:AddLine(spell);
            tooltip:SetCell(line, 2, spell, cellProvider);
         end
      end
   end

   tooltip:SmartAnchorTo(self);
   tooltip:SetAutoHideDelay(0.1, self);
   tooltip:Show();
end

function lib.UpdateLDB()
   local pet = GetUnitName("pet");
   local color;
   local fixer = "";

   local inInstance = lib.GetInInstance();
   for name,id in pairs(lib.Spells) do
      local castable,state = GetSpellAutocast(name, BOOKTYPE_PET);
      if castable then
         if state and inInstance or not state and not inInstance then
            color = "|cffff0000"
            fixer = fixer .. "/petautocasttoggle "..name.."\n";
         end
      end
   end

   if not color then
      color = "|cff00ff00"
   end

   lib.fixer:SetAttribute("macrotext", fixer);
   if pet then
      lib.ldbdata.text = color..pet.."|r";
   else
      lib.ldbdata.text = "Bad Pet";
   end
end
