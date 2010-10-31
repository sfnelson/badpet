--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    BadPet-ldb.lua
-- Author:  @project-author@
-- License: LICENSE.txt
--------------------------------------------------------------------------------

-- Check that dependencies are available.

if not BadPet then return end
local BadPet = BadPet;

local ldb = LibStub:GetLibrary("LibDataBroker-1.1", true);
if not ldb then return end

local qtip = LibStub:GetLibrary("LibQTip-1.0", true);
if not qtip then return end

local BadPet = BadPet;
local Fixer = BadPet.Fixer;

if not Fixer then
  Fixer = BadPet:NewModule("BadPetFixer","AceConsole-3.0", "AceEvent-3.0");
  Fixer.parent = BadPet;
  BadPet.Fixer = Fixer;
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local options = {
  name = "BadPetFixer",
  type = 'group',
  handler = BadPet,
  set = "SetOption",
  get = "GetOption",
  args = {
    fixer = {
      name = "Enable BadPet Fixer (Data Broker Feed)",
      type = "toggle",
    },
  },
};

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

--- Initializes the addon's configuration and registers hooks.
-- Called by Ace3 when the addon loads and saved variables are available.
function Fixer:OnInitialize()

  -- Create Frame
  self.frame = CreateFrame("Button", "BadPetFixer", UIParent,
    "SecureActionButtonTemplate");
  self.frame:SetAttribute("type","macro");
  self.frame:SetAttribute("macrotext","");

  -- Register configuration page and slash commands.
  local conf = LibStub("AceConfig-3.0");
  conf:RegisterOptionsTable("BadPet: Fixer", options);

  local dialog = LibStub("AceConfigDialog-3.0");
  dialog:AddToBlizOptions("BadPet: Fixer", "Fixer", "BadPet");
end

function Fixer:OnEnable()
  self.parent.db.profile.fixer = true;

  self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh");
  self:RegisterEvent("PET_BAR_UPDATE", "Refresh");
  self:RegisterEvent("UNIT_PET", "Refresh");
  self:Refresh();
end

function Fixer:OnDisable()
  self.parent.db.profile.fixer = false;

  self:UnregisterEvent("PLAYER_ENTERING_WORLD");
  self:UnregisterEvent("PET_BAR_UPDATE");
  self:UnregisterEvent("UNIT_PET");
  self:Refresh();
end

--- Update the LDB Object.
function Fixer:Refresh()
  if not self.parent.db.profile.fixer then
    self.ldbdata.text = "Bad Pet";
    self.frame:SetAttribute("macrotext", "/bp");
  end

  local pet = GetUnitName("pet");
  local color;
  local macrotext = "";

  local inInstance = self.parent:GetInInstance();
  for name,id in pairs(self.parent.spells) do
	local castable,state = GetSpellAutocast(name, BOOKTYPE_PET);
	if castable then
	  if state and inInstance or not state and not inInstance then
		color = "|cffff0000"
		macrotext = macrotext .. "/petautocasttoggle "..name.."\n";
	  end
	 end
  end

  if not color then
	color = "|cff00ff00"
  end

  self.frame:SetAttribute("macrotext", macrotext);
  if pet then
	self.ldbdata.text = color..pet.."|r";
  else
	self.ldbdata.text = "Bad Pet";
  end
end

--- Show tooltip.
function Fixer:ShowTooltip(frame)
   local tooltip = qtip:Acquire("BadPetTooltip", 2, "LEFT", "RIGHT");
   frame.tooltip = tooltip;

   tooltip:Clear();

   local inInstance = self.parent:GetInInstance();

   tooltip:AddHeader("|cffffff00Bad Pet|r");
   tooltip:AddLine("Report Frequency", BadPet.db.profile.state);
   tooltip:AddLine("Report Target", BadPet.db.profile.frame);
   tooltip:AddLine("In Instance", "yes" and inInstance or "no");

   if BadPet.db.profile.debug then
      tooltip:AddLine("Debug", BadPet.db.profile.debug);
   end

   tooltip:AddLine(" ");

   local pet = GetUnitName("pet");
   if not pet then
      tooltip:AddLine("You do not have a pet");
   else
      tooltip:AddHeader("|cffffff00"..pet.."|r");

      for spell,id in pairs(self.parent.spells) do
         local castable, state = GetSpellAutocast(spell, BOOKTYPE_PET);
         local font;
         if castable then
            local line = tooltip:AddLine(spell);
            tooltip:SetCell(line, 2, spell, self.cellProvider);
         end
      end
   end

   tooltip:SmartAnchorTo(frame);
   tooltip:SetAutoHideDelay(0.25, frame);
   tooltip:Show();
end

--------------------------------------------------------------------------------
-- LibDataBroker
--------------------------------------------------------------------------------

--- LDB Data Object
Fixer.ldbdata = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(
  "Bad Pet", { type = "data source", text = "Bad Pet" });

Fixer.ldbdata.OnEnter = function (frame)
  Fixer.ShowTooltip(frame);
end

--------------------------------------------------------------------------------
-- QTip Secure Buttons for toggling casts
--------------------------------------------------------------------------------

Fixer.cellPrototype = {
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
    end );
  end,
  ResetCell = function (frame)
	frame.value = nil;
	frame.fontString:SetText("");
	frame.fontString:SetTextColor(frame.r, frame.g, frame.b);
	frame:SetAttribute("type","macro");
	frame:SetAttribute("macrotext", "");
  end,
}

setmetatable(Fixer.cellPrototype,
  {
     __index = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
  });

Fixer.cellProvider = {
   heap = {},
   cellPrototype = Fixer.cellPrototype,
   cellMetatable = { __index = Fixer.cellPrototype }
}

function Fixer.cellProvider:AcquireCell(tooltip)
   local cell = table.remove(self.heap);

   if not cell then
      cell = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate");
      setmetatable(cell, self.cellMetatable);
      cell:InitCell();
   end

   return cell;
end

function Fixer.cellProvider:ReleaseCell(cell)
   cell:ResetCell();
   table.insert(self.heap, cell);
end

function Fixer.cellProvider:GetCellPrototype()
   return self.cellPrototype, self.cellMetatable;
end
