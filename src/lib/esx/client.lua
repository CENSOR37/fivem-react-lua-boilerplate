local lib_esx = {}

local function until_esx_ready()
    while not (ESX) and not (ESX.IsPlayerLoaded()) do
        Wait(0)
    end
end

function lib_esx.until_ready(...)
    return cslib.async(until_esx_ready)(...)
end

function lib_esx.register_admin_command(command_name, callback)
    RegisterCommand(command_name, function(src, args, raw_command)
        local is_console = src <= 0
        local has_access = is_console

        if not (is_console) then
            local player = ESX.GetPlayerFromId(src)
            has_access = player.isAdmin()
        end

        if (has_access) then
            callback(src, args, raw_command, is_console)
        else
            CreateThread(function()
                cslib.print.warn(("Player %s attempted to use admin command /%s without access"):format(src, command_name))
            end)
        end
    end, false)
end

return lib_esx
