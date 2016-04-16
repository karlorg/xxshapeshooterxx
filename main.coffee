{Phaser} = window

arenaBounds = { left: 8, right: 592, top: 8, bottom: 592 }
arenaWidth = arenaBounds.right - arenaBounds.left
arenaHeight = arenaBounds.bottom - arenaBounds.top
circleInertia = 0.8
circleSpeed = 300 / 60
circleDiameter = 30
drifterDiameter = 40
drifterSpeed = 250 / 60
enemyColor = 0xed4588
enemySpawnChance = 0.01
playerColor = 0xffff0b
scrW = 800
scrH = 600
shieldColor = 0x22ddff
shieldDiameter = 50
tau = 2 * Math.PI

cursors = null
enemies = []
game = null
graphics = null
keys = null
player = null
shield = null

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
  game.input.keyboard.addKeyCapture [
    Phaser.KeyCode.A
    Phaser.KeyCode.R
    Phaser.KeyCode.S
    Phaser.KeyCode.W
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
    angle: 0
  }

  shield = {
    active: false
  }

  return

update = ->
  if game.rnd.frac() < enemySpawnChance
    spawnEnemy()

  shield.active = false
  if game.input.activePointer.leftButton.isDown
    fire()

  processEnemyMovement()
  processPlayerMovement()

  enemiesToKill = []
  for enemy, i in enemies
    if shield.active and enemyTouchingShield enemy
      enemiesToKill.push i
    else if enemyTouchingPlayer enemy
      killPlayer()
  i = enemiesToKill.length
  while i > 0
    i -= 1
    enemies.splice enemiesToKill[i], 1

  draw()
  return

render = ->
  # game.debug.text "#{player.karl.state}", 0, 500
  return

draw = ->
  graphics.clear()
  drawArenaBounds()
  drawPlayer()
  drawEnemies()
  drawShield()
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
  graphics.lineStyle 0
  graphics.beginFill playerColor, 1.0
  {x, y} = toScreen player.x, player.y
  graphics.drawCircle x, y, distToScreen(circleDiameter)
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

drawShield = ->
  return unless shield.active
  graphics.lineStyle 2, shieldColor, 0.8
  {x, y} = toScreen player.x, player.y
  graphics.drawCircle x, y, distToScreen(shieldDiameter)
  return

fire = ->
  shield.active = true
  return

playerSaysLeft = -> cursors.left.isDown or keys.left.isDown
playerSaysRight = -> cursors.right.isDown or keys.right.isDown
playerSaysUp = -> cursors.up.isDown or keys.up.isDown
playerSaysDown = -> cursors.down.isDown or keys.down.isDown

processPlayerMovement = ->
  processCircleMovement()

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

  player.angle = Math.atan2 player.vx, player.vy

  player.x += player.vx
  player.y += player.vy

  if player.x - circleDiameter*0.5 < 0 then player.x = circleDiameter*0.5
  if player.x + circleDiameter*0.5 > 1000
    player.x = 1000 - circleDiameter*0.5
  if player.y - circleDiameter*0.5 < 0 then player.y = circleDiameter*0.5
  if player.y + circleDiameter*0.5 > 1000
    player.y = 1000 - circleDiameter*0.5

  return

processEnemyMovement = ->
  for enemy in enemies
    processDrifterMovement enemy

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
