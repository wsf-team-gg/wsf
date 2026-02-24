-- w s f  l o a d e r  . g g
-- Berry Avenue RP — Full Troll + Avatar Reader
-- Loaded via: loadstring(game:HttpGet("https://raw.githubusercontent.com/wsf-team-gg/Wsf-loader/refs/heads/main/wsf%20loader.lua",true))()

local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()

-- ══ Services ══
local Players            = game:GetService("Players")
local MPS                = game:GetService("MarketplaceService")
local RunService         = game:GetService("RunService")
local UIS                = game:GetService("UserInputService")
local Lighting           = game:GetService("Lighting")
local Debris             = game:GetService("Debris")
local LP                 = Players.LocalPlayer

-- ══ Loop manager ══
local Loops = {}
local function startLoop(id, fn, dt)
    Loops[id] = true
    task.spawn(function()
        while Loops[id] do pcall(fn) task.wait(dt or 0.1) end
    end)
end
local function stopLoop(id) Loops[id] = false end

-- ══ Shortcuts ══
local function getChar()  return LP.Character end
local function getRoot()  local c=getChar() return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum()   local c=getChar() return c and c:FindFirstChild("Humanoid") end
local function getMyVehicle()
    local char=getChar() if not char then return nil,nil end
    for _,v in pairs(workspace:GetDescendants()) do
        if v:IsA("VehicleSeat") and v.Occupant and v.Occupant.Parent==char then
            return v:FindFirstAncestorOfClass("Model"),v
        end
    end
    return nil,nil
end

-- ══ Extract numeric ID from rbxassetid:// strings ══
local function extractId(str)
    if not str or str=="" then return nil end
    return str:match("%d+")
end

-- ══ Safe product name fetch ══
local nameCache = {}
local function getProductName(numId)
    if nameCache[numId] then return nameCache[numId] end
    local ok, info = pcall(function() return MPS:GetProductInfo(numId) end)
    local name = (ok and info and info.Name) and info.Name or ("ID: "..numId)
    nameCache[numId] = name
    return name
end

-- ══════════════════════════════════════════════
--                   WINDOW
-- ══════════════════════════════════════════════
local Window = Luna:CreateWindow({
    Name = "w s f  l o a d e r  . g g",
    Subtitle = "Berry Avenue Troll",
    LogoID = nil,
    LoadingEnabled = true,
    LoadingTitle = "w s f  l o a d e r  . g g",
    LoadingSubtitle = "by wsf loader . gg",
    ConfigSettings = { RootFolder = nil, ConfigFolder = "wsf-berry" },
    KeySystem = false,
})

-- ══════════════════════════════════════════════
--           👗 AVATAR READER TAB
-- ══════════════════════════════════════════════
local AvatarTab = Window:CreateTab({
    Name = "Avatar Reader",
    Icon = "checkroom",
    ImageSource = "Material",
    ShowTitle = true,
})

AvatarTab:CreateSection("Scan Player Outfit")

local scannedDesc  = nil
local scannedItems = {}
local avatarTargetName = ""

AvatarTab:CreateInput({
    Name = "Player to Scan",
    Description = "Type a player name then click Scan",
    PlaceholderText = "Enter player name...",
    CurrentValue = "", Numeric = false, MaxCharacters = nil, Enter = true,
    Callback = function(v) avatarTargetName = v end,
}, "AvatarTarget")

-- ══ Core: scan a player's full outfit including ALL 3D layered clothing ══
local function scanAvatar(targetPlayer)
    scannedItems = {}
    local char = targetPlayer.Character
    if not char then return false, "Player has no character" end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false, "No Humanoid found" end

    local ok, desc = pcall(function() return hum:GetAppliedDescription() end)
    if not ok or not desc then return false, "Could not read HumanoidDescription" end
    scannedDesc = desc

    local addedIds = {}
    local function addItem(id, category, descField)
        if not id or id=="" or id=="0" or id=="nil" then return end
        local numId = tonumber(id)
        if not numId or numId==0 then return end
        local key = tostring(numId)
        if addedIds[key] then return end
        addedIds[key] = true
        local item = {
            id          = key,
            numId       = numId,
            name        = getProductName(numId),
            assetType   = category,
            descField   = descField,   -- which HumanoidDescription field this belongs to
            thumbUrl    = "rbxthumb://type=Asset&id="..key.."&w=150&h=150",
        }
        table.insert(scannedItems, item)
    end

    -- ── HumanoidDescription standard fields ──
    -- Each entry: {csvValue, displayCategory, descFieldName}
    local hdFields = {
        {desc.HatAccessory,       "Hat",           "HatAccessory"},
        {desc.HairAccessory,      "Hair",          "HairAccessory"},
        {desc.FaceAccessory,      "Face Accessory","FaceAccessory"},
        {desc.NeckAccessory,      "Neck",          "NeckAccessory"},
        {desc.ShouldersAccessory, "Shoulders",     "ShouldersAccessory"},
        {desc.BackAccessory,      "Back",          "BackAccessory"},
        {desc.WaistAccessory,     "Waist",         "WaistAccessory"},
        {desc.FrontAccessory,     "Front",         "FrontAccessory"},
    }
    for _, f in pairs(hdFields) do
        local csv, cat, field = f[1], f[2], f[3]
        if csv and csv~="" then
            for _, id in pairs(csv:split(",")) do
                addItem(id:match("^%s*(.-)%s*$"), cat, field)
            end
        end
    end

    addItem(tostring(desc.Shirt),         "Shirt",   "Shirt")
    addItem(tostring(desc.Pants),         "Pants",   "Pants")
    addItem(tostring(desc.GraphicTShirt), "T-Shirt", "GraphicTShirt")
    addItem(tostring(desc.Face),          "Face",    "Face")

    -- ── Deep scan: ALL Accessory instances in the character ──
    -- This catches 3D layered shirts, pants, jackets, shoes, etc.
    -- that Berry Avenue adds directly without updating HumanoidDescription
    for _, acc in pairs(char:GetDescendants()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            if handle then
                -- Method 1: SpecialMesh (classic accessories)
                local sm = handle:FindFirstChildOfClass("SpecialMesh")
                if sm then
                    -- MeshId gives us the mesh asset — sometimes same as item ID
                    local mId = extractId(sm.MeshId)
                    local tId = extractId(sm.TextureId)
                    -- Prefer MeshId as item ID (more reliable for accessories)
                    if mId then addItem(mId, "3D Acc: "..acc.Name, nil) end
                    if tId and tId~=mId then addItem(tId, "3D Tex: "..acc.Name, nil) end
                end

                -- Method 2: MeshPart (layered clothing — shirts, pants, jackets, shoes)
                if handle:IsA("MeshPart") then
                    -- TextureID on MeshPart is the texture, MeshId is the mesh
                    local tId = extractId(handle.TextureID)
                    local mId = extractId(handle.MeshId)
                    if tId then addItem(tId, "Layered: "..acc.Name, nil) end
                    if mId and mId~=tId then addItem(mId, "Layered Mesh: "..acc.Name, nil) end
                end

                -- Method 3: WrapLayer (newest layered clothing system)
                local wl = handle:FindFirstChildOfClass("WrapLayer")
                if wl then
                    local cId = extractId(wl.CageMeshId)
                    if cId then addItem(cId, "WrapLayer: "..acc.Name, nil) end
                end
            end

            -- Method 4: Check AccessoryType attribute Berry Avenue sets
            local accType = acc:GetAttribute("AccessoryType") or acc:GetAttribute("ItemType")
            if accType then
                -- Try to get the item's asset ID from an attribute
                local attrId = acc:GetAttribute("AssetId") or acc:GetAttribute("ItemId")
                if attrId then addItem(tostring(attrId), tostring(accType), nil) end
            end
        end
    end

    -- ── Scan Shirt/Pants instances directly on character (classic clothing) ──
    for _, obj in pairs(char:GetChildren()) do
        if obj:IsA("Shirt") then
            local id = extractId(obj.ShirtTemplate)
            if id then addItem(id, "Shirt", "Shirt") end
        elseif obj:IsA("Pants") then
            local id = extractId(obj.PantsTemplate)
            if id then addItem(id, "Pants", "Pants") end
        elseif obj:IsA("ShirtGraphic") then
            local id = extractId(obj.Graphic)
            if id then addItem(id, "T-Shirt", "GraphicTShirt") end
        end
    end

    return true, "Found "..#scannedItems.." items on "..targetPlayer.Name
end

-- ══ Try On: properly equip each item type ══
local function tryOnItem(item)
    local myHum = getHum()
    if not myHum then return end
    task.spawn(function()
        local ok, myDesc = pcall(function() return myHum:GetAppliedDescription() end)
        if not ok or not myDesc then return end

        local cat     = item.assetType
        local numId   = item.numId
        local field   = item.descField

        -- If we know the exact HumanoidDescription field, use it directly
        if field == "Shirt" then
            myDesc.Shirt = numId
        elseif field == "Pants" then
            myDesc.Pants = numId
        elseif field == "GraphicTShirt" then
            myDesc.GraphicTShirt = numId
        elseif field == "Face" then
            myDesc.Face = numId
        elseif field == "HatAccessory" then
            local cur = myDesc.HatAccessory or ""
            myDesc.HatAccessory = cur~="" and (cur..","..item.id) or item.id
        elseif field == "HairAccessory" then
            local cur = myDesc.HairAccessory or ""
            myDesc.HairAccessory = cur~="" and (cur..","..item.id) or item.id
        elseif field == "FaceAccessory" then
            local cur = myDesc.FaceAccessory or ""
            myDesc.FaceAccessory = cur~="" and (cur..","..item.id) or item.id
        elseif field == "NeckAccessory" then
            local cur = myDesc.NeckAccessory or ""
            myDesc.NeckAccessory = cur~="" and (cur..","..item.id) or item.id
        elseif field == "BackAccessory" then
            local cur = myDesc.BackAccessory or ""
            myDesc.BackAccessory = cur~="" and (cur..","..item.id) or item.id
        elseif field == "ShouldersAccessory" then
            local cur = myDesc.ShouldersAccessory or ""
            myDesc.ShouldersAccessory = cur~="" and (cur..","..item.id) or item.id
        elseif field == "WaistAccessory" then
            local cur = myDesc.WaistAccessory or ""
            myDesc.WaistAccessory = cur~="" and (cur..","..item.id) or item.id
        elseif field == "FrontAccessory" then
            local cur = myDesc.FrontAccessory or ""
            myDesc.FrontAccessory = cur~="" and (cur..","..item.id) or item.id
        else
            -- Layered/3D clothing or unknown — figure out by category name
            local catL = cat:lower()
            if catL:find("hair") then
                local cur = myDesc.HairAccessory or ""
                myDesc.HairAccessory = cur~="" and (cur..","..item.id) or item.id
            elseif catL:find("shirt") or catL:find("top") or catL:find("jacket") or catL:find("hoodie") then
                myDesc.Shirt = numId
            elseif catL:find("pant") or catL:find("trouser") or catL:find("jean") or catL:find("short") then
                myDesc.Pants = numId
            elseif catL:find("face") then
                local cur = myDesc.FaceAccessory or ""
                myDesc.FaceAccessory = cur~="" and (cur..","..item.id) or item.id
            elseif catL:find("neck") then
                local cur = myDesc.NeckAccessory or ""
                myDesc.NeckAccessory = cur~="" and (cur..","..item.id) or item.id
            elseif catL:find("back") then
                local cur = myDesc.BackAccessory or ""
                myDesc.BackAccessory = cur~="" and (cur..","..item.id) or item.id
            elseif catL:find("shoulder") then
                local cur = myDesc.ShouldersAccessory or ""
                myDesc.ShouldersAccessory = cur~="" and (cur..","..item.id) or item.id
            elseif catL:find("waist") then
                local cur = myDesc.WaistAccessory or ""
                myDesc.WaistAccessory = cur~="" and (cur..","..item.id) or item.id
            elseif catL:find("front") then
                local cur = myDesc.FrontAccessory or ""
                myDesc.FrontAccessory = cur~="" and (cur..","..item.id) or item.id
            else
                -- Fallback: add to hat
                local cur = myDesc.HatAccessory or ""
                myDesc.HatAccessory = cur~="" and (cur..","..item.id) or item.id
            end
        end

        pcall(function() myHum:ApplyDescription(myDesc) end)
    end)
end

-- ══ Build the popup viewer window ══
local function openAvatarViewer(targetPlayer)
    local ok, msg = scanAvatar(targetPlayer)
    if not ok then
        Luna:Notification({Title="Avatar Reader",Icon="error",ImageSource="Material",Content=msg,Duration=4})
        return
    end

    local PGui = LP.PlayerGui
    local oldGui = PGui:FindFirstChild("WSFAvatarViewer")
    if oldGui then oldGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "WSFAvatarViewer"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PGui

    -- Backdrop
    local bd = Instance.new("Frame")
    bd.Size = UDim2.fromScale(1,1)
    bd.BackgroundColor3 = Color3.fromRGB(0,0,0)
    bd.BackgroundTransparency = 0.45
    bd.BorderSizePixel = 0
    bd.Parent = gui

    -- Main frame
    local mf = Instance.new("Frame")
    mf.Size = UDim2.new(0,720,0,540)
    mf.Position = UDim2.new(0.5,-360,0.5,-270)
    mf.BackgroundColor3 = Color3.fromRGB(16,16,22)
    mf.BorderSizePixel = 0
    mf.Parent = gui
    Instance.new("UICorner",mf).CornerRadius = UDim.new(0,12)

    -- Title bar
    local tb = Instance.new("Frame")
    tb.Size = UDim2.new(1,0,0,46)
    tb.BackgroundColor3 = Color3.fromRGB(10,10,16)
    tb.BorderSizePixel = 0
    tb.Parent = mf
    Instance.new("UICorner",tb).CornerRadius = UDim.new(0,12)
    local tbFix = Instance.new("Frame")
    tbFix.Size = UDim2.new(1,0,0.5,0)
    tbFix.Position = UDim2.new(0,0,0.5,0)
    tbFix.BackgroundColor3 = Color3.fromRGB(10,10,16)
    tbFix.BorderSizePixel = 0
    tbFix.Parent = tb

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-55,1,0)
    title.Position = UDim2.new(0,14,0,0)
    title.BackgroundTransparency = 1
    title.Text = "👗  "..targetPlayer.Name.."'s Avatar  —  "..#scannedItems.." items"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = tb

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0,28,0,28)
    closeBtn.Position = UDim2.new(1,-36,0,9)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 13
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = tb
    Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,6)
    closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

    -- ── LEFT panel (3D viewport + action buttons) ──
    local lp = Instance.new("Frame")
    lp.Size = UDim2.new(0,210,1,-46)
    lp.Position = UDim2.new(0,0,0,46)
    lp.BackgroundColor3 = Color3.fromRGB(20,20,28)
    lp.BorderSizePixel = 0
    lp.Parent = mf

    -- ViewportFrame
    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.new(1,-14,0,250)
    vp.Position = UDim2.new(0,7,0,8)
    vp.BackgroundColor3 = Color3.fromRGB(28,28,40)
    vp.BorderSizePixel = 0
    vp.LightColor = Color3.fromRGB(255,255,255)
    vp.LightDirection = Vector3.new(-1,-2,-1)
    vp.Ambient = Color3.fromRGB(200,200,200)
    vp.Parent = lp
    Instance.new("UICorner",vp).CornerRadius = UDim.new(0,8)

    task.spawn(function()
        local char = targetPlayer.Character
        if not char then return end
        local clone = char:Clone()
        for _,s in pairs(clone:GetDescendants()) do
            if s:IsA("Script") or s:IsA("LocalScript") or s:IsA("Tool") then s:Destroy() end
        end
        clone.Parent = vp
        local vpCam = Instance.new("Camera")
        vpCam.Parent = vp
        vp.CurrentCamera = vpCam
        local root = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChild("Torso")
        if root then
            vpCam.CFrame = CFrame.new(root.Position+Vector3.new(0,1,5), root.Position+Vector3.new(0,0.5,0))
        end
        local angle = 0
        while vp and vp.Parent do
            angle += 0.008
            if clone.PrimaryPart then
                clone:SetPrimaryPartCFrame(CFrame.new(clone.PrimaryPart.Position)*CFrame.Angles(0,angle,0))
            end
            task.wait(0.03)
        end
    end)

    -- Info labels
    local function infoLabel(txt, yOff, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,-10,0,18)
        l.Position = UDim2.new(0,5,0,yOff)
        l.BackgroundTransparency = 1
        l.Text = txt
        l.TextColor3 = color or Color3.fromRGB(200,200,220)
        l.Font = Enum.Font.Gotham
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = lp
    end
    infoLabel(targetPlayer.Name, 264, Color3.fromRGB(255,255,255))
    infoLabel("UID: "..targetPlayer.UserId, 282, Color3.fromRGB(130,130,160))
    infoLabel(#scannedItems.." items detected", 300, Color3.fromRGB(100,220,130))

    -- Action buttons
    local function makeActionBtn(txt, color, yOff, fn)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1,-14,0,30)
        b.Position = UDim2.new(0,7,0,yOff)
        b.BackgroundColor3 = color
        b.Text = txt
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.BorderSizePixel = 0
        b.Parent = lp
        Instance.new("UICorner",b).CornerRadius = UDim.new(0,6)
        b.MouseButton1Click:Connect(fn)
        return b
    end

    makeActionBtn("✨ Equip Full Outfit", Color3.fromRGB(40,160,80), 324, function()
        local myHum = getHum()
        if not myHum or not scannedDesc then return end
        task.spawn(function()
            pcall(function() myHum:ApplyDescription(scannedDesc) end)
            Luna:Notification({Title="Outfit Applied!",Icon="checkroom",ImageSource="Material",
                Content="Wearing "..targetPlayer.Name.."'s full outfit!",Duration=4})
        end)
    end)

    makeActionBtn("📋 Copy All IDs", Color3.fromRGB(50,110,200), 360, function()
        local lines={}
        for _,item in pairs(scannedItems) do
            table.insert(lines,"["..item.assetType.."] "..item.name.." | ID: "..item.id)
        end
        if setclipboard then
            setclipboard(table.concat(lines,"\n"))
            Luna:Notification({Title="Copied!",Icon="content_copy",ImageSource="Material",
                Content=#lines.." items copied.",Duration=3})
        end
    end)

    makeActionBtn("🔗 Copy Catalog Links", Color3.fromRGB(80,55,180), 396, function()
        local lines={}
        for _,item in pairs(scannedItems) do
            table.insert(lines,"https://www.roblox.com/catalog/"..item.id.." ("..item.name..")")
        end
        if setclipboard then
            setclipboard(table.concat(lines,"\n"))
            Luna:Notification({Title="Copied!",Icon="link",ImageSource="Material",Content="Links copied!",Duration=3})
        end
    end)

    makeActionBtn("🔄 Rescan", Color3.fromRGB(90,70,25), 432, function()
        gui:Destroy()
        openAvatarViewer(targetPlayer)
    end)

    -- ── RIGHT panel (scrollable item list) ──
    local rp = Instance.new("Frame")
    rp.Size = UDim2.new(1,-210,1,-46)
    rp.Position = UDim2.new(0,210,0,46)
    rp.BackgroundColor3 = Color3.fromRGB(12,12,18)
    rp.BorderSizePixel = 0
    rp.Parent = mf

    -- Divider
    local div = Instance.new("Frame")
    div.Size = UDim2.new(0,1,1,0)
    div.BackgroundColor3 = Color3.fromRGB(35,35,55)
    div.BorderSizePixel = 0
    div.Parent = rp

    -- Search
    local sb = Instance.new("TextBox")
    sb.Size = UDim2.new(1,-14,0,28)
    sb.Position = UDim2.new(0,7,0,7)
    sb.BackgroundColor3 = Color3.fromRGB(26,26,38)
    sb.BorderSizePixel = 0
    sb.PlaceholderText = "🔍  Filter by name, type, or ID..."
    sb.PlaceholderColor3 = Color3.fromRGB(90,90,120)
    sb.Text = ""
    sb.TextColor3 = Color3.fromRGB(220,220,240)
    sb.Font = Enum.Font.Gotham
    sb.TextSize = 12
    sb.ClearTextOnFocus = false
    sb.Parent = rp
    Instance.new("UICorner",sb).CornerRadius = UDim.new(0,6)

    -- Scroll
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,-6,1,-42)
    scroll.Position = UDim2.new(0,3,0,38)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70,70,110)
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.BorderSizePixel = 0
    scroll.Parent = rp

    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0,4)
    ll.Parent = scroll
    local lpad = Instance.new("UIPadding")
    lpad.PaddingTop = UDim.new(0,4)
    lpad.PaddingLeft = UDim.new(0,4)
    lpad.PaddingRight = UDim.new(0,4)
    lpad.Parent = scroll

    local typeColors = {
        ["Hat"]="ff6633",["Hair"]="cc55cc",["Face"]="55aaee",["Face Accessory"]="44ccdd",
        ["Shirt"]="44bb77",["Pants"]="4466dd",["T-Shirt"]="77cc44",["Back"]="ddaa33",
        ["Neck"]="aa66dd",["Shoulders"]="dd5577",["Waist"]="55ddaa",["Front"]="dddd44",
    }
    local function typeColor(cat)
        for k,v in pairs(typeColors) do
            if cat:find(k) then return Color3.fromHex(v) end
        end
        return Color3.fromRGB(120,100,180) -- default purple for 3D/layered
    end

    local allCards = {}
    local function buildCards(filter)
        for _,c in pairs(allCards) do pcall(function() c:Destroy() end) end
        allCards = {}
        local f = filter and filter:lower() or ""
        for _, item in pairs(scannedItems) do
            if f=="" or item.name:lower():find(f) or item.assetType:lower():find(f) or item.id:find(f) then
                local card = Instance.new("Frame")
                card.Size = UDim2.new(1,0,0,62)
                card.BackgroundColor3 = Color3.fromRGB(20,20,32)
                card.BorderSizePixel = 0
                card.Parent = scroll
                Instance.new("UICorner",card).CornerRadius = UDim.new(0,8)
                table.insert(allCards,card)

                -- Color bar
                local bar = Instance.new("Frame")
                bar.Size = UDim2.new(0,4,1,-8)
                bar.Position = UDim2.new(0,3,0,4)
                bar.BackgroundColor3 = typeColor(item.assetType)
                bar.BorderSizePixel = 0
                bar.Parent = card
                Instance.new("UICorner",bar).CornerRadius = UDim.new(0,2)

                -- Thumbnail
                local th = Instance.new("ImageLabel")
                th.Size = UDim2.new(0,48,0,48)
                th.Position = UDim2.new(0,11,0,7)
                th.BackgroundColor3 = Color3.fromRGB(28,28,42)
                th.BorderSizePixel = 0
                th.Image = item.thumbUrl
                th.ScaleType = Enum.ScaleType.Fit
                th.Parent = card
                Instance.new("UICorner",th).CornerRadius = UDim.new(0,6)

                -- Name
                local nl = Instance.new("TextLabel")
                nl.Size = UDim2.new(1,-190,0,20)
                nl.Position = UDim2.new(0,66,0,6)
                nl.BackgroundTransparency = 1
                nl.Text = item.name
                nl.TextColor3 = Color3.fromRGB(235,235,255)
                nl.Font = Enum.Font.GothamBold
                nl.TextSize = 11
                nl.TextXAlignment = Enum.TextXAlignment.Left
                nl.TextTruncate = Enum.TextTruncate.AtEnd
                nl.Parent = card

                -- Type badge
                local badge = Instance.new("TextLabel")
                badge.Size = UDim2.new(0,0,0,16)
                badge.AutomaticSize = Enum.AutomaticSize.X
                badge.Position = UDim2.new(0,66,0,28)
                badge.BackgroundColor3 = typeColor(item.assetType)
                badge.BackgroundTransparency = 0.55
                badge.Text = "  "..item.assetType.."  "
                badge.TextColor3 = Color3.fromRGB(255,255,255)
                badge.Font = Enum.Font.Gotham
                badge.TextSize = 9
                badge.BorderSizePixel = 0
                badge.Parent = card
                Instance.new("UICorner",badge).CornerRadius = UDim.new(0,3)

                -- ID
                local idL = Instance.new("TextLabel")
                idL.Size = UDim2.new(1,-190,0,14)
                idL.Position = UDim2.new(0,66,1,-20)
                idL.BackgroundTransparency = 1
                idL.Text = "ID: "..item.id
                idL.TextColor3 = Color3.fromRGB(110,110,145)
                idL.Font = Enum.Font.Gotham
                idL.TextSize = 9
                idL.TextXAlignment = Enum.TextXAlignment.Left
                idL.Parent = card

                -- Try On button
                local tryBtn = Instance.new("TextButton")
                tryBtn.Size = UDim2.new(0,52,0,20)
                tryBtn.Position = UDim2.new(1,-172,0.5,-10)
                tryBtn.BackgroundColor3 = Color3.fromRGB(130,50,200)
                tryBtn.Text = "Try On"
                tryBtn.TextColor3 = Color3.fromRGB(255,255,255)
                tryBtn.Font = Enum.Font.GothamBold
                tryBtn.TextSize = 9
                tryBtn.BorderSizePixel = 0
                tryBtn.Parent = card
                Instance.new("UICorner",tryBtn).CornerRadius = UDim.new(0,4)
                tryBtn.MouseButton1Click:Connect(function()
                    tryOnItem(item)
                    tryBtn.Text = "✓ On!"
                    tryBtn.BackgroundColor3 = Color3.fromRGB(40,160,80)
                    task.delay(2, function()
                        tryBtn.Text = "Try On"
                        tryBtn.BackgroundColor3 = Color3.fromRGB(130,50,200)
                    end)
                end)

                -- Copy ID button
                local cpBtn = Instance.new("TextButton")
                cpBtn.Size = UDim2.new(0,52,0,20)
                cpBtn.Position = UDim2.new(1,-115,0.5,-10)
                cpBtn.BackgroundColor3 = Color3.fromRGB(45,95,185)
                cpBtn.Text = "Copy ID"
                cpBtn.TextColor3 = Color3.fromRGB(255,255,255)
                cpBtn.Font = Enum.Font.GothamBold
                cpBtn.TextSize = 9
                cpBtn.BorderSizePixel = 0
                cpBtn.Parent = card
                Instance.new("UICorner",cpBtn).CornerRadius = UDim.new(0,4)
                cpBtn.MouseButton1Click:Connect(function()
                    if setclipboard then
                        setclipboard(item.id)
                        cpBtn.Text = "✓"
                        task.delay(1.5, function() cpBtn.Text = "Copy ID" end)
                    end
                end)

                -- Catalog button
                local catBtn = Instance.new("TextButton")
                catBtn.Size = UDim2.new(0,54,0,20)
                catBtn.Position = UDim2.new(1,-58,0.5,-10)
                catBtn.BackgroundColor3 = Color3.fromRGB(35,145,70)
                catBtn.Text = "Catalog🔗"
                catBtn.TextColor3 = Color3.fromRGB(255,255,255)
                catBtn.Font = Enum.Font.GothamBold
                catBtn.TextSize = 9
                catBtn.BorderSizePixel = 0
                catBtn.Parent = card
                Instance.new("UICorner",catBtn).CornerRadius = UDim.new(0,4)
                catBtn.MouseButton1Click:Connect(function()
                    if setclipboard then
                        setclipboard("https://www.roblox.com/catalog/"..item.id)
                        catBtn.Text = "Copied!"
                        task.delay(1.5, function() catBtn.Text = "Catalog🔗" end)
                    end
                end)
            end
        end
    end

    buildCards("")
    sb:GetPropertyChangedSignal("Text"):Connect(function() buildCards(sb.Text) end)

    -- Draggable
    local dragging, dragStart, startPos = false, nil, nil
    tb.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging=true dragStart=inp.Position startPos=mf.Position
        end
    end)
    tb.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    UIS.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local d=inp.Position-dragStart
            mf.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)

    Luna:Notification({Title="Avatar Reader",Icon="checkroom",ImageSource="Material",
        Content="Scanned "..#scannedItems.." items from "..targetPlayer.Name,Duration=4})
end

-- Scan button
AvatarTab:CreateButton({
    Name = "Scan & Open Viewer",
    Description = "Opens the full avatar viewer popup",
    Callback = function()
        local t = Players:FindFirstChild(avatarTargetName)
        if not t then
            Luna:Notification({Title="Not Found",Icon="error",ImageSource="Material",
                Content="'"..avatarTargetName.."' not in server.",Duration=3})
            return
        end
        openAvatarViewer(t)
    end,
})

AvatarTab:CreateDivider()
AvatarTab:CreateSection("Quick Scan")

AvatarTab:CreateButton({
    Name = "Scan MY Avatar",
    Description = "View your own outfit",
    Callback = function() openAvatarViewer(LP) end,
})

AvatarTab:CreateButton({
    Name = "List All Players",
    Description = "Shows everyone online in a notification",
    Callback = function()
        local names={}
        for _,p in pairs(Players:GetPlayers()) do
            if p~=LP then table.insert(names,p.Name) end
        end
        Luna:Notification({Title="Players Online",Icon="people",ImageSource="Material",
            Content=#names>0 and table.concat(names,", ") or "No other players",Duration=7})
    end,
})

-- ══════════════════════════════════════════════
--           🗑️ SPAM TAB (Visible to All)
-- ══════════════════════════════════════════════
local SpamTab = Window:CreateTab({
    Name = "Spam",
    Icon = "campaign",
    ImageSource = "Material",
    ShowTitle = true,
})

SpamTab:CreateSection("Trash Spam (Visible to All)")

local trashTarget = ""
SpamTab:CreateInput({
    Name = "Trash Target (leave blank = spam self)",
    Description = "Player name to surround with trash, or blank for yourself",
    PlaceholderText = "Player name or leave blank...",
    CurrentValue = "", Numeric = false, MaxCharacters = nil, Enter = true,
    Callback = function(v) trashTarget = v end,
}, "TrashTarget")

-- Trash spam: spawns dozens of ugly colored parts around the target
SpamTab:CreateToggle({
    Name = "Trash Spam (Visible)",
    Description = "Constantly spawns trash parts around target — visible to all",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("TrashSpam", function()
                local origin
                if trashTarget~="" then
                    local tp = Players:FindFirstChild(trashTarget)
                    if tp and tp.Character then
                        local r = tp.Character:FindFirstChild("HumanoidRootPart")
                        if r then origin = r.Position end
                    end
                else
                    local r = getRoot()
                    if r then origin = r.Position end
                end
                if not origin then return end

                local trashColors = {
                    Color3.fromRGB(80,60,40),   -- brown
                    Color3.fromRGB(50,50,50),   -- dark grey
                    Color3.fromRGB(60,80,40),   -- dirty green
                    Color3.fromRGB(100,80,50),  -- tan
                    Color3.fromRGB(70,50,30),   -- dark brown
                }
                local trashShapes = {
                    Vector3.new(0.3,0.5,0.3),
                    Vector3.new(0.8,0.2,0.4),
                    Vector3.new(0.4,0.4,0.4),
                    Vector3.new(1,0.2,0.5),
                    Vector3.new(0.3,0.8,0.3),
                }
                for i=1,5 do
                    local p = Instance.new("Part")
                    p.Size = trashShapes[math.random(#trashShapes)]
                    p.Color = trashColors[math.random(#trashColors)]
                    p.Material = Enum.Material.SmoothPlastic
                    p.CFrame = CFrame.new(
                        origin+Vector3.new(math.random(-6,6),math.random(2,8),math.random(-6,6))
                    )
                    p.Velocity = Vector3.new(math.random(-5,5),math.random(-3,3),math.random(-5,5))
                    p.Parent = workspace
                    Debris:AddItem(p, 12)
                end
            end, 0.15)
        else
            stopLoop("TrashSpam")
        end
    end,
}, "TrashSpam")

SpamTab:CreateDivider()
SpamTab:CreateSection("Physical Spam (Visible to All)")

-- Ball Spam: continuously fires neon balls in random directions
SpamTab:CreateToggle({
    Name = "Neon Ball Spam (Visible)",
    Description = "Constantly launches neon balls in all directions",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("BallSpam", function()
                local root = getRoot()
                if not root then return end
                local ball = Instance.new("Part")
                ball.Shape = Enum.PartType.Ball
                ball.Size = Vector3.new(4,4,4)
                ball.BrickColor = BrickColor.Random()
                ball.Material = Enum.Material.Neon
                ball.CFrame = CFrame.new(root.Position+Vector3.new(0,3,0))
                ball.Velocity = Vector3.new(math.random(-80,80),math.random(20,60),math.random(-80,80))
                ball.Parent = workspace
                Debris:AddItem(ball,8)
            end, 0.2)
        else
            stopLoop("BallSpam")
        end
    end,
}, "BallSpam")

-- Explosion Spam: real Explosion instances (visible physics and visual)
SpamTab:CreateToggle({
    Name = "Explosion Spam (Visible)",
    Description = "Creates explosions around your position continuously",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("ExplosionSpam", function()
                local root = getRoot()
                if not root then return end
                local e = Instance.new("Explosion")
                e.Position = root.Position + Vector3.new(math.random(-10,10),0,math.random(-10,10))
                e.BlastRadius = 8
                e.BlastPressure = 0  -- 0 = visual only, won't kill
                e.Parent = workspace
            end, 0.5)
        else
            stopLoop("ExplosionSpam")
        end
    end,
}, "ExplosionSpam")

-- Brick Spam: constant rain of bricks from above
SpamTab:CreateToggle({
    Name = "Brick Rain (Visible)",
    Description = "Constant bricks falling from the sky",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("BrickRain", function()
                local root = getRoot()
                if not root then return end
                local p = Instance.new("Part")
                p.Size = Vector3.new(math.random(1,4),math.random(1,4),math.random(1,4))
                p.BrickColor = BrickColor.Random()
                p.Material = Enum.Material.SmoothPlastic
                p.CFrame = CFrame.new(root.Position+Vector3.new(math.random(-15,15),math.random(25,50),math.random(-15,15)))
                p.Velocity = Vector3.new(math.random(-10,10),-20,math.random(-10,10))
                p.Parent = workspace
                Debris:AddItem(p,15)
            end, 0.1)
        else
            stopLoop("BrickRain")
        end
    end,
}, "BrickRain")

-- Giant Part Spam: massive colorful blocks
SpamTab:CreateToggle({
    Name = "Giant Block Spam (Visible)",
    Description = "Spawns huge neon blocks around the map",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("GiantBlocks", function()
                local root = getRoot()
                if not root then return end
                local p = Instance.new("Part")
                p.Size = Vector3.new(math.random(8,20),math.random(8,20),math.random(8,20))
                p.BrickColor = BrickColor.Random()
                p.Material = Enum.Material.Neon
                p.CFrame = CFrame.new(root.Position+Vector3.new(math.random(-30,30),math.random(5,30),math.random(-30,30)))
                p.Velocity = Vector3.new(math.random(-20,20),math.random(-10,30),math.random(-20,20))
                p.Parent = workspace
                Debris:AddItem(p,20)
            end, 0.4)
        else
            stopLoop("GiantBlocks")
        end
    end,
}, "GiantBlocks")

-- Part Wall: builds a wall in front of you that blocks everyone
SpamTab:CreateButton({
    Name = "Spawn Wall in Front (Visible)",
    Description = "Builds a solid wall blocking players in front of you",
    Callback = function()
        local root = getRoot()
        if not root then return end
        for i=-3,3 do
            for j=0,4 do
                local p = Instance.new("Part")
                p.Size = Vector3.new(4,4,0.5)
                p.CFrame = root.CFrame * CFrame.new(i*4, j*4, -6)
                p.Anchored = true
                p.BrickColor = BrickColor.new("Bright red")
                p.Material = Enum.Material.Neon
                p.Parent = workspace
                Debris:AddItem(p,30)
            end
        end
    end,
})

-- Litter the map: spam static anchored trash everywhere around map
SpamTab:CreateButton({
    Name = "Litter Whole Map (Visible)",
    Description = "Scatters 60 random parts across the map instantly",
    Callback = function()
        local root = getRoot()
        if not root then return end
        task.spawn(function()
            for i=1,60 do
                local p = Instance.new("Part")
                p.Size = Vector3.new(math.random(1,3),math.random(1,3),math.random(1,3))
                p.BrickColor = BrickColor.Random()
                p.Material = math.random(2)==1 and Enum.Material.Neon or Enum.Material.SmoothPlastic
                p.CFrame = CFrame.new(root.Position+Vector3.new(math.random(-80,80),math.random(2,15),math.random(-80,80)))
                p.Parent = workspace
                Debris:AddItem(p,60)
                task.wait(0.02)
            end
        end)
    end,
})

SpamTab:CreateDivider()
SpamTab:CreateSection("Chat Spam (Visible to All)")

local chatMsg = "w s f  l o a d e r  . g g"
SpamTab:CreateInput({
    Name = "Chat Message",
    Description = "Message to spam in server chat",
    PlaceholderText = "Type message...",
    CurrentValue = "", Numeric = false, MaxCharacters = nil, Enter = true,
    Callback = function(v) if v~="" then chatMsg=v end end,
}, "ChatMsg")

SpamTab:CreateToggle({
    Name = "Chat Spam",
    Description = "Sends your message in chat every 0.6s",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("ChatSpam", function()
                pcall(function()
                    local tcs = game:GetService("TextChatService")
                    local ch = tcs.TextChannels:FindFirstChildOfClass("TextChannel")
                    if ch then ch:SendAsync(chatMsg) end
                end)
            end, 0.6)
        else stopLoop("ChatSpam") end
    end,
}, "ChatSpam")

-- ══════════════════════════════════════════════
--               🎯 FLING TAB
-- ══════════════════════════════════════════════
local FlingTab = Window:CreateTab({
    Name = "Fling",
    Icon = "whatshot",
    ImageSource = "Material",
    ShowTitle = true,
})

FlingTab:CreateSection("Target")

local targetName = ""
FlingTab:CreateInput({
    Name = "Target Name",
    Description = "Exact Roblox username",
    PlaceholderText = "Enter player name...",
    CurrentValue = "", Numeric = false, MaxCharacters = nil, Enter = true,
    Callback = function(v) targetName = v end,
}, "TargetInput")

local function getTarget() return Players:FindFirstChild(targetName) end

local flingActive = false
FlingTab:CreateToggle({
    Name = "FE Fling Target",
    Description = "Visible to all players",
    CurrentValue = false,
    Callback = function(Value)
        flingActive = Value
        if not Value then
            local h=getHum() if h then h.PlatformStand=false end
            local r=getRoot()
            if r then
                local bav=r:FindFirstChild("FlingBAV") local bv=r:FindFirstChild("FlingBV")
                if bav then bav:Destroy() end if bv then bv:Destroy() end
            end
            return
        end
        task.spawn(function()
            while flingActive do
                local t=getTarget() local myRoot=getRoot() local myHum=getHum()
                if t and t.Character and myRoot and myHum then
                    local tRoot=t.Character:FindFirstChild("HumanoidRootPart")
                    if tRoot then
                        myHum.PlatformStand=true
                        myRoot.CFrame=tRoot.CFrame*CFrame.new(0,0,0.5)
                        local bav=Instance.new("BodyAngularVelocity")
                        bav.Name="FlingBAV" bav.AngularVelocity=Vector3.new(9999,9999,9999)
                        bav.MaxTorque=Vector3.new(9e9,9e9,9e9) bav.P=9e9 bav.Parent=myRoot
                        local bv=Instance.new("BodyVelocity")
                        bv.Name="FlingBV" bv.Velocity=Vector3.new(math.random(-200,200),math.random(150,300),math.random(-200,200))
                        bv.MaxForce=Vector3.new(9e9,9e9,9e9) bv.P=9e9 bv.Parent=myRoot
                        task.wait(0.15) bav:Destroy() bv:Destroy()
                        myHum.PlatformStand=false task.wait(0.1)
                    end
                end
                task.wait(0.05)
            end
        end)
    end,
}, "FEFling")

local flingAllActive = false
FlingTab:CreateToggle({
    Name = "Fling ALL Players",
    Description = "Cycles and flings every player",
    CurrentValue = false,
    Callback = function(Value)
        flingAllActive = Value
        if Value then
            task.spawn(function()
                while flingAllActive do
                    local myRoot=getRoot() local myHum=getHum()
                    if myRoot and myHum then
                        for _,plr in pairs(Players:GetPlayers()) do
                            if plr~=LP and plr.Character then
                                local tRoot=plr.Character:FindFirstChild("HumanoidRootPart")
                                if tRoot then
                                    myHum.PlatformStand=true
                                    myRoot.CFrame=tRoot.CFrame*CFrame.new(0,0,0.5)
                                    local bav=Instance.new("BodyAngularVelocity")
                                    bav.AngularVelocity=Vector3.new(9999,9999,9999) bav.MaxTorque=Vector3.new(9e9,9e9,9e9) bav.P=9e9 bav.Parent=myRoot
                                    local bv=Instance.new("BodyVelocity")
                                    bv.Velocity=Vector3.new(math.random(-300,300),math.random(200,500),math.random(-300,300)) bv.MaxForce=Vector3.new(9e9,9e9,9e9) bv.P=9e9 bv.Parent=myRoot
                                    task.wait(0.12) bav:Destroy() bv:Destroy() myHum.PlatformStand=false task.wait(0.05)
                                end
                            end
                        end
                    end
                    task.wait(0.2)
                end
            end)
        end
    end,
}, "FlingAll")

FlingTab:CreateDivider()
FlingTab:CreateSection("Follow")

FlingTab:CreateToggle({
    Name = "Follow Target",
    Description = "Walk to target using Humanoid:MoveTo",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("Follow", function()
                local t=getTarget() local hum=getHum()
                if t and t.Character and hum then
                    local r=t.Character:FindFirstChild("HumanoidRootPart")
                    if r then hum:MoveTo(r.Position) end
                end
            end, 0.1)
        else stopLoop("Follow") end
    end,
}, "Follow")

FlingTab:CreateToggle({
    Name = "Sit On Target Head",
    Description = "Teleport and sit on their head constantly",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("SitHead", function()
                local t=getTarget() local myRoot=getRoot()
                if t and t.Character and myRoot then
                    local head=t.Character:FindFirstChild("Head")
                    if head then myRoot.CFrame=CFrame.new(head.Position+Vector3.new(0,3.5,0)) end
                end
            end, 0.05)
        else stopLoop("SitHead") end
    end,
}, "SitHead")

-- ══════════════════════════════════════════════
--               🚗 CARS TAB
-- ══════════════════════════════════════════════
local CarTab = Window:CreateTab({
    Name = "Cars",
    Icon = "directions_car",
    ImageSource = "Material",
    ShowTitle = true,
})

CarTab:CreateSection("Your Car (Visible to All)")

CarTab:CreateButton({
    Name = "Flip Car",
    Description = "Flips your car upside-down",
    Callback = function()
        local model=getMyVehicle()
        if model and model.PrimaryPart then
            model:SetPrimaryPartCFrame(model.PrimaryPart.CFrame*CFrame.new(0,3,0)*CFrame.Angles(math.pi,0,0))
        end
    end,
})

CarTab:CreateButton({
    Name = "Launch Car Into Sky",
    Description = "Blasts your car straight up",
    Callback = function()
        local model=getMyVehicle()
        if model then
            for _,p in pairs(model:GetDescendants()) do
                if p:IsA("BasePart") and not p.Anchored then
                    local bv=Instance.new("BodyVelocity")
                    bv.Velocity=Vector3.new(math.random(-60,60),600,math.random(-60,60))
                    bv.MaxForce=Vector3.new(9e9,9e9,9e9) bv.Parent=p Debris:AddItem(bv,0.4)
                end
            end
        end
    end,
})

CarTab:CreateToggle({
    Name = "Spin Car",
    Description = "Spins your car wildly in place",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            startLoop("CarSpin", function()
                local model=getMyVehicle()
                if model and model.PrimaryPart then
                    local bav=model.PrimaryPart:FindFirstChild("CarBAV") or Instance.new("BodyAngularVelocity")
                    bav.Name="CarBAV" bav.AngularVelocity=Vector3.new(0,80,0)
                    bav.MaxTorque=Vector3.new(0,9e9,0) bav.Parent=model.PrimaryPart
                end
            end, 0.1)
        else
            stopLoop("CarSpin")
            local model=getMyVehicle()
            if model and model.PrimaryPart then
                local b=model.PrimaryPart:FindFirstChild("CarBAV") if b then b:Destroy() end
            end
        end
    end,
}, "CarSpin")

CarTab:CreateToggle({
    Name = "Rainbow Car",
    Description = "Cycles your car through rainbow colors",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            local hue=0
            startLoop("RainbowCar", function()
                hue=(hue+0.01)%1
                local model=getMyVehicle()
                if model then
                    for _,p in pairs(model:GetDescendants()) do
                        if p:IsA("BasePart") then pcall(function() p.Color=Color3.fromHSV(hue,1,1) end) end
                    end
                end
            end, 0.05)
        else stopLoop("RainbowCar") end
    end,
}, "RainbowCar")

CarTab:CreateSlider({
    Name = "Car Max Speed",
    Description = "Override your seat MaxSpeed",
    Range = {0,500}, Increment = 10, CurrentValue = 100,
    Callback = function(v)
        local _,seat=getMyVehicle()
        if seat then pcall(function() seat.MaxSpeed=v end) end
    end,
}, "CarSpeed")

CarTab:CreateDivider()
CarTab:CreateSection("Other Cars")

CarTab:CreateButton({
    Name = "Delete Nearest Car",
    Description = "Destroys the closest car to you",
    Callback = function()
        local root=getRoot() if not root then return end
        local closest,dist=nil,math.huge
        for _,v in pairs(workspace:GetDescendants()) do
            if v:IsA("VehicleSeat") then
                local m=v:FindFirstAncestorOfClass("Model")
                if m and m.PrimaryPart then
                    local d=(m.PrimaryPart.Position-root.Position).Magnitude
                    if d<dist then dist=d; closest=m end
                end
            end
        end
        if closest and dist<120 then closest:Destroy() end
    end,
})

-- ══════════════════════════════════════════════
--               🌍 GRIEF TAB
-- ══════════════════════════════════════════════
local GriefTab = Window:CreateTab({
    Name = "Grief",
    Icon = "public",
    ImageSource = "Material",
    ShowTitle = true,
})

GriefTab:CreateSection("World Grief (Visible to All)")

GriefTab:CreateButton({
    Name = "Brick Bomb",
    Description = "Drops 30 bricks from the sky",
    Callback = function()
        local root=getRoot() if not root then return end
        task.spawn(function()
            for i=1,30 do
                local p=Instance.new("Part")
                p.Size=Vector3.new(math.random(2,5),math.random(2,5),math.random(2,5))
                p.BrickColor=BrickColor.Random() p.Material=Enum.Material.SmoothPlastic
                p.CFrame=CFrame.new(root.Position+Vector3.new(math.random(-20,20),math.random(30,70),math.random(-20,20)))
                p.Velocity=Vector3.new(math.random(-20,20),math.random(-30,-5),math.random(-20,20))
                p.Parent=workspace Debris:AddItem(p,20) task.wait(0.05)
            end
        end)
    end,
})

GriefTab:CreateButton({
    Name = "Invisible Trap Box",
    Description = "Spawns an invisible cage around your position",
    Callback = function()
        local root=getRoot() if not root then return end
        local c=root.Position
        local walls={
            {Vector3.new(0.5,12,12),Vector3.new(6,6,0)},{Vector3.new(0.5,12,12),Vector3.new(-6,6,0)},
            {Vector3.new(12,12,0.5),Vector3.new(0,6,6)},{Vector3.new(12,12,0.5),Vector3.new(0,6,-6)},
            {Vector3.new(12,0.5,12),Vector3.new(0,12,0)},
        }
        for _,w in pairs(walls) do
            local p=Instance.new("Part")
            p.Size=w[1] p.CFrame=CFrame.new(c+w[2])
            p.Anchored=true p.Transparency=1 p.CanCollide=true p.Parent=workspace Debris:AddItem(p,30)
        end
    end,
})

local floodPart=nil
GriefTab:CreateToggle({
    Name = "Rising Flood",
    Description = "A giant water plane rises across the map",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            floodPart=Instance.new("Part")
            floodPart.Size=Vector3.new(2000,1,2000) floodPart.CFrame=CFrame.new(0,-60,0)
            floodPart.Anchored=true floodPart.CanCollide=true
            floodPart.BrickColor=BrickColor.new("Bright blue") floodPart.Material=Enum.Material.Neon
            floodPart.Transparency=0.4 floodPart.Parent=workspace
            startLoop("Flood", function()
                if floodPart and floodPart.Parent then
                    floodPart.CFrame=floodPart.CFrame+Vector3.new(0,0.4,0)
                    if floodPart.Position.Y>200 then floodPart.CFrame=CFrame.new(0,-60,0) end
                end
            end, 0.05)
        else
            stopLoop("Flood")
            if floodPart then floodPart:Destroy(); floodPart=nil end
        end
    end,
}, "Flood")

local platformPart=nil
GriefTab:CreateToggle({
    Name = "Neon Platform Follow",
    Description = "Glowing platform follows you everywhere",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            platformPart=Instance.new("Part")
            platformPart.Size=Vector3.new(20,1,20) platformPart.Anchored=true
            platformPart.BrickColor=BrickColor.new("Bright red") platformPart.Material=Enum.Material.Neon
            platformPart.Transparency=0.2 platformPart.CanCollide=true platformPart.Parent=workspace
            startLoop("Platform", function()
                local r=getRoot()
                if r and platformPart and platformPart.Parent then
                    platformPart.CFrame=CFrame.new(r.Position.X,r.Position.Y-3,r.Position.Z)
                end
            end, 0.05)
        else
            stopLoop("Platform")
            if platformPart then platformPart:Destroy(); platformPart=nil end
        end
    end,
}, "Platform")

GriefTab:CreateToggle({
    Name = "Rave Lights",
    Description = "Flickers all map lights on and off",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            local on=true
            startLoop("RaveLights", function()
                on=not on
                for _,l in pairs(workspace:GetDescendants()) do
                    if l:IsA("PointLight") or l:IsA("SpotLight") or l:IsA("SurfaceLight") then
                        pcall(function() l.Enabled=on end)
                    end
                end
            end, 0.1)
        else
            stopLoop("RaveLights")
            for _,l in pairs(workspace:GetDescendants()) do
                if l:IsA("PointLight") or l:IsA("SpotLight") or l:IsA("SurfaceLight") then
                    pcall(function() l.Enabled=true end)
                end
            end
        end
    end,
}, "RaveLights")

GriefTab:CreateButton({
    Name = "Launch Neon Ball",
    Description = "Fires a huge rolling ball in your camera direction",
    Callback = function()
        local root=getRoot() if not root then return end
        local ball=Instance.new("Part")
        ball.Shape=Enum.PartType.Ball ball.Size=Vector3.new(8,8,8)
        ball.BrickColor=BrickColor.new("Bright orange") ball.Material=Enum.Material.Neon
        ball.CFrame=CFrame.new(root.Position+Vector3.new(0,4,0))
        ball.Velocity=workspace.CurrentCamera.CFrame.LookVector*250
        ball.Parent=workspace Debris:AddItem(ball,15)
    end,
})

-- ══════════════════════════════════════════════
--             🏃 MOVEMENT TAB
-- ══════════════════════════════════════════════
local MoveTab = Window:CreateTab({
    Name = "Movement",
    Icon = "directions_run",
    ImageSource = "Material",
    ShowTitle = true,
})

MoveTab:CreateSection("Speed & Jump")

MoveTab:CreateSlider({
    Name = "Walk Speed", Description = nil,
    Range = {16,500}, Increment = 1, CurrentValue = 16,
    Callback = function(v) local h=getHum() if h then h.WalkSpeed=v end end,
}, "WalkSpeed")

MoveTab:CreateSlider({
    Name = "Jump Power", Description = nil,
    Range = {50,500}, Increment = 1, CurrentValue = 50,
    Callback = function(v) local h=getHum() if h then h.JumpPower=v end end,
}, "JumpPower")

MoveTab:CreateToggle({
    Name = "Infinite Jump", Description = nil, CurrentValue = false,
    Callback = function(Value)
        _G.InfJump=Value
        if Value then
            UIS.JumpRequest:Connect(function()
                if _G.InfJump then local h=getHum() if h then h:ChangeState("Jumping") end end
            end)
        end
    end,
}, "InfJump")

MoveTab:CreateDivider()
MoveTab:CreateSection("Fly  (WASD + Space / Shift)")

MoveTab:CreateToggle({
    Name = "Fly", Description = nil, CurrentValue = false,
    Callback = function(Value)
        local root=getRoot() local hum=getHum()
        if not root or not hum then return end
        _G.Flying=Value
        if Value then
            hum.PlatformStand=true
            local bv=Instance.new("BodyVelocity")
            bv.Name="FlyBV" bv.Velocity=Vector3.zero bv.MaxForce=Vector3.new(9e9,9e9,9e9) bv.Parent=root
            local bg=Instance.new("BodyGyro")
            bg.Name="FlyBG" bg.MaxTorque=Vector3.new(9e9,9e9,9e9) bg.P=1e4 bg.CFrame=root.CFrame bg.Parent=root
            task.spawn(function()
                while _G.Flying and root and root.Parent do
                    local spd=_G.FlySpeed or 60
                    local cam=workspace.CurrentCamera
                    local mv=Vector3.zero
                    if UIS:IsKeyDown(Enum.KeyCode.W) then mv+=cam.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.S) then mv-=cam.CFrame.LookVector end
                    if UIS:IsKeyDown(Enum.KeyCode.A) then mv-=cam.CFrame.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.D) then mv+=cam.CFrame.RightVector end
                    if UIS:IsKeyDown(Enum.KeyCode.Space) then mv+=Vector3.new(0,1,0) end
                    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv-=Vector3.new(0,1,0) end
                    bv.Velocity=mv.Magnitude>0 and mv.Unit*spd or Vector3.zero
                    bg.CFrame=cam.CFrame task.wait()
                end
            end)
        else
            hum.PlatformStand=false
            local bv=root:FindFirstChild("FlyBV") if bv then bv:Destroy() end
            local bg=root:FindFirstChild("FlyBG") if bg then bg:Destroy() end
        end
    end,
}, "Fly")

MoveTab:CreateSlider({
    Name = "Fly Speed", Description = nil,
    Range = {10,500}, Increment = 10, CurrentValue = 60,
    Callback = function(v) _G.FlySpeed=v end,
}, "FlySpeed")

MoveTab:CreateDivider()
MoveTab:CreateSection("Utility")

MoveTab:CreateToggle({
    Name = "Noclip", Description = "Walk through walls", CurrentValue = false,
    Callback = function(Value)
        _G.Noclip=Value
        if Value then
            RunService.Stepped:Connect(function()
                if _G.Noclip then
                    local c=getChar()
                    if c then for _,p in pairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide=false end
                    end end
                end
            end)
        end
    end,
}, "Noclip")

MoveTab:CreateToggle({
    Name = "Anti AFK", Description = nil, CurrentValue = false,
    Callback = function(Value)
        if Value then
            local VU=game:GetService("VirtualUser")
            LP.Idled:Connect(function()
                VU:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
                task.wait(1)
                VU:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
            end)
        end
    end,
}, "AntiAFK")

-- ══════════════════════════════════════════════
--                CONFIG TAB
-- ══════════════════════════════════════════════
local ConfigTab = Window:CreateTab({
    Name = "Config",
    Icon = "save",
    ImageSource = "Material",
    ShowTitle = true,
})
ConfigTab:BuildConfigSection()

Luna:Notification({
    Title = "w s f  l o a d e r  . g g",
    Icon = "check_circle",
    ImageSource = "Material",
    Content = "Loaded! Check Avatar Reader & Spam tabs.",
    Duration = 5,
})
