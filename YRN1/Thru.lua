local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"

local Thru = Class {}
Thru:include(Unit)

function Thru:init(args)
    args.title = "Pass Through"
    args.mnemonic = "Thru"
    args.version = 1
    Unit.init(self, args)
end

function Thru:onLoadGraph(channelCount)
    local vca1 = self:addObject("vca1", app.ConstantGain())
    vca1:hardSet("Gain", 1.0)
    connect(self, "In1", vca1, "In")
    connect(vca1, "Out", self, "Out1")

    if channelCount == 2 then
        local vca2 = self:addObject("vca2", app.ConstantGain())
        vca2:hardSet("Gain", 1.0)
        connect(self, "In2", vca2, "In")
        connect(vca2, "Out", self, "Out2")
    end
end

function Thru:onLoadViews(objects, branches)
    local views = {
        expanded = {},
        collapsed = {}
    }
    local controls = {}
    return controls, views
end

return Thru
