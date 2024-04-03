-- Aseprite 3D Viewer
-- Author: Anthony Drapeau / MundanePixel
-- Renders OBJ files to wireframes and animates basic rotation and translation

-- Global variables
sprite = nil
xOffset = 0
yOffset = 0
zOffset = 0
vertSize = 1
lineSize = 1
focalLength = 512
img = nil
vertColor = nil
lineColor = nil
scale = 0

open = io.open

-- Vertice Class
-- Contains its coordinates
vert = {x = 0, y = 0, z = 0, parentShape = nil}
vert.__index = vert

-- Constructor
function vert:new (x, y, z)
    local v = {}
    setmetatable(v, self)
    v.__index = self
    v.x = x
    v.y = y
    v.z = z
    return v
end 

-- Translates the point's location to screenspace
function vert:toPoint()
    local vertX = self.x
    local vertY = self.y
    local vertZ = self.z

    if self.parentShape ~= nil then
        local r = self.parentShape.rx
        local zPos = (vertZ * math.cos( r )) - (vertY * math.sin( r ))
        local yPos = (vertZ * math.sin( r )) + (vertY * math.cos( r ))
        vertZ = zPos
        vertY = yPos

        r = self.parentShape.ry
        local xPos = (vertX * math.cos( r )) - (vertZ * math.sin( r ))
        zPos = (vertX * math.sin( r )) + (vertZ * math.cos( r ))
        vertX = xPos
        vertZ = zPos

        r = self.parentShape.rz
        xPos = (vertX * math.cos( r )) - (vertY * math.sin( r ))
        yPos = (vertX * math.sin( r )) + (vertY * math.cos( r ))
        vertX = xPos
        vertY = yPos

        vertX = vertX + self.parentShape.px
        vertY = vertY + self.parentShape.py
        vertZ = vertZ + self.parentShape.pz
    end

    local xPos = ((focalLength * vertX) / ((focalLength + vertZ) + zOffset)) + xOffset
    local yPos = ((focalLength * vertY) / ((focalLength + vertZ) + zOffset)) + yOffset
    return Point(xPos, yPos)
end

-- Draws the Vertice
function vert:draw(c)
    local p = self:toPoint();
    app.useTool{
        tool="line",
        color=c,
        brush=Brush(vertSize),
        points={p, p}}
end 

-- Line Class
-- References two points and draws a line between them
 line = {v1 = nil, v2 = nil}
 line.__index = line

-- Constructor
function line:new (v1, v2)
    local l = {}
    setmetatable(l, self)
    l.__index = self
    l.v1 = v1
    l.v2 = v2
    return l
end

-- Draws the Line
function line:draw(c)
    app.useTool{
        tool="line",
        color=c,
        brush=Brush(lineSize),
        points={self.v1:toPoint(), self.v2:toPoint()}
    }
end

-- Shape Class
-- Contains a list of Lines and Vertices
shape = {verts = {}, lines = {}, rx = 0, ry = 0, rz = 0, px = 0, py = 0, pz = 0}
shape.__index = shape

-- Constructor
function shape:new (verts, lines)
    local s = {}
    setmetatable(s, self)
    s.__index = self
    s.verts = verts
    s.lines = lines
    for _, v in ipairs(verts) do
        v.parentShape = s
    end  
    return s
end

-- Draws the shape by drawing all lines and vertices
function shape:draw()
    for _, l in ipairs(self.lines) do
        l:draw(lineColor)
    end  
    for _, v in ipairs(self.verts) do
        v:draw(vertColor)
    end  
end

-- Rotates all vertices in the shape
function shape:rotate(x, y, z)
    self.rx = self.rx + (x * math.pi)/180
    self.ry = self.ry + (y * math.pi)/180
    self.rz = self.rz + (z * math.pi)/180
end

-- Moves all vertices in the shape
function shape:move(x, y, z)
    self.px = self.px + x
    self.py = self.py + y
    self.pz = self.pz + z 
end

-- Translates the vertices into faces
function vertsToFace(verts, vertArray)
    local l = {}
    for i = 1, #vertArray do

        local numOne = i - 1

        if i == 1 then
            numOne = #vertArray
        end

        local v1 = verts[vertArray[numOne]]
        local v2 = verts[vertArray[i]]
        local addLine = line:new(v1, v2)
        table.insert(l, addLine)
    end

    return l
end

-- String split
function split(s, sep)
    local fields = {}
    
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    
    return fields
end

-- Reads a file and returns all lines
function read_file(path)
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:lines()
    return content
end

-- Reads the entered file and parses the vert and line data to render the shape
function renderOBJ(path)
    
    local fileContent = read_file(path)
    readVerts = {}
    readLines = {}
    linePoints = {}
   
    for fileLine in fileContent do
        -- if the line is referencing a vert
        if(string.sub(fileLine, 1, 2) == "v ") then
           positions = {}
   
           for v in string.gmatch(fileLine, "[^%s]+") do
             table.insert( positions, v )
           end
   
           table.insert( readVerts, vert:new(
           tonumber(positions[2]) * -scale,
           tonumber(positions[3]) * -scale,
           tonumber(positions[4]) * scale)) 
        -- if the line is referencing a face
        elseif(string.sub(fileLine, 1, 2) == "f ") then
            local lineVerts = {}
            local first = true
           for v in string.gmatch(fileLine, "[^%s]+") do
                if(first == false) then 
                    table.insert( lineVerts, tonumber(split(v, "/")[1]))
                end
                first = false
           end

           table.insert( linePoints, lineVerts)
       end
   end
   
   for i = 1, #linePoints do
       local newLines = vertsToFace(readVerts, linePoints[i])
       for j = 1, #newLines do
           table.insert(readLines, newLines[j])
       end
   end
   
   return shape:new(readVerts, readLines)
end

-- Display Menu

local dlg1 = Dialog("3D Viewer")

local function hideOptions()
    local bool = (dlg1.data.Change == "yes")
    dlg1:modify{ id="frameCount", visible=bool, enabled=bool}
    dlg1:modify{ id="xRotate", visible=bool, enabled=bool}
    dlg1:modify{ id="yRotate", visible=bool, enabled=bool}
    dlg1:modify{ id="zRotate", visible=bool, enabled=bool}
end

dlg1:separator{ text="WARNING: This project was made as a one off, so its unoptimized" }
dlg1:separator{ text="Detailed models and long animations can have render times of 30+ minutes" }
dlg1:separator{ text="I reccomend generating a still image to test scale and focal length before generating the full animation" }
dlg1:separator{ text="Path Of OBJ File" }:file{ id = "Path", open = true, filetypes={ "obj" }}
dlg1:number{ label="Model Scale", id="S", text = "96" }
dlg1:number{ label="Image Size", id="X", text = "512" } :number{ id="Y", text = "512" }
dlg1:number{ label="Start Position Vector", id="vX", text = "0" } :number{ id="vY", text = "0" } :number{ id="vZ", text = "0" }
dlg1:number{ label="Start Rotation Vector", id="rX", text = "0" } :number{ id="rY", text = "0" } :number{ id="rZ", text = "0" }
dlg1:number{ label="Z Offset", id="Z", text = "1024" }
dlg1:number{ label="Focal Length", id="Focal", text = "128" }
dlg1:number{ label="Vert & Line Width", id="vSize", text = "1" }:number{ id="lSize", text = "1" }
dlg1:color{ label="Vert & Line Color", id = "vColor", color = Color{r = 255, g = 0, b = 0, a = 255}} :color{ id = "lColor", color = Color{r = 0, g = 255, b = 0, a = 255}}
dlg1:color{ label="Background Color", id = "bColor", color = Color{r = 0, g = 0, b = 0, a = 0}}

dlg1:separator{ text="Animation" }:combobox{ label="Animate", id="Change", option = "no", options = {"yes", "no"}, onchange=function() hideOptions(dlg1) end }

dlg1:number{ label="frames to render", id="frameCount", text = "120" }
dlg1:number{ label="Rotation Vector", id="xRotate", text = "3" } :number{ id="yRotate", text = "3" }:number{ id="zRotate", text = "3" }

dlg1:separator()
dlg1:button{ text="&Cancel",onclick=function() dlg1:close() end }
dlg1:button{ text="&Finish",onclick=function() execute(dlg1.data.Path) end }

dlg1:show{ wait=false }
hideOptions()

function execute(path)

    if read_file(path) == nil then 
        print("File not found")
        return
    end

    dlg1:close()

    sprite = Sprite(dlg1.data.X, dlg1.data.Y)
    xOffset = sprite.width / 2
    yOffset = sprite.height / 2
    zOffset = dlg1.data.Z
    vertSize = dlg1.data.vSize
    lineSize = dlg1.data.lSize
    focalLength = dlg1.data.Focal
    vertColor = dlg1.data.vColor
    lineColor = dlg1.data.lColor
    img = app.activeCel.image
    scale = dlg1.data.S

    local s1 = renderOBJ(path)
    
    app.useTool{
        tool="paint_bucket",
        color=dlg1.data.bColor,
        brush=Brush(1),
        points={ Point(0,0)},
    }

    s1:rotate(dlg1.data.rX, dlg1.data.rY,dlg1.data.rZ)

    s1:move(dlg1.data.vX, dlg1.data.vZ, dlg1.data.vZ)

    s1:draw()
    
    if(dlg1.data.Change == "yes") then
        sprite:newEmptyFrame() 
        for i = 0, dlg1.data.frameCount - 2 do

            app.useTool{
                tool="paint_bucket",
                color=dlg1.data.bColor,
                brush=Brush(1),
                points={ Point(0,0)},
            }

            s1:rotate(dlg1.data.xRotate, dlg1.data.yRotate, dlg1.data.zRotate)
            s1:draw()

            if i < dlg1.data.frameCount - 2 then
                sprite:newEmptyFrame() 
            end
        end
    end
end