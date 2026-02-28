local lib = cslib
local synced_instance = {}
synced_instance.__index = synced_instance

local table_unpack = table.unpack
local native = {
    create_thread = Citizen.CreateThread,
    create_thread_now = Citizen.CreateThreadNow,
}

function synced_instance:new(...)
    lib.validate.type.assert(self.__classname, "string")

    local args = { ... }
    local object = setmetatable({}, self)

    if (lib.is_server) then
        self.__ids = self.__ids + 1
        self.__objects[self.__ids] = object
        self.__objects_args[self.__ids] = args
    end

    native.create_thread_now(function()
        if (self.constructor) then
            -- Allow server to assign any synced meta before sending to clients
            object:constructor(table_unpack(args))
        end

        if (lib.is_server) then
            lib.resource.emit_all_clients(("rep:%s:new"):format(self.__classname), self.__ids, args)
        end
    end)

    return object
end

function synced_instance:destroy()
    if (self.destructor) then
        native.create_thread_now(function()
            self:destructor()
        end)
    end

    if (lib.is_server) then
        for id, object in pairs(self.__objects) do
            if (object == self) then
                self.__objects[id] = nil
                self.__objects_args[id] = nil
                lib.resource.emit_all_clients(("rep:%s:destroy"):format(self.__classname), id)
                break
            end
        end
    end
end

function synced_instance:get_objects()
    local objects = {}
    for _, object in pairs(self.__objects) do
        objects[#objects + 1] = object
    end
    return objects
end

local function create_synced_instance(classname)
    lib.validate.type.assert(classname, "string")

    local self = setmetatable({}, synced_instance)
    self.__index = self
    self.__classname = classname
    self.__objects = {}
    self.__objects_args = {}
    self.__ids = 10

    if (lib.is_server) then
        lib.resource.callback.register(("rep:%s:get_inst_ids"):format(self.__classname), function()
            local inst_ids = {}
            for id, _ in pairs(self.__objects) do
                inst_ids[#inst_ids + 1] = id
            end
            return inst_ids
        end)

        lib.resource.callback.register(("rep:%s:get_object_from_ids"):format(self.__classname), function(ids)
            if not (ids) then return {} end
            if (type(ids) ~= "table") then return {} end
            local objects = {}
            for _, id in pairs(ids) do
                objects[id] = self.__objects_args[id]
            end
            return objects
        end)
    else
        local refresh_inst = function()
            local inst_ids = lib.resource.callback(("rep:%s:get_inst_ids"):format(self.__classname)).await()
            local non_exinst_ids = {}
            local valid_ids = {}
            for _, id in pairs(inst_ids) do
                if not (self.__objects[id]) then
                    non_exinst_ids[#non_exinst_ids + 1] = id
                end
                valid_ids[id] = true
            end

            local objects = lib.resource.callback(("rep:%s:get_object_from_ids"):format(self.__classname), non_exinst_ids).await()
            for id, arg in pairs(objects) do
                if not (self.__objects[id]) then
                    self.__objects[id] = self:new(table_unpack(arg))
                end
            end

            for id, object in pairs(self.__objects) do
                if not (valid_ids[id]) then
                    object:destroy()
                    self.__objects[id] = nil
                end
            end
        end

        -- refresh when load for the first time
        native.create_thread(refresh_inst)

        local new_inst = function(id, args)
            if not (self.__objects[id]) then
                self.__objects[id] = self:new(table_unpack(args))
            end
        end
        lib.resource.on_server(("rep:%s:new"):format(self.__classname), new_inst)

        local destroy_inst = function(id)
            if (self.__objects[id]) then
                self.__objects[id]:destroy()
                self.__objects[id] = nil
            end
        end
        lib.resource.on_server(("rep:%s:destroy"):format(self.__classname), destroy_inst)
    end

    lib.resource.on_stop(function()
        for _, object in pairs(self.__objects) do
            object:destroy()
        end
    end)

    return self
end


return setmetatable({
    new = create_synced_instance,
}, {
    __call = function(t, ...)
        return create_synced_instance(...)
    end,
})
