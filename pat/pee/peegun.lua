require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

function init()
  local cfg = config.getParameter("scriptConfig")
  local species = (player and player.species()) or (npc and npc.species())
  local override = cfg.speciesOverrides[species]
  if override then cfg = sb.jsonMerge(cfg, override) end

  setmetatable(self, {__index = cfg})

  local function tableToRadians(t)
    t[1], t[2] = math.rad(t[1]), math.rad(t[2])
  end
  tableToRadians(self.aimRange)
  tableToRadians(self.crouchAimRange)

  animator.playSound("unzip")

  self.weapon = Weapon:new()
  self.weapon.ownerId = activeItem.ownerEntityId()
  
  local function addAbility(slot, config)
    if not config then return end
    local ability = getAbility(slot, config)
    self.weapon:addAbility(ability)
  end

  addAbility("primary", config.getParameter("primaryAbility"))
  addAbility("alt", config.getParameter("altAbility"))

  self.weapon:init()
end

function update(dt, fireMode, shiftHeld)
  setArmFrames(mcontroller.crouching() and self.crouchArmFrames or self.armFrames)

  updateAim()

  self.weapon:update(dt, fireMode, shiftHeld)

  activeItem.setRecoil(not self.weapon.currentAbility)
end

function updateAim()
  local ownerPos = mcontroller.position()
  local crouching = mcontroller.crouching()

  local handPos = activeItem.handPosition(crouching and self.crouchProjectileOffset or self.projectileOffset)
  local projectilePos = vec2.add(handPos, ownerPos)

  local toTarget = world.distance(activeItem.ownerAimPosition(), {ownerPos[1], projectilePos[2]})
  local direction = util.toDirection(toTarget[1])
  toTarget[1] = math.abs(toTarget[1])

  local angle = vec2.angle(toTarget)
  if angle > math.pi then
    angle = angle - (math.pi * 2)
  end
  
  local range = crouching and self.crouchAimRange or self.aimRange
  if angle < range[1] then angle = range[1] end
  if angle > range[2] then angle = range[2] end
  angle = util.lerp(self.aimApproach, self.weapon.aimAngle, angle)

  activeItem.setFacingDirection(direction)

  self.weapon.aimAngle = angle
  self.weapon.aimDirection = direction
  self.weapon.muzzleOffset = handPos
  self.weapon.projectilePosition = projectilePos
end

function setArmFrames(frames)
  activeItem.setFrontArmFrame(frames[1])
  activeItem.setBackArmFrame(frames[2])
end

function uninit()
  self.weapon:uninit()
  
  if self.zipProjectile and status.resourcePositive("health") then
    world.spawnProjectile(self.zipProjectile, mcontroller.position(), self.weapon.ownerId)
  end
end

WeaponAbility.init = WeaponAbility.init or function() end
WeaponAbility.uninit = WeaponAbility.uninit or function() end
