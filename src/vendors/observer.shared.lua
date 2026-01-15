--[[ NOTE: todo features
    - ability to add/remove watches
    - ability to add/remove on_change
    - ability to have multiple on_change handlers
]]

--[[ DRAFT:
    - observer:add_watch(key, getter, opts)
    - observer:remove_watch(key)
    - observer:on_chance(key, func)
 ]]

observer = cslib.class()

function observer:constructor(opts)
    self.interval = cslib.coalesce(opts.interval, 1000)
    self.immediate = cslib.coalesce(opts.immediate, true)

    self.timer = nil
    self.watches = {}

    self:start()
end

function observer:start()
    if (self.timer) then
        self.timer:destroy()
        self.timer = nil
    end

    self.timer = cslib.set_interval(function()
        self:tick()
    end, self.interval)
end

function observer:stop()

end

function observer:tick()
    for key, watch in pairs(self.watches) do
        local current_value = watch.getter()
        local is_equal = nil

        if (watch.compare) then
            is_equal = watch.compare(current_value, watch.last_value)
        else
            is_equal = (current_value == watch.last_value)
        end

        if not (is_equal) then
            watch.on_change(current_value, watch.last_value)
            watch.last_value = current_value
        end
    end
end

function observer:add_watch(key, opts)
    opts = opts or {}

    local getter = opts.getter
    local on_change = opts.on_change
    local compare = opts.compare

    cslib.validate.type.assert(getter, "function", "table")
    cslib.validate.type.assert(on_change, "function", "table")
    cslib.validate.type.assert(compare, "function", "table", "nil")

    self.watches[key] = {
        getter = getter,
        last_value = getter(),
        on_change = on_change,
        compare = compare,
    }

    if on_change and self.immediate then
        on_change(self.watches[key].last_value, nil)
    end
end
