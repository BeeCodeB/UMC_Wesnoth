


# >>>> data/macros/abilities.cfg
# --------------------------------------------------------------------
#define ABILITY_DIVERSION
    # Canned definition of the Distraction ability to be included 
    # in an [abilities] clause.
    [chance_to_hit] # this is a weapon special, but as of 1.15.0, it is possible to use it this way in [abilities]
        id=diversion
        sub=20
        name= _ "diversion"
        female_name= _ "female^diversion"
        description= _ "If there is an enemy of the target on the opposite side of the target, this unit diverts the target’s attention and reduces its chance to hit by 20%."
        description_inactive= _ "This is inactive for now."
        affect_self=no
        affect_allies=no
        affect_enemies=yes
        cumulative=yes
        [filter]
            [filter_adjacent]
                is_enemy=yes
            [/filter_adjacent]
        [/filter]
        # three of these tags, for (hex faces)/2, as we try for similar conditions to backstab
        [affect_adjacent]
            adjacent=n,s
            [filter]
                [filter_adjacent]
                    is_enemy=yes
                    count=2-6
                    adjacent=n,s
                [/filter_adjacent]
            [/filter]
        [/affect_adjacent]
        [affect_adjacent]
            adjacent=se,nw
            [filter]
                [filter_adjacent]
                    is_enemy=yes
                    count=2-6
                    adjacent=se,nw
                [/filter_adjacent]
            [/filter]
        [/affect_adjacent]
        [affect_adjacent]
            adjacent=ne,sw
            [filter]
                [filter_adjacent]
                    is_enemy=yes
                    count=2-6
                    adjacent=ne,sw
                [/filter_adjacent]
            [/filter]
        [/affect_adjacent]
    [/chance_to_hit]
#enddef



# >>>> data/core/_main.cfg
# --------------------------------------------------------------------
#textdomain wesnoth
# Main purpose of this file is to ensure that macros get read in first.

# wmlscope: set export=yes
(..)
[lua]
    code=<<
wesnoth.dofile 'lua/diversion.lua'
>>
[/lua]
(..)



# >>>> data/lua/diversion.lua
# --------------------------------------------------------------------

local _ = wesnoth.textdomain 'wesnoth-help'
local T = wml.tag
local on_event = wesnoth.require("on_event")

local u_pos_filter = function(u_id)

        local output = "initial"
        local hex_dirs = {"n", "ne", "se", "s", "sw", "nw"}
        local diversion_unit = wesnoth.units.get(u_id)
        if not diversion_unit then
            return nil
        end
        for i, dir in ipairs(hex_dirs) do
            if diversion_unit:matches {
              id = u_id, 
              T.filter_adjacent {
                  is_enemy = "yes",
                  adjacent = dir,
                  formula = "self.hitpoints > 0",
                  T.filter_adjacent {
                      is_enemy = "yes",
                      adjacent = dir,
                      formula = "self.hitpoints > 0"
                  }
              }
            } then
                output = "diverter"
                break 
            end
        end
        if output ~= "initial" then
            return output
        else
        -- either nothing passed filter, or there was an error
            return nil
        end
end


local status_anim_update = function(is_undo)

	local ec = wesnoth.current.event_context
	local changed_something  = false

	if not ec.x1 or not ec.y1 then
                return
        end

        -- find all units on map with ability = diversion but not status.diversion = true
        local div_candidates = wesnoth.units.find_on_map({
                ability = "diversion",
                {"not", { status = "diversion" }}
                })
        -- for those that pass the filter now, change status and fire animation
        for index, ec_unit in ipairs(div_candidates) do
                local filter_result = u_pos_filter(ec_unit.id)
                if filter_result then
		    changed_something = true
                    ec_unit.status.diversion = true
                    ec_unit:extract()
                    ec_unit:to_map()
                    wesnoth.wml_actions.animate_unit {
                            flag = "launching",
                            with_bars = true,
                            T.filter { id = ec_unit.id }
                    }
                end
        end
        
        -- find all units on map with ability = diversion and status.diversion = true
        local stop_candidates = wesnoth.units.find_on_map({
                ability = "diversion",
                status = "diversion"
                })
        -- for those that fail the filter now, change status and fire animation
        for index, ec_unit in ipairs(stop_candidates) do
                local filter_result = u_pos_filter(ec_unit.id)
                if not filter_result then
		    changed_something = true
                    ec_unit.status.diversion = false
                    ec_unit:extract()
                    ec_unit:to_map()
                    wesnoth.wml_actions.animate_unit {
                            flag = "landing",
                            with_bars = true,
                            T.filter { id = ec_unit.id }
                    }
                end
        end
	if changed_something and not is_undo then
		wesnoth.wml_actions.on_undo {
			wml.tag.on_undo_diversion {
			}
		}
	end
end

function wesnoth.wml_actions.on_undo_diversion(cfg)
	status_anim_update(true)
end

on_event("moveto, die", function()
        status_anim_update()
        
end)



