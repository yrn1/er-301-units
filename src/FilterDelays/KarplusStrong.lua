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
-- TODO cpu
-- app.globalConfig.sampleRate
-- app.globalConfig.frameLength
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

local KarplusStrong = Class {}
KarplusStrong:include(YBase)

function KarplusStrong:init(args)
  args.title = "Karplus Strong"
  args.mnemonic = "KPS"
  args.version = 1
  YBase.init(self, args)
end

function KarplusStrong:onLoadGraph(channelCount)
  local delay = self:addObject("delay", libcore.DopplerDelay(2))

  local tune = self:createControl("tune", app.ConstantOffset())
  local f0 = self:createAdapterControl("f0")
  local exp = self:addObject("exp", libcore.VoltPerOctave())
  local frequency = self:addObject("frequency", app.ConstantGain())
  local hertzToSeconds = self:addObject("hertzToSeconds", libcore.RationalMultiply())
  local one = self:constant("One", 1.0)
  local frameOffset = self:addObject("frameOffset", app.ConstantOffset())
  frameOffset:hardSet("Offset", 0 - (app.globalConfig.frameLength / app.globalConfig.sampleRate))
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
  connect(clippedDelayTime, "Out", delay, "Delay")

  local xfade = self:addObject("xfade", app.CrossFade())
  local fader = self:createControl("fader", app.GainBias())
  connect(fader, "Out", xfade, "Fade")

  local feedbackGainAdapter = self:createAdapterControl("feedbackGainAdapter")

  local feedbackMix = self:addObject("feedbackMix", app.Sum())
  local feedbackGain = self:addObject("feedbackGain", app.ConstantGain())
  feedbackGain:setClampInDecibels(-35.9)

  tie(feedbackGain, "Gain", feedbackGainAdapter, "Out")

  connect(self, "In1", xfade, "B")
  connect(self, "In1", feedbackMix, "Left")
  connect(feedbackMix, "Out", delay, "In")
  connect(delay, "Out", feedbackGain, "In")
  connect(delay, "Out", xfade, "A")

  connect(feedbackGain, "Out", feedbackMix, "Right")
  connect(xfade, "Out", self, "Out1")
  if channelCount == 2 then
    connect(xfade, "Out", self, "Out2")
  end
end

function KarplusStrong:onLoadViews(objects, branches)
  local controls = {}
  local views = {collapsed = {}}

  views.expanded = {"tune", "freq", "feedback", "wet"}

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
    biasMap = Encoder.getMap("oscFreq"),
    biasUnits = app.unitHertz,
    initialBias = 27.5,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }

  controls.feedback = GainBias {
    button = "fdbk",
    description = "Feedback",
    branch = branches.feedbackGainAdapter,
    gainbias = objects.feedbackGainAdapter,
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
    range = objects.faderRange,
    biasMap = Encoder.getMap("unit")
  }

  return controls, views
end

function KarplusStrong:onRemove()
  self.objects.delay:deallocate()
  Unit.onRemove(self)
end

return KarplusStrong
