-- Settings --
local ESP = {
    Enabled = false,
    Boxes = true,
    BoxShift = CFrame.new(0, -1.5, 0),
    BoxSize = Vector3.new(4, 6, 0),
    Color = Color3.fromRGB(255, 170, 0),
    FaceCamera = false,
    Names = true,
    TeamColor = true,
    Thickness = 2,
    AttachShift = 1,
    TeamMates = true,
    Players = true,
    AutoRemove = true,
    Objects = setmetatable({}, { __mode = "kv" }),
    Overrides = {}
}

-- Declarations --
local cam = workspace.CurrentCamera
local plrs = game:GetService("Players")
local plr = plrs.LocalPlayer

local function WorldToViewportPoint(position)
    return cam:WorldToViewportPoint(position)
end

-- Functions --
local function Draw(obj, props)
    local new = Drawing.new(obj)
    for i, v in pairs(props or {}) do
        new[i] = v
    end
    return new
end

function ESP:GetTeam(p)
    if self.Overrides.GetTeam then
        return self.Overrides.GetTeam(p)
    end
    return p and p.Team or nil
end

function ESP:IsTeamMate(p)
    if self.Overrides.IsTeamMate then
        return self.Overrides.IsTeamMate(p)
    end
    return self:GetTeam(p) == self:GetTeam(plr)
end

function ESP:GetColor(obj)
    if self.Overrides.GetColor then
        return self.Overrides.GetColor(obj)
    end
    local p = self:GetPlrFromChar(obj)
    return p and self.TeamColor and p.Team and p.Team.TeamColor.Color or self.Color
end

function ESP:GetPlrFromChar(char)
    if self.Overrides.GetPlrFromChar then
        return self.Overrides.GetPlrFromChar(char)
    end
    return plrs:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
    self.Enabled = bool
    if not bool then
        for _, v in pairs(self.Objects) do
            if v.Type == "Box" then
                if v.Temporary then
                    v:Remove()
                else
                    for _, component in pairs(v.Components) do
                        component.Visible = false
                    end
                end
            end
        end
    end
end

function ESP:GetBox(obj)
    return self.Objects[obj]
end

function ESP:AddObjectListener(parent, options)
    local function NewListener(c)
        if (not options.Type or c:IsA(options.Type)) and
           (not options.Name or c.Name == options.Name) and
           (not options.Validator or options.Validator(c)) then
           
            local box = ESP:Add(c, {
                PrimaryPart = (type(options.PrimaryPart) == "string" and c:FindFirstChild(options.PrimaryPart)) or
                              (type(options.PrimaryPart) == "function" and options.PrimaryPart(c)),
                Color = (type(options.Color) == "function" and options.Color(c)) or options.Color,
                ColorDynamic = options.ColorDynamic,
                Name = (type(options.CustomName) == "function" and options.CustomName(c)) or options.CustomName,
                IsEnabled = options.IsEnabled,
                RenderInNil = options.RenderInNil
            })
            if options.OnAdded then
                coroutine.wrap(options.OnAdded)(box)
            end
        end
    end

    if options.Recursive then
        parent.DescendantAdded:Connect(NewListener)
        for _, v in pairs(parent:GetDescendants()) do
            coroutine.wrap(NewListener)(v)
        end
    else
        parent.ChildAdded:Connect(NewListener)
        for _, v in pairs(parent:GetChildren()) do
            coroutine.wrap(NewListener)(v)
        end
    end
end

-- boxBase Methods --
local boxBase = {}
boxBase.__index = boxBase

function boxBase:Remove()
    if self.Object then
        ESP.Objects[self.Object] = nil
    end
    for _, v in pairs(self.Components) do
        if v then
            v.Visible = false
            v:Remove()
        end
    end
    self.Components = nil
end

function boxBase:Update()
    if not self.PrimaryPart then
        return self:Remove()
    end

    local color = self.Color or (self.ColorDynamic and self:ColorDynamic()) or ESP:GetColor(self.Object) or ESP.Color

    local allow = true
    if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then
        allow = false
    end
    if self.Player and not ESP.TeamMates and ESP:IsTeamMate(self.Player) then
        allow = false
    end
    if self.Player and not ESP.Players then
        allow = false
    end
    if self.IsEnabled and
       (type(self.IsEnabled) == "string" and not ESP[self.IsEnabled] or
        type(self.IsEnabled) == "function" and not self:IsEnabled()) then
        allow = false
    end
    if not workspace:IsAncestorOf(self.PrimaryPart) and not self.RenderInNil then
        allow = false
    end

    if not allow then
        for _, v in pairs(self.Components) do
            if v then
                v.Visible = false
            end
        end
        return
    end

    -- Calculations --
    local cf = self.PrimaryPart.CFrame
    if ESP.FaceCamera then
        cf = CFrame.new(cf.Position, cam.CFrame.Position)
    end
    local size = self.Size or ESP.BoxSize
    local locs = {
        TopLeft = cf * ESP.BoxShift * CFrame.new(size.X / 2, size.Y / 2, 0),
        TopRight = cf * ESP.BoxShift * CFrame.new(-size.X / 2, size.Y / 2, 0),
        BottomLeft = cf * ESP.BoxShift * CFrame.new(size.X / 2, -size.Y / 2, 0),
        BottomRight = cf * ESP.BoxShift * CFrame.new(-size.X / 2, -size.Y / 2, 0),
        TagPos = cf * ESP.BoxShift * CFrame.new(0, size.Y / 2, 0),
        Torso = cf * ESP.BoxShift
    }

    -- Update Box
    if ESP.Boxes and self.Components.Quad then
        local TopLeft, Vis1 = WorldToViewportPoint(locs.TopLeft.Position)
        local TopRight, Vis2 = WorldToViewportPoint(locs.TopRight.Position)
        local BottomLeft, Vis3 = WorldToViewportPoint(locs.BottomLeft.Position)
        local BottomRight, Vis4 = WorldToViewportPoint(locs.BottomRight.Position)

        if Vis1 or Vis2 or Vis3 or Vis4 then
            self.Components.Quad.Visible = true
            self.Components.Quad.PointA = Vector2.new(TopRight.X, TopRight.Y)
            self.Components.Quad.PointB = Vector2.new(TopLeft.X, TopLeft.Y)
            self.Components.Quad.PointC = Vector2.new(BottomLeft.X, BottomLeft.Y)
            self.Components.Quad.PointD = Vector2.new(BottomRight.X, BottomRight.Y)
            self.Components.Quad.Color = color
        else
            self.Components.Quad.Visible = false
        end
    elseif self.Components.Quad then
        self.Components.Quad.Visible = false
    end

    -- Update Names
    if ESP.Names and self.Components.Name and self.Components.Distance then
        local TagPos, Vis5 = WorldToViewportPoint(locs.TagPos.Position)

        if Vis5 then
            self.Components.Name.Visible = true
            self.Components.Name.Position = Vector2.new(TagPos.X, TagPos.Y)
            self.Components.Name.Text = self.Name
            self.Components.Name.Color = color

            self.Components.Distance.Visible = true
            self.Components.Distance.Position = Vector2.new(TagPos.X, TagPos.Y + 14)
            self.Components.Distance.Text = math.floor((cam.CFrame.Position - cf.Position).Magnitude) .. "m away"
            self.Components.Distance.Color = color
        else
            self.Components.Name.Visible = false
            self.Components.Distance.Visible = false
        end
    else
        if self.Components.Name then
            self.Components.Name.Visible = false
        end
        if self.Components.Distance then
            self.Components.Distance.Visible = false
        end
    end

    -- Update Tracers
    if ESP.Tracers and self.Components.Tracer then
        local TorsoPos, Vis6 = WorldToViewportPoint(locs.Torso.Position)

        if Vis6 then
            self.Components.Tracer.Visible = true
            self.Components.Tracer.From = Vector2.new(TorsoPos.X, TorsoPos.Y)
            self.Components.Tracer.To = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / ESP.AttachShift)
            self.Components.Tracer.Color = color
        else
            self.Components.Tracer.Visible = false
        end
    elseif self.Components.Tracer then
        self.Components.Tracer.Visible = false
    end
end

function ESP:Add(obj, options)
    if not obj.Parent and not options.RenderInNil then
        return warn(obj, "has no parent")
    end

    local box = setmetatable({
        Name = options.Name or obj.Name,
        Type = "Box",
        Color = options.Color or ESP:GetColor(obj),
        Size = options.Size or ESP.BoxSize,
        PrimaryPart = options.PrimaryPart or obj.PrimaryPart,
        RenderInNil = options.RenderInNil,
        Components = {
            Quad = Draw("Quad", {
                Color = options.Color or ESP:GetColor(obj),
                Thickness = ESP.Thickness,
                Visible = false
            }),
            Name = Draw("Text", {
                Color = options.Color or ESP:GetColor(obj),
                Size = 14,
                Center = true,
                Outline = true,
                Visible = false
            }),
            Distance = Draw("Text", {
                Color = options.Color or ESP:GetColor(obj),
                Size = 14,
                Center = true,
                Outline = true,
                Visible = false
            }),
            Tracer = Draw("Line", {
                Color = options.Color or ESP:GetColor(obj),
                Thickness = ESP.Thickness,
                Visible = false
            })
        }
    }, boxBase)

    self.Objects[obj] = box
    return box
end
