require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  for k, v in pairs(config.getParameter("scriptConfig", {})) do
    self[k] = v
  end

  animator.playSound("unzip")

  activeItem.setRecoil(true)
  activeItem.setFrontArmFrame(self.armFrames[1])
  activeItem.setBackArmFrame(self.armFrames[2])

  self.ownerId = activeItem.ownerEntityId()

  self.aimOffset = self.projectileOffset[2] - 0.25 -- weapon.lua line 11 moment
end

function update(dt, fireMode, shiftHeld, moves)
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.aimOffset, activeItem.ownerAimPosition())

  local standing = not mcontroller.crouching()
  activeItem.setHoldingItem(standing)

  if standing then
    activeItem.setFacingDirection(self.aimDirection)
  end

  if not self.pissThread and fireMode ~= "none" and standing and status.resourcePositive("energy") then
    self.pissThread = coroutine.create(pissing)
  end

  if self.pissThread then
    if coroutine.status(self.pissThread) ~= "dead" then
      local status, result = coroutine.resume(self.pissThread, dt, fireMode)
      if not status then error(result) end
    else
      self.pissThread = nil
    end
  end
end

function pissing(dt, fireMode)
  activeItem.setRecoil(false)

  local soundRepeatTimer = 0
  local startWiggleTimer = self.startInaccuracyTime
  local pissAngle = self.aimAngle * self.aimAngleMultiplier

  while fireMode ~= "none" and not mcontroller.crouching() and status.overConsumeResource("energy", self.energyUsage * dt) do
    if soundRepeatTimer > 0 then
      soundRepeatTimer = soundRepeatTimer - dt
    else
      soundRepeatTimer = self.soundRepeatTime
      animator.setSoundPitch("piss", util.randomInRange(self.soundPitchRange))
      animator.playSound("piss")
    end

    local inaccuracy = self.inaccuracy
    if startWiggleTimer > 0 then
      startWiggleTimer = math.max(0, startWiggleTimer - dt)
      inaccuracy = util.lerp(startWiggleTimer / self.startInaccuracyTime, self.inaccuracy, self.startInaccuracy)
    end
    
    pissAngle = approach(pissAngle, self.aimAngle * self.aimAngleMultiplier, self.aimAngleApproach)
    local angle = pissAngle + sb.nrand(inaccuracy, 0)

    spawnPiss(angle)

    dt, fireMode = coroutine.yield()
  end

  activeItem.setRecoil(true)
end

function spawnPiss(angle)
  local position = vec2.add(mcontroller.position(), activeItem.handPosition(self.projectileOffset))

  local aimVector = {math.cos(angle) * mcontroller.facingDirection(), math.sin(angle)}

  local params = {}
  params.referenceVelocity = {mcontroller.xVelocity(), 0}
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
  if self.zipProjectile then
    world.spawnProjectile(self.zipProjectile, mcontroller.position(), self.ownerId)
  end
end
