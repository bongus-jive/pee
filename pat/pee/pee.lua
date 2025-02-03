require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  for k, v in pairs(config.getParameter("scriptConfig", {})) do
    self[k] = v
  end

  animator.playSound("unzip")

  activeItem.setFrontArmFrame(self.armFrames[1])
  activeItem.setBackArmFrame(self.armFrames[2])

  self.ownerId = activeItem.ownerEntityId()

  self.aimOffset = self.projectileOffset[2] - 0.25 -- weapon.lua line 11 moment
  self.pissAngle = 0

  self.soundRepeatTimer = 0
end

function update(dt, fireMode, shiftHeld, moves)
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.aimOffset, activeItem.ownerAimPosition())
  self.pissAngle = approach(self.pissAngle, self.aimAngle * self.aimAngleMultiplier, self.aimAngleApproach)
  
  if self.soundRepeatTimer > 0 then
    self.soundRepeatTimer = math.max(0, self.soundRepeatTimer - dt)
  end

  local standing = not mcontroller.crouching()
  activeItem.setHoldingItem(standing)

  if standing then
    activeItem.setFacingDirection(self.aimDirection)

    local firing = fireMode ~= "none"
    activeItem.setRecoil(not firing)

    if firing and status.overConsumeResource("energy", self.energyUsage * dt) then
      piss()
    end
  end
end

function piss()
  if self.soundRepeatTimer == 0 then
    self.soundRepeatTimer = self.soundRepeatTime
    animator.setSoundPitch("piss", util.randomInRange(self.soundPitchRange))
    animator.playSound("piss")
  end

  local position = vec2.add(mcontroller.position(), activeItem.handPosition(self.projectileOffset))
 
  local aimVector = vec2.rotate({1, 0}, self.pissAngle + sb.nrand(self.inaccuracy, 0))
  aimVector[1] = aimVector[1] * self.aimDirection

  local params = {}
  params.speed = util.interpolateHalfSigmoid(status.resourcePercentage("energy"), self.speedRange)

  world.spawnProjectile(self.projectileType, position, self.ownerId, aimVector, false, params)
end

function approach(current, target, rate)
  local max = math.abs(target - current)
  if max <= rate then return target end
  local fractionalRate = rate / max
  return current + fractionalRate * (target - current)
end

function uninit()
  local zip = config.getParameter("zipProjectile")
  if zip then
    world.spawnProjectile(zip, mcontroller.position(), self.ownerId)
  end
end
