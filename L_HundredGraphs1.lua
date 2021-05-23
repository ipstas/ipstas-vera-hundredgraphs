-- Setup your account at http://hundredgraphs.com
-- See API documentation at http://hundredgraphs.com/apidocs

-- include that in Startup:
-- monitcode = require("Moniton")
-- monitcode.HGTimer(600)

-- or you can run it only once like:
-- monitcode = require("Moniton")
-- monitcode.HGTimerOnce()


local pkg = 'L_HundredGraphs1'
module(pkg, package.seeall)
local version = '3.00'

local ltn12 = require("ltn12")
local library	= require "L_HundredGraphsLibrary"
--local cli   	= library.cli()
--local gviz  	= library.gviz()
local json  	= library.json() 

--luup.log('HundredGraphs json version: ' .. (json.version or 'empty'))

local SID = {
	["HG"] = "urn:hundredgraphs-com:serviceId:HundredGraphs1",
	["PM"] = "urn:micasaverde-com:serviceId:EnergyMetering1",
	["SES"] = "urn:micasaverde-com:serviceId:SecuritySensor1",
	["HUM"] = "urn:micasaverde-com:serviceId:HumiditySensor1",
	["TMP"] = "urn:upnp-org:serviceId:TemperatureSensor1",
	["THM"] = "urn:micasaverde-com:serviceId:HVAC_OperatingState1",
	["DIM"] = "urn:upnp-org:serviceId:Dimming1"
}
local SRV = {
	["PM"] = "Watts",
	["PM2"] = "KWH",
	["SES"] = "Tripped",
	["TMP"] = "CurrentTemperature",
	["HUM"] = "CurrentLevel",
	["THM"] = "ModeState",
	["LVL"] = "LoadLevelStatus"
}


--local device
local pdev

-- API Key
-- local API_KEY = "AABBCCDD" -- grab that KEY from your settings on https://www.hundredgraphs.com/settings
local API_KEY = ''
local NODE_ID = ''
local TOTAL = 'Total'
local SRV_URL = "https://www.hundredgraphs.com/api?key="
local SRV_URL_POST = "http://www.hundredgraphs.com/hook/"
local DEV_URL_POST = "http://dev.hundredgraphs.com/hook/"

-- Log debug messages
local DEBUG = 0 -- if you want to see results in the log on Vera 
local remotedebug = false -- remote log, you probably don't need that

-- local lastFullUpload = 0

local items = {} -- contains items: { time, deviceId, value }
local itemsExtended = {} -- contains items: { time, deviceId, value }
local g_deviceData = {}
local dataTextExt = 'empty'

local function cDiff( dev1, dev2, svc, var )
	-- Log(" getting calculate: " .. dev1 .. dev2 .. svc .. var)
    local data1 = luup.variable_get( svc, var, dev1 )
    local data2 = luup.variable_get( svc, var, dev2 )
	local endData = tonumber( data1 ) - tonumber( data2 )
	-- Log(" calculate cDiff: " .. dev1 .. dev2 .. endData)	
    return endData
end

local function calcTime( dev, svc, var )
    local data = luup.variable_get( svc, var, dev )
	local endData = data * 86400
	Log(" calculate calcTime: " .. dev .. endData)	
    return endData
end

-- Setup your devices here. You can use a function to calculate the power as illustrated in the sample.
-- For device logging, use: key, deviceId, serviceId, serviceVar
-- For function based logging, use: key, calculate, serviceVar
-- if you want power to be counted for Total use countTotal=true
local VARIABLES = {}
local VARIABLES2 = {
	{ key="House", deviceId = 301, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=false }, -- Send device energy
	{ key="HouseA", deviceId = 303, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=false }, 
	-- { key="HouseB", deviceId = 304, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=false }, 
	-- { key="Aquarium", deviceId = 286, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true }, 
	-- { key="pwr08", deviceId = 281, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true }, 
	-- { key="pwr04", deviceId = 285, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true },
	-- { key="pwr10_blue", deviceId = 376, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true },
	-- { key="pwr11_green", deviceId = 377, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true },
	-- { key='EntranceBtr', deviceId=331, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	-- { key='GarageBtr', deviceId=320, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	-- { key='OfficeBtr', deviceId=354, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	-- { key='LivingBtr', deviceId=315, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	-- { key='MaxBtr', deviceId=367, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	-- { key='BedroomBtr', deviceId=382, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	-- { key='LockBtr', deviceId=437, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	-- { key='GarageTmp', deviceId=475, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	-- { key='OfficeTmp', deviceId=355, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	-- { key='MaxTmp', deviceId=368, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	-- { key='BedroomTmp', deviceId=383, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	-- { key='LivingTmp', deviceId=316, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	-- { key='WeatherTmp', deviceId=427, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	-- { key='EntranceSns', deviceId=331, serviceId="urn:micasaverde-com:serviceId:MotionSensor1", serviceVar="Tripped"},
	-- { key='GarageSns', deviceId=320, serviceId="urn:micasaverde-com:serviceId:SecuritySensor1", serviceVar="Tripped"},
	-- { key='OfficeSns', deviceId=354, serviceId="urn:micasaverde-com:serviceId:MotionSensor1", serviceVar="Tripped"},
	-- { key='GarageHum', deviceId=318, serviceId="urn:micasaverde-com:serviceId:HumiditySensor1", serviceVar="CurrentLevel"},
	-- { key='BedroomHum', deviceId=385, serviceId="urn:micasaverde-com:serviceId:HumiditySensor1", serviceVar="CurrentLevel"},
	-- { key='TempDiff', calculate=function() return cDiff(427, 316, "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature") end, serviceVar="CurrentTemperature" } -- Send a calculated value
--	{ key='House B', deviceId=13, serviceId="urn:upnp-org:serviceId:SwitchPower1", serviceVar="Status"}, -- Send switch status
--	{ key='Computer', calculate=function() return (IsComputerPingSensorTripped() and 38 or 1) end, serviceVar="Watts" }, -- Send variable value
--	{ key='Other', calculate=function() return 15 end, serviceVar="Watts" } -- Send a constant value
}


-- You shouldn't need to change anything below this line --
local enabled
local devEnabled
local updateInterval = 3600
local interval = 'empty'
local httpRes = 0

local iter = 0
local count = 0
local lastfull = 0
local lastnew = 0

local p = print
local https = require "ssl.https"
local http = require('socket.http')
https.TIMEOUT = 5
http.TIMEOUT = 60


local BASE_URL = ""

local Log = function (text) 
	luup.log('[HundredGraphs Logger] ' .. (text or "empty")) 
end

local function TableInsert(item)
	Log( " Inserting item data: " .. item )
end

local function dumpTable(t)
	if type(t) == 'table' then
		local s = '{ '
		for k,v in pairs(t) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dumpTable(v) .. ','
		end
		return s .. '} '
	else
		return tostring(t)
	end
end

local function dumpJson(t)
	if type(t) == 'table' then
		local s = '{ '
		for k,v in pairs(t) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. ''..k..': ' .. dumpJson(v) .. ','
		end
		return s .. '} '
	else
		return tostring(t)
	end
end

local function split(str)
	local tbl = {}
	local pat = '([^;]+)'
	--Log('----')
	--Log(" Start Splitting: " .. str) 
	for line in str.gmatch(str, pat) do
        local item = {}
        line = string.gsub(line, ';', '')
        --Log(" Splitting line: " .. line) 
        pat = '([^,]+)'
        for ins in line.gmatch(line, pat) do
            ins = string.gsub(ins, ',', '')
            local res = {}
			for key, value in string.gmatch(ins, "([^&=]+)=([^&=]+)") do
				key = string.gsub(key, ' ', '')
                --Log ('key: ' .. key .. ' value: ' .. value)
                item[key]=value
            end
            --Log(' Solitting ins: ' .. ins)
            --table.insert(item, res)
        end
		table.insert(tbl, item)
	end
	--Log(" End Splitting: " .. dumpTable(tbl)) 
	--Log('----')
    
	return tbl	
 end

function initHG()
	enabled = luup.variable_get( SID.HG, "Enabled", pdev )
	if enabled == nil then
		luup.variable_set( SID.HG, "Enabled", 0, pdev )
	end
	devEnabled = luup.variable_get( SID.HG, "Dev", pdev )
	if devEnabled == nil then
		luup.variable_set( SID.HG, "Enabled", 0, pdev )
	end
	local ver = luup.variable_get( SID.HG, "version", pdev ) or 'empty'
	if ver ~= version then
		luup.variable_set(SID.HG, "version", version, pdev)
	end	
	local int = luup.variable_get( SID.HG, "Interval", pdev )
	if int == nil then
		luup.variable_set(SID.HG, "Interval", 3600, pdev)
	end
	DEBUG = luup.variable_get( SID.HG, "DEBUG", pdev )
	if DEBUG == nil then
		luup.variable_set(SID.HG, "DEBUG", 0, pdev)
	end
	Log( " Init done " .. enabled .. ' ' .. ver .. ' ' .. devEnabled .. ' ' .. int .. ' ' .. DEBUG .. ' ' )
end
function UpdateStartHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)	
	if lul_variable == 'Enabled' then
		enabled = tonumber(lul_value_new)
	elseif lul_variable == 'Dev' then
		devEnabled = tonumber(lul_value_new)
	end
	
	local running = luup.variable_get( SID.HG, "running", pdev ) or 0
	running = tonumber(running)
	
	Log('running was:' .. running .. 'enabled: ' .. enabled .. ', dev enabled: ' .. devEnabled)
	if (running == 0) then
		if (enabled == 1 or devEnabled == 1) then
			Log('Starting HGTimer')
			HGTimer()
		end
	end
	
end
function UpdateStartVersionHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)	
	version = luup.variable_get( SID.HG, "version", pdev ) or ''
	Log(' version was updated: ' .. version)
	return version
end
function UpdateVariablesHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	local deviceData = luup.variable_get(SID.HG, "DeviceData", pdev) 
	-- Log( " Watched device data: " .. (deviceData or "empty"))
	if (deviceData == nil or deviceData == '') then return end
	VARIABLES = split(deviceData)
	-- Log( " Updated VARIABLES: " .. dumpTable(VARIABLES))
	-- Log( " Updated VARIABLES2: " .. dumpTable(VARIABLES2))
end
function UpdateAPIHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	API_KEY = luup.variable_get(SID.HG, "API", pdev) or 'empty'
	Log( " Watched API_KEY: " .. API_KEY )
end
function UpdateDebugHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	-- DEBUG = luup.variable_get(SID.HG, "DEBUG", pdev) or 0
	DEBUG = tonumber(lul_value_new)
	-- if DEBUG == 0 then
		-- DEBUG = false
	-- elseif DEBUG == 1 then 
		-- DEBUG = true
	-- end
	-- Log( " Watched DEBUG change: " .. DEBUG )
	-- Log( " Watched DEBUG change2: " .. lul_device)
	-- Log( " Watched DEBUG change3: " .. lul_service)
	-- Log( " Watched DEBUG change4: " .. lul_variable)
	-- Log( " Watched DEBUG change5: " .. lul_value_old)
	-- Log( " Watched DEBUG change6: " .. lul_value_new)
	Log( " Watched DEBUG change: " .. lul_device .. ' ' .. lul_service .. ' ' .. lul_variable .. ' ' .. lul_value_new )
end
function UpdateIntervalHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	local int = luup.variable_get(SID.HG, "Interval", pdev) or 3600
	-- if interval == ''
	-- then
		-- luup.variable_set( SID.HG, "Interval", 600, pdev )		
		-- interval = 600
	-- end
	interval = tonumber(int) or 3600
	-- if interval == 'empty' then
		-- Log( " Setting Interval (wrong): " .. interval .. ' int: ' .. int)
	-- else
	if (interval < 60) then
		interval = 65
		Log( " Setting Interval (wrong): " .. interval .. ' int: ' .. int)
		luup.variable_set(SID.HG, "Interval", interval, pdev)
	else
		Log( " Setting Interval (right): " .. interval .. ' int: ' .. int)
	end	
	Log( ' Watched Interval: ' .. interval .. ' int: ' .. int)
	--Log( ' Watched Interval2: ' .. lul_device .. ' ' .. lul_service .. ' ' .. lul_variable .. ' ' .. lul_value_old .. ' ' .. lul_value_new )
	--print('[HundredGraphs] Watched Interval2:', lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	return interval
end
function UpdateNodeIdHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	NODE_ID = luup.variable_get(SID.HG, "DeviceNode", pdev) or '1'
	Log( " Watched NODE_ID: " .. NODE_ID )
end

function watchHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	NODE_ID = luup.variable_get(SID.HG, "DeviceNode", pdev) or '1'
	Log( " Watched NODE_ID: " .. NODE_ID )
end

function PackDeviceDataHG()
	local deviceData = ""
	for i, v in pairs( VARIABLES ) do
		local item = "deviceId=".. v.deviceId
		item = item ..",type=".. v.type
		item = item ..",key=".. v.key
		item = item ..",serviceId=".. v.serviceId
		item = item ..",serviceVar=".. v.serviceVar
		item = item ..",enabled=".. (v.enabled and "checked" or "false")
		deviceData = deviceData .. item .. '; '
	end
	Log( " New device data: " .. deviceData )
	if (deviceData == '') then return deviceData end
	luup.variable_set( SID.HG, "DeviceData", deviceData, pdev )
	return deviceData
end

local function SerializeData()
	local dataText = "{" .. table.concat(items, ",") .. "}"
	-- if (DEBUG) then Log(" SerializeData: " .. dataText) end
	dataTextExt = json.encode(itemsExtended)
	dataText = string.gsub(dataText, " ", "_")	
	--dataTextExt = string.gsub(dataTextExt, " ", "_")
	-- if (DEBUG) then Log(" SerializeData Ext: " .. dataTextExt) end
	return dataText, dataTextExt
end

local function ResetData()
	items = {}
	itemsExtended = {}
	count = 0
end

local function AddPair(last, id, var, value, key)
--AddPair(last, v.deviceId, v.serviceVar, val, v.key )
	if (key == nil or value == nil) then
		Log(' AddPair nil! key: ' .. (key or "empty") .. ' value: ' .. (value or "empty"))
	else
		local item = string.format("%s:%s", key, value)
		local itemExtended = {['time'] = last, ['id'] = id, ['type'] = var, ['value'] = value, ['device'] = key }
		items[#items + 1] = item
		itemsExtended[#itemsExtended + 1] = itemExtended
	end
end

local function GetWatchEvents()
	count = 0
	local total = 0
	local current = os.time()
	
	for i, v in ipairs(VARIABLES) do
		if (v.enabled == 'checked') then
			local val = 0
			local comm = 0
			
			local last = 0
			if v.deviceId then
				v.deviceId = tonumber(v.deviceId)				
				comm = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailure', v.deviceId) or 0
			elseif v.calculate then
				val = v.calculate()
				comm = 0
			end
			comm = tonumber(comm) or 0
			if (comm == 0) then
				val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
				val = tonumber(val) or 0
				if (v.serviceId == "urn:micasaverde-com:serviceId:HaDevice1") then	
					last = luup.variable_get(v.serviceId, 'BatteryDate', v.deviceId) or current
				elseif (v.serviceId == 'urn:micasaverde-com:serviceId:EnergyMetering1') then
					last = luup.variable_get(v.serviceId, 'KWHReading', v.deviceId) or current
				elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and val == 1) then
					last = luup.variable_get(v.serviceId, 'LastTrip', v.deviceId) or current
				elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and val == 0) then
					last = luup.variable_get(v.serviceId, 'LastWakeup', v.deviceId) or current
				else
					last = current
				end
				last = last * 1000
			end
			
			val = tostring(val)
			if v.countTotal == true then
				total = total + val
			end
			
			if (comm == 0) then
				AddPair(last, v.deviceId, v.serviceVar, val, v.key )
			elseif (last >= lastnew) then
				AddPair(last, v.deviceId, 'activity', 'offline', v.key )
				Log('HG log offline: ' .. v.deviceId .. ' offline ' .. comm)
			end
			--Log('HG log poll: ' .. v.deviceId .. ' ' .. poll)
			
			--AddPair(v.key, poll, 'activity', v.deviceId)
			count = count + 1
		end
	end
	AddPair(current, TOTAL, 'Watts', total,  'Total' )
	if (DEBUG == 1) then Log(" collected vars: " .. count) end
	-- if (DEBUG) then Log(" collected Ext vars: " .. #itemsExtended .. ' table: ' .. json.encode(itemsExtended)) end
	return count
end
local function GetNewEvents()
	count = 0
	local total = 0
	local current = os.time()
	
	for i, v in ipairs(VARIABLES) do
		if (v.enabled == 'checked') then
			local val = 0
			local comm = 0
			
			local last = 0
			if v.deviceId then
				v.deviceId = tonumber(v.deviceId)				
				comm = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailure', v.deviceId) or 0
			elseif v.calculate then
				val = v.calculate()
				comm = 0
			end
			comm = tonumber(comm) or 0
			if (comm == 0) then
				val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
				val = tonumber(val) or 0
				if (v.serviceId == "urn:micasaverde-com:serviceId:HaDevice1") then	
					last = luup.variable_get(v.serviceId, 'BatteryDate', v.deviceId) or current
				elseif (v.serviceId == 'urn:micasaverde-com:serviceId:EnergyMetering1') then
					last = luup.variable_get(v.serviceId, 'KWHReading', v.deviceId) or current
				elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and val == 1) then
					last = luup.variable_get(v.serviceId, 'LastTrip', v.deviceId) or current
				elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and val == 0) then
					last = luup.variable_get(v.serviceId, 'LastWakeup', v.deviceId) or current
				else
					last = current
				end
				last = last * 1000
			end
			
			val = tostring(val)
			if v.countTotal == true then
				total = total + val
			end
			
			if (comm == 0) then
				AddPair(last, v.deviceId, v.serviceVar, val, v.key )
			elseif (last >= lastnew) then
				AddPair(last, v.deviceId, 'activity', 'offline', v.key )
				Log('HG log offline: ' .. v.deviceId .. ' offline ' .. comm)
			end
			--Log('HG log poll: ' .. v.deviceId .. ' ' .. poll)
			
			--AddPair(v.key, poll, 'activity', v.deviceId)
			count = count + 1
		end
	end
	AddPair(current, TOTAL, 'Watts', total,  'Total' )
	if (DEBUG == 1) then Log(" collected vars: " .. count) end
	-- if (DEBUG) then Log(" collected Ext vars: " .. #itemsExtended .. ' table: ' .. json.encode(itemsExtended)) end
	return count
end
local function GetCurrentEvents()
	count = 0
	local total = 0
	local current = os.time()
	
	for i, v in ipairs(VARIABLES) do
		if (v.enabled == 'checked') then
			local val = 0
			local comm = 0
			
			local last = 0
			if v.deviceId then
				v.deviceId = tonumber(v.deviceId)				
				comm = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailure', v.deviceId) or 0
			elseif v.calculate then
				val = v.calculate()
				comm = 0
			end
			comm = tonumber(comm) or 0
			if (comm == 0) then
				val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
				val = tonumber(val) or 0
				-- if (v.serviceId == "urn:micasaverde-com:serviceId:HaDevice1") then	
					-- last = luup.variable_get(v.serviceId, 'BatteryDate', v.deviceId) or current
				-- elseif (v.serviceId == 'urn:micasaverde-com:serviceId:EnergyMetering1') then
					-- last = luup.variable_get(v.serviceId, 'KWHReading', v.deviceId) or current
				-- elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and val == 1) then
					-- last = luup.variable_get(v.serviceId, 'LastTrip', v.deviceId) or current
				-- elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and val == 0) then
					-- last = luup.variable_get(v.serviceId, 'LastWakeup', v.deviceId) or current
				-- else
					-- last = current
				-- end
				-- last = last * 1000
			end
			
			val = tostring(val)
			if v.countTotal == true then
				total = total + val
			end
			
			if (comm == 0) then
				AddPair(last, v.deviceId, v.serviceVar, val, v.key )
			else
				AddPair(last, v.deviceId, 'activity', 'offline', v.key )
				Log('HG log offline: ' .. v.deviceId .. ' offline ' .. comm)
			end
			--Log('HG log poll: ' .. v.deviceId .. ' ' .. poll)
			
			--AddPair(v.key, poll, 'activity', v.deviceId)
			count = count + 1
		end
	end
	AddPair(current, TOTAL, 'Watts', total,  'Total' )
	if (DEBUG == 1) then Log(" collected vars: " .. count) end
	-- if (DEBUG) then Log(" collected Ext vars: " .. #itemsExtended .. ' table: ' .. json.encode(itemsExtended)) end
	return count
end
local function sendRequestHook(events)
	
	local response_body = {} 
	-- local response_body2 = {}
	local res, code, code1, code2, response_headers, status, monitors, payload	
	local hubId = luup.pk_accesspoint

	enabled = luup.variable_get(SID.HG, "Enabled", pdev) or 0
	enabled = tonumber(enabled) or 0
	devEnabled = luup.variable_get(SID.HG, "Dev", pdev) or 0
	devEnabled = tonumber(devEnabled) or 0
	

	if enabled == 1 or devEnabled == 1 then
		NODE_ID = NODE_ID or luup.variable_get(SID.HG, "DeviceNode", pdev) or 1
		payload = '{"apiKey":"' .. API_KEY .. '","app":"Vera","version":"'.. version .. '","hubId":"' .. hubId ..'","interval":"'.. interval .. '","node":"' .. NODE_ID .. '","events":'..events..'}' 	
	end
	
	if enabled == 1 then
		Log(' prod enabled: ' .. enabled)
		res, code1, response_headers, status = http.request{
			url = SRV_URL_POST,
			method = "POST",
			headers = {
				["Content-Type"] = "application/json",
				["Content-Length"] = payload:len()
			},
			source = ltn12.source.string(payload),
			sink = ltn12.sink.table(response_body)
		}
		code1 = tonumber(code1) or 501
		Log('Post response code = ' .. code1 .. ' status = ' .. (status or 'empty')) 
		if (DEBUG == 1) then
			Log('Response prod: = ' .. table.concat(response_body) .. '\n')
			luup.variable_set( SID.HG, "ServerResponse", table.concat(response_body), pdev )
		end
		
		if code1 ~= 200 then
			Log('Prod Payload was: ' .. payload)
		end
	end
	
	if devEnabled == 1 then
		Log(' dev enabled: ' .. enabled)
		res, code2, response_headers, status = http.request{
			url = DEV_URL_POST,
			method = "POST",
			headers = {
				["Content-Type"] = "application/json",
				["Content-Length"] = payload:len()
			},
			source = ltn12.source.string(payload),
			sink = ltn12.sink.table(response_body)
		}
		code2 = tonumber(code2) or 501
		Log(' dev done: ' .. devEnabled)
		Log(' http code ' .. code2 )
		Log('Post response code = ' .. code2 .. '   status = ' .. (status or 'empty'))
		if (DEBUG == 1) then 
			Log('Response dev: = ' .. table.concat(response_body) .. '\n')
		end
	end
	
	code = code1 or code2 or 501
	
	--luup.task('Response: = ' .. table.concat(response_body) .. ' code = ' .. code .. '   status = ' .. status,1,'Sample POST request with JSON data',-1)

	return code
end	

local function sendRequestOld(data)
	
	local parameters = "&debug=" .. tostring(remotedebug) .. "&version=" .. tostring(version) .. "&node=" .. tostring(NODE_ID) .. "&json=" .. data
	local url = BASE_URL .. parameters
	if (DEBUG == 1) then Log(" sending data: " .. parameters) end
	local res, code, response_headers, status = https.request{
		url = url,
		protocol = "tlsv1_2",
	}
	
	Log('Status Old: ' .. (code or 'empty') .. ' url: ' .. BASE_URL .. '\n')

	return code
end	
	
local function SendData()
	Log(" Start sending data ")
	local data, dataExt = SerializeData()

	-- sendRequestOld(data)
	local code = sendRequestHook(dataExt)	
	
	-- Log(" sent data code: " .. code .. '\n\n')
	code = tonumber(code)		
	if (code ~= nil and code ~= 200) then
		Log('Status: ' .. (code or 'empty') .. ' url: ' .. SRV_URL_POST)
	end
	ResetData()
	return code
end

function HGTimerOnce()
	count = 0
	local code = 0
	count = GetNewEvents() 
	code = SendData() or 501
end

function HGTimer()
	iter = iter + 1
	count = 0
	local current = os.time()
	local code = 0
	local showcode = 'Running'
	local int = luup.variable_get( SID.HG, "Interval", pdev) or 'empty'
	Log('HG HGTimer start: ' .. interval .. ' ' .. int)
	
	API_KEY = luup.variable_get( SID.HG, "API", pdev ) or 'empty'
	enabled = luup.variable_get(SID.HG, "Enabled", pdev) or 0
	enabled = tonumber(enabled)
	devEnabled = luup.variable_get(SID.HG, "Dev", pdev) or 0
	devEnabled = tonumber(devEnabled)
		
	if API_KEY == 'empty' then	
		code = 'Switched off!!! wrong API key: '
		Log(code) 
		Log('HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled) 
		luup.variable_set( SID.HG, "lastRun", code, pdev )
		luup.variable_set( SID.HG, "running", 0, pdev )
		return false
	elseif interval == 'empty' then
		showcode = 'No interval set'
		code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled
		Log(code) 
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		luup.variable_set( SID.HG, "running", 0, pdev )		
		return false
	elseif enabled == 0 and devEnabled == 0 then
		showcode = 'Disabled'
		code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled
		Log(code) 
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		luup.variable_set( SID.HG, "running", 0, pdev )		
		return false
	end
		
	BASE_URL = SRV_URL .. API_KEY
	--if (iter == 6) then
	if (current - lastfull > 60*60) then
		lastfull = current
		count = GetCurrentEvents()
	else	
		count = GetNewEvents() 
	end
	
	if count > 0 then
		code = SendData() or 501
	else
		showcode = ' No data to report'
		Log(showcode) 
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		return false
	end

	if (code == 200) then
		lastnew = current
		showcode = 'OK'
	elseif code == nil then
		showcode = 'server returned empty code' 
	elseif code == 204 then
		showcode = ' server returned 204 (no data), interval was updated to once a day. Update reporting sensors and restart a plugin'
		updateInterval = interval
		interval = 86400000
	elseif code == 401 then
		showcode = ' server returned 401, your API key is wrong, interval was updated to once an hour. Update reporting sensors and restart a plugin'
		updateInterval = interval
		interval = 3600
	elseif code == 402 then
		showcode = ' server returned 402, you are using extended features requiring payment. Reporting interval was switched to 600 secs'
		updateInterval = interval
		interval = 610
	elseif code == 429 then
		showcode = ' server returned 429, you are using extended features requiring payment. Reporting interval was switched to 600 secs'
		updateInterval = interval
		interval = 615
	else
		showcode = ' unknown send status was returned: ' .. (code or 'empty') 
	end
	Log(showcode) 

	if (code ~= httpRes) then
		httpRes = code
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		if code == 200 then
			local commfailure = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', "CommFailure", pdev) or 0
			commfailure = tonumber(commfailure)
			if (commfailure == 1) then 
				luup.log("Device "..pdev.." has CommFailure="..commfailure..". set it to 0") 
				luup.variable_set('urn:micasaverde-com:serviceId:HaDevice1', "CommFailure", 0, pdev) 
				-- luup.call_action(SID.HG, "Reload", {}, 0) 
			end 
		end
	end
	
	local res = luup.call_timer("HGTimer", 1, interval, "", interval)
	luup.variable_set( SID.HG, "running", 1, pdev )

	Log(' next in ' .. interval)

	return true
end


_G.UpdateDebugHG = UpdateDebugHG
_G.HGTimerOnce = HGTimerOnce
_G.HGTimer = HGTimer
_G.UpdateVariablesHG = UpdateVariablesHG
_G.UpdateAPIHG = UpdateAPIHG
_G.UpdateNodeIdHG = UpdateNodeIdHG
_G.UpdateIntervalHG = UpdateIntervalHG
_G.UpdateStartHG = UpdateStartHG
_G.UpdateStartVersionHG = UpdateStartVersionHG

function startup(lul_device)
	lul_device = lul_device
	pdev = tonumber(lul_device)
	-- version = UpdateStartVersionHG()
	initHG()
	interval = UpdateIntervalHG()
		
	local deviceData = luup.variable_get( SID.HG, "DeviceData", pdev ) or ""
	-- if (DEBUG) then Log(" current dev data: " .. deviceData) end
	if (deviceData == "" or deviceData == '-') then
		VARIABLES = {}
		-- Get the list of power meters.
		-- for devNum, devAttr in pairs( luup.devices ) do		
			-- local val = luup.variable_get(SID.PM, SRV.PM, devNum)
			-- if (val ~= nil) then	
				-- local desc = luup.variable_get(SID.PM, "description", devNum)			
				-- Log("Device #" .. devAttr.id .. " desc: " .. devAttr.description .. " KWH:" .. val)
				-- local item = {}
				-- item.type = 'PM'
				-- item.deviceId = devNum
				-- item.key = devAttr.description
				-- item.serviceId = SID.PM
				-- item.serviceVar = SRV.PM
				-- item.enabled = "checked"
				-- table.insert(VARIABLES, item)				
			-- end
		-- end
		-- Log(' Created initial VARIABLES: ' .. dumpTable(VARIABLES))
		-- deviceData = PackDeviceDataHG()
		-- Log(' Created initial deviceData: ' .. deviceData)
	else
		UpdateVariablesHG()
		-- luup.log("HundredGraphs: existing deviceData: " .. deviceData .. " VARS: " .. dumpTable(VARIABLES))
	end

	-- UpdateDeviceDataHG()
	-- UpdateVariablesHG()

	enabled = luup.variable_get( SID.HG, "Enabled", pdev ) or 0
	enabled = tonumber(enabled)
	devEnabled = luup.variable_get( SID.HG, "Dev", pdev ) or 0
	devEnabled = tonumber(enabled)
	
	NODE_ID = luup.variable_get( SID.HG, "DeviceNode", pdev ) or '1'
	API_KEY = luup.variable_get( SID.HG, "API", pdev )
	if (API_KEY == nil) then
		luup.variable_set( SID.HG, "API", 'empty', pdev )
		API_KEY = 'empty'
	else
		Log('Initial API_KEY: ' .. API_KEY)
	end	
	BASE_URL = SRV_URL .. API_KEY
	
	Log(" Started with version " .. version)

	luup.variable_watch("UpdateVariablesHG", SID.HG, "DeviceData", pdev)
	luup.variable_watch("UpdateVariablesHG", SID.HG, "DeviceData2", pdev)
	luup.variable_watch("UpdateAPIHG", SID.HG, "API", pdev)
	luup.variable_watch("UpdateIntervalHG", SID.HG, "Interval", pdev)
	luup.variable_watch("UpdateStartHG", SID.HG, "Enabled", pdev)
	luup.variable_watch("UpdateStartHG", SID.HG, "Dev", pdev)
	--luup.variable_watch("UpdateStartVersionHG", SID.HG, "version", pdev)
	luup.variable_watch("UpdateNodeIdHG", SID.HG, "DeviceNode", pdev)
	luup.variable_watch("UpdateDebugHG", SID.HG, "DEBUG", pdev)
	
	-- Log(' Started from plugin, ' .. SID.HG .. ' dev: ' .. (pdev  or "empty") .. ' enabled: ' .. (enabled or 'disabled') .. ' API_KEY: ' .. API_KEY)  
	HGTimer() 
	return true
end

Log(" *********************************************** ")


-- startup()
-- HGTimer()

return true