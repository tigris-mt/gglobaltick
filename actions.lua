gglobaltick.actions = {
	actions = {},
}

local storage = minetest.get_mod_storage()

local function current_tick()
	return storage:get_int("tick")
end

(function()
	local st = storage:to_table()
	local removed = 0
	local current = current_tick()
	st.fields = b.t.map(st.fields, function(v, k)
		local n = tonumber(k:match("tick_(.*)"))
		if n and n < current then
			removed = removed + 1
			return nil
		else
			return v
		end
	end)
	storage:from_table(st)
	if removed > 0 then
		minetest.log("action", ("[gglobaltick] Cleared %d old tick queues."):format(removed))
	end
end)()

local function next_tick()
	return current_tick() + 1
end

local function increment_tick()
	storage:set_int("tick", next_tick())
end

local function key(tick)
	return "tick_" .. tick
end

function gglobaltick.actions.get_tick_actions(tick)
	local k = key(tick)
	return storage:contains(k) and minetest.deserialize(storage:get_string(k)) or {}
end

function gglobaltick.actions.set_tick_actions(tick, actions)
	storage:set_string(key(tick), minetest.serialize(actions))
end

function gglobaltick.actions.iterate_tick_actions(tick)
	local actions = gglobaltick.actions.get_tick_actions(tick)
	local i = 0
	return function()
		i = i + 1
		while actions[i] ~= nil do
			return actions[i]
		end
	end
end

function gglobaltick.actions.add_tick_action(tick, def)
	local actions = gglobaltick.actions.get_tick_actions(tick)
	table.insert(actions, def)
	gglobaltick.actions.set_tick_actions(tick, actions)
end

function gglobaltick.actions.clear_tick(tick)
	storage:set_string(key(tick), "")
end

function gglobaltick.actions.register(name, def)
	def = b.t.combine({
		func = function(params) end,
	}, def)
	gglobaltick.actions.actions[name] = def
end

-- Insert an action into the queue, with a specified delay.
-- A delay of 0 means the next tick, 1 means the tick after that, etc.
-- The delay will be floored.
function gglobaltick.actions.insert(name, delay, params)
	assert(gglobaltick.actions.actions[name], name .. " is not a registered action")
	gglobaltick.actions.add_tick_action(next_tick() + math.floor(delay), {
		name = name,
		params = params,
	})
end

-- Insert an action into the queue, with a specified delay and factor.
-- The delay is every <factor>th tick, so that if factor is 3,
--- a delay of 0 means the next tick divisible by three, 1 means three ticks after that, etc.
-- The delay will be floored.
-- The factor must be an integer.
function gglobaltick.actions.insert_factor(name, factor, delay, params)
	assert(gglobaltick.actions.actions[name], name .. " is not a registered action")
	local nt = next_tick()
	gglobaltick.actions.add_tick_action(nt + math.floor(delay) * factor + (nt % factor), {
		name = name,
		params = params,
	})
end

function gglobaltick.actions.tick()
	increment_tick()
	for action in gglobaltick.actions.iterate_tick_actions(current_tick()) do
		local def = gglobaltick.actions.actions[action.name]
		def.func(action.params)
	end
	gglobaltick.actions.clear_tick(current_tick())
end
