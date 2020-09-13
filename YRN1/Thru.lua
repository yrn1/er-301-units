-- luacheck: globals app os verboseLevel connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local Thru = Class{}
Thru:include(Unit)

function Thru:init(args)
  args.title = "Thru"
  args.mnemonic = "Th"
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
  local sum = self:createObject("Sum","sum")
  local gainbias = self:createObject("GainBias","gainbias")
  local range = self:createObject("MinMax","range")

  connect(self,"In1",sum,"Left")
  connect(gainbias,"Out",sum,"Right")
  connect(gainbias,"Out",range,"In")
  connect(sum,"Out",self,"Out1")

  self:createMonoBranch("offset",gainbias,"In",gainbias,"Out")
end

function Thru:loadStereoGraph()
  local sum1 = self:createObject("Sum","sum1")
  local gainbias1 = self:createObject("GainBias","gainbias1")
  local range1 = self:createObject("MinMax","range1")

  connect(self,"In1",sum1,"Left")
  connect(gainbias1,"Out",sum1,"Right")
  connect(gainbias1,"Out",range1,"In")
  connect(sum1,"Out",self,"Out1")

  self:createMonoBranch("offsetL",gainbias1,"In",gainbias1,"Out")

  local sum2 = self:createObject("Sum","sum2")
  local gainbias2 = self:createObject("GainBias","gainbias2")
  local range2 = self:createObject("MinMax","range2")

  connect(self,"In2",sum2,"Left")
  connect(gainbias2,"Out",sum2,"Right")
  connect(gainbias2,"Out",range2,"In")
  connect(sum2,"Out",self,"Out2")

  self:createMonoBranch("offsetR",gainbias2,"In",gainbias2,"Out")
end

function Thru:onLoadViews(objects,branches)
  local views = {
    collapsed = {},
  }
  local controls = {}

  if self.channelCount == 2 then

    controls.leftOffset = GainBias {
      button = "left",
      description = "Left Offset",
      branch = branches.offsetL,
      gainbias = objects.gainbias1,
      range = objects.range1,
      initialBias = 0.0,
    }

    controls.rightOffset = GainBias {
      button = "right",
      description = "Right Offset",
      branch = branches.offsetR,
      gainbias = objects.gainbias2,
      range = objects.range2,
      initialBias = 0.0,
    }

    views.expanded = {"leftOffset","rightOffset"}
  else

    controls.offset = GainBias {
      button = "offset",
      description = "Offset",
      branch = branches.offset,
      gainbias = objects.gainbias,
      range = objects.range,
      initialBias = 0.0,
    }

    views.expanded = {"offset"}
  end

  return controls, views
end

function Thru:deserialize(t)
  Unit.deserialize(self,t)
  if self:getPresetVersion(t) < 1 then
    -- handle legacy preset (<v0.3.0)
    local Serialization = require "Persist.Serialization"
    local offset = Serialization.get("objects/offset/params/Offset",t)
    if self.channelCount==1 then
      if offset then
        app.log("%s:deserialize:legacy preset detected:setting offset to %s",self,offset)
        self.objects.gainbias:hardSet("Bias", offset)
      end
    elseif self.channelCount==2 then
      local offset1 = Serialization.get("objects/offset1/params/Offset",t)
      if offset1 then
        app.log("%s:deserialize:legacy preset detected:setting offset1 to %s",self,offset1)
        self.objects.gainbias1:hardSet("Bias", offset1)
      end
      local offset2 = Serialization.get("objects/offset2/params/Offset",t)
      if offset2 then
        app.log("%s:deserialize:legacy preset detected:setting offset2 to %s",self,offset2)
        self.objects.gainbias2:hardSet("Bias", offset2)
      end
    end
  end
end

return Thru
