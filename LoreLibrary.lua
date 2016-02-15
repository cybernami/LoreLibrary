﻿
local _addonName, _addon = ...;

local LoreLibrary = LibStub("AceAddon-3.0"):NewAddon("LoreLibrary")

local _db = nil;

local defaults = {
	global = {
		
		unlockedLore = {},
		options = {
			version = "";
		}
	}
}

local _filter = {
			["collected"] = true,
			["notCollected"] = true,
			["sources"] = {
					["Object"] = true,
					["Quest"] = true,
					["Drop"] = true,
					["Container"] = true,
					["Pickpocket"] = true,
				}
			}
			

local _data = {}
local unlockedLoreTitles = {};
local stuff = {};


local LoreList = {};
local BinderTextures = {"Mechanical", "ALLIANCE", "Amber", "FANCY", "HORDE", "NATURAL", "WOOD", "Darkmoon"};
local _playerName = GetUnitName("player", false);
local _playerClass = UnitClass("player");
local _playerSex = UnitSex("player");

local BookColors = {
		{["name"] = "LOCKED", ["r"] = 0.35, ["g"] = 0.35, ["b"] = 0.35},
		{["name"] = "DARKBLUE", ["r"] = 0.15, ["g"] = 0.15, ["b"] = 0.5},
		{["name"] = "GREEN", ["r"] = 0.15, ["g"] = 0.5, ["b"] = 0.15},
		{["name"] = "RED", ["r"] = 0.5, ["g"] = 0.15, ["b"] = 0.15},
		{["name"] = "BLACK", ["r"] = 0.15, ["g"] = 0.15, ["b"] = 0.15},
		{["name"] = "BROWN", ["r"] = 0.36, ["g"] = 0.25, ["b"] = 0.2},
		
	}
	
local AchievementsToCheck = {
		1244 -- Well Read
		,6716 -- Between a Saurok and a Hard Place
		,6754 -- The Dark Heart of the Mogu
		,6846 -- Fish Tales
		,6850 -- Hozen in the Mist
		,6847 -- The Song of the Yaungol
		,6855 -- The Seven Burdens of Shaohao
		,6857 -- Heart of the Mantid Swarm
		,6856 -- Ballad of Liu Lang
		,7230 -- Legend of the Brewfathers
		,7230 -- Legend of the Brewfathers
	}

local FORMAT_LORE_UNLOCK = "LoreLibrary added: %s";
local FORMAT_SOURCE = "%s\n%s";
local FORMAT_PROGRESS = "%d/%d";
local SIZE_BOOKWIDTH = 210;
local SIZE_TITLEWIDTH_MAX = 150;
local SIZE_TITLEWIDTH_MIN = 75;
local SIZE_BOOKHEIGHT = 29;
local SIZE_LISTBOOKHEIGHT = 40;
local MAX_SHELVES = 3;
local MAX_BOOKS_PER_SHELF = 15;
local MAX_SOURCES = 8;
local SOURCETYPE_OBJECT = "Object found in this area.";
local SOURCETYPE_NPC = "Can drop from this npc.";
local SOURCETYPE_CONTAINER = "Can be found in this container.";
local SOURCETYPE_STEALTH = "Can pickpocket from this npc.";
local SOURCETYPE_QUEST = "Obtained during a quest.";

local function SortLore(list) 
	if list == nil then list = LoreList; end
	table.sort(list, function(a, b) 
		--if (a.unlocked and b.unlocked) or (not a.unlocked and not b.unlocked) then
			return a.title < b.title;
		--end
		--return (a.unlocked and not b.unlocked);
	end);
end

local function SortLoreUnlockFirst(list) 
	if list == nil then list = LoreList; end
	table.sort(list, function(a, b) 
		if (a.unlocked and b.unlocked) or (not a.unlocked and not b.unlocked) then
			return a.title < b.title;
		end
		return (a.unlocked and not b.unlocked);
	end);
end

function _addon:UpdateMapProgressBar(currentProgress, maxProgress)
	local level = GetCurrentMapDungeonLevel();

	if maxProgress == 0 then
		LoreLibraryMap.progressBar:Hide();
		return;
	end
	
	LoreLibraryMap.progressBar:Show();
	LoreLibraryMap.progressBar:SetMinMaxValues(0, maxProgress);
	LoreLibraryMap.progressBar:SetValue(currentProgress);

	LoreLibraryMap.progressBar.text:SetFormattedText(FORMAT_PROGRESS, currentProgress, maxProgress);
	LoreLibraryMap.progressBar.currentProg = currentProgress;
	LoreLibraryMap.progressBar.maxProg = maxProgress;
end

function _addon:ShowLoreMapPins(list)
	local width = WorldMapDetailFrame:GetWidth();
	local height = WorldMapDetailFrame:GetHeight();
	local pin = nil;
	for k, lore in ipairs(list) do
		pin = LoreLibraryMap.pins[k];
		if pin ~= nil then
			pin.lore = lore;
			pin:ClearAllPoints();
			pin:SetPoint("CENTER", LoreLibraryMap, "TOPLEFT", width * (lore.poi.x/100), -height * (lore.poi.y/100));
			pin:Show();
		end
	end
end

function _addon:LorePiecesInMap(area) 
	-- reset pins
	for k, pin in ipairs(LoreLibraryMap.pins) do
		pin:Hide();
		pin.lore = nil;
	end

	if (area == nil or not LoreLibraryMap.pinsEnabled) then return; end

	local level = GetCurrentMapDungeonLevel();
	local levelLore = {};
	local countAll = 0;
	local countLocked = 0;
	local new = {};
	for k, lore in pairs(_data) do
		for kl, loc in ipairs(lore.locations) do
			if loc.sourceType == nil and string.lower(loc.area) == string.lower(area)  then
				-- If it's the same area, this location becomes the lore's point of interest
				lore.poi = loc;
				countAll = countAll + 1;
				if not lore.unlocked then
					-- Same area and lore is still locked
					countLocked = countLocked + 1;
					if tonumber(loc.level) == level then
						-- Same area, still locked, and on the current map level? Show this one!
						table.insert(levelLore, lore);
					end
				end
			end
		end
	end
	self:ShowLoreMapPins(levelLore);

	_addon:UpdateMapProgressBar(countAll - countLocked, countAll);
end

function _addon:GetNumUnlockedLore()
	SortLore();
	local count = 0;
	for k, v in ipairs(LoreList) do
		if v.unlocked then
			count = count + 1;
		end
	end
	return count;
end

function _addon:UpdateProgressBar()
	local maxProgress = #LoreList;
	local currentProgress = self.GetNumUnlockedLore();

	LoreLibraryCore.progressBar:SetMinMaxValues(0, maxProgress);
	LoreLibraryCore.progressBar:SetValue(currentProgress);

	LoreLibraryCore.progressBar.text:SetFormattedText(FORMAT_PROGRESS, currentProgress, maxProgress);
end

function _addon:UpdateBookNavigation()
	if LoreLibraryBook.currentLore == nil then return; end;

	local nav = LoreLibraryBook.navigation;
	local page = LoreLibraryBook.currentPage;
	local pages = #LoreLibraryBook.currentLore.pages;
	
	nav.prev:Disable();
	nav.next:Disable();

	
	if LoreLibraryBook.currentLore.unlocked and page > 1 then
		nav.prev:Enable();
	end
	
	if LoreLibraryBook.currentLore.unlocked and page < pages then
		nav.next:Enable();
	end
	
	nav.text:SetText("Page ".. page);
end

function _addon:UpdateListDisplayNavigation()
	local display = LoreLibraryListInsetRight;
	local nav = display.navigation;

	if display.currentLore == nil then return; end;
	nav:Show();
	
	local page = display.currentPage;
	local pages = #display.currentLore.pages;
	
	nav.prev:Disable();
	nav.next:Disable();

	
	if display.currentLore.unlocked and page > 1 then
		nav.prev:Enable();
	end
	
	if display.currentLore.unlocked and page < pages then
		nav.next:Enable();
	end
	
	nav.text:SetText("Page ".. page);
end

function _addon:UpdateShelfNavigation()
	local page = LoreLibraryBookcase.currentPage;
	-- total shelves - 2 because we show 3 shelves;
 	local limit = math.ceil(#LoreLibraryBookcase.displayList / MAX_BOOKS_PER_SHELF) - 2;
	
	LoreLibraryBookcase.prev:Disable();
	LoreLibraryBookcase.next:Disable();
	
	if page > 1 then
		LoreLibraryBookcase.prev:Enable();
	end
	
	if page < limit then
		LoreLibraryBookcase.next:Enable();
	end
end

function _addon:ChangeCoreShelf(direction)
	local limit = math.ceil(#LoreLibraryBookcase.displayList / MAX_BOOKS_PER_SHELF) - 2;
	local lastPage = LoreLibraryBookcase.currentPage;
	local lore = LoreLibraryBookcase.currentLore;
	LoreLibraryBookcase.currentPage = LoreLibraryBookcase.currentPage + direction;
	LoreLibraryBookcase.currentPage = LoreLibraryBookcase.currentPage < 1 and 1 or LoreLibraryBookcase.currentPage;
	LoreLibraryBookcase.currentPage = LoreLibraryBookcase.currentPage > limit and limit or LoreLibraryBookcase.currentPage;
	
	if LoreLibraryBookcase.currentPage ~= lastPage then
		self:DisplayBooks();
	end
	
	self:UpdateShelfNavigation();
end

function _addon:FilterPageText(text)

	-- < and >
	text = text:gsub("&lt;", "<");
	text = text:gsub("&gt;", ">");
	
	-- player name
	text = text:gsub("<name>", _playerName);
	text = text:gsub("$p", _playerName);
	
	-- player class
	text = text:gsub("<class>", _playerClass);
	
	-- sex
	text = text:gsub("<his/her>", (_playerSex == 3 and "her" or "his"));
	text = text:gsub("<him/her>", (_playerSex == 3 and "her" or "him"));
	text = text:gsub("<Brother/Sister>", (_playerSex == 3 and "Sister" or "Brother"));
	
	text = text .. "\n\n";
	
	return text;
end

function _addon:ChangeBookPage(direction)
	
	local lastPage = LoreLibraryBook.currentPage;
	local lore = LoreLibraryBook.currentLore;
	-- prevent page changing for locked lore
	if not lore.unlocked then return; end 
	
	LoreLibraryBook.currentPage = LoreLibraryBook.currentPage + direction;
	LoreLibraryBook.currentPage = LoreLibraryBook.currentPage < 1 and 1 or LoreLibraryBook.currentPage;
	LoreLibraryBook.currentPage = LoreLibraryBook.currentPage > #lore.pages and #lore.pages or LoreLibraryBook.currentPage;
	
	if LoreLibraryBook.currentPage ~= lastPage then
		LoreLibraryBook.pageText:SetText(self:FilterPageText(lore.pages[LoreLibraryBook.currentPage]));
	end
	
	self:UpdateBookNavigation();
end

function _addon:ChangeDisplayPage(direction)
	local display = LoreLibraryListInsetRight;
	local lastPage = display.currentPage;
	local lore = display.currentLore;
	-- prevent page changing for locked lore
	if not lore or not lore.unlocked then return; end 
	
	display.currentPage = display.currentPage + direction;
	display.currentPage = display.currentPage < 1 and 1 or display.currentPage;
	display.currentPage = display.currentPage > #lore.pages and #lore.pages or display.currentPage;
	
	if display.currentPage ~= lastPage then
		display.pageText:SetText(self:FilterPageText(lore.pages[display.currentPage]));
	end
	
	self:UpdateListDisplayNavigation();
end

function _addon:OpenBook(lore)
	LoreLibraryOverlay:Show();
	
	LoreLibraryBook.currentLore = lore;
	LoreLibraryBook.currentPage = 1;
	LoreLibraryBook.TitleText:SetText(lore.title);
	
	for i = 1, MAX_SOURCES do
	    local button = LoreLibraryBook.sources["s"..i];
		button:Hide();
	end	
	
	if (lore.unlocked) then
		LoreLibraryBook.pageText:SetText(self:FilterPageText(lore.pages[1]));
	else
		local locationString = "<HTML><BODY><BR/><P align=\"center\">This lore can be found in:</P><BR/></BODY></HTML>";
		for k, location in ipairs(lore.locations) do
			local button = LoreLibraryBook.sources["s"..k];
			button:Show();
			local texture = "Interface/AddOns/LoreLibrary/Images/icon_Object";
			local text = location.area;
			local sourceType = SOURCETYPE_OBJECT;
			
			if location.sourceType == "drop" then
				texture = "Interface/AddOns/LoreLibrary/Images/icon_NPC";
				text = string.format(FORMAT_SOURCE, location.source, location.area);
				sourceType = SOURCETYPE_NPC;
			elseif location.sourceType == "container" then
				texture = "Interface/AddOns/LoreLibrary/Images/icon_Container";
			    text = location.source;
			    sourceType = SOURCETYPE_CONTAINER;
			elseif location.sourceType == "pickpocket" then
				texture = "Interface/AddOns/LoreLibrary/Images/icon_Stealth";
			    text = string.format(FORMAT_SOURCE, location.source, location.area);
			    sourceType = SOURCETYPE_STEALTH;
			elseif location.sourceType == "quest" then
				texture = "Interface/AddOns/LoreLibrary/Images/icon_Quest";
				text = string.format(FORMAT_SOURCE, location.source, location.area);
				if (location.level == "A") then
					--text = string.format(FORMAT_SOURCE, "|TInterface/WORLDSTATEFRAME/AllianceIcon:16|t " .. location.source, location.area);
					text = string.format(FORMAT_SOURCE, "|TInterface/Timer/Alliance-Logo:20|t" .. location.source, location.area);
				elseif  (location.level == "H") then
					--text = string.format(FORMAT_SOURCE, "|TInterface/WORLDSTATEFRAME/HordeIcon:16|t " .. location.source, location.area);
					text = string.format(FORMAT_SOURCE, "|TInterface/Timer/Horde-Logo:20|t" .. location.source, location.area);
				end
			    
			    sourceType = SOURCETYPE_QUEST;
			end
			
			button.icon:SetNormalTexture(texture);
			button.icon.sourceType = sourceType;
			button.text:SetText(text);
		end
	
		LoreLibraryBook.pageText:SetText(locationString);
	end
	
	self:UpdateBookNavigation();
end

function _addon:UnlockNewLore(title, silent)
	print(FORMAT_LORE_UNLOCK:format(title));
	
	_data[title].unlocked = true;
	unlockedLoreTitles[title] = true;
	SortLore();
	if not silent then
		self:DisplayBooks()
		self:UpdateBookList()
	end
end

function _addon:HasFilteredSource(lore)
	for sourceType, fEnabled in pairs(_filter.sources) do
		if (fEnabled) then
			for k, location in ipairs(lore.locations) do
				local loreSource = location.sourceType == nil and "object" or location.sourceType;
				if (loreSource:lower() == sourceType:lower()) then
					return true;
				end
			end
		end
	end
	
	return false;
end

function _addon:GetFilteredList(unlockedFirst)
	local list = {};
	local search = LoreLibraryCore.searchString;
	
	-- Base list depending on collected or not
	if (_filter.collected and _filter.notCollected) then
		-- just copy paste when showing everything
		list = LoreList;
	elseif (_filter.collected) then
		for k, lore in ipairs(LoreList) do
			if (lore.unlocked) then
				table.insert(list, lore);
			end
		end
	elseif (_filter.notCollected) then
		for k, lore in ipairs(LoreList) do
			if (not lore.unlocked) then
				table.insert(list, lore);
			end
		end
	end

	-- Apply search
	if (search ~= nil and search ~= "") then
		local searchList = {}
		for k, lore in ipairs(list) do
			if (string.find(lore.title:lower(), search:lower())) then
				table.insert(searchList, lore);
			end
		end
		
		list = searchList;
	end
	
	-- Apply filters
	local sourcelist = {}
	
	for lk, lore in ipairs(list) do
		if (self:HasFilteredSource(lore)) then
			table.insert(sourcelist, lore);
		end
		
	end
	list = sourcelist;
	
	
	-- Sort the list
	if (unlockedFirst) then
		SortLoreUnlockFirst(list);
	else
		SortLore(list);
	end

	return list;
end

function _addon:BookLooksFromTitle(data)
	local byteTitle = 0;
	-- at most 20 chars to keep 'part x' the same
	local length = data.title:len() > 20 and 20 or data.title:len();

	for i = 1, length do
		byteTitle = byteTitle + string.byte(data.title, i);
	end
	
	local perc = byteTitle % 21;
	
	return (100-perc)/100, (100-(perc/2))/100, BookColors[2 + (byteTitle%(#BookColors-1))];
	
end

function _addon:DisplayBooks()
	LoreLibraryBookcase.s1.nr:SetText(LoreLibraryBookcase.currentPage);
	LoreLibraryBookcase.s2.nr:SetText(LoreLibraryBookcase.currentPage+1);
	LoreLibraryBookcase.s3.nr:SetText(LoreLibraryBookcase.currentPage+2);
	
	self:UpdateProgressBar();

	_addon:HideAllBooks();
	local list = _addon:GetFilteredList();
	LoreLibraryBookcase.displayList = list;
	local count = 1;
	local s = 1;
	local b = 1;
	local book = nil;
	local color = nil;
	local totalBooks = MAX_SHELVES * MAX_BOOKS_PER_SHELF;
	local start = (LoreLibraryBookcase.currentPage-1) * MAX_BOOKS_PER_SHELF + 1;
	local bookData = nil;
	local prec = nil;
	local fixedLastStack = false;
	
	for i = start, start + totalBooks-1 do
		bookData = list[i];
		if bookData == nil then break; end
		--if totalBooks - i < 5 and #list - totalBooks > 0 and not fixedLastStack then
		--	print(totalBooks - i);
		--end
		
		s = math.ceil(count / MAX_BOOKS_PER_SHELF);
		b = count % MAX_BOOKS_PER_SHELF;
		b = (b == 0 and 15 or b);
		book = LoreLibraryBookcase.books[s][b];
		book.data = bookData;
		book:Show();
		book.title:SetFontObject((bookData.unlocked) and "GameFontNormalSmall" or "GameFontDisableSmall");
		book.title:SetWidth(0);
		book.title:SetText(bookData.title);
		
		hperc, wperc, color = _addon:BookLooksFromTitle(bookData);
		
		book:SetWidth(SIZE_BOOKWIDTH * wperc);
		book:SetHeight(SIZE_BOOKHEIGHT * hperc);
		if (book.title:GetWidth() > SIZE_TITLEWIDTH_MAX) then
			book.title:SetWidth(SIZE_TITLEWIDTH_MAX);
			book:SetHeight(SIZE_BOOKHEIGHT);
		elseif (book.title:GetWidth() < SIZE_TITLEWIDTH_MIN) then
			book.title:SetWidth(SIZE_TITLEWIDTH_MIN);
		end
		
		--local rngBinder = math.random(1, #BinderTextures);
		--book.binderLeft:SetTexture("Interface/PLAYERACTIONBARALT/" .. BinderTextures[rngBinder]);
		--book.binderRight:SetTexture("Interface/PLAYERACTIONBARALT/" .. BinderTextures[rngBinder]);
		
		book.binderLeft:SetDesaturated(not bookData.unlocked);
		book.binderRight:SetDesaturated(not bookData.unlocked);
		
		-- not unlocked? use grey
		color = bookData.unlocked == true and color or BookColors[1];
		book.bg:SetVertexColor(color.r, color.g, color.b);
		
		count = count + 1;
	end
	
	self:UpdateShelfNavigation();
end

function _addon:HideAllBooks()
	for s = 1, 3 do
		for b = 1, 15 do
			book = LoreLibraryBookcase.books[s][b];
			book:Hide();
			book:SetHeight(0.1);
		end
	end
end

function _addon:CheckWellRead(id)
	local _, _, _, overallCompleted = GetAchievementInfo(id);
	for i=2, GetAchievementNumCriteria(id) do 
		local description, _, completed = GetAchievementCriteriaInfo(id, i);
		if overallCompleted or completed then
			self:UnlockNewLore(description, true);
		end
	end
end

function _addon:UpdateBookDisplay(lore)
	local display = LoreLibraryListInsetRight;
	
	for i = 1, MAX_SOURCES do
	    local button = display.sources["s"..i];
		button:Hide();
	end	
	display.sources:Hide();
	
	display.title:SetText(lore.title);
	
	if (lore.unlocked) then
		display.lore = lore;
		display.pageText:SetText(self:FilterPageText(lore.pages[1]));
	else
		local locationString = "<HTML><BODY><BR/><P align=\"center\">This lore can be found in:</P><BR/></BODY></HTML>";
		display.pageText:SetText(locationString);
		for k, location in ipairs(lore.locations) do
			display.sources:Show();
			local button = display.sources["s"..k];
			button:Show();
			local texture = "Interface/AddOns/LoreLibrary/Images/icon_Object";
			local text = location.area;
			local sourceType = SOURCETYPE_OBJECT;
			
			if location.sourceType == "drop" then
				texture = "Interface/AddOns/LoreLibrary/Images/icon_NPC";
				text = string.format(FORMAT_SOURCE, location.source, location.area);
				sourceType = SOURCETYPE_NPC;
			elseif location.sourceType == "container" then
				texture = "Interface/AddOns/LoreLibrary/Images/icon_Container";
			    text = location.source;
			    sourceType = SOURCETYPE_CONTAINER;
			elseif location.sourceType == "pickpocket" then
				texture = "Interface/AddOns/LoreLibrary/Images/icon_Stealth";
			    text = string.format(FORMAT_SOURCE, location.source, location.area);
			    sourceType = SOURCETYPE_STEALTH;
			elseif location.sourceType == "quest" then
				texture = "Interface/AddOns/LoreLibrary/Images/icon_Quest";
				text = string.format(FORMAT_SOURCE, location.source, location.area);
				if (location.level == "A") then
					--text = string.format(FORMAT_SOURCE, "|TInterface/WORLDSTATEFRAME/AllianceIcon:16|t " .. location.source, location.area);
					text = string.format(FORMAT_SOURCE, "|TInterface/Timer/Alliance-Logo:20|t" .. location.source, location.area);
				elseif  (location.level == "H") then
					--text = string.format(FORMAT_SOURCE, "|TInterface/WORLDSTATEFRAME/HordeIcon:16|t " .. location.source, location.area);
					text = string.format(FORMAT_SOURCE, "|TInterface/Timer/Horde-Logo:20|t" .. location.source, location.area);
				end
			    
			    sourceType = SOURCETYPE_QUEST;
			end
			
			button.icon:SetNormalTexture(texture);
			button.icon.sourceType = sourceType;
			button.text:SetText(text);
		end
	
		
	end
	
	self:UpdateListDisplayNavigation();
end

function _addon:UpdateBookList()
	local scrollFrame = LoreLibraryListScrollFrame;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	
	local list = _addon:GetFilteredList(true);
	
	local numMounts = #list;
	for i=1, #buttons do
		local button = buttons[i];
		local displayIndex = i + offset;
		if ( displayIndex <= #list) then
			local lore = list[displayIndex];
			button.lore = lore;
			button.title:SetFontObject((lore.unlocked) and "GameFontNormal" or "GameFontDisable");
			button.title:SetText(lore.title);
			if (button.title:GetText()== LoreLibraryListInsetRight.title:GetText()) then
				button.selectedTexture:Show();
			else
				button.selectedTexture:Hide();
			end
		else
			button.lore = nil;
			button.title:SetText("");
			button.selectedTexture:Hide();
		end
	end
	
	HybridScrollFrame_Update(scrollFrame, #list * SIZE_LISTBOOKHEIGHT, scrollFrame:GetHeight());
end

function LOLIB_ListBook_OnClick(self, button)
	if ( button == "LeftButton" ) then
		if self.lore ~= nil then
			LoreLibraryListInsetRight.currentLore = self.lore;
			LoreLibraryListInsetRight.currentPage = 1;
			_addon:UpdateBookDisplay(self.lore);
			_addon:UpdateBookList();
			
		end
	end
end

function _addon:SetAllSourcesTo(enable)
	for k, v in pairs(_filter.sources) do
			_filter.sources[k] = enable;
	end
end

function _addon:InitFilter(self, level)
	local info = UIDropDownMenu_CreateInfo();
	info.keepShownOnClick = true;	

	if level == 1 then
		info.text = COLLECTED;
		info.func = function(_, _, _, value)
						_filter.collected = value;
						_addon:UpdateBookList();
					end 
		info.checked = _filter.collected;
		info.isNotRadio = true;
		UIDropDownMenu_AddButton(info, level)

		info.text = NOT_COLLECTED;
		info.func = function(_, _, _, value)
						_filter.notCollected = value;
						_addon:UpdateBookList();
					end 
		info.checked = _filter.notCollected;
		info.isNotRadio = true;
		UIDropDownMenu_AddButton(info, level)
	
		info.checked = 	nil;
		info.isNotRadio = nil;
		info.func =  nil;
		info.hasArrow = true;
		info.notCheckable = true;
		
		info.text = SOURCES;
		info.value = 1;
		UIDropDownMenu_AddButton(info, level)
	else --if level == 2 then
		
		info.hasArrow = false;
		info.isNotRadio = true;
		info.notCheckable = true;
			
		info.text = CHECK_ALL
		info.func = function()
						_addon:SetAllSourcesTo(true);
						UIDropDownMenu_Refresh(LoreLibraryCoreFilterDropDown, 1, 2);
						_addon:UpdateBookList();
					end
		UIDropDownMenu_AddButton(info, level)
		
		info.text = UNCHECK_ALL
		info.func = function()
						_addon:SetAllSourcesTo(false);
						UIDropDownMenu_Refresh(LoreLibraryCoreFilterDropDown, 1, 2);
						_addon:UpdateBookList();
					end
		UIDropDownMenu_AddButton(info, level)

		
		info.notCheckable = false;
		for k, v in pairs(_filter.sources) do
			info.text = k;
			info.func = function(_, _, _, value)
								_filter.sources[k] = value;
								_addon:UpdateBookList();
							end
			info.checked = function() return _filter.sources[k] end;
			UIDropDownMenu_AddButton(info, level);			
		end
	end
end

function _addon:InitCoreFrame()
	LoreLibraryBookcase.prev:Disable();
	LoreLibraryBookcase.currentPage = 1;
	
	LoreLibraryBookcase.prev:SetScript("OnClick", function() _addon:ChangeCoreShelf(-1) end);
	LoreLibraryBookcase.next:SetScript("OnClick", function() _addon:ChangeCoreShelf(1) end);
	LoreLibraryBookcase:SetScript("OnMouseWheel", function(self, delta) _addon:ChangeCoreShelf(-delta) end);
	LoreLibraryCore.searchBox:SetScript("OnTextChanged", function(self) _addon:SearchChanged(self) end);
	
	LoreLibraryListScrollFrame.scrollBar.doNotHide = true;
	HybridScrollFrame_CreateButtons(LoreLibraryListScrollFrame, "LOLIB_ListBookTemplate", 1, 0);
	HybridScrollFrame_Update(LoreLibraryListScrollFrame, #LoreList*SIZE_LISTBOOKHEIGHT, LoreLibraryListScrollFrame:GetHeight());
	
	LoreLibraryListScrollFrame.update = function() _addon:UpdateBookList() end;
	
	local nav = LoreLibraryListInsetRight.navigation;
	nav.prev:SetScript("OnClick", function() _addon:ChangeDisplayPage(-1) end);
	nav.next:SetScript("OnClick", function() _addon:ChangeDisplayPage(1) end);
	LoreLibraryListInsetRight:SetScript("OnMouseWheel", function(self, delta) _addon:ChangeDisplayPage(-delta) end);
	
	self:UpdateBookList();
	
	UIDropDownMenu_Initialize(LoreLibraryCoreFilterDropDown, function(self, level) _addon:InitFilter(self, level) end, "MENU");
	
	
end

function _addon:InitMap()
	LoreLibraryMap.pins = {};
	LoreLibraryMap.pinsEnabled = true;
	
	for i=1, 100 do 
		local pin = CreateFrame("FRAME", nil, LoreLibraryMap, "LOLIB_MapPinTemplate");
		pin:SetPoint("CENTER", LoreLibraryMap, "TOPLEFT", i * 20, -20);
		pin:Hide();
		table.insert(LoreLibraryMap.pins, pin)
	end
	
	LoreLibraryMap.progressBar.button:SetScript("OnEnter", function(self) 
									GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
									GameTooltip:SetText("Lore Library");
									GameTooltip:AddDoubleLine("Unlocked", LoreLibraryMap.progressBar.currentProg ,1 ,1 ,1 ,1 ,1 ,1);
									GameTooltip:AddDoubleLine("Total", LoreLibraryMap.progressBar.maxProg ,1 ,1 ,1 ,1 ,1 ,1);
									GameTooltip:AddDoubleLine("Pins", LoreLibraryMap.pinsEnabled and "Enabled" or "Disabled",1 ,1 ,1 ,1 ,1 ,1);
									GameTooltip:Show();
								end)
	LoreLibraryMap.progressBar.button:SetScript("OnLeave", function(self) 
									GameTooltip:Hide();
								end)		
	LoreLibraryMap.progressBar.button:SetScript("OnClick", function(self) 
									LoreLibraryMap.pinsEnabled = not LoreLibraryMap.pinsEnabled;
									_addon:LorePiecesInMap(GetMapNameByID(GetCurrentMapAreaID()));
									
									GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
									GameTooltip:SetText("Lore Library");
									GameTooltip:AddDoubleLine("Unlocked", LoreLibraryMap.progressBar.currentProg ,1 ,1 ,1 ,1 ,1 ,1);
									GameTooltip:AddDoubleLine("Total", LoreLibraryMap.progressBar.maxProg ,1 ,1 ,1 ,1 ,1 ,1);
									GameTooltip:AddDoubleLine("Pins", LoreLibraryMap.pinsEnabled and "Enabled" or "Disabled",1 ,1 ,1 ,1 ,1 ,1);
									GameTooltip:Show();
								end)	
								
end

function _addon:InitBooks()
	LoreLibraryBookcase.books = {{}, {}, {}};
	--for s = 1, 3 do
	--	LoreLibraryCore.books[s] = {};
	--end
	for s = 1, 3 do
		for b = 1, 15 do
			local book = _G["LoreLibraryBookcaseS" .. s .."B" .. b];
			LoreLibraryBookcase.books[s][b] = book;
			local width = SIZE_BOOKWIDTH * math.random(90, 100) / 100;
			book:SetWidth(width);
			book:SetHeight(SIZE_BOOKHEIGHT * math.random(80, 100) / 100);
			--book:SetHeight(SIZE_BOOKHEIGHT);
			--local space = SIZE_BOOKWIDTH - width;
			--if(space > 2 and b ~= 1 and b ~= 6 and b ~= 11) then
			--	local point, relativeTo, relativePoint = book:GetPoint(1)
			--	local offset = math.random(space) - space / 2;
			--	book:SetPoint(point, relativeTo, relativePoint, offset, 0);
			--end
			book.title:SetText("Shelf " .. s .. " book " .. b);
			
			book:SetScript("OnClick", function() _addon:OpenBook(book.data); end);
		end
	end
	
	self:HideAllBooks();
end

function _addon:InitLoreBook()
	local nav = LoreLibraryBook.navigation;
	LoreLibraryBook.currentPage = 1;
	self:UpdateBookNavigation();
	
	nav.prev:SetScript("OnClick", function() _addon:ChangeBookPage(-1) end);
	nav.next:SetScript("OnClick", function() _addon:ChangeBookPage(1) end);
	LoreLibraryBook:SetScript("OnMouseWheel", function(self, delta) _addon:ChangeBookPage(-delta) end);

end

function _addon:SearchChanged(searchBox)
	SearchBoxTemplate_OnTextChanged(searchBox);
	
	local oldText = LoreLibraryCore.searchString;
	LoreLibraryCore.searchString = searchBox:GetText();
	
	if ( oldText ~= LoreLibraryCore.searchString ) then		
		LoreLibraryCore.currentPage = 1;
		self:DisplayBooks()
		self:UpdateBookList();
	end
end

function LoreLibrary:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("LoLibDB", defaults, true);
	
	
	--
	--
end

function LoreLibrary:OnEnable()
	LoreLibrary.db.global.unlockedLore = unlockedLoreTitles;
	--_addon:AddUnlockedToDB();
end

_addon.events = CreateFrame("FRAME", "LoLib_EventFrame"); 
_addon.events:RegisterEvent("ITEM_TEXT_BEGIN");
_addon.events:RegisterEvent("ITEM_TEXT_READY");
_addon.events:RegisterEvent("ADDON_LOADED");
_addon.events:RegisterEvent("PLAYER_LOGOUT");
_addon.events:RegisterEvent("WORLD_MAP_UPDATE");
_addon.events:RegisterEvent("PLAYER_LOGIN");
_addon.events:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

function _addon.events:WORLD_MAP_UPDATE(loaded_addon)
	-- Only update when map is visible
	if WorldMapFrame:IsShown() then
		_addon:LorePiecesInMap(GetMapNameByID(GetCurrentMapAreaID()));
	end
end

function _addon.events:ITEM_TEXT_BEGIN(loaded_addon)
	-- Check if existing data and if not yet unlocked
	if _data["" .. ItemTextGetItem()] and not _data["" .. ItemTextGetItem()].unlocked then
		_addon:UnlockNewLore(ItemTextGetItem())
	end
end

function _addon.events:ITEM_TEXT_READY(loaded_addon)
	--if (stuff["" .. ItemTextGetItem()]) then
	--	stuff["" .. ItemTextGetItem()].pages[ItemTextGetPage()] = ItemTextGetText();
	--end
end

local function IsInUnlockSave(list, title)
	for k, v in ipairs(list) do
		if v == title then
			return true;
		end
	end
	return false;
end

function _addon:AddUnlockedToDB()
	for k, lore in pairs(LoreList) do
		if lore.unlocked then
			unlockedLoreTitles[lore.title] = true;
		end
	end
end

function _addon.events:ADDON_LOADED(loaded_addon)
	if (loaded_addon ~= _addonName) then return; end
	_data = _addon.data;
	
	--[[
	if(LoLib_Lore) then
		for k, v in pairs(LoLib_Lore.unlocked) do
			print(v);
		end
	
		for k, v in pairs(_data) do
			v.title = k;
			v.unlocked = IsInUnlockSave(LoLib_Lore.unlocked, k);
			table.insert(LoreList, v);
		end
	end
	]]--

	for k, v in pairs(_data) do
		v.title = k;
		v.unlocked = false; --IsInUnlockSave(, k);
		table.insert(LoreList, v);
	end
		for k, v in pairs(LoreLibrary.db.global.unlockedLore) do
		_addon:UnlockNewLore(k, true);
	end

	SortLore();
	_addon:InitCoreFrame();
	_addon:InitLoreBook();
	_addon:InitBooks();
	_addon:InitMap();
	_addon:DisplayBooks();
	
	for k, id in ipairs(AchievementsToCheck) do
		_addon:CheckWellRead(id);
	end
	
	self:UnregisterEvent("ADDON_LOADED");
end

function _addon.events:PLAYER_LOGIN(loaded_addon)
	if (loaded_addon ~= _addonName) then return; end
	
	
	self:UnregisterEvent("PLAYER_LOGIN");
end

function _addon.events:PLAYER_LOGOUT(loaded_addon)
	--for k, v in pairs(stuff) do 
	--	LoLib_books[k] = v;
	--end
	--LoLib_Lore = {};
	--LoLib_Lore.unlocked = {};
	--for k, v in pairs(LoreList) do
	--	if v.unlocked then
	--		table.insert(LoLib_Lore.unlocked, v.title);
	--	end
	--end
	--LoLib_Lore.gotIt = stuff;
end




SLASH_LOLIBSLASH1 = '/lolib';
local function slashcmd(msg, editbox)
	if msg == 'log' then
		print("Unlocked Lore");
		for k, v in pairs(LoreList)do
			local lore = _data[k];
			if lore == nil then
				print("Unknown lore for " .. k);
			else
				print(k .. ": " .. #lore.pages .." pages");
			end
		end
	elseif msg == 'list' then
		for i = 1, 64 do
		
			print(i%5 .. " - " .. (i*i)%8);
		end
		
	elseif msg == 'info' then
		_addon:CheckWellRead();
	
	elseif msg == 'o' then
		print(ItemTextGetText());
	
	else
		if LoreLibraryCore:IsShown() then
			LoreLibraryCore:Hide();
		else
			LoreLibraryCore:Show();
		end
		--if ( not InterfaceOptionsFramePanelContainer.displayedPanel ) then
		--	InterfaceOptionsFrame_OpenToCategory(CONTROLS_LABEL);
		--end
		--InterfaceOptionsFrame_OpenToCategory(_addonName) 
	  
   end
end
SlashCmdList["LOLIBSLASH"] = slashcmd



