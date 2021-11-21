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
local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local libcore = require "core.libcore"
local OptionControl = require "Unit.ViewControl.OptionControl"

local MidKnob = Class {}
MidKnob:include(Unit)

function MidKnob:init(args)
  args.title = "Mid Knob"
  args.mnemonic = "MidKnob"
  args.version = 1
  Unit.init(self, args)
end

function MidKnob:onLoadGraph(channelCount)
  local dead = 0.1;
  local scale = self:addObject("scale", app.ConstantGain())
  scale:hardSet("Gain", 4 + (dead * 4))
  local offset = self:addObject("offset", app.ConstantOffset())
  offset:hardSet("Offset", -1 - dead)
  local rectify = self:addObject("rectify", libcore.Rectify())
  local abs = self:addObject("abs", libcore.Rectify())
  abs:setOptionValue("Type", libcore.RECTIFY_FULL)
  local deadzone = self:addObject("deadzone", app.ConstantOffset())
  deadzone:hardSet("Offset", 0 - dead)
  local deadrect = self:addObject("deadrect", libcore.Rectify())
  deadrect:setOptionValue("Type", libcore.RECTIFY_POSITIVEHALF)

  connect(self, "In1", scale, "In")
  connect(scale, "Out", offset, "In")
  connect(offset, "Out", rectify, "In")
  connect(rectify, "Out", abs, "In")
  connect(abs, "Out", deadzone, "In")
  connect(deadzone, "Out", deadrect, "In")

  connect(deadrect, "Out", self, "Out1")
end

function MidKnob:onLoadViews(objects, branches)
  local views = {
    expanded = {
      "type"
    },
    collapsed = {}
  }
  local controls = {}

  controls.type = OptionControl {
    button = "o",
    description = "Type",
    option = objects.rectify:getOption("Type"),
    choices = {
      "right",
      "left",
      "both"
    },
    muteOnChange = true
  }

  return controls, views
end

return MidKnob
