local node = main.class.node

---@diagnostic disable-next-line: duplicate-set-field
function node:constructor(...)
    self:initialize(...)
end

---@diagnostic disable-next-line: duplicate-set-field
function node:destructor()
    self:uninitialize()
end
