{Phaser} = window

arenaBounds = { left: 8, right: 592, top: 8, bottom: 592 }
arenaWidth = arenaBounds.right - arenaBounds.left
arenaHeight = arenaBounds.bottom - arenaBounds.top
circleInertia = 0.8
circleSpeed = 300 / 60
circleDiameter = 30
scrW = 800
scrH = 600
shieldColor = 0x22ddff
shieldDiameter = 50
tau = 2 * Math.PI

cursors = null
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
    bomb: Phaser.KeyCode.X
    whip: Phaser.KeyCode.Z
  game.input.keyboard.addKeyCapture [
    Phaser.KeyCode.X
    Phaser.KeyCode.Z
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
    x: 500
    y: 500
    vx: 0
    vy: 0
  }

  shield = {
    active: false
  }

  return

update = ->
  shield.active = false
  if game.input.activePointer.leftButton.isDown
    fire()

  processPlayerMovement()

  draw()
  return

render = ->
  # game.debug.text "#{player.karl.state}", 0, 500
  return

draw = ->
  graphics.clear()
  drawArenaBounds()
  drawPlayer()
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
  graphics.lineStyle 0
  graphics.beginFill 0xffff0b, 1.0
  {x, y} = toScreen player.x, player.y
  graphics.drawCircle x, y, distToScreen(circleDiameter)
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

processPlayerMovement = ->
  targetvx = 0
  if cursors.left.isDown then targetvx -= circleSpeed
  if cursors.right.isDown then targetvx += circleSpeed
  targetvy = 0
  if cursors.up.isDown then targetvy -= circleSpeed
  if cursors.down.isDown then targetvy += circleSpeed

  if targetvx != 0 and targetvy != 0
    # divide by root 2 so that total speed is still circleSpeed
    targetvx *= 0.707
    targetvy *= 0.707

  player.vx = circleInertia * player.vx + (1-circleInertia) * targetvx
  player.vy = circleInertia * player.vy + (1-circleInertia) * targetvy
  player.x += player.vx
  player.y += player.vy

  if player.x - circleDiameter*0.5 < 0 then player.x = circleDiameter*0.5
  if player.x + circleDiameter*0.5 > 1000
    player.x = 1000 - circleDiameter*0.5
  if player.y - circleDiameter*0.5 < 0 then player.y = circleDiameter*0.5
  if player.y + circleDiameter*0.5 > 1000
    player.y = 1000 - circleDiameter*0.5

  return
