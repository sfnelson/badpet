--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    localization.de.lua
-- Author:  Corydon - Die Nachtwache (EU)
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
BadPetI18N["de"] = L

L["BadPet"] = "BadPet";

L["My pet, %s,"] = "Mein Pet, %s,";
L["My pet"] = "Mein Pet";
L["Your pet, %s,"] = "Dein Pet, %s,";
L["Your pet"] = "Dein Pet";
L["%s's pet, %s,"] = "%s's Pet, %s,";
L["%s's pet"] = "%s's Pet";
L["An unknown pet"] = "Ein unbekanntes Pet";
L["An unknown pet, %s,"] = "Ein unbekanntes Pet, %s,";

L["%s was hit by %s"] = "%s wurde getroffen von %s";
L["%s was missed by %s"] = "%s verfehlte %s";
L["%s used %s on %s"] = "%s benutzte %s auf %s";
L["%s used %s"] = "%s benutzte %s";

L["disabled"] = "abgeschaltet";
L["%s, reporting to %q"] = "%s, meldet an %q";
