---@diagnostic disable: undefined-global
local table_wipe = table.wipe

-- Map class: ordered key-value map
-- THIS MEANT TO BE USED FROM CSLIB but we will implement it here for now, i don't want to make tech debt by using cslib for this

local map = {}
map.__index = map

function map.factory()
    local self = {}
    self.data = {}
    self.index = {}
    self.size = 0

    return self
end

function map.new()
    local self = setmetatable(map.factory(), map)

    self:clear()

    return self
end

function map.from_array(array)
    cslib.validate.type.assert(array, "table")

    local self = map.new()

    for i = 1, #array do
        local value = array[i]
        cslib.validate.type.assert(value, "table")
        assert(#value == 2, "map constructor requires a table with two elements")

        self:set(value[1], value[2])
    end

    return self
end

function map:clear()
    table_wipe(self.data)
    table_wipe(self.index)

    self.size = 0
end

function map:delete(key)
    cslib.validate.type.assert(key, "string", "number", "boolean")

    local pos = self.index[key]
    if not (pos) then return false end

    table.remove(self.data, pos)
    self.size = #self.data

    table_wipe(self.index)
    for i, entry in ipairs(self.data) do
        self.index[entry.key] = i
    end

    return true
end

function map:for_each(func)
    cslib.validate.type.assert(func, "function")

    local tb_cloned = table.clone(self.data)

    for i = 1, self.size, 1 do
        local entry = tb_cloned[i]

        func(entry.key, entry.value)
    end
end

map.foreach = map.for_each

function map:get(key)
    cslib.validate.type.assert(key, "string", "number", "boolean")

    local pos = self.index[key]

    return pos and self.data[pos].value or nil
end

function map:has(key)
    cslib.validate.type.assert(key, "string", "number", "boolean")

    return self.index[key] ~= nil
end

function map:set(key, value)
    cslib.validate.type.assert(key, "string", "number", "boolean")

    local pos = self.index[key]

    if (pos) then
        self.data[pos].value = value
    else
        local entry = { key = key, value = value }
        table.insert(self.data, entry)

        self.size = #self.data
        self.index[key] = self.size
    end
end

--[[

    Sync Array Module
    is a feature used for efficient replication of dynamic arrays over a network.
    is designed to minimize bandwidth usage by only sending deltas (changes) to the array rather than the entire array.

    FYI:
     - THIS MOUDLE IS DESIGNED TO BE USED ON FIVEM


    additional features to implement:
     - relevancy filtering: only send changes to clients that are relevant to them

    available methods:
    - new() : creates a new synced map instance,
    - set(key, value) : sets a value for the specified key,
    - delete(key) : deletes the specified key,
    - mark_dirty() : marks the array as dirty, indicating that changes have been made and need to be replicated.

    available abstract methods:
    - post_replicate_add(added_indices, final_size)
    - post_replicate_change(changed_indices, final_size)
    - pre_replicate_remove(removed_indices, final_size)
 ]]

local function event_name(name, action)
    cslib.validate.type.assert(name, "string")
    cslib.validate.type.assert(action, "string")

    return ("syncmap:%s.%s"):format(name, action)
end

local SYNC_MAP_ACTION = {
    SET = 1,
    DELETE = 2,
}

local synced_map = {}
synced_map.__index = synced_map
synced_map.__id = 10
setmetatable(synced_map, map)

function synced_map.new(name)
    cslib.validate.type.assert(name, "string")

    synced_map.__id = synced_map.__id + 1

    local self = map.factory()
    self.super = setmetatable({}, {
        __index = function(tbl, k)
            local super_func = rawget(map, k)

            assert(super_func and type(super_func) == "function", ("synced_map:super() called with invalid method '%s'"):format(k))

            -- this will get garbage collecte eventually, no need to cache it
            return function(_, ...)
                return super_func(self, ...)
            end
        end,
    })
    self.name = ("syncmap:%s"):format(name)
    self.id = synced_map.__id
    self.deltas = {}
    self.destroyed = false
    self.delegates = {
        post_replicate_change = cslib.delegate.new(),
    }
    self.event_handlers = {}

    if (cslib.is_server) then
        local event_handler = cslib.resource.callback.register(event_name(self.name, "request.data"), function()
            return self.data
        end)
        self.event_handlers[#self.event_handlers + 1] = event_handler
    else
        local request_data_cb = cslib.resource.callback(event_name(self.name, "request.data")).callback(function(data)
            self.super:clear()

            for _, entry in pairs(data) do
                local key = entry.key
                local value = entry.value

                if (self.super:has(key)) then
                    cslib.print.warn("synced_map", self.name, "key already exists skipping", key, value)
                else
                    self.super:set(key, value)
                    self.delegates.post_replicate_change:broadcast(key, value)
                end
            end
        end)
        self.event_handlers[#self.event_handlers + 1] = request_data_cb

        local commit_cb = cslib.resource.on_server(event_name(self.name, "commit"), function(incoming_deltas)
            local deltas_len = #incoming_deltas

            if (deltas_len > 0) then
                for i = 1, deltas_len, 1 do
                    local delta = incoming_deltas[i]
                    local action = delta[1]

                    if (action == SYNC_MAP_ACTION.SET) then
                        local id = delta[2]
                        local value = delta[3]

                        self.super:set(id, value)
                        self.delegates.post_replicate_change:broadcast(id, value)
                    elseif (action == SYNC_MAP_ACTION.DELETE) then
                        local id = delta[2]

                        self.super:delete(id)
                        self.delegates.post_replicate_change:broadcast(id, nil)
                    else
                        error(("synced_map:mark_dirty() called with invalid action '%s'"):format(action))
                    end
                end
            end
        end)
        self.event_handlers[#self.event_handlers + 1] = commit_cb

        cslib.resource.once_server(event_name(self.name, "destroy"), function()
            self.super:clear()
            self.destroyed = true
        end)
    end

    return setmetatable(self, synced_map)
end

-- this function will need to manually called, which will sent the deltas to the client
function synced_map:mark_dirty()
    assert(cslib.is_server, "synced_map:mark_dirty() can only be called on the server")

    cslib.resource.emit_all_clients(event_name(self.name, "commit"), self.deltas)

    table_wipe(self.deltas)
end

function synced_map:set(id, value)
    cslib.validate.type.assert(id, "string", "number", "boolean")
    assert(cslib.is_server, "synced_map:set() can only be called on the server")
    assert(not self.destroyed, "synced_map:set() called on a destroyed synced_map instance")

    -- TODO: maybe we need to remove previous delta if exists

    self.super:set(id, value)
    self.delegates.post_replicate_change:broadcast(id, value)

    self.deltas[#self.deltas + 1] = { SYNC_MAP_ACTION.SET, id, value }
end

function synced_map:delete(id)
    cslib.validate.type.assert(id, "string", "number", "boolean")
    assert(cslib.is_server, "synced_map:delete() can only be called on the server")
    assert(not self.destroyed, "synced_map:delete() called on a destroyed synced_map instance")

    -- TODO: maybe we need to remove previous delta if exists

    self.super:delete(id)
    self.delegates.post_replicate_change:broadcast(id, nil)

    self.deltas[#self.deltas + 1] = { SYNC_MAP_ACTION.DELETE, id }
end

function synced_map:clear()
    assert(cslib.is_server, "synced_map:clear() can only be called on the server")
    assert(not self.destroyed, "synced_map:clear() called on a destroyed synced_map instance")

    self.super:for_each(function(key, _)
        self:delete(key)
    end)

    self:mark_dirty()
end

function synced_map:destroy()
    assert(cslib.is_server, "synced_map:destroy() can only be called on the server")

    if (self.destroyed) then
        cslib.print.warn("synced_map", self.name, "already destroyed")
        return
    end

    self.destroyed = true

    cslib.resource.emit_all_clients(event_name(self.name, "destroy"))
end

function synced_map:on_post_change(func)
    cslib.validate.type.assert(func, "function")

    self.delegates.post_replicate_change:bind(func)
end

rawset(_ENV, "synced_map", synced_map)
