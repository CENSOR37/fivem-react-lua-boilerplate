local ctx = {}

ctx.name = cslib.is_server and "^1[SERVER] ^7" or "^2[CLIENT] ^7"

function ctx.greeting()
    print(("Hello from %scontext!"):format(ctx.name))
end

return ctx
