--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    localization.lua
-- Author:  @project-author@
-- License: LICENSE.txt
--------------------------------------------------------------------------------

--
local function defaultI18n(i18n, locale)
    if locale:len() == 4 then
        locale = locale:sub(1, 2);
        return i18n[locale];
    else
        return i18n["en"];
    end
end

local I18N = setmetatable({}, { __index = defaultI18n });

local function default(i18n, key)
    return key
end

local default_i18n = setmetatable({}, { __index = default });
I18N["en"] = default_i18n

BadPetI18N = I18N;
