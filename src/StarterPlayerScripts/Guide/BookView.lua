--!strict
-- Builds the Guide's flip-through manual as an open-book ScreenGui.
-- Two-page spread, tan pages, dark inset content cards, bottom-corner
-- arrow buttons to navigate between spreads.
--
-- Each spread is described by a PageSpread record:
-- {
--   Title        = "Stranger Danger",          -- shown across the top
--   LeftHeading  = "Risky Signs",
--   LeftImage    = "rbxassetid://0",           -- swap with real asset id
--   LeftCaption  = "the white van",
--   LeftBullets  = { "Calling you over from a parked car", ... },
--   RightHeading = "Safer Signs",
--   RightImage   = "rbxassetid://0",
--   RightCaption = "park ranger",
--   RightBullets = { "Behind a counter", ... },
-- }
--
-- The image fields default to a 1x1 placeholder so the layout still reads
-- when no asset has been uploaded yet — User 2 fills in real IDs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIStyle = require(Modules:WaitForChild("UIStyle"))

local BookView = {}
BookView.__index = BookView

export type PageBullet = string

export type PageSide = {
	Heading: string,
	Image: string?,
	Caption: string?,
	Bullets: { PageBullet }?,
	Body: string?,
}

export type PageSpread = {
	Title: string,
	Left: PageSide,
	Right: PageSide,
}

-- warm cartoon palette tuned to the reference book screenshot
local PALETTE = {
	PaperLight = Color3.fromRGB(244, 230, 200),
	PaperDark = Color3.fromRGB(220, 198, 158),
	Spine = Color3.fromRGB(76, 50, 32),
	SpineEdge = Color3.fromRGB(46, 28, 18),
	CardInset = Color3.fromRGB(204, 184, 148),
	TitleBand = Color3.fromRGB(120, 80, 50),
	Ink = Color3.fromRGB(48, 34, 20),
	InkSoft = Color3.fromRGB(96, 72, 48),
	ArrowFill = Color3.fromRGB(255, 220, 150),
	ArrowEdge = Color3.fromRGB(120, 80, 50),
	Shadow = Color3.fromRGB(20, 12, 6),
}

local function makePageSide(parent: Frame, alignment: "Left" | "Right"): {
	Container: Frame,
	Heading: TextLabel,
	Caption: TextLabel,
	ImageHolder: Frame,
	Image: ImageLabel,
	Bullets: Frame,
}
	local container = Instance.new("Frame")
	container.Name = alignment .. "Page"
	container.BackgroundColor3 = PALETTE.PaperLight
	container.BorderSizePixel = 0
	container.Size = UDim2.new(0.5, -10, 1, 0)
	if alignment == "Left" then
		container.Position = UDim2.new(0, 0, 0, 0)
	else
		container.Position = UDim2.new(0.5, 10, 0, 0)
	end
	container.Parent = parent

	-- subtle paper texture via gradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PALETTE.PaperLight),
		ColorSequenceKeypoint.new(1, PALETTE.PaperDark),
	})
	gradient.Rotation = 90
	gradient.Parent = container

	local corner = Instance.new("UICorner")
	-- pages have outer rounding only on the side away from the spine
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, alignment == "Left" and 24 or 16)
	padding.PaddingRight = UDim.new(0, alignment == "Right" and 24 or 16)
	padding.Parent = container

	-- image card — rounded inset panel with a title strip on top of the image
	local imageHolder = Instance.new("Frame")
	imageHolder.Name = "ImageHolder"
	imageHolder.BackgroundColor3 = PALETTE.CardInset
	imageHolder.BorderSizePixel = 0
	imageHolder.Size = UDim2.new(1, 0, 0, 220)
	imageHolder.Position = UDim2.new(0, 0, 0, 0)
	imageHolder.Parent = container
	UIStyle.ApplyCorner(imageHolder, UDim.new(0, 14))

	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	image.Size = UDim2.new(1, -16, 1, -52)
	image.Position = UDim2.new(0, 8, 0, 8)
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = ""
	image.Parent = imageHolder

	-- heading "name tag" — sits at the bottom of the image card
	local headingHolder = Instance.new("Frame")
	headingHolder.Name = "HeadingHolder"
	headingHolder.AnchorPoint = Vector2.new(0.5, 1)
	headingHolder.Position = UDim2.new(0.5, 0, 1, -8)
	headingHolder.Size = UDim2.new(1, -16, 0, 36)
	headingHolder.BackgroundColor3 = PALETTE.PaperLight
	headingHolder.BorderSizePixel = 0
	headingHolder.Parent = imageHolder
	UIStyle.ApplyCorner(headingHolder, UDim.new(0, 10))
	UIStyle.ApplyStroke(headingHolder, PALETTE.TitleBand, 2)

	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.BackgroundTransparency = 1
	heading.Size = UDim2.new(1, -16, 1, 0)
	heading.Position = UDim2.new(0, 8, 0, 0)
	heading.Font = UIStyle.FontBold
	heading.TextSize = 22
	heading.TextColor3 = PALETTE.Ink
	heading.TextXAlignment = Enum.TextXAlignment.Center
	heading.TextYAlignment = Enum.TextYAlignment.Center
	heading.Text = ""
	heading.Parent = headingHolder

	-- caption beneath the image card
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.Size = UDim2.new(1, 0, 0, 24)
	caption.Position = UDim2.new(0, 0, 0, 232)
	caption.Font = UIStyle.Font
	caption.TextSize = UIStyle.TextSize.Caption
	caption.TextColor3 = PALETTE.InkSoft
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextYAlignment = Enum.TextYAlignment.Center
	caption.TextWrapped = true
	caption.Text = ""
	caption.Parent = container

	-- bullet text card below caption
	local bullets = Instance.new("Frame")
	bullets.Name = "Bullets"
	bullets.BackgroundColor3 = PALETTE.CardInset
	bullets.BorderSizePixel = 0
	bullets.Size = UDim2.new(1, 0, 1, -270)
	bullets.Position = UDim2.new(0, 0, 0, 268)
	bullets.Parent = container
	UIStyle.ApplyCorner(bullets, UDim.new(0, 14))

	local bulletsPad = Instance.new("UIPadding")
	bulletsPad.PaddingTop = UDim.new(0, 10)
	bulletsPad.PaddingBottom = UDim.new(0, 10)
	bulletsPad.PaddingLeft = UDim.new(0, 14)
	bulletsPad.PaddingRight = UDim.new(0, 14)
	bulletsPad.Parent = bullets

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = bullets

	return {
		Container = container,
		Heading = heading,
		Caption = caption,
		ImageHolder = imageHolder,
		Image = image,
		Bullets = bullets,
	}
end

local function clearBullets(frame: Frame)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function addBullet(parent: Frame, text: string, order: number)
	local row = Instance.new("TextLabel")
	row.Name = "Bullet" .. order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Font = UIStyle.Font
	row.TextSize = 16
	row.TextColor3 = PALETTE.Ink
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextYAlignment = Enum.TextYAlignment.Top
	row.TextWrapped = true
	row.RichText = true
	row.Text = "• " .. text
	row.LayoutOrder = order
	row.Parent = parent
end

local function paintSide(rendered, side: PageSide)
	rendered.Heading.Text = side.Heading or ""
	rendered.Caption.Text = side.Caption or ""
	if side.Image and side.Image ~= "" then
		rendered.Image.Image = side.Image
	else
		rendered.Image.Image = ""
	end
	clearBullets(rendered.Bullets)
	if side.Bullets then
		for i, bullet in ipairs(side.Bullets) do
			addBullet(rendered.Bullets, bullet, i)
		end
	elseif side.Body then
		addBullet(rendered.Bullets, side.Body, 1)
	end
end

local function makeArrowButton(parent: Frame, name: string, label: string, anchor: "Left" | "Right"): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 64, 0, 64)
	btn.AnchorPoint = Vector2.new(anchor == "Left" and 0 or 1, 1)
	btn.Position = UDim2.new(anchor == "Left" and 0 or 1, anchor == "Left" and 24 or -24, 1, -24)
	btn.BackgroundColor3 = PALETTE.ArrowFill
	btn.AutoButtonColor = true
	btn.Text = label
	btn.Font = UIStyle.FontBold
	btn.TextSize = 36
	btn.TextColor3 = PALETTE.Ink
	btn.BorderSizePixel = 0
	btn.Parent = parent
	UIStyle.ApplyCorner(btn, UDim.new(0, 18))
	UIStyle.ApplyStroke(btn, PALETTE.ArrowEdge, 3)
	return btn
end

function BookView.new(parent: Instance, pages: { PageSpread })
	assert(#pages > 0, "BookView needs at least one page")

	local screen = Instance.new("ScreenGui")
	screen.Name = "BB_GuideBook"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 5
	screen.Parent = parent

	-- dim backdrop so the book pops against a dark scene
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Color3.fromRGB(20, 14, 8)
	backdrop.BackgroundTransparency = 0.55
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.Parent = screen

	-- centered book container with a soft drop shadow
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 22)
	shadow.Size = UDim2.new(0, 980, 0, 660)
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxasset://textures/ui/Controls/DropShadow.png"
	shadow.ImageColor3 = PALETTE.Shadow
	shadow.ImageTransparency = 0.4
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(12, 12, 244, 244)
	shadow.Parent = screen

	local book = Instance.new("Frame")
	book.Name = "Book"
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	book.Position = UDim2.new(0.5, 0, 0.5, 0)
	book.Size = UDim2.new(0, 940, 0, 620)
	book.BackgroundColor3 = PALETTE.PaperDark
	book.BorderSizePixel = 0
	book.Parent = screen
	UIStyle.ApplyCorner(book, UDim.new(0, 22))
	UIStyle.ApplyStroke(book, PALETTE.SpineEdge, 4)

	-- title band at the top (same on every page so the spread reads as one
	-- chapter — User 2 wanted "Stranger Danger" headlining the spread)
	local titleHolder = Instance.new("Frame")
	titleHolder.Name = "TitleHolder"
	titleHolder.AnchorPoint = Vector2.new(0.5, 0)
	titleHolder.Position = UDim2.new(0.5, 0, 0, -18)
	titleHolder.Size = UDim2.new(0, 360, 0, 56)
	titleHolder.BackgroundColor3 = PALETTE.TitleBand
	titleHolder.BorderSizePixel = 0
	titleHolder.Parent = book
	UIStyle.ApplyCorner(titleHolder, UDim.new(0, 14))
	UIStyle.ApplyStroke(titleHolder, PALETTE.SpineEdge, 3)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -16, 1, 0)
	title.Position = UDim2.new(0, 8, 0, 0)
	title.Font = UIStyle.FontBold
	title.TextSize = 28
	title.TextColor3 = Color3.fromRGB(255, 232, 196)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Text = ""
	title.Parent = titleHolder

	-- inner frame for the two pages — leaves room for the title + buttons
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.new(1, -32, 1, -120)
	inner.Position = UDim2.new(0, 16, 0, 60)
	inner.Parent = book

	local leftRendered = makePageSide(inner, "Left")
	local rightRendered = makePageSide(inner, "Right")

	-- spine — vertical dark band between pages
	local spine = Instance.new("Frame")
	spine.Name = "Spine"
	spine.AnchorPoint = Vector2.new(0.5, 0.5)
	spine.Position = UDim2.new(0.5, 0, 0.5, 0)
	spine.Size = UDim2.new(0, 14, 1, 0)
	spine.BackgroundColor3 = PALETTE.Spine
	spine.BorderSizePixel = 0
	spine.Parent = inner
	UIStyle.ApplyCorner(spine, UDim.new(0, 6))

	-- arrow buttons + page indicator on the bottom strip
	local prev = makeArrowButton(book, "PrevButton", "<", "Left")
	local nextBtn = makeArrowButton(book, "NextButton", ">", "Right")

	local pageIndicator = Instance.new("TextLabel")
	pageIndicator.Name = "PageIndicator"
	pageIndicator.AnchorPoint = Vector2.new(0.5, 1)
	pageIndicator.Position = UDim2.new(0.5, 0, 1, -32)
	pageIndicator.Size = UDim2.new(0, 120, 0, 24)
	pageIndicator.BackgroundTransparency = 1
	pageIndicator.Font = UIStyle.FontBold
	pageIndicator.TextSize = 18
	pageIndicator.TextColor3 = PALETTE.InkSoft
	pageIndicator.Text = ""
	pageIndicator.Parent = book

	local self = setmetatable({
		_screen = screen,
		_book = book,
		_pages = pages,
		_index = 1,
		_left = leftRendered,
		_right = rightRendered,
		_title = title,
		_indicator = pageIndicator,
		_prev = prev,
		_next = nextBtn,
		_connections = {},
	}, BookView)

	prev.Activated:Connect(function() self:Prev() end)
	nextBtn.Activated:Connect(function() self:Next() end)

	self:_render()
	return self
end

function BookView:_render()
	local spread = self._pages[self._index]
	if not spread then return end
	self._title.Text = string.upper(spread.Title or "")
	paintSide(self._left, spread.Left)
	paintSide(self._right, spread.Right)
	self._indicator.Text = string.format("%d / %d", self._index, #self._pages)
	self._prev.AutoButtonColor = self._index > 1
	self._prev.Active = self._index > 1
	self._prev.TextTransparency = self._index > 1 and 0 or 0.5
	self._next.AutoButtonColor = self._index < #self._pages
	self._next.Active = self._index < #self._pages
	self._next.TextTransparency = self._index < #self._pages and 0 or 0.5
end

function BookView:Next()
	if self._index < #self._pages then
		self._index = self._index + 1
		self:_render()
	end
end

function BookView:Prev()
	if self._index > 1 then
		self._index = self._index - 1
		self:_render()
	end
end

function BookView:GoToTitle(title: string)
	for i, spread in ipairs(self._pages) do
		if spread.Title == title then
			self._index = i
			self:_render()
			return true
		end
	end
	return false
end

function BookView:SetPages(pages: { PageSpread })
	self._pages = pages
	self._index = 1
	self:_render()
end

function BookView:Destroy()
	if self._screen then
		self._screen:Destroy()
		self._screen = nil
	end
end

return BookView
