{Phaser} = window

arenaBounds = { left: 8, right: 592, top: 8, bottom: 592 }
arenaWidth = arenaBounds.right - arenaBounds.left
arenaHeight = arenaBounds.bottom - arenaBounds.top
bulletSpeed = 600 / 60
circleInertia = 0.85
circleSpeed = 200 / 60
circleDiameter = 30
coolingRecovery = 35  # % of energy needed before cooldown expires
drifterDiameter = 40
drifterSpeed = 250 / 60
enemyColor = 0xed4588
enemySpawnChance = 0.01
playerColor = 0xffff0b
scrW = 800
scrH = 600
shieldDiameter = 50
tau = 2 * Math.PI
triangleAccel = 30 / 60
triangleMaxSpeed = 600 / 60
triangleTurnRate = (tau/2) / 60
weaponColor = 0x22ddff

bullets = []
cursors = null
enemies = []
game = null
graphics = null
keys = null
player = null
weapons = {}

window.onload = ->
  game = new Phaser.Game scrW, scrH, Phaser.AUTO, '', {
    preload, create, render, update
  }
  return

preload = ->
  return

create = ->
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
    angle: 0  # clockwise from top
  }

  createWeapons()

  return

update = ->
  if game.rnd.frac() < enemySpawnChance
    spawnEnemy()

  processWeaponFire()
  processWeaponEnergy()

  processEnemyMovement()
  processShapeshiftKeys()
  processPlayerMovement()
  processBulletMovement()

  enemiesToKill = []
  for enemy, i in enemies
    if weapons.circle.active and enemyTouchingShield enemy
      enemiesToKill.push i
    else if enemyTouchingPlayer enemy
      killPlayer()
  i = enemiesToKill.length
  while i > 0
    i -= 1
    enemies.splice enemiesToKill[i], 1

  collideBulletsAndEnemies()

  draw()
  return

render = ->
  # game.debug.text "#{weapons.circle.energy}", 0, 500
  return

createWeapons = ->
  for name in ['circle', 'triangle']
    weapon = {
      active: false
      energy: 100
      drain: 100 / 60
      recharge: 40 / 60
      cooling: false
    }
    weapons[name] = weapon
  return

draw = ->
  graphics.clear()
  drawArenaBounds()
  drawPlayer()
  drawEnemies()
  drawShield()
  drawBullets()
  drawEnergyLevels()
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
  drawDrifter enemy

drawDrifter = (drifter) ->
  graphics.lineStyle 0
  graphics.beginFill enemyColor, 1.0
  {x, y} = toScreen drifter.x, drifter.y
  graphics.drawCircle x, y, distToScreen(drifterDiameter)
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

drawShield = ->
  return unless weapons.circle.active
  graphics.lineStyle 2, weaponColor, 0.8
  {x, y} = toScreen player.x, player.y
  graphics.drawCircle x, y, distToScreen(shieldDiameter)
  return

drawEnergyLevels = ->
  y = 0
  for own name, weapon of weapons
    y += 20
    color = if weapon.cooling then enemyColor else weaponColor
    graphics.lineStyle 4, color, 1.0
    graphics.moveTo 620, y
    graphics.lineTo 620+(weapon.energy*160*0.01), y

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
  }
  bullets.push bullet
  return bullet

playerSaysLeft = -> cursors.left.isDown or keys.left.isDown
playerSaysRight = -> cursors.right.isDown or keys.right.isDown
playerSaysUp = -> cursors.up.isDown or keys.up.isDown
playerSaysDown = -> cursors.down.isDown or keys.down.isDown

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

  movePlayerByVel()

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

  movePlayerByVel()

  return

movePlayerByVel = ->
  player.x += player.vx
  player.y += player.vy

  if player.x - circleDiameter*0.5 < 0
    player.x = circleDiameter*0.5
    player.vx = 0
  if player.x + circleDiameter*0.5 > 1000
    player.x = 1000 - circleDiameter*0.5
    player.vx = 0
  if player.y - circleDiameter*0.5 < 0
    player.y = circleDiameter*0.5
    player.vy = 0
  if player.y + circleDiameter*0.5 > 1000
    player.y = 1000 - circleDiameter*0.5
    player.vy = 0

  return

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
    processDrifterMovement enemy
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

processBulletMovement = ->
  spent = []
  for bullet, i in bullets
    bullet.x += bulletSpeed * Math.sin bullet.angle
    bullet.y -= bulletSpeed * Math.cos bullet.angle
    if (bullet.x <= 0 or bullet.x >= 1000 or
        bullet.y <= 0 or bullet.y >= 1000)
      spent.push i
  # remove spent
  i = spent.length
  while i > 0
    i -= 1
    bullets.splice spent[i], 1
  return

collideBulletsAndEnemies = ->
  spent = []
  dead = []
  for enemy, ei in enemies
    testCircle = new Phaser.Circle enemy.x, enemy.y, enemy.radius * 2
    for bullet, bi in bullets
      if testCircle.contains bullet.x, bullet.y
        spent.push bi
        dead.push ei

  # remove dead
  i = dead.length
  while i > 0
    i -= 1
    enemies.splice dead[i], 1

  # remove spent
  i = spent.length
  while i > 0
    i -= 1
    bullets.splice spent[i], 1

  return

spawnEnemy = ->
  enemy = {
    type: 'drifter'
  }
  x = null
  until x != null and Math.abs(x-player.x) > 200
    x = game.rnd.between drifterDiameter, 1000-drifterDiameter
  y = null
  until y != null and Math.abs(y-player.y) > 200
    y = game.rnd.between drifterDiameter, 1000-drifterDiameter
  enemy.x = x
  enemy.y = y
  angle = game.rnd.realInRange 0, tau
  enemy.vx = drifterSpeed * Math.cos angle
  enemy.vy = drifterSpeed * Math.sin angle
  enemy.radius = drifterDiameter / 2
  enemies.push enemy
  return enemy

killPlayer = ->
  player.alive = false
  return

enemyTouchingShield = (enemy) ->
  doCirclesIntersect enemy.x, enemy.y, enemy.radius,
                     player.x, player.y, shieldDiameter / 2

enemyTouchingPlayer = (enemy) ->
  doCirclesIntersect enemy.x, enemy.y, enemy.radius,
                     player.x, player.y, circleDiameter / 2

doCirclesIntersect = (x0, y0, r0, x1, y1, r1) ->
  distSq = (x0-x1)**2 + (y0-y1)**2
  return distSq <= (r0+r1)**2

shiftToCircle = ->
  player.mode = 'circle'
  weapons.triangle.active = false
  return

shiftToTriangle = ->
  player.mode = 'triangle'
  weapons.circle.active = false
  return
