-- syncnode is still work in progress and not ready for use.

local lib = cslib
local syncnode = {}
syncnode.__index = syncnode

local table_unpack = table.unpack
local table_clone = table.clone
local CreateThread = Citizen.CreateThread
local CreateThreadNow = Citizen.CreateThreadNow

local function deep_copy(tbl)
    tbl = table_clone(tbl)

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            tbl[k] = deep_copy(v)
        end
    end

    return tbl
end

local function next_seq(class, id)
    local seq = (class.__seq[id] or 0) + 1
    class.__seq[id] = seq
    return seq
end

function syncnode:new(...)
    local class = self
    lib.validate.type.assert(class.__classname, "string")

    local args = { ... }
    local instance = setmetatable({}, class)

    if (lib.is_server) then
        class.__ids = class.__ids + 1
        local new_id = class.__ids
        instance.__id = new_id
        class.__objects[new_id] = instance
        class.__objects_args[new_id] = deep_copy(args)

        if (class.__opts.only_relevant) then
            class.__relevant_sources[new_id] = {}
        end
    end

    if (class.__next_client_id) then
        instance.__id = class.__next_client_id
        class.__objects[instance.__id] = instance
    end

    local captured_id = instance.__id

    CreateThreadNow(function()
        if (class.constructor) then
            instance:constructor(table_unpack(args))
        end

        if (class.begin_play) then
            instance:begin_play()
        end

        if (lib.is_server) then
            if (not class.__opts.only_relevant) then
                local captured_args = class.__objects_args[captured_id]
                local seq = next_seq(class, captured_id)
                lib.resource.emit_all_clients_latent(("rep:%s:new"):format(class.__classname), class.__opts.bps, captured_id, seq, captured_args)
            end
        end
    end)

    return instance
end

function syncnode:destroy()
    if (self.destructor) then
        CreateThreadNow(function()
            self:destructor()
        end)
    end

    local id = self.__id

    if (lib.is_server) then
        if (id and self.__objects[id]) then
            if (self.__opts.only_relevant) then
                if (self.__relevant_sources[id]) then
                    for src, _ in pairs(self.__relevant_sources[id]) do
                        local seq = next_seq(self, id)
                        lib.resource.emit_client_latent(("rep:%s:destroy"):format(self.__classname), src, self.__opts.bps, id, seq)
                    end
                end
                self.__relevant_sources[id] = nil
            else
                local seq = next_seq(self, id)
                lib.resource.emit_all_clients_latent(("rep:%s:destroy"):format(self.__classname), self.__opts.bps, id, seq)
            end

            self.__objects[id] = nil
            self.__objects_args[id] = nil
        end
    else
        if (id and self.__objects[id]) then
            self.__objects[id] = nil
        end
    end
end

function syncnode:add_relevant_player(in_src)
    assert(lib.is_server, "add_relevant_player can only be called on the server")
    if (not self.__opts.only_relevant) then return end

    local src = tonumber(in_src) --[[@as number]]
    assert(src, "Invalid source provided to add_relevant_player")
    local id = self.__id

    if (self.__relevant_sources?[id]?[src] == true) then return end

    self.__relevant_sources[id][src] = true
    local seq = next_seq(self, id)
    lib.resource.emit_client_latent(("rep:%s:new"):format(self.__classname), src, self.__opts.bps, id, seq, self.__objects_args[id])
end

function syncnode:remove_relevant_player(in_src)
    assert(lib.is_server, "remove_relevant_player can only be called on the server")
    if (not self.__opts.only_relevant) then return end

    local src = tonumber(in_src) --[[@as number]]
    assert(src, "Invalid source provided to remove_relevant_player")
    local id = self.__id

    if not (self.__relevant_sources?[id]?[src]) then return end

    self.__relevant_sources[id][src] = nil
    local seq = next_seq(self, id)
    lib.resource.emit_client_latent(("rep:%s:destroy"):format(self.__classname), src, self.__opts.bps, id, seq)
end

function syncnode:is_player_relevant(in_src)
    if (not lib.is_server or not self.__opts.only_relevant) then return false end
    local src = tonumber(in_src) --[[@as number]]
    local id = self.__id

    return self.__relevant_sources?[id]?[src] == true
end

function syncnode:get_objects()
    local objects = {}
    for _, object in pairs(self.__objects) do
        objects[#objects + 1] = object
    end
    return objects
end

local function create_syncnode_class(classname, in_opts)
    lib.validate.type.assert(classname, "string")

    local class = setmetatable({}, syncnode)
    class.__index = class
    class.__classname = classname

    class.__opts = in_opts or {}
    class.__opts.only_relevant = class.__opts.only_relevant == true
    class.__opts.bps = type(class.__opts.bps) == "number" and class.__opts.bps or 0

    class.__objects = {}
    class.__objects_args = {}
    class.__ids = 10
    class.__seq = {} -- Per-instance event counter. Server: increments; Client: last seen.

    if (class.__opts.only_relevant) then
        class.__relevant_sources = {}
    end

    if (lib.is_server) then
        class.__ready_clients = {}

        lib.resource.on_client(("rep:%s:client_ready"):format(class.__classname), function()
            local src = tonumber(source) --[[@as number]]

            if (class.__ready_clients[src]) then return end
            class.__ready_clients[src] = true

            for id, args in pairs(class.__objects_args) do
                local is_relevant = (not class.__opts.only_relevant) or (class.__relevant_sources[id] and class.__relevant_sources[id][src])

                if (is_relevant) then
                    local seq = next_seq(class, id)
                    lib.resource.emit_client_latent(("rep:%s:new"):format(class.__classname), src, class.__opts.bps, id, seq, args)
                end
            end
        end)

        lib.on("playerDropped", function()
            local src = tonumber(source) --[[@as number]]

            class.__ready_clients[src] = nil

            if (class.__opts.only_relevant) then
                for id, sources in pairs(class.__relevant_sources) do
                    if (sources[src]) then
                        sources[src] = nil
                    end
                end
            end
        end)
    else
        local new_inst = function(id, seq, args)
            if (class.__seq[id] and seq <= class.__seq[id]) then return end
            class.__seq[id] = seq

            if (class.__objects[id]) then
                class.__objects[id].__id = id
                class.__objects[id]:destroy()
            end

            class.__next_client_id = id
            class:new(table_unpack(args))
            class.__next_client_id = nil
        end

        local destroy_inst = function(id, seq)
            if (class.__seq[id] and seq <= class.__seq[id]) then return end
            class.__seq[id] = seq

            if (class.__objects[id]) then
                class.__objects[id].__id = id
                class.__objects[id]:destroy()
            end
        end

        lib.resource.on_server(("rep:%s:new"):format(class.__classname), new_inst)
        lib.resource.on_server(("rep:%s:destroy"):format(class.__classname), destroy_inst)

        CreateThread(function()
            lib.resource.emit_server(("rep:%s:client_ready"):format(class.__classname))
        end)
    end

    lib.resource.on_stop(function()
        local snapshot = {}
        for _, object in pairs(class.__objects) do
            snapshot[#snapshot + 1] = object
        end

        for _, object in ipairs(snapshot) do
            object:destroy()
        end
    end)

    return class
end

return setmetatable({
    new = create_syncnode_class,
}, {
    __call = function(t, ...)
        return create_syncnode_class(...)
    end,
})
