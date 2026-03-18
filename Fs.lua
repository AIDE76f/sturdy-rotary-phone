local player = game.Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

if guiParent:FindFirstChild("TopCarsScanner") then
    guiParent.TopCarsScanner:Destroy()
end

--------------------------------------------------
-- 1. تصميم واجهة تعرض "أعلى 5 نتائج"
--------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TopCarsScanner"
screenGui.Parent = guiParent

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 400, 0, 350)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "🏆 أعلى 5 أسعار في السيرفر حالياً"
title.TextColor3 = Color3.fromRGB(0, 255, 150)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -100)
scrollFrame.Position = UDim2.new(0, 10, 0, 45)
scrollFrame.BackgroundTransparency = 1
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ScrollBarThickness = 5
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = scrollFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 100, 0, 35)
closeBtn.Position = UDim2.new(0.5, -50, 1, -45)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "إغلاق"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = mainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

--------------------------------------------------
-- 2. تحويل الأرقام العربية واستخراج الرقم الأكبر
--------------------------------------------------
local function convertArabicNumbers(str)
    local map = {
        ["٠"]="0", ["١"]="1", ["٢"]="2", ["٣"]="3", ["٤"]="4",
        ["٥"]="5", ["٦"]="6", ["٧"]="7", ["٨"]="8", ["٩"]="9",
        [","]="", ["،"]="", [" "]="", ["\n"]=""
    }
    local res = str
    for ar, en in pairs(map) do
        res = string.gsub(res, ar, en)
    end
    return res
end

local function extractMaxNumber(text)
    if not text then return 0 end
    local cleanText = convertArabicNumbers(text)
    local maxN = 0
    for numStr in string.gmatch(cleanText, "%d+") do
        local num = tonumber(numStr)
        if num and num > maxN then maxN = num end
    end
    return maxN
end

--------------------------------------------------
-- 3. مسح الخريطة وجمع كل الأسعار
--------------------------------------------------
local foundPrices = {}

local function registerPrice(obj, price, typeFound)
    -- نتجاهل الأرقام الصغيرة (مثل الموديلات 2023) لتجنب التلوث
    if price < 5000 then return end 

    -- البحث عن المجسم الرئيسي المرتبط بهذا السعر
    local mainModel = obj
    while mainModel and mainModel.Parent ~= workspace and not mainModel:IsA("Model") do
        mainModel = mainModel.Parent
    end
    if not mainModel then mainModel = obj end

    -- تسجيل المجسم إذا كان جديداً أو تحديث سعره إذا وجدنا سعراً أعلى له
    if not foundPrices[mainModel] or price > foundPrices[mainModel].price then
        local pos = Vector3.new(0,0,0)
        pcall(function() pos = mainModel:GetPivot().Position end)
        
        foundPrices[mainModel] = {
            price = price,
            name = mainModel.Name,
            pos = pos,
            typeInfo = typeFound
        }
    end
end

-- البحث في جميع الكائنات
for _, obj in pairs(workspace:GetDescendants()) do
    
    -- 1. اللوحات ثلاثية الأبعاد (فوق السيارات)
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        if obj:FindFirstAncestorWhichIsA("BillboardGui") or obj:FindFirstAncestorWhichIsA("SurfaceGui") then
            local p = extractMaxNumber(obj.Text)
            if p > 0 then registerPrice(obj, p, "لوحة 3D") end
        end
    end
    
    -- 2. أزرار التفاعل (مثل: اضغط E للشراء بـ 500000)
    if obj:IsA("ProximityPrompt") then
        local text = obj.ActionText .. " " .. obj.ObjectText
        local p = extractMaxNumber(text)
        if p > 0 then registerPrice(obj, p, "زر تفاعل (E)") end
    end
    
    -- 3. القيم البرمجية المخفية
    if obj:IsA("IntValue") or obj:IsA("NumberValue") then
        local n = string.lower(obj.Name)
        if string.find(n, "price") or string.find(n, "cost") or string.find(n, "value") then
            registerPrice(obj, obj.Value, "قيمة مخفية")
        end
    end
end

--------------------------------------------------
-- 4. ترتيب النتائج وعرضها في الواجهة
--------------------------------------------------
local sortedResults = {}
for model, data in pairs(foundPrices) do
    table.insert(sortedResults, data)
end

-- ترتيب تنازلي (الأغلى أولاً)
table.sort(sortedResults, function(a, b)
    return a.price > b.price
end)

if #sortedResults > 0 then
    -- عرض أعلى 10 نتائج (أو أقل إذا لم يتوفر)
    local maxDisplay = math.min(#sortedResults, 10)
    
    for i = 1, maxDisplay do
        local res = sortedResults[i]
        
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, 0, 0, 80)
        itemFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = scrollFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = itemFrame
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, -10, 1, -10)
        textLabel.Position = UDim2.new(0, 5, 0, 5)
        textLabel.BackgroundTransparency = 1
        textLabel.TextXAlignment = Enum.TextXAlignment.Right
        textLabel.TextYAlignment = Enum.TextYAlignment.Top
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.Font = Enum.Font.Gotham
        textLabel.TextSize = 13
        textLabel.TextWrapped = true
        
        local posTxt = string.format("%.1f, %.1f, %.1f", res.pos.X, res.pos.Y, res.pos.Z)
        
        -- تمييز المركز الأول بلون ذهبي
        if i == 1 then textLabel.TextColor3 = Color3.fromRGB(255, 215, 0) end
        
        textLabel.Text = 
            "#" .. i .. " السعر: " .. res.price .. " ريال\n" ..
            "الاسم: " .. res.name .. " | المصدر: " .. res.typeInfo .. "\n" ..
            "الإحداثيات: " .. posTxt
            
        textLabel.Parent = itemFrame
    end
else
    local noRes = Instance.new("TextLabel")
    noRes.Size = UDim2.new(1, 0, 0, 50)
    noRes.BackgroundTransparency = 1
    noRes.Text = "❌ لم يتم العثور على أي أسعار تتجاوز 5000 ريال في السيرفر حالياً."
    noRes.TextColor3 = Color3.fromRGB(255, 100, 100)
    noRes.Font = Enum.Font.GothamBold
    noRes.TextSize = 14
    noRes.Parent = scrollFrame
end
