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
local libcore = require "core.libcore"

local YBase = Class {}
YBase:include(Unit)

function YBase:init(args)
  Unit.init(self, args)
end

function YBase:createControl(name, type)
  local control = self:addObject(name, type)
  local controlRange = self:addObject(name .. "Range", app.MinMax())
  connect(control, "Out", controlRange, "In")
  self:addMonoBranch(name, control, "In", control, "Out")
  return control
end

function YBase:createAdapterControl(name)
  local adapter = self:addObject(name, app.ParameterAdapter())
  self:addMonoBranch(name, adapter, "In", adapter, "Out")
  return adapter
end

function YBase:createEq(name, high, mid, low)
  local eq = self:addObject(name, libcore.Equalizer3())
  eq:hardSet("Low Freq", 3000.0)
  eq:hardSet("High Freq", 2000.0)
  connect(high, "Out", eq, "High Gain")
  connect(mid, "Out", eq, "Mid Gain")
  connect(low, "Out", eq, "Low Gain")
  return eq
end

function YBase:createEqHighControl(toneControl)
  local eqRectifyHigh = self:addObject("eqRectifyHigh", libcore.Rectify())
  eqRectifyHigh:setOptionValue("Type", 2)
  local eqHigh = self:addObject("eqHigh", app.GainBias())
  eqHigh:hardSet("Gain", 1.0)
  eqHigh:hardSet("Bias", 1.0)
  connect(toneControl, "Out", eqRectifyHigh, "In")
  connect(eqRectifyHigh, "Out", eqHigh, "In")
  return eqHigh
end

function YBase:createEqMidControl()
  local eqMid = self:addObject("eqMid", app.Constant())
  eqMid:hardSet("Value", 1.0)
  return eqMid
end

function YBase:createEqLowControl(toneControl)
  local eqRectifyLow = self:addObject("eqRectifyLow", libcore.Rectify())
  eqRectifyLow:setOptionValue("Type", 1)
  local eqLow = self:addObject("eqLow", app.GainBias())
  eqLow:hardSet("Gain", -1.0)
  eqLow:hardSet("Bias", 1.0)
  connect(toneControl, "Out", eqRectifyLow, "In")
  connect(eqRectifyLow, "Out", eqLow, "In")
  return eqLow
end

function YBase:constant(name, value)
  local constant = self:addObject(name, app.Constant())
  constant:hardSet("Value", value)
  return constant
end

function YBase:positive(name, sum)
  local negation = self:addObject(name .. "r", app.ConstantGain())
  negation:hardSet("Gain", 1.0)
  connect(negation, "Out", sum, "Right")
  return negation
end

function YBase:negative(name, sum)
  local negation = self:addObject(name .. "r", app.ConstantGain())
  negation:hardSet("Gain", -1.0)
  connect(negation, "Out", sum, "Right")
  return negation
end

return YBase
