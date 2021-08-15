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
-- Takes 9-10% CPU in stereo
local YBase = require "filterdelays.YBase"
local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local libcore = require "core.libcore"
local Pitch = require "Unit.ViewControl.Pitch"
local Gate = require "Unit.ViewControl.Gate"
local GainBias = require "Unit.ViewControl.GainBias"
local Utils = require "Utils"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"

local TunedFilterDelay = Class {}
TunedFilterDelay:include(YBase)

function TunedFilterDelay:init(args)
  args.title = "Tuned Filter Delay"
  args.mnemonic = "TFD"
  args.version = 1
  YBase.init(self, args)
end

function TunedFilterDelay:onLoadGraph(channelCount)
  -- Stereo / General
  local tune = self:createControl("tune", app.ConstantOffset())
  local f0 = self:createAdapterControl("f0")
  local exp = self:addObject("exp", libcore.VoltPerOctave())
  local frequency = self:addObject("frequency", app.ConstantGain())
  local hertzToSeconds = self:addObject("hertzToSeconds", libcore.RationalMultiply())
  local one = self:addObject("One", app.Constant())
  one:hardSet("Value", 1.0)
  local frameOffset = self:addObject("frameOffset", app.ConstantOffset())
  frameOffset:hardSet("Offset", 0 - ((app.globalConfig.frameLength + 4) / app.globalConfig.sampleRate))
  local clippedDelayTime = self:addObject("clippedDelayTime", libcore.Clipper(0.00001, 2))
  tie(frequency, "Gain", f0, "Out")
  connect(tune, "Out", exp, "In")
  connect(exp, "Out", frequency, "In")
  connect(frequency, "Out", self, "Out1")
  connect(one, "Out", hertzToSeconds, "In")
  connect(one, "Out", hertzToSeconds, "Numerator")
  connect(frequency, "Out", hertzToSeconds, "Divisor")
  connect(hertzToSeconds, "Out", frameOffset, "In")
  connect(frameOffset, "Out", clippedDelayTime, "In")

  local xfade = self:addObject("xfade", app.StereoCrossFade())
  local fader = self:createControl("fader", app.GainBias())
  connect(fader, "Out", xfade, "Fade")

  local feedbackGainAdapter = self:createAdapterControl("feedbackGainAdapter")

  local tone = self:createControl("tone", app.GainBias())
  local eqHigh = self:createEqHighControl(tone)
  local eqMid = self:createEqMidControl()
  local eqLow = self:createEqLowControl(tone)

  -- Left
  local delayL = self:addObject("delayL", libcore.DopplerDelay(4))
  local feedbackMixL = self:addObject("feedbackMixL", app.Sum())
  local feedbackGainL = self:addObject("feedbackGainL", app.ConstantGain())
  feedbackGainL:setClampInDecibels(-35.9)
  tie(feedbackGainL, "Gain", feedbackGainAdapter, "Out")

  local eqL = self:createEq("eqL", eqHigh, eqMid, eqLow)

  connect(clippedDelayTime, "Out", delayL, "Delay")

  connect(self, "In1", xfade, "Left B")
  connect(self, "In1", feedbackMixL, "Left")
  connect(feedbackMixL, "Out", eqL, "In")
  connect(eqL, "Out", delayL, "In")
  connect(delayL, "Out", feedbackGainL, "In")
  connect(delayL, "Out", xfade, "Left A")

  connect(feedbackGainL, "Out", feedbackMixL, "Right")
  connect(xfade, "Left Out", self, "Out1")

  -- Right
  if channelCount == 2 then
    local delayR = self:addObject("delayR", libcore.DopplerDelay(4))
    local feedbackMixR = self:addObject("feedbackMixR", app.Sum())
    local feedbackGainR = self:addObject("feedbackGainR", app.ConstantGain())
    feedbackGainR:setClampInDecibels(-35.9)
    tie(feedbackGainR, "Gain", feedbackGainAdapter, "Out")
  
    local eqR = self:createEq("eqR", eqHigh, eqMid, eqLow)
  
    connect(clippedDelayTime, "Out", delayR, "Delay")

    connect(self, "In2", xfade, "Right B")
    connect(self, "In2", feedbackMixR, "Left")
    connect(feedbackMixR, "Out", eqR, "In")
    connect(eqR, "Out", delayR, "In")
    connect(delayR, "Out", feedbackGainR, "In")
    connect(delayR, "Out", xfade, "Right A")
  
    connect(feedbackGainR, "Out", feedbackMixR, "Right")
    connect(xfade, "Right Out", self, "Out2")
    end
end

local function freqMap(from, to, F0, step)
  local n = 0
  for x = from, to, step do n = n + 1 end
  local map = app.LUTDialMap(n)
  for x = from, to, step do map:add((2 ^ x) * F0) end
  return map
end

local function toneMap(min, max, superCoarse, coarse, fine, superFine)
  local map = app.LinearDialMap(min, max)
  map:setSteps(superCoarse, coarse, fine, superFine)
  return map
end

function TunedFilterDelay:onLoadViews(objects, branches)
  local controls = {}
  local views = {collapsed = {}}

  views.expanded = {"tune", "freq", "tone", "feedback", "wet"}

  controls.tune = Pitch {
    button = "V/oct",
    branch = branches.tune,
    description = "V/oct",
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.freq = GainBias {
    button = "f0",
    description = "Fundamental",
    branch = branches.f0,
    gainbias = objects.f0,
    range = objects.f0,
    biasMap = freqMap(-3, 3, 27.5, 1.0 / 12),
    biasUnits = app.unitHertz,
    initialBias = 27.5,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }

  controls.tone = GainBias {
    button = "tone",
    description = "Tone",
    branch = branches.tone,
    gainbias = objects.tone,
    initialBias = -0.05,
    range = objects.toneRange,
    biasMap = toneMap(-0.2, 0.2, 0.1, 0.01, 0.001, 0.0001)
  }

  controls.feedback = GainBias {
    button = "fdbk",
    description = "Feedback",
    branch = branches.feedbackGainAdapter,
    gainbias = objects.feedbackGainAdapter,
    initialBias = 0.99,
    range = objects.feedbackGainAdapter,
    biasMap = Encoder.getMap("feedback"),
    biasUnits = app.unitDecibels
  }
  controls.feedback:setTextBelow(-35.9, "-inf dB")

  controls.wet = GainBias {
    button = "wet",
    branch = branches.fader,
    description = "Wet/Dry",
    gainbias = objects.fader,
    initialBias = 0.5,
    range = objects.faderRange,
    biasMap = Encoder.getMap("unit")
  }

  return controls, views
end

function TunedFilterDelay:onRemove()
  self.objects.delayL:deallocate()
  if channelCount == 2 then
    self.object.delayR:deallocate()
  end
  Unit.onRemove(self)
end

return TunedFilterDelay
