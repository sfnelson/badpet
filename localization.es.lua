--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    localization.es.lua
-- Author:  @project-author@
-- License: LICENSE.txt
--------------------------------------------------------------------------------

--
if not BadPetI18N then
    return
end

local default = BadPetI18N["en"];
local L = setmetatable({}, default);
BadPetI18N["es"] = L

L["My pet, %s,"] = "Mi mascota, %s,";
L["My pet"] = "Mi mascota";
L["Your pet, %s,"] = "Su mascota, %s,";
L["Your pet"] = "Su mascota";
L["%s's pet, %s,"] = "Mascota de %s, %s,";
L["%s's pet"] = "Mascota de %s";
L["An unknown pet"] = "Una mascota desconocida";
L["An unknown pet, %s,"] = "Una mascota desconocida, %s,";

L["%s was hit by %s"] = "%2$s golpe alcanzó %1$s";
L["%s was missed by %s"] = "%2$s golpe falló %1$s";
L["%s used %s on %s"] = "%s lanzó %s %s";
L["%s used %s"] = "%s lanzó %s";

L["disabled"] = "desactivado";
L["%s, reporting to %q"] = "%s, informes a %q";
