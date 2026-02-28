local shape_manager = {}
shape_manager.__index = shape_manager

function shape_manager.new(...)
    local self = setmetatable({}, shape_manager)

    self.shapes = {
        instances = {},
        length = 0,
    }

    self.delegate = {
        player_enter_colshape = cslib.delegate(),
        player_exit_colshape = cslib.delegate(),
    }

    self.entered_colshape = cslib.set()

    local in_colshapes = { ... }
    for i = 1, #in_colshapes, 1 do
        local colshape = in_colshapes[i]
        self:add_colshape(colshape)
    end

    cslib.set_interval(function()
        local player = {
            ped = PlayerPedId(),
            pos = GetEntityCoords(PlayerPedId()),
        }

        for i = 1, self.shapes.length, 1 do
            local colshape = self.shapes.instances[i]
            local is_in_colshape = colshape:is_position_inside(player.pos)
            if (is_in_colshape) then
                if (not self.entered_colshape:has(colshape)) then
                    self.entered_colshape:add(colshape)
                    self.delegate.player_enter_colshape:broadcast(colshape)
                end
            else
                if (self.entered_colshape:has(colshape)) then
                    self.entered_colshape:remove(colshape)
                    self.delegate.player_exit_colshape:broadcast(colshape)
                end
            end
        end
    end, 250)

    return self
end

function shape_manager:add_colshape(shape)
    self.shapes.length = self.shapes.length + 1
    self.shapes.instances[self.shapes.length] = shape
end

function shape_manager:remove_colshape(shape)
    for i = 1, self.shapes.length, 1 do
        if (self.shapes.instances[i] == shape) then
            table.remove(self.shapes.instances, i)
            self.shapes.length = self.shapes.length - 1
            break
        end
    end

    self.entered_colshape:remove(shape)
end

function shape_manager:on_player_enter_colshape(callback)
    return self.delegate.player_enter_colshape:add(callback)
end

function shape_manager:on_player_exit_colshape(callback)
    return self.delegate.player_exit_colshape:add(callback)
end

return shape_manager
