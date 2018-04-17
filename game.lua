cam = require 'camera'
map = require 'map'
enemy = require 'enemy'
net = require 'net'

local game = {}

local state = {
    players = {},
    bullets = {}
}

FIRETIME = 0.2
MAXBULLETS = 40

GRAVITY = 9.8

player_attrs = {
    speed = 180,
    jumpSpeed = 400,
    skins ={
      pink=love.graphics.newImage('res/img/p3_spritesheet.png'),
      green=love.graphics.newImage('res/img/p1_spritesheet.png'),
      blue=love.graphics.newImage('res/img/p2_spritesheet.png')
    }
}

enemy:load()
map:load()

function newPlayer(x_, y_,skin_)
    local p = {
	type = "player",
	x = x_, y = y_,
	vx = 0, vy = 0,
	canJump = false,
	direction = 1,
	lastfire = 0,
	w = 70, h = 95,
  skin=skin_,
  hp = 100,
  lives = 4
    }
    table.insert(state.players, p)
    map.world:add(p, p.x, p.y, p.w, p.h)
    return p
end

function left(player)
    player.vx = -player_attrs.speed
    player.direction=-1
end

function right(player)
    player.vx = player_attrs.speed
    player.direction=1
end

function jump(player)
    if player.canJump then
	player.vy = -player_attrs.jumpSpeed
	player.canJump = false
    end
end

function updatePlayer(dt, player)
    player.vy = player.vy + GRAVITY
    local goalX, goalY = player.x + player.vx * dt, player.y + player.vy * dt
    local actualX, actualY, cols, len = map.world:move(player, goalX, goalY, function(item, other)
	if other.type == "bullet" then
	    return nil
	end
	return "slide"
    end)
    player.x, player.y = actualX, actualY

    if len > 0 then
	player.canJump = true
    end

    -- reset vx so player input doesn't keep vx going when a key is released
    player.vx = 0
end


function fireGun(player)
    if love.timer.getTime() - player.lastfire > FIRETIME then
	local b = {
	    type = 'bullet',
	    owner = player,
	    x = player.x + player.w / 2,
	    y = player.y + player.h / 2,
	    vx = 400 * player.direction,
	    vy = 0,
	    ttl = 3
	}
	map.world:add(b, b.x, b.y, 10, 10)
	table.insert(state.bullets, b)
	player.lastfire = love.timer.getTime()
    end
end

function takeDamage(player)
	player.hp = player.hp - 10

	-- death state
	if player.hp <= 0 then
		player.hp = 100
		player.lives = player.lives - 1
	end
end

me = newPlayer(0, 0,"pink")
me2 = newPlayer(100, 0,"green")

beholder.group(me, function()
    beholder.observe("player1-up", function() jump(me) end)
    --beholder.observe("control-down", player:jump)
    beholder.observe("player1-left", function() left(me) end)
    beholder.observe("player1-right", function() right(me) end)
    beholder.observe("player1-fire", function() fireGun(me) end)
end)

beholder.group(me2, function()
    beholder.observe("player2-up", function() jump(me2) end)
    --beholder.observe("control-down", player:jump)
    beholder.observe("player2-left", function() left(me2) end)
    beholder.observe("player2-right", function() right(me2) end)
    beholder.observe("player2-fire", function() fireGun(me2) end)
end)

beholder.observe("take-damage", function(player) takeDamage(player) end)

local foo = enemy:new("slime", 200,150)
map.world:add(enemy.stack[foo], enemy.stack[foo].x,enemy.stack[foo].y, 52,28)

function game:load()
end

function game:update(dt)
    fun.each(function(p) updatePlayer(dt, p) end, state.players)

    for i, b in ipairs(state.bullets) do
	b.vy = b.vy + GRAVITY
	local x, y, cols, _ = map.world:move(b, b.x + b.vx * dt, b.y + b.vy * dt,
	function(item, other)
	    if other.type == "player" and other == item.owner then
			return nil
	    end

		if other.type == "player" and other ~= item.owner then
			return "touch"
		end

	    return "bounce"
	end)

	b.x = x
	b.y = y

	for i, col in ipairs(cols) do
	  local doKill = false
	  -- the bullet is hitting a wall
	  if col.type == "bounce" then
	    col.item.ttl = col.item.ttl - 1

	    if col.item.ttl <= 0 then
	      doKill = true
	    end

	    if col.normal.x ~= 0 then
	      col.item.vx = math.abs(col.item.vx) * col.normal.x
	    end

	    col.item.vy = math.abs(col.item.vy) * col.normal.y

	  elseif col.type == "touch" then
	    -- remove the bullet if it hits another player
	    doKill = true
	    beholder.trigger("take-damage", col.other)
	  end

	  if doKill then
	    local n = table.remove(state.bullets, i)
	    if n then
	      map.world:remove(n)
	    else
	      print("RERRRRRR CHARLES ITS HAPPENING AGINNNNN")
	    end
	  end
	end

	if #state.bullets > MAXBULLETS then
	    map.world:remove(table.remove(state.bullets, 1))
	end

    end

    enemy:update(dt)
    map:update(dt)
end

stand=love.graphics.newQuad(0,0,70,95,player_attrs.skins["pink"]:getDimensions())
jumpFrame=love.graphics.newQuad(436,92,70,95,player_attrs.skins["pink"]:getDimensions())
run1=love.graphics.newQuad(0,95,70,95,player_attrs.skins["pink"]:getDimensions())
run2=love.graphics.newQuad(73,98,70,95,player_attrs.skins["pink"]:getDimensions())


function drawPlayer(player)
    img=player_attrs.skins[player.skin]
    --love.graphics.rectangle('line', player.x, player.y, player.w, player.h)
    local drawX = player.x
    if player.direction == -1 then
	     drawX = drawX + player.w
    end
    time=love.timer.getTime() * 10
    if player.canJump then
	     if (time % 6) > 3 then
	        love.graphics.draw(img, run1, drawX, player.y,0,player.direction,1)
	     else
	        love.graphics.draw(img, run2, drawX, player.y,0,player.direction,1)
	     end
    else
	     if (time % 6) > 3 then
	        love.graphics.draw(img, jumpFrame, drawX, player.y,0,player.direction,1)
	     else
	        love.graphics.draw(img, jumpFrame, drawX, player.y,0,player.direction,1)
	     end

    end

	health = player.w * (player.hp / 100)

	if player.hp > 30 then
		-- light green
		love.graphics.setColor(129, 199, 132)
	else
		love.graphics.setColor(239, 83, 80)
	end

	love.graphics.rectangle("fill", player.x, player.y - 20, health, 10)

	-- reset colors
	love.graphics.setColor(255, 255, 255)
end

hudsprite=love.graphics.newImage('res/img/hud_spritesheet.png')
hart=love.graphics.newQuad(0,92,52,49,hudsprite:getDimensions())
pinkFace=love.graphics.newQuad(97,97,52,49,hudsprite:getDimensions())
greenFace=love.graphics.newQuad(0,140,48,49,hudsprite:getDimensions())

function game:draw()
    cam:follow(me)

    -- start the camera
    cam:set()

    map:draw()

    fun.each(drawPlayer, state.players)

    enemy:draw()

    -- draw bullets
    for _, b in pairs(state.bullets) do
	if b.owner.skin == "blue" then
	    love.graphics.setColor(20, 20, 100)
	elseif b.owner.skin == "pink" then
	    love.graphics.setColor(255, 50, 50)
	end
	love.graphics.rectangle('fill', b.x, b.y, 10, 10)
	love.graphics.setColor(255, 255, 255)
    end

    cam:unset()

    numLives(10,10,"pink",state.players[1].lives)
    numLives(love.graphics.getWidth()-148,10,"green",state.players[2].lives)
end

function numLives(x,y,avatar,lives)
  if avatar=="pink" then
    love.graphics.draw(hudsprite, pinkFace, x, y,0,0.5,0.5)
  else
    if avatar == "green" then
        love.graphics.draw(hudsprite, greenFace, x, y,0,0.5,0.5)
    end
  end

  for i = 1, lives do
    love.graphics.draw(hudsprite, hart, x + (i * (52/2)), y,0,0.5,0.5)
  end
end

return game
