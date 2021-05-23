local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local libcore = require "core.libcore"
local Gate = require "Unit.ViewControl.Gate"
local GainBias = require "Unit.ViewControl.GainBias"
local Utils = require "Utils"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"

local FDN = Class {}
FDN:include(Unit)

function FDN:init(args)
    args.title = "Feedback Delay Network"
    args.mnemonic = "DN"
    args.version = 1
    Unit.init(self, args)
end

function FDN:onLoadGraph(channelCount)
    local delay1 = self:addObject("delay1", libcore.DopplerDelay(2.0))
    local delay2 = self:addObject("delay2", libcore.DopplerDelay(2.0))
    local delay3 = self:addObject("delay3", libcore.DopplerDelay(2.0))
    local delay4 = self:addObject("delay4", libcore.DopplerDelay(2.0))
    local delay = self:createControl("delay", app.GainBias())

    local xfade = self:addObject("xfade", app.StereoCrossFade())
    local fader = self:createControl("fader", app.GainBias())
    connect(fader, "Out", xfade, "Fade")

    if channelCount == 2 then
        connect(self, "In1", xfade, "Left B")
        connect(self, "In2", xfade, "Right B")
        connect(xfade, "Left Out", self, "Out1")
        connect(xfade, "Right Out", self, "Out2")
    else
        connect(self, "In1", xfade, "Left B")
        connect(xfade, "Left Out", self, "Out1")
    end
end

function FDN:createControl(name, type)
    local control = self:addObject(name, type)
    local controlRange = self:addObject(name .. "Range", app.MinMax())
    connect(control, "Out", controlRange, "In")
    self:addMonoBranch(name, control, "In", control, "Out")
    return control
end

function FDN:createAdapterControl(name)
    local adapter = self:addObject(name, app.ParameterAdapter())
    self:addMonoBranch(name, adapter, "In", adapter, "Out")
    return adapter
end

local function feedbackMap()
    local map = app.LinearDialMap(-36, 6)
    map:setZero(-160)
    map:setSteps(6, 1, 0.1, 0.01);
    return map
end

local function timeMap(max, n)
    local map = app.LinearDialMap(0, max)
    map:setCoarseRadix(n)
    return map
end

function FDN:onLoadViews(objects, branches)
    local controls = {}
    local views = {
        expanded = {"delay", "wet"},
        collapsed = {}
    }

    local allocated1 = self.objects.delay1:maximumDelayTime()
    local allocated2 = self.objects.delay2:maximumDelayTime()
    local allocated3 = self.objects.delay3:maximumDelayTime()
    local allocated4 = self.objects.delay4:maximumDelayTime()
    local allocated = math.min(allocated1, allocated2, allocated3, allocated4)
    allocated = Utils.round(allocated, 1)

    controls.delay = GainBias {
        button = "delay",
        branch = branches.delay,
        description = "Delay",
        gainbias = objects.delay,
        range = objects.delayRange,
        biasMap = timeMap(allocated, 100),
        initialBias = 0.1,
        biasUnits = app.unitSecs
    }

    controls.wet = GainBias {
        button = "wet",
        branch = branches.fader,
        description = "Wet/Dry",
        gainbias = objects.fader,
        range = objects.faderRange,
        biasMap = Encoder.getMap("unit")
    }

    return controls, views
end

function FDN:onRemove()
    self.objects.delay:deallocate()
    Unit.onRemove(self)
end

return FDN
