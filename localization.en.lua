--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    localization.en.lua
-- Author:  @project-author@
-- License: LICENSE.txt
--------------------------------------------------------------------------------

--
if not BadPetI18N then
    return
end

local function defaultI18n(i18n, key)
    return key;
end

local L = setmetatable({}, { __index = defaultI18n });
BadPetI18N["en"] = L

L["BadPet"] = "BadPet";

L["My pet, %s,"] = "My pet, %s,";
L["My pet"] = "My pet";
L["Your pet, %s,"] = "Your pet, %s,";
L["Your pet"] = "Your pet";
L["%s's pet, %s,"] = "%s's pet, %s,";
L["%s's pet"] = "%s's pet";
L["An unknown pet"] = "An unknown pet";
L["An unknown pet, %s,"] = "An unknown pet, %s,";

L["%s was hit by %s"] = "%s was hit by %s";
L["%s was missed by %s"] = "%s missed %s";
L["%s used %s on %s"] = "%s used %s on %s";
L["%s used %s"] = "%s used %s";

L["disabled"] = "disabled";
L["%s, reporting to %q"] = "%s, reporting to %q";
