local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local libcore = require "core.libcore"
local Gate = require "Unit.ViewControl.Gate"
local GainBias = require "Unit.ViewControl.GainBias"
local Utils = require "Utils"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"

local FilterDelay = Class {}
FilterDelay:include(Unit)

function FilterDelay:init(args)
    args.title = "Filter Delay"
    args.mnemonic = "FD"
    args.version = 1
    Unit.init(self, args)
end

function FilterDelay:onLoadGraph(channelCount)
    if channelCount == 2 then
        self:loadStereoGraph()
    else
        self:loadMonoGraph()
    end
end

function FilterDelay:loadMonoGraph()
    local delay = self:addObject("delay", libcore.Delay(1))

    local tap = self:addObject("tap", libcore.TapTempo())
    tap:setBaseTempo(120)
    local tapEdge = self:addObject("tapEdge", app.Comparator())

    local multiplier = self:addObject("multiplier", app.ParameterAdapter())
    local divider = self:addObject("divider", app.ParameterAdapter())
    tie(tap, "Multiplier", multiplier, "Out")
    tie(tap, "Divider", divider, "Out")
    tie(delay, "Left Delay", tap, "Derived Period")

    connect(tapEdge, "Out", tap, "In")

    connect(self, "In1", delay, "Left In")
    connect(delay, "Left Out", self, "Out1")

    self:addMonoBranch("clock", tapEdge, "In", tapEdge, "Out")
    self:addMonoBranch("multiplier", multiplier, "In", multiplier, "Out")
    self:addMonoBranch("divider", divider, "In", divider, "Out")
end

function FilterDelay:loadStereoGraph()
    local delay = self:addObject("delay", libcore.Delay(2))

    local tap = self:addObject("tap", libcore.TapTempo())
    tap:setBaseTempo(120)
    local tapEdge = self:addObject("tapEdge", app.Comparator())

    local multiplier = self:addObject("multiplier", app.ParameterAdapter())
    local divider = self:addObject("divider", app.ParameterAdapter())
    tie(tap, "Multiplier", multiplier, "Out")
    tie(tap, "Divider", divider, "Out")
    tie(delay, "Left Delay", tap, "Derived Period")
    tie(delay, "Right Delay", tap, "Derived Period")

    connect(tapEdge, "Out", tap, "In")

    connect(self, "In1", delay, "Left In")
    connect(self, "In2", delay, "Right In")
    connect(delay, "Left Out", self, "Out1")
    connect(delay, "Right Out", self, "Out2")

    self:addMonoBranch("clock", tapEdge, "In", tapEdge, "Out")
    self:addMonoBranch("multiplier", multiplier, "In", multiplier, "Out")
    self:addMonoBranch("divider", divider, "In", divider, "Out")
end

function FilterDelay:setMaxDelayTime(secs)
    local requested = math.floor(secs + 0.5)
    self.objects.delay:allocateTimeUpTo(requested)
end

local menu = {"setHeader", "set100ms", "set1s", "set10s", "set30s"}

function FilterDelay:onShowMenu(objects, branches)
    local controls = {}
    local allocated = self.objects.delay:maximumDelayTime()
    allocated = Utils.round(allocated, 1)

    controls.setHeader = MenuHeader {
        description = string.format("Current Maximum Delay is %0.1fs.", allocated)
    }

    controls.set100ms = Task {
        description = "0.1s",
        task = function()
            self:setMaxDelayTime(0.1)
        end
    }

    controls.set1s = Task {
        description = "1s",
        task = function()
            self:setMaxDelayTime(1)
        end
    }

    controls.set10s = Task {
        description = "10s",
        task = function()
            self:setMaxDelayTime(10)
        end
    }

    controls.set30s = Task {
        description = "30s",
        task = function()
            self:setMaxDelayTime(30)
        end
    }

    return controls, menu
end

function FilterDelay:onLoadViews(objects, branches)
    local controls = {}
    local views = {
        expanded = {"clock", "mult", "div"},
        collapsed = {}
    }

    controls.clock = Gate {
        button = "clock",
        branch = branches.clock,
        description = "Clock",
        comparator = objects.tapEdge
    }

    controls.mult = GainBias {
        button = "mult",
        branch = branches.multiplier,
        description = "Clock Multiplier",
        gainbias = objects.multiplier,
        range = objects.multiplier,
        biasMap = Encoder.getMap("int[1,32]"),
        gainMap = Encoder.getMap("[-20,20]"),
        initialBias = 1,
        biasPrecision = 0
    }

    controls.div = GainBias {
        button = "div",
        branch = branches.divider,
        description = "Clock Divider",
        gainbias = objects.divider,
        range = objects.divider,
        biasMap = Encoder.getMap("int[1,32]"),
        gainMap = Encoder.getMap("[-20,20]"),
        initialBias = 1,
        biasPrecision = 0
    }

    self:setMaxDelayTime(1.0)

    return controls, views
end

function FilterDelay:serialize()
    local t = Unit.serialize(self)
    t.maximumDelayTime = self.objects.delay:maximumDelayTime()
    return t
end

function FilterDelay:deserialize(t)
    local time = t.maximumDelayTime
    if time and time > 0 then
        self:setMaxDelayTime(time)
    end
    Unit.deserialize(self, t)
end

function FilterDelay:onRemove()
    self.objects.delay:deallocate()
    Unit.onRemove(self)
end

return FilterDelay
