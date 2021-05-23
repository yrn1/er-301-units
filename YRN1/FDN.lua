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
-- Takes 20% CPU in stereo
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
    local levelAdapter = self:createAdapterControl("levelAdapter")
    local inLevelL = self:addObject("inLevelL", app.ConstantGain())
    tie(inLevelL, "Gain", levelAdapter, "Out")
    local inLevelR = self:addObject("inLevelR", app.ConstantGain())
    tie(inLevelR, "Gain", levelAdapter, "Out")

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

    local delay1 = self:addObject("delay1", libcore.DopplerDelay(2.0))
    local delay2 = self:addObject("delay2", libcore.DopplerDelay(2.0))
    local delay3 = self:addObject("delay3", libcore.DopplerDelay(2.0))
    local delay4 = self:addObject("delay4", libcore.DopplerDelay(2.0))
    local delay = self:createControl("delay", app.GainBias())
    local delayTime1 = self:addObject("delayTime1", app.ConstantGain())
    -- delayTime1:hardSet("Gain", 0.686869)
    delayTime1:hardSet("Gain", 0.365994)
    connect(delay, "Out", delayTime1, "In")
    local delayTime2 = self:addObject("delayTime2", app.ConstantGain())
    -- delayTime2:hardSet("Gain", 0.777778)
    delayTime2:hardSet("Gain", 0.573487)
    connect(delay, "Out", delayTime2, "In")
    local delayTime3 = self:addObject("delayTime3", app.ConstantGain())
    -- delayTime3:hardSet("Gain", 0.909091)
    delayTime3:hardSet("Gain", 0.775216)
    connect(delay, "Out", delayTime3, "In")

    local modulation = self:createAdapterControl("modulation")
    local modulatedDelayTime1 = self:modulate("modulatedDelayTime1", delayTime1, modulation, 0.13)
    local modulatedDelayTime2 = self:modulate("modulatedDelayTime2", delayTime2, modulation, 0.17)
    local modulatedDelayTime3 = self:modulate("modulatedDelayTime3", delayTime3, modulation, 0.19)
    local modulatedDelayTime4 = self:modulate("modulatedDelayTime4", delay, modulation, 0.23)

    connect(modulatedDelayTime1, "Out", delay1, "Delay")
    connect(modulatedDelayTime2, "Out", delay2, "Delay")
    connect(modulatedDelayTime3, "Out", delay3, "Delay")
    connect(modulatedDelayTime4, "Out", delay4, "Delay")

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
    feedback1:setClampInDecibels(-35.9)
    tie(feedback1, "Gain", "*", half, "Value", feedbackAdapter, "Out")
    local feedback2 = self:addObject("feedback2", app.ConstantGain())
    feedback2:setClampInDecibels(-35.9)
    tie(feedback2, "Gain", "*", half, "Value", feedbackAdapter, "Out")
    local feedback3 = self:addObject("feedback3", app.ConstantGain())
    feedback3:setClampInDecibels(-35.9)
    tie(feedback3, "Gain", "*", half, "Value", feedbackAdapter, "Out")
    local feedback4 = self:addObject("feedback4", app.ConstantGain())
    feedback4:setClampInDecibels(-35.9)
    tie(feedback4, "Gain", "*", half, "Value", feedbackAdapter, "Out")

    local fdnMixL = self:addObject("fdnMixL", app.Sum())
    local fdnMixR = self:addObject("fdnMixR", app.Sum())

    local outMixL = self:addObject("outMixL", app.Sum())
    local outMixR = self:addObject("outMixR", app.Sum())

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

    connect(eq1, "Out", delay1, "In")
    connect(eq2, "Out", delay2, "In")
    connect(eq3, "Out", delay3, "In")
    connect(eq4, "Out", delay4, "In")

    connect(delay1, "Out", dif11, "Left")
    connect(delay1, "Out", sum12, "Left")
    connect(delay2, "Out", dif11r, "In")
    connect(delay2, "Out", sum12r, "In")
    connect(delay3, "Out", dif13, "Left")
    connect(delay3, "Out", sum14, "Left")
    connect(delay4, "Out", dif13r, "In")
    connect(delay4, "Out", sum14r, "In")

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

    connect(fdnMixL, "Out", outMixL, "Right")
    connect(fdnMixR, "Out", outMixR, "Right")

    if channelCount == 2 then
        connect(self, "In1", outMixL, "Left")
        connect(self, "In2", outMixR, "Left")
        connect(outMixL, "Out", self, "Out1")
        connect(outMixR, "Out", self, "Out2")
    else
        connect(self, "In1", outMixL, "Left")
        connect(outMixL, "Out", self, "Out1")
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

function FDN:positive(name, sum)
    local negation = self:addObject(name .. "r", app.ConstantGain())
    negation:hardSet("Gain", 1.0)
    connect(negation, "Out", sum, "Right")
    return negation
end

function FDN:negative(name, sum)
    local negation = self:addObject(name .. "r", app.ConstantGain())
    negation:hardSet("Gain", -1.0)
    connect(negation, "Out", sum, "Right")
    return negation
end

function FDN:createEq(name, high, mid, low)
    local eq = self:addObject(name, libcore.Equalizer3())
    eq:hardSet("Low Freq", 3000.0)
    eq:hardSet("High Freq", 2000.0)
    connect(high, "Out", eq, "High Gain")
    connect(mid, "Out", eq, "Mid Gain")
    connect(low, "Out", eq, "Low Gain")
    return eq
end

function FDN:createEqHighControl(toneControl)
    local eqRectifyHigh = self:addObject("eqRectifyHigh", libcore.Rectify())
    eqRectifyHigh:setOptionValue("Type", 2)
    local eqHigh = self:addObject("eqHigh", app.GainBias())
    eqHigh:hardSet("Gain", 1.0)
    eqHigh:hardSet("Bias", 1.0)
    connect(toneControl, "Out", eqRectifyHigh, "In")
    connect(eqRectifyHigh, "Out", eqHigh, "In")
    return eqHigh
end

function FDN:createEqMidControl()
    local eqMid = self:addObject("eqMid", app.Constant())
    eqMid:hardSet("Value", 1.0)
    return eqMid
end

function FDN:createEqLowControl(toneControl)
    local eqRectifyLow = self:addObject("eqRectifyLow", libcore.Rectify())
    eqRectifyLow:setOptionValue("Type", 1)
    local eqLow = self:addObject("eqLow", app.GainBias())
    eqLow:hardSet("Gain", -1.0)
    eqLow:hardSet("Bias", 1.0)
    connect(toneControl, "Out", eqRectifyLow, "In")
    connect(eqRectifyLow, "Out", eqLow, "In")
    return eqLow
end

function FDN:modulate(name, time, modulation, frequency)
    local sine = self:addObject(name.."sine", libcore.SineOscillator())
    local freq = self:addObject(name.."freq", app.Constant())
    freq:hardSet("Value", frequency)
    connect(freq, "Out", sine, "Fundamental")
    local scaledSine = self:addObject(name.."scale", app.GainBias())
    scaledSine:hardSet("Bias", 1.0)
    local fraction = self:addObject(name.."frac", app.Constant())
    fraction:hardSet("Value", 0.1)
    tie(scaledSine, "Gain", "*", fraction, "Value", modulation, "Out")
    connect(sine, "Out", scaledSine, "In")
    local mult = self:addObject(name.."mult", app.Multiply())
    connect(time, "Out", mult, "Left")
    connect(scaledSine, "Out", mult, "Right")
    return mult
end

local function timeMap(max, n)
    local map = app.LinearDialMap(0, max)
    map:setCoarseRadix(n)
    return map
end

function FDN:onLoadViews(objects, branches)
    local controls = {}
    local views = {
        expanded = {"delay", "feedback", "tone", "mod", "level"},
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
        description = "Delay",
        branch = branches.delay,
        gainbias = objects.delay,
        range = objects.delayRange,
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
        biasMap = Encoder.getMap("feedback"),
        biasUnits = app.unitDecibels,
        initialBias = 0.95
    }
    controls.feedback:setTextBelow(-35.9, "-inf dB")

    controls.tone = GainBias {
        button = "tone",
        description = "Tone",
        branch = branches.tone,
        gainbias = objects.tone,
        range = objects.toneRange,
        biasMap = Encoder.getMap("[-1,1]")
    }

    controls.mod = GainBias {
        button = "mod",
        description = "Modulation",
        branch = branches.modulation,
        gainbias = objects.modulation,
        range = objects.modulation,
        biasMap = Encoder.getMap("[0,1]"),
        initialBias = 0.02
    }

    controls.level = GainBias {
        button = "level",
        description = "FDN Input Level",
        branch = branches.levelAdapter,
        gainbias = objects.levelAdapter,
        range = objects.levelAdapter,
        biasMap = Encoder.getMap("unit"),
        initialBias = 0.8
    }

    return controls, views
end

function FDN:onRemove()
    self.objects.delay1:deallocate()
    self.objects.delay2:deallocate()
    self.objects.delay3:deallocate()
    self.objects.delay4:deallocate()
    Unit.onRemove(self)
end

return FDN
