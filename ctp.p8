pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

_griddata = {
"                            ",
" ............  ............ ",
" .    .     .  .     .    . ",
" o    .     .  .     .    o ",
" .    .     .  .     .    . ",
" .......................... ",
" .    .  .        .  .    . ",
" .    .  .        .  .    . ",
" ......  ....  ....  ...... ",
"      .     -  -     .      ",
"      .     -  -     .      ",
"      .  ----------  .      ",
"      .  -        -  .      ",
"      .  -        -  .      ",
" -----.---        ---.----- ",
"      .  -        -  .      ",
"      .  -        -  .      ",
"      .  ----------  .      ",
"      .  -        -  .      ",
"      .  -        -  .      ",
" ............  ............ ",
" .    .     .  .     .    . ",
" .    .     .  .     .    . ",
" o..  .......--.......  ..o ",
"   .  .  .        .  .  .   ",
"   .  .  .        .  .  .   ",
" ......  ....  ....  ...... ",
" .          .  .          . ",
" .          .  .          . ",
" .......................... ",
"                            "
}

_left=0
_right=1
_up=2
_down=3

states = { menu=1, intro=2,
           playing=3, dying=4,
           finish=5 }

game    = { speed=1, level=1, state=1}
pellets = {}
juncts  = {}
pacman  = {}
ghosts  = {}

timer = {}
timer.intro  = 120
timer.fright = 0
timer.dying  = 0 

score = 0

dot = {}
function dot.new(x,y,super)
  local d = {}
  d.x = x
  d.y = y
  d.super=super
  return d
end

ghost = {}
ghost.__index = ghost
ghost.states = {
  chase=1,
  scatter=2,
  fright=3,
  dead=4,
  caged=5
}

function ghost.new( x, y, name, speed)
  local g = {}
  setmetatable( g, ghost)
  g.x        = x
  g.y        = y
  g._speed   = speed
  g.name     = name
  g.dir      = _left
  g.ap       = 0
  g.freetime = 0 -- how long til release from cage
  g.freefood = 0 -- how many pellets til release from cage
  g.state    = ghost.states.chase
  g.sprite   = 3
  g.eyesspr  = 60
  
  if g.name=="blinky" then
    g.colour   = 8
    g.state    = g.states.chase
  elseif g.name=="pinky" then
    g.colour   = 14
    g.state    = g.states.caged
    g.freetime = 150
    g.freefood = 30
  elseif g.name=="inky" then
    g.colour   = 12
    g.state    = g.states.caged
    g.freetime = 300
    g.freefood = 60
  elseif g.name=="clyde" then
    g.colour   = 9
    g.state    = g.states.caged
    g.freetime = 400
    g.freefood = 90
  end
  
  return g
end

function ghost:get_colour()
  if self.state==ghost.states.fright then
    if timer.fright < 150 and (flr(timer.fright/8)%2)==1 then
      return 7
    else
      return 1
    end
  elseif self.state==ghost.states.dead then
    return 0
  else
    return self.colour
  end
end

function ghost:speed()
  if self.state==ghost.states.dead then
    return 2
  elseif intunnel( self) then
    return 0.4
  else
    return self._speed
  end
end

function ghost:uncage()
  if self.state == ghost.states.caged then
    self.x     = 14*4
    self.y     = 14*4-2
    self.dir   = _up
    self.ap    = 0
    self.state = self.states.chase
  end
end

function ghost:frighten()
  
  if self.state==ghost.states.chase or
     self.state==ghost.states.scatter or
     self.state==ghost.states.fright then
    self.state = ghost.states.fright
    self.dir = oppdir( self.dir)
  end
end

function irnd( n, m)
  return flr( rnd(m-n+1))+n
end

function intunnel( o)
  -- checking to see if object
  -- is in a tunnel. reduces speed
  -- for ghosts
  
  if o.y==58 then
    if o.x<26 or o.x>90 then
      return true
    end
  end

  return false
end

function collision()
  for g in all(ghosts) do
    if abs(g.x-pacman.x) + abs(g.y-pacman.y) < 2 then
      p( "collision!"..(g.name))
      return g
    end
  end
  return false
end


function oppdir( d)
  if(d==_left)  return _right
  if(d==_right) return _left
  if(d==_up)    return _down
  if(d==_down)  return _up
end

function to_s( o)
  output = ""
  if type(o) == "table" then
    for v in all(o) do
      output = output .. to_s(v) .. " "
    end
  elseif type(o) == "string" then
    output = o
  elseif type(o) == "number" then
    output = "" .. o
  elseif type(o) == "boolean" then
    if o then
      output = "true"
    else
      output = "false"
    end
  end
  return output
end

function p( o)
  printh( to_s(o))
end

function xoffset( dir)
  if(dir==_left)  return -1
  if(dir==_right) return  1
  return 0
end

function yoffset( dir)
  if(dir==_up)   return -1
  if(dir==_down) return  1
  return 0
end

function griditem( grid, x, y)
  local l = grid[y]
  local v = sub( l, x, x)
  if (v=="-") return true
  if (v=="o") return true
  if (v==".") return true
  return false
end

function parsegrid( grid)
  pellets = {}
  for y=2,#grid-1 do
    l = grid[y]
    for x=2,#l-1 do
      v = sub(l,x,x)
      
      if v=="." then
        add(pellets,
            dot.new(x*4-2,y*4-2,false))
      elseif v=="o" then
        add(pellets,
            dot.new(x*4-2,y*4-2,true))
      end
      
      local ctr =griditem(grid,x,y)
      local up  =griditem(grid,x,y-1)
      local down=griditem(grid,x,y+1)
      local left=griditem(grid,x-1,y)
      local rght=griditem(grid,x+1,y)
      
      if (ctr and (up or down) and
         (left or rght)) then
         local key = (x*4-2)..","..(y*4-2)
        juncts[key]= {
          up=up,
          down=down,
          left=left,
          right=rght
        }
      end
    end
  end
  
  -- special cases
  -- ghost exit
  juncts[(14*4)..","..(12*4-2)] = {
    up=false,
    down=false,
    left=true,
    right=true
  }
end

function resetactors()
  ghosts = {}
  
  pacman = {
    x=14*4,
    y=24*4-2,
    ap=0, --action points
    speed=0.8,
    dir=_left,
    eatanim = { 48, 49, 50, 51, 50, 49 },
    sprite = 48,
    drawsprite = 48,
    eatanimframe = 0
  }
  
  add( ghosts, ghost.new( 14*4, 12*4-2, "blinky", 0.6))
  add( ghosts, ghost.new( 12*4, 15*4-2, "pinky", 0.6))
  add( ghosts, ghost.new( 14*4, 15*4-2, "inky", 0.6))
  add( ghosts, ghost.new( 16*4, 15*4-2, "clyde", 0.6))
  
  newdir = pacman.dir
  game.playtime = 0
end


function resetlevel()
  pellets = {}
  
  resetactors()
  
  game.speed    = 1 + (game.level * 0.2)
  game.playtime = 0
  game.state    = states.finish
  parsegrid( _griddata)
end

function newgame()
  timer.intro = 160
  timer.intro = 10
  game.level  = 1
  game.lives  = 3
  score=0
  resetlevel()
  game.state=states.intro
  music(0)
end

function _draw()
  rectfill( 0, 0, 128, 128, 0)
  print( score, 44, 44, 2)
  map( 0, 0, 0, 0, 15, 16)
  
  if game.state == states.menu then
    rectfill( 8, 60, 104, 68, 0)
    rect( 8, 60, 104, 68, 7)
    print( "pRESS ANY KEY TO START!", 12, 62, 7)
    return
  end
  
  for d in all(pellets) do
    if d.super then
      rectfill(   d.x, d.y-1,   d.x, d.y+1, 10)
      rectfill( d.x-1,   d.y, d.x+1,   d.y, 10)
    else
      rectfill( d.x, d.y, d.x, d.y, 7)
    end
  end
  
  if game.state == states.playing then
    pacman.drawsprite = pacman.eatanim[pacman.eatanimframe+1]
    --pacman.drawsprite = pacman.eatanim[flr(game.playtime/4)%(#pacman.eatanim)+1]
  elseif game.state == states.dying then
    pacman.drawsprite = pacman.sprite
  end
  
  pal(1,10)
  pal(2,10)
  pal(3,10)
  pal(4,10)
  palt(pacman.dir+1,true)
  spr( pacman.drawsprite, pacman.x-3, pacman.y-4)
  pal()
  palt()
  
  for g in all(ghosts) do
    pal( 3, g:get_colour())
    spr( g.sprite + flr(game.playtime/4)%2, g.x-3, g.y-4)
    pal()
    spr( g.eyesspr+g.dir, g.x-3, g.y-3)
  end
end

function frighten()
  for g in all(ghosts) do
    g:frighten()
  end
  timer.fright = 400 - (game.level*20)
end

function eatpellet(x,y)
  for d in all(pellets) do
    if d.x==x and d.y==y then
      del( pellets, d)
      sfx(3+(#pellets)%2)
      score += 10
      pacman.ap -= 0.1
      
      if d.super then
        frighten()
        score += 40
        pacman.ap -= 0.2
      end
    end
  end
end

function finishlevel()
  game.state = states.finish
  resetlevel()
end

function move_pacman()
  
  if (btn(_up))   newdir=_up
  if (btn(_left)) newdir=_left
  if (btn(_down)) newdir=_down
  if (btn(_right))newdir=_right

  local key = (pacman.x)..
              ","..(pacman.y)
    
  local j = juncts[key]
  
  if j then
    
    if newdir==_up and j.up then
      pacman.dir=newdir
      pacman.y -= 1
    elseif newdir==_down and j.down then
      pacman.dir=newdir
      pacman.y += 1
    elseif newdir==_left and j.left then
      pacman.dir=newdir
      pacman.x -= 1
    elseif newdir==_right and j.right then
      pacman.dir=newdir
      pacman.x += 1
    else
      pacman.ap = 0
    end
  else
    if newdir==_up and
       pacman.dir==_down then
         pacman.dir=_up
    elseif newdir==_down and
       pacman.dir==_up then
         pacman.dir=_down
    elseif newdir==_left and
       pacman.dir==_right then
         pacman.dir=_left
    elseif newdir==_right and
       pacman.dir==_left then
         pacman.dir=_right
    end
    
    if pacman.ap>=1 then
      pacman.x += xoffset( pacman.dir)
      pacman.y += yoffset( pacman.dir)
      pacman.ap -= 1
      
      if pacman.x<0 then
        pacman.x = 112+pacman.x
      elseif pacman.x>112 then
        pacman.x -= 112
      end
    end
    
    pacman.eatanimframe = (pacman.eatanimframe+1) % #pacman.eatanim
    eatpellet(pacman.x, pacman.y)
  end
  
  if pacman.ap >= 1 then
    move_pacman()
  end
end

function gexits( g)
  
  -- possible junction exits for
  -- the ghosts. this differs from
  -- the possible pacman exits.
  
  local dirs = {}
  local key = (g.x)..","..(g.y)

  local j = juncts[key]
  
  if j then
    if j.up    then add( dirs, _up)    end
    if j.down  then add( dirs, _down)  end
    if j.left  then add( dirs, _left)  end
    if j.right then add( dirs, _right) end
  end

  return dirs
end

function distance( x1, y1, x2, y2)
  return sqrt((x1-x2)^2+(y1-y2)^2)
end

function death()
  game.lives -= 1
  game.state  = states.dying
  sfx(5)
  timer.dying = 120
end

function move_ghost( g)
  
  if g.ap < 1 then
    return
  end
  
  local exits = gexits( g)
  
  if #exits>0 and g.state==g.states.fright then
    del( exits, oppdir( g.dir))
    g.dir = exits[irnd(1,#exits)]
    
  elseif #exits>0 then
    del( exits, oppdir( g.dir))
    
    local tx, ty
    
    if g.name=="blinky" then
      tx = pacman.x
      ty = pacman.y
    elseif g.name=="pinky" then
      tx = pacman.x + xoffset( pacman.dir)*16
      ty = pacman.y + yoffset( pacman.dir)*16
      if pacman.dir==_up then
        tx = pacman.x - 16
      end
    elseif g.name=="inky" then
      tx = pacman.x + xoffset( pacman.dir)*8
      ty = pacman.y + yoffset( pacman.dir)*8
      if pacman.dir==_up then
        tx = pacman.x - 8
      end
      tx = tx - (ghosts[1].x-tx)
      ty = ty - (ghosts[1].y-ty)
    elseif g.name=="clyde" then
      if distance( g.x, g.y, pacman.x, pacman.y)>32 then
        tx = pacman.x
        ty = pacman.y
      else
        tx = 0
        ty = 128
      end
    end
    
    if g.state==ghost.states.dead then
      
      if g.x == 14*4 and g.y==12*4-2 then
        g.state = ghost.states.caged
        g.y = 14*4-2
      else
        tx = 14*4
        ty = 14*4-2
      end
    end
    
    local closest = 500
    for e in all(exits) do
      local dist=distance( tx, ty, g.x+xoffset(e), g.y+yoffset(e))
      if dist < closest then
          g.dir=e
        closest = dist
      end
    end
 end
  
  g.x += xoffset( g.dir)
  g.y += yoffset( g.dir)
  g.ap -= 1
    
  if g.x<0 then
    g.x += 112
  elseif g.x>112 then
    g.x -= 112
  end
  
  if g.ap >= 1 then
    move_ghost( g)
  end
end

function update_ap()
  pacman.ap += pacman.speed * game.speed
  for g in all(ghosts) do
    g.ap += (g:speed()) * game.speed
  end
end

function _update()
  
  if game.state==states.menu then
    if btn()>0 then
      newgame()
    end
    return
  end
   
  if game.state==states.intro then
    timer.intro -= 1
    if timer.intro==0 then
      game.state=states.playing
    end
    return
  end
  
  if game.state==states.finish and
     btn()>0 then
    game.state=states.playing
  end
  
  if game.state==states.dying then
    if timer.dying>0 then
      timer.dying -= game.speed
    else
      resetactors()
      game.state    = states.finish
    end
  end
  
  if game.state~=states.playing then
    return
  end
  
  game.playtime += 1
  
  if timer.fright>0 then
    timer.fright -= game.speed
    if timer.fright < 0 then
      for g in all(ghosts) do
        if g.state ~= ghost.states.dead then
          g.state=g.states.chase
        end
      end
    end
  end
  
  g = collision()
  if( collision()) then
    if g.state == ghost.states.fright then
      g.state  =  ghost.states.dead
    elseif g.state ~= ghost.states.dead then
      death()
      return
    end
  end

  update_ap()
  
  if #pellets==0 then
    finishlevel()
    return
  end
  
  move_pacman()
  
  for g in all(ghosts) do
    if g.state==g.states.caged then
      if g.freetime <= game.playtime or
         g.freefood <= 244-#pellets then
        g:uncage()
      end
    else
      g.drawsprite = g.sprite+flr(game.playtime/4)%2
      move_ghost( g)
    end
  end
end

__gfx__
00000000303003036060000044444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000003b33b300600080044ffff44000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070033bbbb33044088804ffffff4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000bb8bb8bb40400800ffcffcff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000bbbbbbbb0044440049ffff94000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007003bb88bb3004ff4004f7777f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000bb88bb00090090049777794000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000030bbbb030900009040ffff04000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
