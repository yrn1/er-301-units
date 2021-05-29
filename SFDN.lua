-- Copyright (c) 2021, Jeroen Baekelandt
-- All rights reserved.
-- Redistribution and use in source and binary forms, with or without modification,
-- are permitted provided that the following conditions are met:
-- * Redistributions of source code must retain the above copyright notice, this
--   list of conditions and the following disclaimer.
-- * Redistributions in binary form must reproduce the above copyright notice, this
--   list of conditions and the following disclaimer in the documentation and/or
--   other materials provided with the distribution.
-- * Neither the name of the {organization} nor the names of its
--   contributors may be used to endorse or promote products derived from
--   this software without specific prior written permission.
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
-- ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
-- ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-- This FDN reverb is based on a paper by
-- TOM ERBE - UC SAN DIEGO: REVERB TOPOLOGIES AND DESIGN
-- http://tre.ucsd.edu/wordpress/wp-content/uploads/2018/10/reverbtopo.pdf
--
-- TODO CPU
local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local libcore = require "core.libcore"
local Gate = require "Unit.ViewControl.Gate"
local GainBias = require "Unit.ViewControl.GainBias"
local Utils = require "Utils"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"

local SFDN = Class {}
SFDN:include(Unit)

function SFDN:init(args)
    args.title = "Simple Feedback Delay Network"
    args.mnemonic = "DN"
    args.version = 1
    Unit.init(self, args)
end

function SFDN:onLoadGraph(channelCount)
    local inLevelAdapter = self:createAdapterControl("inLevelAdapter")
    local inLevelL = self:addObject("inLevelL", app.ConstantGain())
    tie(inLevelL, "Gain", inLevelAdapter, "Out")
    local inLevelR = self:addObject("inLevelR", app.ConstantGain())
    tie(inLevelR, "Gain", inLevelAdapter, "Out")

    local xfade = self:addObject("xfade", app.StereoCrossFade())
    local fader = self:createControl("fader", app.GainBias())
    connect(fader, "Out", xfade, "Fade")

    local eq1Mix = self:addObject("eq1Mix", app.Sum())
    local eq2Mix = self:addObject("eq2Mix", app.Sum())

    local tone = self:createControl("tone", app.GainBias())
    local eqHigh = self:createEqHighControl(tone)
    local eqMid = self:createEqMidControl()
    local eqLow = self:createEqLowControl(tone)

    local eq1 = self:createEq("eq1", eqHigh, eqMid, eqLow)
    local eq2 = self:createEq("eq2", eqHigh, eqMid, eqLow)
    local eq3 = self:createEq("eq3", eqHigh, eqMid, eqLow)
    local eq4 = self:createEq("eq4", eqHigh, eqMid, eqLow)

    local delay12 = self:addObject("delay12", libcore.Delay(2))
    delay12:allocateTimeUpTo(5.0)
    local delay34 = self:addObject("delay34", libcore.Delay(2))
    delay34:allocateTimeUpTo(5.0)

    local delayAdapter = self:createAdapterControl("delayAdapter")
    local delayScale1 = self:addObject("delayScale1", app.Constant())
    delayScale1:hardSet("Value", 0.365994)
    local delayScale2 = self:addObject("delayScale2", app.Constant())
    delayScale2:hardSet("Value", 0.573487)
    local delayScale3 = self:addObject("delayScale3", app.Constant())
    delayScale3:hardSet("Value", 0.775216)

    tie(delay12, "Left Delay", "*", delayScale1, "Value", delayAdapter, "Out")
    tie(delay12, "Right Delay", "*", delayScale2, "Value", delayAdapter, "Out")
    tie(delay34, "Left Delay", "*", delayScale3, "Value", delayAdapter, "Out")
    tie(delay34, "Right Delay", delayAdapter, "Out")

    local dif11 = self:addObject("dif11", app.Sum())
    local dif11r = self:negative("dif11", dif11)
    local sum12 = self:addObject("sum12", app.Sum())
    local sum12r = self:positive("sum12", sum12)
    local dif13 = self:addObject("dif13", app.Sum())
    local dif13r = self:negative("dif13", dif13)
    local sum14 = self:addObject("sum14", app.Sum())
    local sum14r = self:positive("sum14", sum14)

    local dif21 = self:addObject("dif21", app.Sum())
    local dif21r = self:negative("dif21", dif21)
    local sum22 = self:addObject("sum22", app.Sum())
    local sum22r = self:positive("sum22", sum22)
    local dif23 = self:addObject("dif23", app.Sum())
    local dif23r = self:negative("dif23", dif23)
    local sum24 = self:addObject("sum24", app.Sum())
    local sum24r = self:positive("sum24", sum24)

    local feedbackAdapter = self:createAdapterControl("feedbackAdapter")
    local half = self:addObject("half", app.Constant())
    half:hardSet("Value", 0.5)
    local feedback1 = self:addObject("feedback1", app.ConstantGain())
    feedback1:setClampInDecibels(-23.9)
    tie(feedback1, "Gain", "*", half, "Value", feedbackAdapter, "Out")
    local feedback2 = self:addObject("feedback2", app.ConstantGain())
    feedback2:setClampInDecibels(-23.9)
    tie(feedback2, "Gain", "*", half, "Value", feedbackAdapter, "Out")
    local feedback3 = self:addObject("feedback3", app.ConstantGain())
    feedback3:setClampInDecibels(-23.9)
    tie(feedback3, "Gain", "*", half, "Value", feedbackAdapter, "Out")
    local feedback4 = self:addObject("feedback4", app.ConstantGain())
    feedback4:setClampInDecibels(-23.9)
    tie(feedback4, "Gain", "*", half, "Value", feedbackAdapter, "Out")

    local fdnMixL = self:addObject("fdnMixL", app.Sum())
    local fdnMixR = self:addObject("fdnMixR", app.Sum())

    if channelCount == 2 then
        connect(self, "In1", inLevelL, "In")
        connect(self, "In2", inLevelR, "In")
    else
        connect(self, "In1", inLevelL, "In")
        connect(self, "In1", inLevelR, "In")
    end
    connect(inLevelL, "Out", eq1Mix, "Left")
    connect(inLevelR, "Out", eq2Mix, "Left")
    connect(eq1Mix, "Out", eq1, "In")
    connect(eq2Mix, "Out", eq2, "In")

    connect(eq1, "Out", delay12, "Left In")
    connect(eq2, "Out", delay12, "Right In")
    connect(eq3, "Out", delay34, "Left In")
    connect(eq4, "Out", delay34, "Right In")

    connect(delay12, "Left Out", dif11, "Left")
    connect(delay12, "Left Out", sum12, "Left")
    connect(delay12, "Right Out", dif11r, "In")
    connect(delay12, "Right Out", sum12r, "In")
    connect(delay34, "Left Out", dif13, "Left")
    connect(delay34, "Left Out", sum14, "Left")
    connect(delay34, "Right Out", dif13r, "In")
    connect(delay34, "Right Out", sum14r, "In")

    connect(dif11, "Out", dif21, "Left")
    connect(dif11, "Out", sum22, "Left")
    connect(sum12, "Out", dif23, "Left")
    connect(sum12, "Out", sum24, "Left")
    connect(dif13, "Out", dif21r, "In")
    connect(dif13, "Out", sum22r, "In")
    connect(sum14, "Out", dif23r, "In")
    connect(sum14, "Out", sum24r, "In")

    connect(dif21, "Out", feedback1, "In")
    connect(sum22, "Out", feedback2, "In")
    connect(dif23, "Out", feedback3, "In")
    connect(sum24, "Out", feedback4, "In")

    connect(feedback1, "Out", eq1Mix, "Right")
    connect(feedback2, "Out", eq3, "In")
    connect(feedback3, "Out", eq2Mix, "Right")
    connect(feedback4, "Out", eq4, "In")

    connect(feedback1, "Out", fdnMixL, "Left")
    connect(feedback2, "Out", fdnMixR, "Left")
    connect(feedback3, "Out", fdnMixL, "Right")
    connect(feedback4, "Out", fdnMixR, "Right")

    connect(fdnMixL, "Out", xfade, "Left A")
    connect(fdnMixR, "Out", xfade, "Right A")

    connect(self, "In1", xfade, "Left B")
    connect(xfade, "Left Out", self, "Out1")
    if channelCount == 2 then
        connect(self, "In2", xfade, "Right B")
        connect(xfade, "Right Out", self, "Out2")
    end
end

function SFDN:createControl(name, type)
    local control = self:addObject(name, type)
    local controlRange = self:addObject(name .. "Range", app.MinMax())
    connect(control, "Out", controlRange, "In")
    self:addMonoBranch(name, control, "In", control, "Out")
    return control
end

function SFDN:createAdapterControl(name)
    local adapter = self:addObject(name, app.ParameterAdapter())
    self:addMonoBranch(name, adapter, "In", adapter, "Out")
    return adapter
end

function SFDN:positive(name, sum)
    local negation = self:addObject(name .. "r", app.ConstantGain())
    negation:hardSet("Gain", 1.0)
    connect(negation, "Out", sum, "Right")
    return negation
end

function SFDN:negative(name, sum)
    local negation = self:addObject(name .. "r", app.ConstantGain())
    negation:hardSet("Gain", -1.0)
    connect(negation, "Out", sum, "Right")
    return negation
end

function SFDN:createEq(name, high, mid, low)
    local eq = self:addObject(name, libcore.Equalizer3())
    eq:hardSet("Low Freq", 3000.0)
    eq:hardSet("High Freq", 2000.0)
    connect(high, "Out", eq, "High Gain")
    connect(mid, "Out", eq, "Mid Gain")
    connect(low, "Out", eq, "Low Gain")
    return eq
end

function SFDN:createEqHighControl(toneControl)
    local eqRectifyHigh = self:addObject("eqRectifyHigh", libcore.Rectify())
    eqRectifyHigh:setOptionValue("Type", 2)
    local eqHigh = self:addObject("eqHigh", app.GainBias())
    eqHigh:hardSet("Gain", 1.0)
    eqHigh:hardSet("Bias", 1.0)
    connect(toneControl, "Out", eqRectifyHigh, "In")
    connect(eqRectifyHigh, "Out", eqHigh, "In")
    return eqHigh
end

function SFDN:createEqMidControl()
    local eqMid = self:addObject("eqMid", app.Constant())
    eqMid:hardSet("Value", 1.0)
    return eqMid
end

function SFDN:createEqLowControl(toneControl)
    local eqRectifyLow = self:addObject("eqRectifyLow", libcore.Rectify())
    eqRectifyLow:setOptionValue("Type", 1)
    local eqLow = self:addObject("eqLow", app.GainBias())
    eqLow:hardSet("Gain", -1.0)
    eqLow:hardSet("Bias", 1.0)
    connect(toneControl, "Out", eqRectifyLow, "In")
    connect(eqRectifyLow, "Out", eqLow, "In")
    return eqLow
end

local function timeMap(max, n)
    local map = app.LinearDialMap(0, max)
    map:setCoarseRadix(n)
    return map
end

local function feedbackMap()
    local map = app.LinearDialMap(-18, 0)
    map:setZero(-160)
    map:setSteps(1, 0.1, 0.01, 0.001);
    return map
end

function SFDN:onLoadViews(objects, branches)
    local controls = {}
    local views = {
        expanded = {"delay", "feedback", "tone", "input", "wet"},
        collapsed = {}
    }

    local allocated1 = self.objects.delay12:maximumDelayTime()
    local allocated2 = self.objects.delay34:maximumDelayTime()
    local allocated = math.min(allocated1, allocated2)
    allocated = Utils.round(allocated, 1)

    controls.delay = GainBias {
        button = "delay",
        description = "Delay",
        branch = branches.delayAdapter,
        gainbias = objects.delayAdapter,
        range = objects.delayAdapter,
        biasMap = timeMap(allocated, 100),
        initialBias = 0.3,
        biasUnits = app.unitSecs
    }

    controls.feedback = GainBias {
        button = "fdbk",
        description = "Feedback",
        branch = branches.feedbackAdapter,
        gainbias = objects.feedbackAdapter,
        range = objects.feedbackAdapter,
        biasMap = feedbackMap(),
        biasUnits = app.unitDecibels,
        initialBias = 0.95
    }
    controls.feedback:setTextBelow(-17.9, "-inf dB")

    controls.tone = GainBias {
        button = "tone",
        description = "Tone",
        branch = branches.tone,
        gainbias = objects.tone,
        range = objects.toneRange,
        biasMap = Encoder.getMap("[-1,1]")
    }

    controls.input = GainBias {
        button = "input",
        description = "FDN Input Level",
        branch = branches.inLevelAdapter,
        gainbias = objects.inLevelAdapter,
        range = objects.inLevelAdapter,
        biasMap = Encoder.getMap("unit"),
        initialBias = 0.8
    }

    controls.wet = GainBias {
        button = "wet",
        branch = branches.fader,
        description = "Wet/Dry",
        gainbias = objects.fader,
        range = objects.faderRange,
        biasMap = Encoder.getMap("unit"),
        initialBias = 0.4
    }

    return controls, views
end

function SFDN:onRemove()
    self.objects.delay12:deallocate()
    self.objects.delay34:deallocate()
    Unit.onRemove(self)
end

return SFDN
