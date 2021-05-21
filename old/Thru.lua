local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local Thru = Class{}
Thru:include(Unit)

function Thru:init(args)
  args.title = "Pass Through"
  args.mnemonic = "Thru"
  Unit.init(self,args)
end

function Thru:onLoadGraph(channelCount)
  if channelCount==2 then
    self:loadStereoGraph()
  else
    self:loadMonoGraph()
  end
end

function Thru:loadMonoGraph()
  local vca = self:createObject("ConstantGain","a")
  a:hardSet("Gain", 1.0)

  connect(self,"In1",a,"In")
  connect(a,"Out",self,"Out1")
end

function Thru:loadStereoGraph()
  local a = self:createObject("ConstantGain","a")
  local b = self:createObject("ConstantGain","b")

  a:hardSet("Gain", 1.0)
  b:hardSet("Gain", 1.0)

  connect(self,"In1",a,"In")
  connect(self,"In2",b,"In")

  connect(a,"Out",self,"Out1")
  connect(b,"Out",self,"Out2")
end

function Thru:onLoadViews(objects,branches)
  local views = {
    expanded = {},
    collapsed = {},
  }

  local controls = {}

  return controls, views
end

return Thru
