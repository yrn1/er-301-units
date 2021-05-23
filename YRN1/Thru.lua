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

local Thru = Class {}
Thru:include(Unit)

function Thru:init(args)
    args.title = "Pass Through"
    args.mnemonic = "Thru"
    args.version = 1
    Unit.init(self, args)
end

function Thru:onLoadGraph(channelCount)
    local vca1 = self:addObject("vca1", app.ConstantGain())
    vca1:hardSet("Gain", 1.0)
    connect(self, "In1", vca1, "In")
    connect(vca1, "Out", self, "Out1")

    if channelCount == 2 then
        local vca2 = self:addObject("vca2", app.ConstantGain())
        vca2:hardSet("Gain", 1.0)
        connect(self, "In2", vca2, "In")
        connect(vca2, "Out", self, "Out2")
    end
end

function Thru:onLoadViews(objects, branches)
    local views = {
        expanded = {},
        collapsed = {}
    }
    local controls = {}
    return controls, views
end

return Thru
