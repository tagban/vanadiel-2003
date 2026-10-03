-----------------------------------
-- Module: era2003 seasonal events
-- Desc: Only the seasonal events of the time are checked: the Starlight Celebration (December) and
--       the Egg Hunt Egg-stravaganza (spring). Mog Bonanza and Strange Happenings came years later,
--       and Strange Happenings' mobs live in zones era2003 removes: its end function then calls
--       GetMobByID(nil), the error aborts the whole check, and no event after it - the start pass
--       included - ever runs. Each event is checked on its own, so one failing cannot stop another.
-----------------------------------
require('modules/module_utils')
require('scripts/events/handler')
-----------------------------------
local m = Module:new('era2003_seasonal_events')

local inEra =
{
    StarlightCelebration = true,
    egg_hunt             = true,
}

local function check(event, step)
    local ok, err = pcall(step, event)
    if not ok then
        print(string.format('Seasonal event %s: %s', event.id, err))
    end
end

m:addOverride('xi.events.handler.checkSeasonalEvents', function()
    print('Checking Seasonal Events (era2003)')

    for _, event in pairs(xi.events.registeredEvents) do
        if inEra[event.id] then
            check(event, event.checkEnding)
        end
    end

    for _, event in pairs(xi.events.registeredEvents) do
        if inEra[event.id] then
            check(event, event.checkStarting)
        end
    end
end)
