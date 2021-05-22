local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local libcore = require "core.libcore"
local Gate = require "Unit.ViewControl.Gate"
local GainBias = require "Unit.ViewControl.GainBias"
local Utils = require "Utils"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"

local TieBug = Class {}
TieBug:include(Unit)

function TieBug:init(args)
    args.title = "Tie Function Bug"
    args.mnemonic = "FD"
    args.version = 1
    Unit.init(self, args)
end

function TieBug:onLoadGraph(channelCount)
    local eqHigh = self:addObject("eqHigh", app.Constant())
    local eqLow = self:addObject("eqLow", app.Constant())

    local eqAdapter = self:addObject("eqAdapter", app.ParameterAdapter())
    tie(eqHigh, "Value", "function(x) return 1 + math.min(x, 0.0) end", eqAdapter, "Out")
    tie(eqLow, "Value", "function(x) return 0 end", eqAdapter, "Out")

    connect(eqHigh, "Out", self, "Out1")
    connect(eqLow, "Out", self, "Out2")

    self:addMonoBranch("eq", eqAdapter, "In", eqAdapter, "Out")
end

function TieBug:onLoadViews(objects, branches)
    local controls = {}
    local views = {
        expanded = {"eq"},
        collapsed = {}
    }

    controls.eq = GainBias {
        button = "eq",
        description = "EQ",
        branch = branches.eq,
        gainbias = objects.eqAdapter,
        range = objects.eqAdapter,
        biasMap = Encoder.getMap("[-1,1]")
    }

    return controls, views
end

return TieBug
