local Class = require "Base.Class"
local Source = require "Source"

local PrivateSource = Class {}
PrivateSource:include(Source)

function PrivateSource:init(channel, outlet)
  Source.init(self, "private")
  self:setClassName("filterdelays.PrivateSource")
  self.outlet = outlet
  self.channel = channel -- if mono, might be nil
end

function PrivateSource:getOutlet()
  return self.outlet
end

function PrivateSource:getDisplayName()
  return "Effect Input"
end

function PrivateSource:serialize()
  return {}
end

return PrivateSource
