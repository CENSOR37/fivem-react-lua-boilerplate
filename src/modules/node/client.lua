local node = require "src.modules.node.shared"

---@diagnostic disable-next-line: duplicate-set-field
function node:constructor(...)
    self:initialize(...)
end

---@diagnostic disable-next-line: duplicate-set-field
function node:destructor()
    self:uninitialize()
end

return node
