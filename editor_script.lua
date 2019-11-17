
local script = {}

local zoomRate = 0.1

local images = {}

function script.init(self)
	Input.enable(self)
	self.msx, self.msy = 0, 0
	self.mwx, self.mwy = 0, 0
	self.lastmwx, self.lastmwy = 0, 0
	self.lastmsx, self.lastmsy = 0, 0
end

local function safeLoadNewImage(file)
	local success, img = pcall(love.graphics.newImage, file)
	if success then
		print(file, img)
		return img
	end
end

local function updateImageRect(img)
	local w, h = img.w * img.scale, img.h * img.scale
	img.lt, img.rt = img.x - w/2, img.x + w/2
	img.top, img.bot = img.y - h/2, img.y + h/2
end

local function addImage(imgData, name, x, y, scale)
	x = x or 0;  y = y or 0;  scale = scale or 1
	local i = {
		img = imgData, name = name,
		x = x, y = y, scale = scale
	}
	local w, h = imgData:getDimensions()
	i.w, i.h = w, h
	w, h = w * scale, h * scale
	i.ox, i.oy = w/2, h/2
	i.lt, i.rt, i.top, i.bot = x - w/2, x + w/2, y - h/2, y + h/2
	table.insert(images, i)
	shouldUpdate = true
end

function script.draw(self)
	for i,v in ipairs(images) do
		love.graphics.draw(v.img, v.x, v.y, 0, v.scale, v.scale, v.ox, v.oy)
	end
	if self.hoverImg then
		local img = self.hoverImg
		-- Draw outline around hovered image.
		love.graphics.setColor(0, 1, 1, 1)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", img.lt, img.top, img.w*img.scale, img.h*img.scale)

		if self.scaling then
			local z = Camera.current.zoom

			-- Base scale line & end square.
			love.graphics.setLineWidth(4/z)
			love.graphics.setColor(0, 1, 1, 1)
			local vx, vy = vector.normalize(self.mwx - img.x, self.mwy - img.y)
			local x, y = img.x + vx * self.dragStartDist, img.y + vy * self.dragStartDist
			love.graphics.line(img.x, img.y, x, y)
			love.graphics.circle("fill", x, y, 6/z, 4)

			-- Base scale circle.
			local a = math.atan2(vy, vx)
			love.graphics.setLineWidth(1/z)
			love.graphics.setColor(0, 1, 1, 0.6)
			love.graphics.arc("line", "open", img.x, img.y, self.dragStartDist, a + 0.15, a + math.pi*2 - 0.15, 64)

			-- New scale circle.
			love.graphics.setColor(0, 0.5, 0.5, 0.8)
			local r = vector.len(self.mwx - img.x, self.mwy - img.y)
			love.graphics.arc("line", "open", img.x, img.y, r, a + 0.15, a + math.pi*2 - 0.15, 64)

			-- New scale line & end squares.
			love.graphics.setLineWidth(2/z)
			love.graphics.setColor(0, 0.5, 0.5, 1)
			love.graphics.line(img.x, img.y, self.mwx, self.mwy)
			love.graphics.circle("fill", self.mwx, self.mwy, 6/z, 4)
			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.circle("fill", self.mwx, self.mwy, 3/z, 4)

			-- Draw scale factor text (with background box).
			love.graphics.push()
			love.graphics.scale(1/z, 1/z)

			local tx, ty = self.mwx*z + 10, self.mwy*z - 30
			local str = "x" .. math.round(self.dragScale, 0.001)
			local font = love.graphics.getFont()
			local fw, fh = font:getWidth("x1.000") + 9, font:getHeight() + 7
			love.graphics.setColor(1, 1, 1, 0.5)
			love.graphics.rectangle("fill", tx -3, ty -2, fw, fh, 4, 4, 3)
			love.graphics.setColor(0.5, 0, 0, 1)
			love.graphics.print(str, tx, ty, 0, 1, 1)

			love.graphics.pop()
		end
	end
end

function love.filedropped(file)
	local path = file:getFilename()
	print("FILE DROPPED: " .. tostring(file:getFilename()))
	local img = safeLoadNewImage(file)
	if img then
		local x, y = Camera.current.pos.x, Camera.current.pos.y
		addImage(img, path, x, y)
	end
end

function love.directorydropped(path)
	print("DIRECTORY DROPPED: " .. tostring(path))
	love.filesystem.mount(path, "newImages")
	local files = love.filesystem.getDirectoryItems("newImages")
	local x, y = Camera.current.pos.x, Camera.current.pos.y
	for k,subPath in pairs(files) do
		subPath = "newImages/" .. subPath
		local info = love.filesystem.getInfo(subPath)
		if not info then
			print("ERROR: Can't get file info for path: \n  " .. subPath)
		elseif info.type == "file" then
			local img = safeLoadNewImage(subPath)
			if img then  addImage(img, subPath, x, y)  end
		end
	end
end

local function posOverlapsImage(img, x, y)
	return x < img.rt and x > img.lt and y < img.bot and y > img.top
end

local function updateHoverList(self, except)
	self.hoverList = {}
	for i,img in ipairs(images) do
		if posOverlapsImage(img, self.mwx, self.mwy) then
			table.insert(self.hoverList, img)
		end
	end
end

function script.update(self, dt)
	self.msx, self.msy = love.mouse.getPosition()
	self.mwx, self.mwy = Camera.current:screenToWorld(self.msx, self.msy)

	if self.dragging then
		local img = self.hoverImg
		if img then
			img.x, img.y = self.mwx + self.dragx, self.mwy + self.dragy
			updateImageRect(img)
		end
	elseif self.scaling then
		local img = self.hoverImg
		if img then
			local ox, oy = img.x - self.mwx, img.y - self.mwy
			local newDist = vector.len(ox, oy)
			local scale = newDist / self.dragStartDist
			img.scale = self.dragStartScale * scale
			self.dragScale = scale
			updateImageRect(img)
		end
	else
		updateHoverList(self)
		self.hoverImg = self.hoverList[#self.hoverList]
	end

	if self.panning then
		local dx, dy = self.msx - self.lastmsx, self.msy - self.lastmsy
		dx, dy = Camera.current:screenToWorld(dx, dy, true)
		local camPos = Camera.current.pos
		camPos.x, camPos.y = camPos.x - dx, camPos.y - dy
	end

	self.lastmsx, self.lastmsy = self.msx, self.msy
	self.lastmwx, self.lastmwy = self.mwx, self.mwy
end

local function saveFile(fileName, text)
	print("saving file: " .. fileName)
	local file, err = io.open(fileName, "w")
	if not file then
		print(err)
		return
	else
		file:write(text)
		file:close()
		print("success", file)
		return true
	end
end

function script.input(self, name, value, change)
	shouldUpdate = true
	if name == "click" then
		if change == 1 and self.hoverImg then
			self.dragging = true
			self.dragx, self.dragy = self.hoverImg.x - self.mwx, self.hoverImg.y - self.mwy
		elseif change == -1 then
			self.dragging = nil
			self.dropTarget = nil
		end
	elseif name == "scale" then
		if change == 1 and self.hoverImg then
			self.scaling = true
			self.dragx, self.dragy = self.hoverImg.x - self.mwx, self.hoverImg.y - self.mwy
			self.dragStartDist = vector.len(self.dragx, self.dragy)
			self.dragStartScale = self.hoverImg.scale
		elseif change == -1 then
			self.scaling = false
		end
	elseif name == "zoom" then
		Camera.current:zoomIn(value * zoomRate)
	elseif name == "pan" then
		if value == 1 then
			self.panning = { x = Camera.current.pos.x, y = Camera.current.pos.y }
		else
			self.panning = nil
		end
	elseif name == "delete" and change == 1 then
		if self.hoverImg then
			for i,v in ipairs(images) do
				if v == self.hoverImg then  table.remove(images, i)  end
			end
			self.hoverImg = nil
		end
	elseif name == "quit" and change == 1 then
		love.event.quit(0)
	end
end


return script