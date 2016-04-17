"use strict"

{Phaser} = window

arenaBounds = { left: 8, right: 592, top: 8, bottom: 592 }
arenaWidth = arenaBounds.right - arenaBounds.left
arenaHeight = arenaBounds.bottom - arenaBounds.top
bulletSpeed = 600 / 60
chargerColor = 0xe36912
chargerDiameter = 35
chargerInertia = 0.98
chargerSpawnDistance = 350
chargerSpeed = 450/60
circleInertia = 0.85
circleSpeed = 200 / 60
circleDiameter = 30
coolingRecovery = 35  # % of energy needed before cooldown expires
deathRayColor = 0xff0000
deathRayDamage = 8
deathRaySpeed = 450 / 60
drifterDiameter = 40
drifterSpeed = 250 / 60
drifterColor = 0xed4588
enemyColor = 0xed4588
enemySpawnChance = 0.01
healthColor = 0x83f765
playerColor = 0xffff0b
scrW = 800
scrH = 600
shieldDiameter = 50
straferColor = 0xd654a0
straferDiameter = 25
straferFireChance = 0.5 / 60
straferMinDistance = 250
straferMaxDistance = 300
straferSpeed = 150 / 60
tau = 2 * Math.PI
triangleAccel = 15 / 60
triangleMaxSpeed = 600 / 60
triangleTurnRate = (tau/2) / 60
waveDelay = 7000
waveSpawnDelay = 250
weaponColor = 0x22ddff

barsLeft = 620
barsRight = 780
barsThickness = 4
healthBarY = 20
energyBarsTop = 40
energyBarsSpacing = 20

bullets = null
cursors = null
deathRays = null
enemies = null
game = null
graphics = null
keys = null
particles = null
player = null
weapons = null

window.onload = ->
  game = new Phaser.Game scrW, scrH, Phaser.AUTO, ''
  game.state.add 'play', {
    preload, create, render, shutDown, update
  }
  game.state.add 'title', titleState
  game.state.start 'play'
  return

titleState =
  preload: ->
  create: ->
    game.add.text 80, 80, "xXShapeShooterXx",
                  {font: "50px Arial", fill: "#ffffff"}
    game.add.text 80, scrH-80-50, "Click to start",
                  {font: "50px Arial", fill: "#ffffff"}
    game.input.onTap.add -> game.state.start 'play'
    return

  update: ->
  render: ->

preload = ->
  return

create = ->

  bullets = []
  deathRays = []
  enemies = []
  particles = []
  weapons = {}

  cursors = game.input.keyboard.createCursorKeys()
  keys = game.input.keyboard.addKeys
    left: Phaser.KeyCode.A
    right: Phaser.KeyCode.S
    up: Phaser.KeyCode.W
    down: Phaser.KeyCode.R
    1: Phaser.KeyCode.ONE
    2: Phaser.KeyCode.TWO
    3: Phaser.KeyCode.THREE
    4: Phaser.KeyCode.FOUR
  game.input.keyboard.addKeyCapture [
    Phaser.KeyCode.A
    Phaser.KeyCode.R
    Phaser.KeyCode.S
    Phaser.KeyCode.W
    Phaser.KeyCode.ONE
    Phaser.KeyCode.TWO
    Phaser.KeyCode.THREE
    Phaser.KeyCode.FOUR
    Phaser.KeyCode.UP
    Phaser.KeyCode.DOWN
    Phaser.KeyCode.LEFT
    Phaser.KeyCode.RIGHT
  ]
  game.input.mouse.capture = true

  game.stage.backgroundColor = 'rgb(12, 24, 32)'

  graphics = game.add.graphics 0, 0

  player = {
    mode: 'circle'
    alive: true
    x: 500
    y: 500
    vx: 0
    vy: 0
    health: 100
    radius: circleDiameter / 2
    angle: 0  # clockwise from top
  }

  createWeapons()
  startRandomWave()

  return

shutDown = ->
  game.time.events.removeAll()
  return

update = ->
  processEnemyMovement()
  processEnemyFire()
  if player.alive
    processWeaponFire()
    processWeaponEnergy()
    processShapeshiftKeys()
    processPlayerMovement()
  processParticles()
  processBulletMovement()
  processDeathRayMovement()

  collideEnemiesAndShield()
  collideDeathRaysAndShield()
  collideBulletsAndEnemies()
  if player.alive
    collideDeathRaysAndPlayer()
    collideEnemiesAndPlayer()

  draw()
  return

render = ->
  # game.debug.text "#{weapons.circle.energy}", 0, 500
  return

startRandomWave = ->
  num = game.rnd.frac()
  if num < 0.4
     startWave [{count: 10, type: 'drifter'}]
   else if num < 0.7
     startWave [{count: 3, type: 'strafer'},
                {count: 3, type: 'drifter'}]
   else
     startWave [{count: 12, type: 'charger', interval: 250/12}]

  game.time.events.add waveDelay, startRandomWave
  return

startWave = (spec) ->
  time = 0
  mkSpawner = (t) ->
    -> spawnEnemy t
  for {count, type, interval} in spec
    for i in [0...count]
      game.time.events.add time, mkSpawner(type)
      time += interval ? waveSpawnDelay
  return

createWeapons = ->
  for name in ['circle', 'triangle']
    weapon = {
      active: false
      energy: 100
      drain: 50 / 60
      radius: shieldDiameter / 2
      recharge: 20 / 60
      cooling: false
    }
    weapons[name] = weapon
  weapons.triangle.recharge = 10 / 60
  weapons.triangle.drain = 80 / 60
  return

draw = ->
  graphics.clear()
  drawArenaBounds()
  drawPlayer()
  drawEnemies()
  drawShield()
  drawBullets()
  drawDeathRays()
  drawHealthBar()
  drawEnergyLevels()
  drawParticles()
  return

toScreen = (x, y) ->
  x: x * arenaWidth * 0.001 + arenaBounds.left
  y: y * arenaHeight * 0.001 + arenaBounds.top

distToScreen = (d) -> d * arenaWidth * 0.001

drawArenaBounds = ->
  graphics.lineStyle 2, 0xffffff, 1.0
  { left, right, top, bottom } = arenaBounds
  width = right - left
  height = bottom - top
  graphics.drawRect left, top, width, height
  return

drawParticles = ->
  for p in particles
    switch p.type
      when 'point' then drawPointParticle p
      when 'poly' then drawPolyParticle p
  return

drawPointParticle = (p) ->
  graphics.lineStyle 0
  graphics.beginFill p.color, p.opacity
  {x, y} = toScreen p.x, p.y
  graphics.drawRect x, y, 2, 2
  graphics.endFill()
  return

drawPolyParticle = (p) ->
  graphics.lineStyle 0
  [sx, sy] = p.shape[p.shape.length-1]
  {x, y} = toScreen sx+p.x, sy+p.y
  graphics.moveTo x, y
  graphics.beginFill p.color, p.opacity
  for [sx, sy] in p.shape
    {x, y} = toScreen sx+p.x, sy+p.y
    graphics.lineTo x, y
  graphics.endFill()
  return

drawPlayer = ->
  return unless player.alive
  switch player.mode
    when 'circle' then drawPlayerCircle()
    when 'triangle' then drawPlayerTriangle()
    else throw new Error "unrecognised mode: #{player.mode}"
  return

drawPlayerCircle = ->
  graphics.lineStyle 0
  graphics.beginFill playerColor, 1.0
  {x, y} = toScreen player.x, player.y
  graphics.drawCircle x, y, distToScreen(circleDiameter)
  graphics.endFill()
  return

drawPlayerTriangle = ->
  radius = distToScreen(circleDiameter/2)
  points = []
  for i in [0..2]
    angle = i * tau / 3
    # no idea why *2 here :/
    x = radius * 2 * Math.sin angle
    y = - radius * 2 * Math.cos angle
    points.push [x, y]

  # rotate to player angle
  for point in points
    [x, y] = point
    angle = player.angle
    point[0] = x * Math.cos(angle) - y * Math.sin(angle)
    point[1] = y * Math.cos(angle) + x * Math.sin(angle)

  # translate to player pos
  for point in points
    point[0] += player.x
    point[1] += player.y

  graphics.lineStyle 0
  graphics.beginFill playerColor, 1.0
  {x, y} = toScreen points[2][0], points[2][1]
  graphics.moveTo x, y
  for [x, y] in points
    {x: sx, y: sy} = toScreen x, y
    graphics.lineTo sx, sy
  graphics.endFill()

  return

drawEnemies = ->
  for enemy in enemies
    drawEnemy enemy

drawEnemy = (enemy) ->
  switch enemy.type
    when 'drifter'
      drawDrifter enemy
    when 'strafer'
      drawStrafer enemy
    when 'charger'
      drawCharger enemy
  return

drawDrifter = (drifter) ->
  graphics.lineStyle 0
  graphics.beginFill drifterColor, 1.0
  shape = [[1,1], [0.6, 0],[1,-1],[0, -0.6],
           [-1,-1], [-0.6, 0], [-1, 1], [0, 0.6]]
  for point in shape
    point[0] *= drifter.radius
    point[1] *= drifter.radius
  {x, y} = toScreen shape[7][0]+drifter.x, shape[7][1]+drifter.y
  graphics.moveTo x, y
  for [px, py] in shape
    {x, y} = toScreen px+drifter.x, py+drifter.y
    graphics.lineTo x, y
  graphics.endFill()
  return

drawStrafer = (strafer) ->
  graphics.lineStyle 0
  graphics.beginFill straferColor, 1.0
  {x, y} = toScreen strafer.x, strafer.y
  graphics.drawCircle x, y, distToScreen(straferDiameter)
  graphics.endFill()
  return

drawCharger = (charger) ->
  graphics.lineStyle 0
  graphics.beginFill chargerColor, 1.0
  left = charger.x - charger.radius
  top = charger.y - charger.radius
  {x, y} = toScreen left, top
  width = distToScreen (charger.radius*2)
  graphics.drawRect x, y, width, width
  graphics.endFill()
  return

drawBullets = ->
  graphics.lineStyle 0
  for bullet in bullets
    graphics.beginFill weaponColor, 1.0
    {x, y} = toScreen bullet.x, bullet.y
    graphics.drawRect x, y, 2, 2
    graphics.endFill()
  return

drawDeathRays = ->
  graphics.lineStyle 0
  for deathRay in deathRays
    graphics.beginFill deathRayColor, 1.0
    {x, y} = toScreen deathRay.x, deathRay.y
    graphics.drawRect x, y, 2, 2
    graphics.endFill()
  return

drawShield = ->
  return unless weapons.circle.active
  graphics.lineStyle 2, weaponColor, 0.8
  {x, y} = toScreen player.x, player.y
  graphics.drawCircle x, y, distToScreen(shieldDiameter)
  return

drawHealthBar = ->
  width = barsRight - barsLeft
  graphics.lineStyle barsThickness, enemyColor, 1.0
  graphics.moveTo barsLeft, healthBarY
  graphics.lineTo barsRight, healthBarY

  graphics.lineStyle barsThickness, healthColor, 1.0
  graphics.moveTo barsLeft, healthBarY
  graphics.lineTo barsLeft+(width * player.health / 100), healthBarY
  return

drawEnergyLevels = ->
  width = barsRight - barsLeft
  y = energyBarsTop
  for own name, weapon of weapons
    color = if weapon.cooling then enemyColor else weaponColor
    graphics.lineStyle barsThickness, color, 1.0
    graphics.moveTo barsLeft, y
    graphics.lineTo barsLeft+(weapon.energy*width/100), y
    y += energyBarsSpacing
  return

fire = ->
  switch player.mode
    when 'circle'
      if weapons.circle.energy > 0
        weapons.circle.active = true
    when 'triangle'
      if weapons.triangle.energy > 0
        shootTriangle()
  return

shootTriangle = ->
  bullet = {
    x: player.x
    y: player.y
    angle: player.angle
    speed: bulletSpeed
  }
  bullets.push bullet
  return bullet

playerSaysLeft = -> cursors.left.isDown or keys.left.isDown
playerSaysRight = -> cursors.right.isDown or keys.right.isDown
playerSaysUp = -> cursors.up.isDown or keys.up.isDown
playerSaysDown = -> cursors.down.isDown or keys.down.isDown

processEnemyFire = ->
  for enemy in enemies
    if enemy.type == 'strafer'
      if game.rnd.frac() < straferFireChance
        straferFire enemy
  return

processShapeshiftKeys = ->
  if keys[1].isDown
    shiftToCircle()
  else if keys[2].isDown
    shiftToTriangle()
  return

processPlayerMovement = ->
  switch player.mode
    when 'circle' then processCircleMovement()
    when 'triangle' then processTriangleMovement()
    else throw new Error "unrecognised mode: #{player.mode}"
  return

processCircleMovement = ->
  targetvx = 0
  if playerSaysLeft() then targetvx -= circleSpeed
  if playerSaysRight() then targetvx += circleSpeed
  targetvy = 0
  if playerSaysUp() then targetvy -= circleSpeed
  if playerSaysDown() then targetvy += circleSpeed

  if targetvx != 0 and targetvy != 0
    # divide by root 2 so that total speed is still circleSpeed
    targetvx *= 0.707
    targetvy *= 0.707

  player.vx = circleInertia * player.vx + (1-circleInertia) * targetvx
  player.vy = circleInertia * player.vy + (1-circleInertia) * targetvy

  player.angle = Math.atan2 player.vx, -player.vy

  moveEntityByVel player

  return

processTriangleMovement = ->
  targetrot = 0
  if playerSaysLeft() then targetrot -= triangleTurnRate
  if playerSaysRight() then targetrot += triangleTurnRate
  targetaccel = 0
  if playerSaysUp() then targetaccel += triangleAccel
  if playerSaysDown() then targetaccel -= triangleAccel

  player.angle += targetrot

  normalX = Math.sin player.angle
  normalY = - Math.cos player.angle
  dvx = normalX * targetaccel
  dvy = normalY * targetaccel
  player.vx += dvx
  player.vy += dvy

  # clamp to max speed
  speed = Math.sqrt(player.vx**2 + player.vy**2)
  if speed > triangleMaxSpeed
    player.vx *= triangleMaxSpeed / speed
    player.vy *= triangleMaxSpeed / speed

  moveEntityByVel player

  return

moveEntityByVel = (entity) ->
  # try to move in the direction indicated, bumping into walls
  # if a wall is bumped return false, else true
  entity.x += entity.vx
  entity.y += entity.vy

  bumped = false
  if entity.x - circleDiameter*0.5 < 0
    entity.x = circleDiameter*0.5
    entity.vx = 0
    bumped = true
  if entity.x + circleDiameter*0.5 > 1000
    entity.x = 1000 - circleDiameter*0.5
    entity.vx = 0
    bumped = true
  if entity.y - circleDiameter*0.5 < 0
    entity.y = circleDiameter*0.5
    entity.vy = 0
    bumped = true
  if entity.y + circleDiameter*0.5 > 1000
    entity.y = 1000 - circleDiameter*0.5
    entity.vy = 0
    bumped = true

  return not bumped

processWeaponFire = ->
  unless player.mode of weapons
    throw new Error "unknown mode: #{player.mode}"
  weapon = weapons[player.mode]
  if game.input.activePointer.leftButton.isDown and not weapon.cooling
    if weapon.energy >= 0
      weapon.active = true
  else
    weapon.active = false
  if weapon.active
    fire()
  return

processWeaponEnergy = ->
  for own name, weapon of weapons
    if weapon.active
      weapon.energy -= weapon.drain
      if weapon.energy < 0
        weapon.energy = 0
        weapon.cooling = true
    else
      weapon.energy += weapon.recharge
      if weapon.energy > 100
        weapon.energy = 100
      if weapon.energy >= coolingRecovery
        weapon.cooling = false
  return

processEnemyMovement = ->
  for enemy in enemies
    switch enemy.type
      when 'drifter'
        processDrifterMovement enemy
      when 'strafer'
        processStraferMovement enemy
      when 'charger'
        processChargerMovement enemy
  return

processDrifterMovement = (drifter) ->
  drifter.x += drifter.vx
  drifter.y += drifter.vy

  if drifter.x - drifterDiameter*0.5 < 0
    drifter.x = drifterDiameter*0.5
    drifter.vx *= -1
  if drifter.x + drifterDiameter*0.5 > 1000
    drifter.x = 1000 - drifterDiameter*0.5
    drifter.vx *= -1
  if drifter.y - drifterDiameter*0.5 < 0
    drifter.y = drifterDiameter*0.5
    drifter.vy *= -1
  if drifter.y + drifterDiameter*0.5 > 1000
    drifter.y = 1000 - drifterDiameter*0.5
    drifter.vy *= -1

  return

processStraferMovement = (strafer) ->
  dist = Math.sqrt((strafer.x-player.x)**2 + (strafer.y-player.y)**2)
  if dist < straferMinDistance
    runFromPlayer strafer
  else if dist > straferMaxDistance
    moveToPlayer strafer
  else
    circlePlayer strafer
  return

processChargerMovement = (charger) ->
  targetvx = charger.speed * Math.sin charger.angle
  targetvy = charger.speed * Math.cos charger.angle
  charger.vx = chargerInertia * charger.vx + (1-chargerInertia) * targetvx
  charger.vy = chargerInertia * charger.vy + (1-chargerInertia) * targetvy
  bumped = not moveEntityByVel charger
  if bumped
    charger.angle += tau/2
  return

runFromPlayer = (enemy) ->
  angle = Math.atan2 enemy.x-player.x, enemy.y-player.y
  enemy.vx = enemy.speed * Math.sin angle
  enemy.vy = enemy.speed * Math.cos angle
  moveEntityByVel enemy
  return

moveToPlayer = (enemy) ->
  angle = Math.atan2 player.x-enemy.x, player.y-enemy.y
  enemy.vx = enemy.speed * Math.sin angle
  enemy.vy = enemy.speed * Math.cos angle
  moveEntityByVel enemy
  return

circlePlayer = (enemy) ->
  angleToPlayer = Math.atan2 player.x-enemy.x, player.y-enemy.y
  success = false
  angle = angleToPlayer + enemy.strafeDir * tau/4
  enemy.vx = enemy.speed * Math.sin angle
  enemy.vy = enemy.speed * Math.cos angle
  success = moveEntityByVel enemy
  if not success
    enemy.strafeDir *= -1
  return

straferFire = (strafer) ->
  angleToPlayer = Math.atan2 player.x-strafer.x, strafer.y-player.y
  deathRay = {
    x: strafer.x
    y: strafer.y
    angle: angleToPlayer
    speed: deathRaySpeed
  }
  deathRays.push deathRay
  return

addPlayerThrust = ->
  speed = Math.sqrt(player.vx**2 + player.vy**2)
  chance = 0.1 + speed * (200 / 60) * 0.8
  chance = game.math.clamp chance, 0, 1
  if game.rnd.frac() < chance
    xoff = - circleDiameter * 0.25 * Math.sin player.angle
    yoff = circleDiameter * 0.25 * Math.cos player.angle
    particle = {
      x: player.x + xoff
      y: player.y + yoff
      vx: xoff + game.rnd.realInRange -1, 1
      vy: yoff + game.rnd.realInRange -1, 1
    }
    thrustParticles.push particle
    game.time.events.add 200, ->
      if thrustParticles.length > 0
        thrustParticles.splice thrustParticles.length-1, 1
  return

processParticles = ->
  now = Date.now()
  done = {}
  for p, i in particles
    if p.expirationTime < now
      done[i] = true
      continue
    p.x += p.vx
    p.y += p.vy
  before = particles.length
  removeSetFromArray done, particles
  return

processBulletMovement = ->
  processProjectileMovement bullets
  return

processDeathRayMovement = ->
  processProjectileMovement deathRays
  return

processProjectileMovement = (ary) ->
  spent = []
  for proj, i in ary
    proj.x += proj.speed * Math.sin proj.angle
    proj.y -= proj.speed * Math.cos proj.angle
    if (proj.x <= 0 or proj.x >= 1000 or
        proj.y <= 0 or proj.y >= 1000)
      spent.push i
  # remove spent
  i = spent.length
  while i > 0
    i -= 1
    ary.splice spent[i], 1
  return

collideEnemiesAndShield = ->
  enemiesToKill = {}
  for enemy, i in enemies
    if weapons.circle.active and enemyTouchingShield enemy
      enemiesToKill[i] = true
      explode enemy, player, enemy.color
  removeSetFromArray enemiesToKill, enemies
  return

collideEnemiesAndPlayer = ->
  enemiesToKill = {}
  for enemy, i in enemies
    if enemyTouchingPlayer enemy
      enemiesToKill[i] = true
      explode enemy, player, enemy.color
      damagePlayer enemy.contactDamage ? 20, enemy
  removeSetFromArray enemiesToKill, enemies
  return

collideDeathRaysAndShield = ->
  deathRaysToKill = {}
  testShape = new Phaser.Circle player.x, player.y, weapons.circle.radius * 2
  for deathRay, i in deathRays
    if testShape.contains deathRay.x, deathRay.y
      deathRaysToKill[i] = true
  removeSetFromArray deathRaysToKill, deathRays
  return

collideDeathRaysAndPlayer = ->
  deathRaysToKill = {}
  testShape = new Phaser.Circle player.x, player.y, player.radius * 2
  for deathRay, i in deathRays
    if testShape.contains deathRay.x, deathRay.y
      deathRaysToKill[i] = true
      damagePlayer deathRayDamage, deathRay
  removeSetFromArray deathRaysToKill, deathRays
  return

collideBulletsAndEnemies = ->
  spent = {}
  dead = {}
  for enemy, ei in enemies
    switch enemy.bodytype
      when 'circle'
        testShape = new Phaser.Circle enemy.x, enemy.y, enemy.radius * 2
      when 'square'
        testShape = new Phaser.Rectangle(enemy.x-enemy.radius,
                                         enemy.y-enemy.radius,
                                         enemy.radius*2, enemy.radius*2)
    for bullet, bi in bullets
      if testShape.contains bullet.x, bullet.y
        if bi not in spent
          spent[bi] = true
        if ei not in dead
          dead[ei] = true
          explode enemy, bullet, enemy.color

  removeSetFromArray dead, enemies
  removeSetFromArray spent, bullets

  return

spawnEnemy = (type) ->
  switch type
    when 'drifter'
      spawnDrifter()
    when 'strafer'
      spawnStrafer()
    when 'charger'
      spawnCharger()
  return

spawnDrifter = ->
  enemy = {
    type: 'drifter'
    bodytype: 'circle'
    color: drifterColor
  }
  {x, y} = getEnemySpawnPoint()
  enemy.x = x
  enemy.y = y
  angle = game.rnd.realInRange 0, tau
  enemy.vx = drifterSpeed * Math.cos angle
  enemy.vy = drifterSpeed * Math.sin angle
  enemy.radius = drifterDiameter / 2
  enemy.speed = drifterSpeed
  enemies.push enemy
  return enemy

spawnStrafer = ->
  enemy = {
    type: 'strafer'
    bodytype: 'circle'
    color: straferColor
  }
  {x, y} = getEnemySpawnPoint()
  enemy.x = x
  enemy.y = y
  enemy.radius = straferDiameter / 2
  enemy.speed = straferSpeed
  enemy.strafeDir = 1
  enemies.push enemy
  return enemy

spawnCharger = ->
  enemy = {
    type: 'charger'
    bodytype: 'square'
    color: chargerColor
  }
  {x, y} = getChargerSpawnPoint()
  enemy.x = x
  enemy.y = y
  enemy.vx = 0
  enemy.vy = 0
  enemy.radius = chargerDiameter / 2
  enemy.speed = chargerSpeed
  angleToPlayer = Math.atan2 player.x-enemy.x, player.y-enemy.y
  enemy.angle = angleToPlayer
  enemies.push enemy
  return enemy

getEnemySpawnPoint = ->
  x = null
  until x != null and Math.abs(x-player.x) > 200
    x = game.rnd.between drifterDiameter, 1000-drifterDiameter
  y = null
  until y != null and Math.abs(y-player.y) > 200
    y = game.rnd.between drifterDiameter, 1000-drifterDiameter
  return {x, y}

chargerSpawnAngle = 0

getChargerSpawnPoint = ->
  retries = 10
  ok = false
  while retries > 0 and not ok
    xoff = chargerSpawnDistance * Math.sin chargerSpawnAngle
    yoff = chargerSpawnDistance * Math.cos chargerSpawnAngle
    x = player.x + xoff
    y = player.y + yoff
    chargerSpawnAngle += tau/12
    while chargerSpawnAngle > tau then chargerSpawnAngle -= tau
    if (x > 0 and x < 1000 and y > 0 and y < 1000)
      ok = true
      break
    else
      retries -= 1
      if retries == 0
        return getEnemySpawnPoint()
        break
  return {x, y}

spawnPointParticle = (x, y, ttl, options) ->
  {angle, speed, color, opacity} = options
  if opacity == undefined then opacity = 1
  p = {type: 'point', x, y, color, opacity, expirationTime: Date.now() + ttl}
  p.vx = speed * Math.sin angle
  p.vy = speed * Math.cos angle
  particles.push p
  return p

spawnPolyParticle = (x, y, ttl, options) ->
  {angle, speed, color, shape, opacity} = options
  if opacity == undefined then opacity = 1
  p = {type: 'poly', x, y, color, opacity, shape, expirationTime: Date.now() + ttl}
  p.vx = speed * Math.sin angle
  p.vy = speed * Math.cos angle
  particles.push p
  return p

explode = (victim, source, color, options={}) ->
  duration = options.duration ? 300
  numParticles = options.numParticles ? (victim.radius * 2 * 16 / circleDiameter)
  angleToVictim = Math.atan2 victim.x-source.x, victim.y-source.y
  baseVel = {
    x: 0.8 * source.vx + 0.2 * victim.vx,
    y: 0.8 * source.vy + 0.2 * victim.vy
    }
  baseSpeed = 300 / 60 # Math.sqrt(baseVel.x**2 + baseVel.y**2)
  for i in [0...numParticles]
    x = victim.x + game.rnd.realInRange (- circleDiameter), circleDiameter
    y = victim.y + game.rnd.realInRange (- circleDiameter), circleDiameter
    if source.x == victim.x and source.y == victim.y
      angle = game.rnd.realInRange 0, tau
    else
      angle = angleToVictim + game.rnd.realInRange (-tau/12), tau/12
    speed = baseSpeed * game.rnd.realInRange 0.8, 1.2
    shape = []
    for j in [0...3]
      shape.push [game.rnd.realInRange(-16, 16), game.rnd.realInRange(-16, 16)]
    spawnPolyParticle x, y, duration,
      angle: angle
      speed: speed
      color: color
      opacity: 1.0
      shape: shape
  return

killPlayer = (source) ->
  player.alive = false
  source ?= { x: player.x, y: player.y, vx: 0, vy: 0 }
  explode player, source, playerColor, duration: 1000
  game.time.events.add 3000, -> game.state.start 'title'
  return

damagePlayer = (dmg, source) ->
  player.health -= dmg
  if player.health < 0 then player.health = 0
  explode player, source, playerColor, numParticles: 3
  if player.health <= 0
    killPlayer source
  return

enemyTouchingShield = (enemy) ->
  switch enemy.bodytype
    when 'circle'
      doCirclesIntersect enemy.x, enemy.y, enemy.radius,
                         player.x, player.y, shieldDiameter / 2
    when 'square'
      left = enemy.x - enemy.radius
      right = enemy.x + enemy.radius
      top = enemy.y - enemy.radius
      bottom = enemy.y + enemy.radius
      doesCircleTouchSquare player.x, player.y, shieldDiameter / 2,
                            {left, right, top, bottom}

enemyTouchingPlayer = (enemy) ->
  switch enemy.bodytype
    when 'circle'
      doCirclesIntersect enemy.x, enemy.y, enemy.radius,
                         player.x, player.y, shieldDiameter / 2
    when 'square'
      left = enemy.x - enemy.radius
      right = enemy.x + enemy.radius
      top = enemy.y - enemy.radius
      bottom = enemy.y + enemy.radius
      doesCircleTouchSquare player.x, player.y, circleDiameter / 2,
                            {left, right, top, bottom}

doCirclesIntersect = (x0, y0, r0, x1, y1, r1) ->
  distSq = (x0-x1)**2 + (y0-y1)**2
  return distSq <= (r0+r1)**2

doesCircleTouchSquare = (x, y, r, {left, right, top, bottom}) ->
  # http://stackoverflow.com/questions/21089959/detecting-collision-of-rectangle-with-circle
  half = {x: (right-left)/2, y: (bottom-top)/2}
  center = {x: x - (left+half.x), y: y - (top+half.y)}
  side = {x: Math.abs(center.x) - half.x, y: Math.abs(center.y) - half.y}
  if side.x > r or side.y > r  # outside
    return false
  if side.x < -r or side.y < -r  # inside
    return true
  if side.x < 0 or side.y < 0  # intersects side or corner
    return true
  # circle is near the corner
  return side.x**2 + side.y**2 < r**2

shiftToCircle = ->
  player.mode = 'circle'
  weapons.triangle.active = false
  return

shiftToTriangle = ->
  player.mode = 'triangle'
  weapons.circle.active = false
  return

removeSetFromArray = (set, ary) ->
  i = ary.length
  while i > 0
    i -= 1
    if i of set
      ary.splice i, 1
  return ary
