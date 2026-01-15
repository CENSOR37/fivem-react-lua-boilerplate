function drawText2d(data)
    local text = data.text
    if not (text) then
        return
    end
    local offset = data.offset or vec(0.5, 0.5)
    local scale = data.scale or 1.0
    local font = data.font or 0
    local color = data.color or {
        r = 255,
        g = 255,
        b = 255,
        a = 255,
    }
    local bOutline = data.bOutline or false
    local bCenter = data.bCenter or true
    local bShadow = data.bShadow or false
    local align = data.align or 0
    SetTextFont(font)
    SetTextScale(1, scale)
    SetTextWrap(0.0, 1.0)
    SetTextCentre(bCenter)
    SetTextColour(color.r, color.g, color.b, color.a)
    SetTextJustification(align)
    SetTextEdge(1, 0, 0, 0, 255)
    if bOutline then
        SetTextOutline()
    end
    if bShadow then
        SetTextDropShadow()
    end
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(offset.x, offset.y)
end

function drawText3d(data)
    local text = data.text
    if not (text) then
        return
    end
    local coords = data.coords
    if not (coords) then
        return
    end
    coords = vec(coords.x, coords.y, coords.z)
    local scale = data.scale or 1.0
    local font = data.font or 0
    local color = data.color or {
        r = 255,
        g = 255,
        b = 255,
        a = 255,
    }
    local bOutline = data.bOutline or false
    local bCenter = data.bCenter or true
    local bShadow = data.bShadow or false
    local camDistance = # (coords - GetFinalRenderedCamCoord())
    scale = (scale / camDistance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    SetTextScale(0.0 * scale, 0.55 * scale)
    SetTextFont(font)
    SetTextProportional(true)
    SetTextColour(color.r, color.g, color.b, color.a)
    BeginTextCommandDisplayText("STRING")
    SetTextCentre(bCenter)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextEdge(1, 0, 0, 0, 255)
    if (bOutline) then
        SetTextOutline()
    end
    if (bShadow) then
        SetTextDropShadow()
    end
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end
