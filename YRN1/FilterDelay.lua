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
    -- Stereo / General
    local delay = self:addObject("delay", libcore.Delay(2))

    local xfade = self:addObject("xfade", app.StereoCrossFade())
    local fader = self:createControl("fader", app.GainBias())
    connect(fader, "Out", xfade, "Fade")

    local tapEdge = self:addObject("tapEdge", app.Comparator())
    self:addMonoBranch("clock", tapEdge, "In", tapEdge, "Out")
    local tap = self:createTap(tapEdge)

    local feedbackGainAdapter = self:createAdapterControl("feedbackGainAdapter")

    local eq = self:createControl("eq", app.GainBias())
    local eqHigh = self:createEqHighControl(eq)
    local eqMid = self:createEqMidControl()
    local eqLow = self:createEqLowControl(eq)

    -- Left
    local feedbackMixL = self:addObject("feedbackMixL", app.Sum())
    local feedbackGainL = self:addObject("feedbackGainL", app.ConstantGain())
    feedbackGainL:setClampInDecibels(-35.9)

    local limiterL = self:addObject("limiter", libcore.Limiter())
    limiterL:setOptionValue("Type", 2)

    local eqL = self:createEq("eqL", eqHigh, eqMid, eqLow)

    tie(feedbackGainL, "Gain", feedbackGainAdapter, "Out")

    tie(delay, "Left Delay", tap, "Derived Period")

    connect(self, "In1", xfade, "Left B")
    connect(self, "In1", feedbackMixL, "Left")
    connect(feedbackMixL, "Out", eqL, "In")
    connect(eqL, "Out", delay, "Left In")
    connect(delay, "Left Out", feedbackGainL, "In")
    connect(feedbackGainL, "Out", limiterL, "In")
    connect(limiterL, "Out", feedbackMixL, "Right")
    connect(delay, "Left Out", xfade, "Left A")
    connect(xfade, "Left Out", self, "Out1")

    -- Right
    if channelCount == 2 then
        local spread = self:createSpread(tap, tapEdge)
        local spreadGainControl = self:createAdapterControl("spreadGainControl")
        tie(delay, "Spread", "*", spread, "Value", spreadGainControl, "Out")

        local feedbackMixR = self:addObject("feedbackMixR", app.Sum())
        local feedbackGainR = self:addObject("feedbackGainR", app.ConstantGain())
        feedbackGainR:setClampInDecibels(-35.9)

        local limiterR = self:addObject("limiter", libcore.Limiter())
        limiterR:setOptionValue("Type", 2)

        local eqR = self:createEq("eqR", eqHigh, eqMid, eqLow)

        tie(feedbackGainR, "Gain", feedbackGainAdapter, "Out")

        tie(delay, "Right Delay", tap, "Derived Period")

        connect(self, "In2", xfade, "Right B")
        connect(self, "In2", feedbackMixR, "Left")
        connect(feedbackMixR, "Out", eqR, "In")
        connect(eqR, "Out", delay, "Right In")
        connect(delay, "Right Out", feedbackGainR, "In")
        connect(feedbackGainR, "Out", limiterR, "In")
        connect(limiterR, "Out", feedbackMixR, "Right")
        connect(delay, "Right Out", xfade, "Right A")
        connect(xfade, "Right Out", self, "Out2")
    end
end

function FilterDelay:createControl(name, type)
    local control = self:addObject(name, type)
    local controlRange = self:addObject(name .. "Range", app.MinMax())
    connect(control, "Out", controlRange, "In")
    self:addMonoBranch(name, control, "In", control, "Out")
    return control
end

function FilterDelay:createAdapterControl(name)
    local adapter = self:addObject(name, app.ParameterAdapter())
    self:addMonoBranch(name, adapter, "In", adapter, "Out")
    return adapter
end

function FilterDelay:createTap(tapEdge)
    local tap = self:addObject("tap", libcore.TapTempo())
    tap:setBaseTempo(120)
    connect(tapEdge, "Out", tap, "In")
    local multiplier = self:createAdapterControl("multiplier")
    tie(tap, "Multiplier", multiplier, "Out")
    local divider = self:createAdapterControl("divider")
    tie(tap, "Divider", divider, "Out")
    return tap
end

function FilterDelay:createEq(name, high, mid, low)
    local eq = self:addObject(name, libcore.Equalizer3())
    eq:hardSet("Low Freq", 3000.0)
    eq:hardSet("High Freq", 2000.0)
    connect(high, "Out", eq, "High Gain")
    connect(mid, "Out", eq, "Mid Gain")
    connect(low, "Out", eq, "Low Gain")
    return eq
end

function FilterDelay:createEqHighControl(eqControl)
    local eqRectifyHigh = self:addObject("eqRectifyHigh", libcore.Rectify())
    eqRectifyHigh:setOptionValue("Type", 2)
    local eqHigh = self:addObject("eqHigh", app.GainBias())
    eqHigh:hardSet("Gain", 1.0)
    eqHigh:hardSet("Bias", 1.0)
    connect(eqControl, "Out", eqRectifyHigh, "In")
    connect(eqRectifyHigh, "Out", eqHigh, "In")
    return eqHigh
end

function FilterDelay:createEqMidControl()
    local eqMid = self:addObject("eqMid", app.Constant())
    eqMid:hardSet("Value", 1.0)
    return eqMid
end

function FilterDelay:createEqLowControl(eqControl)
    local eqRectifyLow = self:addObject("eqRectifyLow", libcore.Rectify())
    eqRectifyLow:setOptionValue("Type", 1)
    local eqLow = self:addObject("eqLow", app.GainBias())
    eqLow:hardSet("Gain", -1.0)
    eqLow:hardSet("Bias", 1.0)
    connect(eqControl, "Out", eqRectifyLow, "In")
    connect(eqRectifyLow, "Out", eqLow, "In")
    return eqLow
end

function FilterDelay:createSpread(tap, tapEdge)
    local clock = self:addObject("clock", libcore.ClockInSeconds())
    tie(clock, "Period", tap, "Derived Period")
    local noise = self:addObject("noise", libcore.WhiteNoise())
    local hold = self:addObject("hold", libcore.TrackAndHold())
    local comparator = self:addObject("comparator", app.Comparator())
    comparator:setTriggerMode()
    local spreadGainControl = self:createAdapterControl("spreadGainControl")
    connect(tapEdge, "Out", clock, "Sync")
    connect(clock, "Out", comparator, "In")
    connect(comparator, "Out", hold, "Track")
    connect(noise, "Out", hold, "In")
    return hold
end

local function feedbackMap()
    local map = app.LinearDialMap(-36, 6)
    map:setZero(-160)
    map:setSteps(6, 1, 0.1, 0.01);
    return map
end

local function spreadMap()
    local map = app.LinearDialMap(0, 0.1)
    map:setSteps(0.01, 0.001, 0.0001, 0.00001)
    return map
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
        collapsed = {}
    }

    if self.channelcount == 2 then
        views.expanded = {"clock", "mult", "div", "feedback", "spread", "eq", "wet"}
        controls.spread = GainBias {
            button = "spread",
            description = "Spread",
            branch = branches.spreadGainControl,
            gainbias = objects.spreadGainControl,
            range = objects.spreadGainControl,
            biasMap = spreadMap()
        }
    else
        views.expanded = {"clock", "mult", "div", "feedback", "eq", "wet"}
    end

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

    controls.feedback = GainBias {
        button = "fdbk",
        description = "Feedback",
        branch = branches.feedbackGainAdapter,
        gainbias = objects.feedbackGainAdapter,
        range = objects.feedbackGainAdapter,
        biasMap = feedbackMap(),
        biasUnits = app.unitDecibels
    }
    controls.feedback:setTextBelow(-35.9, "-inf dB")

    controls.eq = GainBias {
        button = "eq",
        description = "EQ",
        branch = branches.eq,
        gainbias = objects.eq,
        range = objects.eqRange,
        biasMap = Encoder.getMap("[-1,1]")
    }

    controls.wet = GainBias {
        button = "wet",
        branch = branches.fader,
        description = "Wet/Dry",
        gainbias = objects.fader,
        range = objects.faderRange,
        biasMap = Encoder.getMap("unit")
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
