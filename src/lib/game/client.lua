local game = {}

local function GetHeadingBetween(coords1, coords2)
    return GetHeadingFromVector_2d(coords2.x - coords1.x, coords2.y - coords1.y)
end

function game.draw_text_3d(pos, text, scale, font, color, outlined, centered, shadow)
    local text = text
    if not (text) then return end
    if not (pos) then return end

    pos = vec(pos.x, pos.y, pos.z)

    local scale = scale or 1.0
    local font = font or 0
    local color = color or { 255, 255, 255, 255 }
    local use_outline = outlined or false
    local is_centered = centered or true
    local enable_shadow = shadow or false
    local cam_dist = # (pos - GetFinalRenderedCamCoord())
    scale = (scale / cam_dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov

    SetTextScale(0.0 * scale, 0.55 * scale)
    SetTextFont(font)
    SetTextProportional(true)
    SetTextColour(color[1], color[2], color[3], color[4])
    BeginTextCommandDisplayText("STRING")
    SetTextCentre(is_centered)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(pos.x, pos.y, pos.z, 0)
    SetTextEdge(1, 0, 0, 0, 255)

    if (use_outline) then
        SetTextOutline()
    end

    if (enable_shadow) then
        SetTextDropShadow()
    end

    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function do_basic_interaction(opts)
    opts.cancel_raw_keys = opts?.cancel_raw_keys or {
        -- https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
        0x58, -- X key
    }

    local anim = {
        dict = opts?.anim?.dict or "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
        name = opts?.anim?.name or "machinic_loop_mechandplayer",
        blend_in_speed = opts?.anim?.blend_in_speed or 8.0,
        blend_out_speed = opts?.anim?.blend_out_speed or 8.0,
        duration = opts?.anim?.duration or -1,
        flags = opts?.anim?.flags or 31, -- 31 = 0x1F (loop, upper body only, allow player control)
    }

    local end_time = GetGameTimer() + opts.duration
    local local_ped = PlayerPedId()
    local start_position = GetEntityCoords(local_ped)

    FreezeEntityPosition(local_ped, true)
    ClearPedTasksImmediately(PlayerPedId())
    FreezeEntityPosition(local_ped, false)

    cslib.streaming.anim_dict.request(anim.dict).await()
    if not (IsEntityPlayingAnim(local_ped, anim.dict, anim.name, 3)) then
        TaskPlayAnim(local_ped, anim.dict, anim.name, anim.blend_in_speed, anim.blend_out_speed, anim.duration, anim.flags, 0, false, false, false)
    end
    cslib.streaming.anim_dict.clear(anim.dict)

    local mythic_args = {
        name = cslib.uuid(),
        duration = opts.duration,
        label = "กำลังกระทำ",
        useWhileDead = false,
        canCancel = false,
        controlDisables = {
            disableMovement = false,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = false,
        },
    }
    TriggerEvent("mythic_progbar:client:progress", mythic_args, function(status) end)

    if (opts?.entity) then
        local heading = GetHeadingBetween(GetEntityCoords(local_ped), GetEntityCoords(opts.entity))
        SetEntityHeading(local_ped, heading)
    end

    local being_damaged = false
    local dmg_event = cslib.on("gameEventTriggered", function(eventName, data)
        if (eventName ~= "CEventNetworkEntityDamage") then return end
        if (data[1] ~= PlayerPedId()) then return end
        being_damaged = true
    end)

    while GetGameTimer() < end_time do
        local_ped = PlayerPedId()

        if (opts?.entity) then
            local does_entity_exist = DoesEntityExist(opts.entity)
            if not (does_entity_exist) then
                break
            end

            local entity_pos = GetEntityCoords(opts.entity)
            if #(entity_pos - GetEntityCoords(local_ped)) > 3.0 then
                break
            end
        else
            if #(start_position - GetEntityCoords(local_ped)) > 3.0 then
                break
            end
        end

        if (being_damaged) then
            break
        end


        if (GetVehiclePedIsIn(local_ped, false) ~= 0) then
            ClearPedTasksImmediately(PlayerPedId())
            break
        end

        if (IsEntityDead(local_ped)) then
            ClearPedTasksImmediately(PlayerPedId())
            break
        end

        if (opts?.handler_should_continue) then
            local should_continue = opts.handler_should_continue()
            if not (should_continue) then
                break
            end
        end

        -- if not (IsEntityPlayingAnim(localPed, animDict, anim, 3)) then
        --     TaskPlayAnim(localPed, animDict, anim, 8.0, 8.0, -1, 31, 0, false, false, false)
        -- end

        if (opts?.cancel_raw_keys) then
            local should_break = false
            for key, value in pairs(opts?.cancel_raw_keys) do
                if IsRawKeyPressed(value) then
                    DisableControlAction(0, value, true)
                    should_break = true
                    break
                end
            end

            if should_break then
                break
            end
        end

        DisableControlAction(0, 30, true)  -- disable left/right
        DisableControlAction(0, 31, true)  -- disable forward/back
        DisableControlAction(0, 36, true)  -- INPUT_DUCK
        DisableControlAction(0, 38, true)  -- E
        DisableControlAction(0, 21, true)  -- disable sprint
        DisableControlAction(0, 21, true)  -- disable sprint
        DisableControlAction(0, 22, true)  -- INPUT_JUMP
        DisableControlAction(0, 24, true)  -- disable attack
        DisableControlAction(0, 25, true)  -- disable aim
        DisableControlAction(0, 47, true)  -- G
        DisableControlAction(0, 58, true)  -- disable weapon
        DisableControlAction(0, 263, true) -- disable melee
        DisableControlAction(0, 264, true) -- disable melee
        DisableControlAction(0, 257, true) -- disable melee
        DisableControlAction(0, 140, true) -- disable melee
        DisableControlAction(0, 141, true) -- disable melee
        DisableControlAction(0, 142, true) -- disable melee
        DisableControlAction(0, 143, true) -- disable melee
        DisableControlAction(0, 75, true)  -- disable exit vehicle
        DisableControlAction(27, 75, true) -- disable exit vehicle
        DisableControlAction(0, 32, true)  -- move (w)
        DisableControlAction(0, 34, true)  -- move (a)
        DisableControlAction(0, 33, true)  -- move (s)
        DisableControlAction(0, 35, true)  -- move (d)

        Wait(0)
    end

    local bResult = (GetGameTimer() >= end_time)
    if not (bResult) then
        TriggerEvent("mythic_progbar:client:cancel")
    end

    cslib.set_timeout(function()
        StopAnimTask(local_ped, anim.dict, anim.name, 1.0)
    end, 0)

    cslib.off(dmg_event)

    return bResult
end

function game.perform_interaction(...)
    return cslib.async(do_basic_interaction)(...)
end

local function getClosestPlayer(distance)
    local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()

    if (closestDistance > distance) then
        return {}
    end

    if (not closestPlayer) or (closestPlayer == -1) then
        return {}
    end

    return {
        ped = GetPlayerPed(closestPlayer),
        player = closestPlayer,
        distance = closestDistance,
        server_id = GetPlayerServerId(closestPlayer),
    }
end

local function getClosestPlayerConfirm(opts)
    local distance = opts?.distance or 3.0
    local draw_indicator = opts?.draw_indicator or true
    ESX.UI.Menu.CloseAll()
    local target = {}

    while true do
        local query = getClosestPlayer(distance)
        local localPed = PlayerPedId()
        local localPlayer = PlayerId()
        local targetEntity = PlayerPedId()

        DisablePlayerFiring(localPlayer, true)
        DisableControlAction(0, 38, true)
        DisableControlAction(0, 73, true)

        if (query.ped and DoesEntityExist(query.ped) and IsPedAPlayer(query.ped)) then
            targetEntity = query.ped
            if (IsDisabledControlJustPressed(0, 38)) then
                target = query
                break
            end
        end

        if (IsDisabledControlJustPressed(0, 73)) then
            break
        end

        local targetDrawPos = GetEntityCoords(targetEntity) + vec(0, 0, 1.0)

        game.draw_text_3d(targetDrawPos + vec(0, 0, -0.1), targetEntity == localPed and "กำลังค้นหาเป้าหมาย\n[X] เพื่อยกเลิก" or "กด [E] เลือกเป้าหมาย\n[X] เพื่อยกเลิก", 0.6, cfg.font_id, { 255, 255, 255, 255 }, true, true, true)

        if (draw_indicator) then
            DrawMarker(2, targetDrawPos, vector3(0, 0, 0), vector3(0, 0, 0), vector3(0.15, 0.15, -0.15), vector4(255, 0, 0, 255), false, true, true, nil, nil, false)
        end

        Wait(0)
    end

    return target
end

function game.find_closest_player(...)
    return cslib.async(getClosestPlayerConfirm)(...)
end

function game.get_closest_player(...)
    return getClosestPlayer(...)
end

return game
