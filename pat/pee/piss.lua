require "/scripts/util.lua"

Piss = {}
setmetatable(Piss, extend(WeaponAbility))

function Piss:update(dt, fireMode, shiftHeld)
  self.dt, self.fireMode, self.shiftHeld = dt, fireMode, shiftHeld

  if not self.weapon.currentState and fireMode == self.abilitySlot and self:hasResource() then
    self:setState(self.piss)
  end
end

function Piss:piss()
  coroutine.yield()

  local soundRepeatTimer = 0
  local wiggleTimer = self.wiggleTime

  while self.fireMode == self.abilitySlot and self:consumeResource() do
    if soundRepeatTimer > 0 then
      soundRepeatTimer = soundRepeatTimer - self.dt
    else
      soundRepeatTimer = self.soundRepeatTime
      animator.setSoundPitch(self.soundName, util.randomInRange(self.soundPitchRange))
      animator.playSound(self.soundName)
    end

    local inaccuracy = self.inaccuracy
    if wiggleTimer > 0 then
      wiggleTimer = math.max(0, wiggleTimer - self.dt)
      inaccuracy = util.lerp(wiggleTimer / self.wiggleTime, inaccuracy, self.wiggleInaccuracy)
    end
    local angle = self.weapon.aimAngle + sb.nrand(inaccuracy or 0, 0)

    world.spawnProjectile(self.projectileType, self.weapon.projectilePosition, self.weapon.ownerId, self:aimVector(angle), false, self:projectileParameters())

    if self.resourceAdd then
      self:addResource()
    end

    coroutine.yield()
  end
end

function Piss:projectileParameters()
  local params = {}
  params.speed = self:projectileSpeed()
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.referenceVelocity = {mcontroller.xVelocity(), 0}
  return params
end

function Piss:projectileSpeed()
  if not self.speedRange then return end
  if not self.resourceUsage then return self.speedRange[2] end

  local percent = status.resourcePercentage(self.resourceUsage[1])
  return util.interpolateHalfSigmoid(percent, self.speedRange)
end

function Piss:aimVector(angle)
  return {math.cos(angle) * mcontroller.facingDirection(), math.sin(angle)}
end

function Piss:hasResource()
  if not self.resourceUsage then return true end
  return status.resourcePositive(self.resourceUsage[1]) and not status.resourceLocked(self.resourceUsage[1])
end

function Piss:consumeResource()
  if not self.resourceUsage then return true end
  return status.overConsumeResource(self.resourceUsage[1], self.resourceUsage[2] * self.dt)
end

function Piss:addResource()
  if self.resourceAdd[3] then
    status.modifyResourcePercentage(self.resourceAdd[1], self.resourceAdd[2] * self.dt)
    return
  end
  status.modifyResource(self.resourceAdd[1], self.resourceAdd[2] * self.dt)
end

function Piss:damagePerShot()
  return self.baseDps * self.dt
end
