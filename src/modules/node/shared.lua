local synced_instance = require "lib.syncer.syncnode"

local node = synced_instance.new(("%s:node"):format(cslib.resource.name))

node.__instances = {}
node.instance = {}

function node.instance.find(cb)
    for key, value in pairs(node.__instances) do
        if (cb(value)) then
            return value
        end
    end

    return nil
end

function node.instance.get(id)
    if (type(id) == "number") then
        id = tostring(id)
    end

    return node.__instances[id]
end

function node:initialize(in_id, in_opts)
    local opts = {}
    for key, value in pairs(in_opts or {}) do
        local value = rawget(in_opts, key)
        rawset(opts, key, value)
    end

    self.event_handlers = {}
    self.timer_ids = {}
    self.id = in_id
    self.opts = opts
    -- self.replicated = synced_map.new(self.id)

    rawset(node.__instances, self.id, self)
end

function node:uninitialize()
    -- if (cslib.is_server) then
    --     self.replicated:destroy()
    -- end

    for _, handler in pairs(self.event_handlers) do
        cslib.off(handler)
    end

    for key, value in pairs(self.timer_ids) do
        value:destroy()
    end

    node.__instances[self.id] = nil
end

function node:event(event_id)
    self.event_handlers[#self.event_handlers + 1] = event_id

    return event_id
end

function node:timer(timer_id)
    self.timer_ids[#self.timer_ids + 1] = timer_id

    return timer_id
end

return node
