--------------------------------------------------------------------------------
-- BadPet @project-version@
-- File:    Data.lua
-- Author:  @project-author@
-- License: LICENSE.txt
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- History tracking, used to suppress noisy warnings
--------------------------------------------------------------------------------

--- Get or create a spell history table
local function SpellHistory(history, spell)
    if type(spell) == "table" then
        return history[spell.id];
    else
        local spellTable = { time = 0, count = 0 }
        history[spell] = spellTable;
        return spellTable;
    end
end

local SpellHistoryMeta = { __index = SpellHistory };

--- Get or create a pet history table
local function PetHistory(history, pet)
    if type(pet) == "table" then
        return history[pet.id];
    else
        local spellTable = setmetatable({}, SpellHistoryMeta);
        history[pet] = spellTable;
        return spellTable;
    end
end

local PetHistoryMeta = { __index = PetHistory };
local function NewHistory()
    return setmetatable({ reset = date() }, PetHistoryMeta);
end

BadPet.history = NewHistory();


--------------------------------------------------------------------------------
-- Report Queue, used to synchronize sending reports to prevent duplicates
--------------------------------------------------------------------------------
local function SpellQueue(queue, spell)
    if type(spell) == "table" then
        return queue(spell.id)
    else
        return nil;
    end
end

local SpellQueueMeta = { __index = SpellQueue };

local function PetQueue(queue, pet)
    if type(pet) == "table" then
        return queue[pet.id];
    else
        local spellTable = setmetatable({}, SpellQueueMeta);
        queue[pet] = spellTable;
        return spellTable;
    end
end

local PetQueueMeta = { __index = PetQueue };
local function NewQueue()
    return setmetatable({}, PetQueueMeta);
end

BadPet.queue = NewQueue();
