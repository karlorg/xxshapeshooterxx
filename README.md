# xXShapeShooterXx

This is the source code for my game jam game xXShapeShooterXx, which
should be available to play
[here](http://karln.itch.io/xxshapeshooterxx).  It's in Coffeescript
so you need to compile `main.coffee` to `main.js`.  Then serve the
directory on `localhost` (for example, using Node's `http-server` or
Python's `SimpleHTTPServer`) and load `index.html` in a browser.
Chrome tends to work best.

## Phaser

The game is made with Phaser but it's unfortunately not a good example
of Phaser usage.  Since I never looked into getting Phaser `Graphics`
objects to work with the collision systems and was a little panicked
and wanting to get started, I just ignored Phaser's scene graph and
physics systems altogether.  Instead the visual parts of the game are
mostly just a single Graphics object that covers the whole screen and
which I manually clear and redraw each frame.  I also update the
position of each game entity from its velocity every frame, convert
between screen and world coordinates manually, etc.

There are a few Phaser `Text` objects used, and all the audio and
state switching are Phaser.  But otherwise it's a gross abuse of
Phaser's capabilities, sorry.
