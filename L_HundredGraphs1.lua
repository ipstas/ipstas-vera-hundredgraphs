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
local version = '3.12'

local ssl = require 'ssl'
local https = require "ssl.https"
local http = require "socket.http"
https.TIMEOUT = 60
http.TIMEOUT = 60
local ltn12 = require("ltn12")
local library  = require "L_HundredGraphsLibrary"
--local cli     = library.cli()
--local gviz    = library.gviz()
local json    = library.json()

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
local SRV_SSL_POST = "https://www.hundredgraphs.com/hook/"
local DEV_URL_POST = "http://dev.hundredgraphs.com/hook/"
local DEV_SSL_POST = "https://dev.hundredgraphs.com/hook/"

-- Log debug messages
local DEBUG = 0 -- if you want to see results in the log on Vera
local remotedebug = false -- remote log, you probably don't need that

-- local lastFullUpload = 0

local items = {} -- contains items: { time, deviceId, value }
itemsExtendedHG = {} -- contains items: { time, deviceId, value }
itemsExtendedOldHG = {} -- contains items: { time, deviceId, value }
itemsSecondaryHG = {} -- contains items: { time, deviceId, value }
itemsSecondaryOldHG = {} -- contains items: { time, deviceId, value }
local uploadedHG = ''
local g_deviceData = {}
local modelData = {}
local sidData = {}
local geoData = {}
local decodeOK
local dataTextExt = 'empty'

local function cDiff( dev1, dev2, svc, var )
  -- LogHG("getting calculate: " .. dev1 .. dev2 .. svc .. var)
    local data1 = luup.variable_get( svc, var, dev1 )
    local data2 = luup.variable_get( svc, var, dev2 )
  local endData = tonumber( data1 ) - tonumber( data2 )
  -- LogHG("calculate cDiff: " .. dev1 .. dev2 .. endData)  
    return endData
end

local function calcTime( dev, svc, var )
    local data = luup.variable_get( svc, var, dev )
  local endData = data * 86400
  LogHG("calculate calcTime: " .. dev .. endData)  
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
--  { key='House B', deviceId=13, serviceId="urn:upnp-org:serviceId:SwitchPower1", serviceVar="Status"}, -- Send switch status
--  { key='Computer', calculate=function() return (IsComputerPingSensorTripped() and 38 or 1) end, serviceVar="Watts" }, -- Send variable value
--  { key='Other', calculate=function() return 15 end, serviceVar="Watts" } -- Send a constant value
}

-- You shouldn't need to change anything below this line --
local enabled = 0
local devEnabled = 0
local realTime = 0
local updateInterval = 600
local interval = 3600
local httpRes = 0
local running = 0

local iter = 0
local count = 0
local lastfull = 0
local lastdetails = 0
lastnewHG = 0

local p = print

local BASE_URL = ""

function errorhandlerHG( err )
   luup.log( "[HundredGraphs Logger] ERROR: " .. err )
   luup.device_message(pdev, -2, 'uploading', 1, 'HGTimer');
   luup.device_message(pdev, -2, 'failed', 0, 'HundredGraphs err');
   luup.device_message(pdev, 2, 'failed', 0, 'HundredGraphs err')
   luup.variable_set( SID.HG, "ERR", err, pdev )
   luup.variable_set( SID.HG, "lastRun", err, pdev )
end	
function logcallHG(text)
	--luup.log('[HundredGraphs Logger] xpcall start')
	luup.log('[HundredGraphs Logger]: ' .. (text or "empty LogHG"))
end
function LogHG(text)
	--local stat, ret, err = xpcall(function() logcallHG(text) end, errorhandlerHG )
	-- if (stat) then
		-- luup.log('[HundredGraphs Logger] status: ' .. ('success' or "empty LogHG"))
	-- else
		-- luup.log('[HundredGraphs Logger] status: ' .. ('failed' or "empty LogHG"))
		-- luup.log('[HundredGraphs Logger] err: ' .. (err or "empty LogHG"))
	-- end
	-- luup.log('[HundredGraphs Logger] return: ' .. (ret or "empty LogHG"))
	luup.log('[HundredGraphs Logger]: ' .. (text or "\n"))
	-- luup.log('[HundredGraphs Logger] xpcall end \n\n' )
end

-- not used anymore
local function TableInsert(item)
  LogHG("Inserting item data: " .. item )
end
-- not used anymore
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
-- not used anymore
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


-- not used anymore
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
  LogHG("New device data: " .. deviceData )
  if (deviceData == '') then return deviceData end
  luup.variable_set( SID.HG, "DeviceData", deviceData, pdev )
  return deviceData
end
-- not used anymore
local function SerializeData()
  local data = json.encode(itemsExtendedHG)
  return data
end
-- not used anymore
local function sendRequestOld(data)
  
  local parameters = "&debug=" .. tostring(remotedebug) .. "&version=" .. tostring(version) .. "&node=" .. tostring(NODE_ID) .. "&json=" .. data
  local url = BASE_URL .. parameters
  if (DEBUG == 1) then LogHG("sending data: " .. parameters) end
  local res, code, response_headers, status = https.request{
    url = url,
    protocol = "tlsv1_2",
  }
  
  LogHG('Status Old: ' .. (code or 'empty') .. ' url: ' .. BASE_URL .. '\n')

  return code
end  


function initHG()
	LogHG("Init started " .. enabled .. ' ' .. version .. ' ' .. devEnabled .. ' ' .. interval .. ' ' .. DEBUG .. ' ' )
	luup.variable_set(SID.HG, "version", version, pdev)
	enabled = luup.variable_get( SID.HG, "Enabled", pdev ) or 0
	devEnabled = luup.variable_get( SID.HG, "Dev", pdev ) or 0  
	interval = luup.variable_get( SID.HG, "Interval", pdev ) or 0
	interval = tonumber(interval)
	if interval < 60 then
		interval = 600
		luup.variable_set(SID.HG, "Interval", interval, pdev)    
	end
	DEBUG = luup.variable_get( SID.HG, "DEBUG", pdev )
	if DEBUG == nil then
		luup.variable_set(SID.HG, "DEBUG", 0, pdev)
		DEBUG = 0
	else
		DEBUG = tonumber(DEBUG)
	end
	local showDev = luup.variable_get( SID.HG, "showDev", pdev )
	if showDev == nil then
		luup.variable_set(SID.HG, "showDev", 0, pdev)
		showDev = 0
	else
		showDev = tonumber(showDev)
	end
		realTime = luup.variable_get( SID.HG, "realTime", pdev )
	if realTime == nil then
		luup.variable_set(SID.HG, "realTime", 0, pdev)
		realTime = 0
	else
		realTime = tonumber(realTime)
	end
	luup.variable_set('urn:micasaverde-com:serviceId:HaDevice1', "CommFailure", 0, pdev)
	LogHG("Init done en:" .. enabled .. ' dev:' .. devEnabled .. ' interval:' .. interval .. ' DEBUG:' .. DEBUG .. ' ' )
end

-- functions for watchin'
function reloadHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)  

	local reload = 0
	local reloadOld = 0
	if lul_value_new == 'true' or lul_value_new == true then
		reload = 1
	end
	if lul_value_old == 'true' or lul_value_old == true then
		reloadOld = 1
	end
	LogHG('reloadHG :' .. lul_device .. '/' .. lul_service .. ' was:' .. reloadOld .. ' now:' .. reload)

	if reload == 1 then
		luup.variable_set(lul_service, "Reload", false, lul_device)    
		LogHG('reloadHG in 30 secs:')
		luup.call_delay(luup.reload(), 30)
	end

end
function UpdateStartHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)  
	if lul_variable == 'Enabled' then
		enabled = tonumber(lul_value_new or 0)
	elseif lul_variable == 'Dev' then
		devEnabled = tonumber(lul_value_new or 0)
	end

	lul_value_old = lul_value_old or 0
	lul_value_new = lul_value_new or 0

	LogHG('running was:' .. lul_value_old .. ' now:' .. lul_value_new .. ' enabled: ' .. enabled .. ', dev enabled: ' .. devEnabled)
	--luup.reload()
end
function UpdateStartVersionHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)  
	version = luup.variable_get( lul_service, "version", lul_device ) or ''
	LogHG(' version was updated: ' .. version .. (lul_value_new or 'empty'))
	return version
end
function UpdateAPIHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	API_KEY = luup.variable_get(lul_service, lul_variable, lul_device) or 'empty'
	LogHG("Watched API_KEY: " .. API_KEY )
	luup.call_delay(luup.reload(), 30)
end
function UpdateIntervalHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	interval = tonumber(lul_value_new) or 3600
	-- if (interval < 60) then
	-- interval = 65
	-- LogHG("Setting Interval (wrong): " .. interval)
	-- luup.variable_set(SID.HG, "Interval", interval, pdev)
	-- else
	-- LogHG("Setting Interval (right): " .. interval)
	-- end  
	LogHG( ' Watched Interval: ' .. interval)
	--luup.reload()
	--return interval
end
function UpdateVariablesHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	-- local function reloadEngine(lul_device, lul_variable)
		-- LogHG("Reloading because of devices: " .. lul_device .. ' var: ' .. lul_variable .. '\n')
		-- luup.reload()
	-- end
-- 	LogHG("Updated devices: " .. lul_device .. ' var: ' .. lul_variable .. '\n')

	--luup.call_action("urn:micasaverde-com:serviceId:HomeAutomationGateway1", "Reload", {}, 0)
	-- GetWatchDevices(VARIABLES)
	-- LogHG("Updated VARIABLES2: " .. dumpTable(VARIABLES2))
end
function UpdateNodeIdHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	NODE_ID = luup.variable_get(lul_service, lul_variable, lul_device) or '1'
	LogHG("Watched NODE_ID: " .. NODE_ID )
end
function UpdateRealHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	realTime = tonumber(lul_value_new) or 0
	LogHG("Watched realTime change: " .. realTime)
	--LogHG("Watched realTime change: " .. lul_device .. ' ' .. lul_service .. ' ' .. lul_variable .. ' ' .. lul_value_new )
end
function UpdateDebugHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	DEBUG = tonumber(lul_value_new) or 0
	LogHG("Watched DEBUG change: " .. DEBUG)
	--LogHG("Watched DEBUG change: " .. lul_device .. ' ' .. lul_service .. ' ' .. lul_variable .. ' ' .. lul_value_new )
end

local function splitTable(str)
	local tbl = {}
	local pat = '([^;]+)'
	--LogHG('----')
	str = str:gsub('\n','');
	--LogHG("Start Splitting: " .. str)

	for line in str.gmatch(str, pat) do
		local item = {}
		--LogHG("Splitting line: " .. (line or 'empty'))	
		line = line:gsub('\n','');
		line = string.gsub(line, ';', '')		
		line = line:gsub('\n','');
		pat = '([^,]+)'
		for ins in line.gmatch(line, pat) do
			--LogHG(' Splitting ins: ' .. (ins or 'empty'))
			ins = string.gsub(ins, ',', '')
			--local res = {}
			for key, value in string.gmatch(ins, "([^&=]+)=([^&=]+)") do
				key = string.gsub(key, ' ', '')
				if value == nil then
					LogHG('EMPTY!!! Splitting keys: ' .. key .. '/' .. (value or 'empty'))
				end
				item[key]=value
			end			
			--table.insert(item, res)
		end
		table.insert(tbl, item)
	end

	--LogHG("End Splitting: " .. dumpTable(tbl))
	--LogHG('----')
	return tbl  
 end
local function GetWatchDevices(VARIABLES)
	count = 0
	local total = 0
	local current = os.time()

	for i, v in ipairs(VARIABLES) do
		if (v.enabled == 'checked' and v.burst == 'checked') then       
			local id = tonumber(v.deviceId)        
			luup.variable_watch("watchDevicesHG", v.serviceId, v.serviceVar, id)
			local key = v.key or luup.attr_get('name', id) or id
			LogHG("Watching device added: " .. id .. ' ' .. v.serviceVar .. ' ' .. key)
			count = count + 1
		end
	end

	LogHG("Watching devices: " .. count)
	return count
end
function watchDevicesHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
	count = 0
	local sender = 'new'
	local realTime = luup.variable_get( SID.HG, "realTime", pdev ) or 0
	realTime = tonumber(realTime) or 0
	local status = -1
	local id = tonumber(lul_device) or 0
	local var = tostring(lul_variable) or 'var'
	local current = os.time()
	local itemExtended

	local old = tostring(lul_value_old) or 0
	local val = tostring(lul_value_new) or 0
	local itemKey = var..id
	local oldValue =  itemsSecondaryOldHG[itemKey] or 'empty'

	if oldValue == value then
		if (DEBUG == 1) then 
			LogHG('watchDevicesHG SAME, key: ' .. id .. '/' .. var .. '/' .. (key or "watched") .. ' value: ' .. (value or "empty") .. '\n\n')
		end
		itemsSecondaryHG[itemKey] = value
		return 
	end
	-- LogHG("Watched devices found: " .. id .. '/' .. var .. ' val:' .. old .. '/' .. val )
	--luup.log(tostring(lul_value_old))
	--luup.log(tostring(lul_value_new))

	if (id ~= 0) then
		itemExtended = {['time'] = 1000*current, ['id'] = id, ['type'] = var, ['value'] = val}
		itemsExtendedHG[#itemsExtendedHG + 1] = itemExtended
		count = count + 1
	end
	
	LogHG("Watched collected:" .. (#itemsExtendedHG or 0) .. ' real?:' .. realTime .. ' id:' .. id .. '/' .. var .. ' val:' .. old .. '/' .. val .. '\n')
	
	if realTime == 1 then  
		SendDataHG('realTime')
		ResetDataHG()
		lastnewHG = tonumber(current)
	end
  
end

-- collect devices model data
local function GetDeviceDetails()
	local count = 0
	modelData = {}
	local str = luup.variable_get( SID.HG, "SIDs", pdev ) or ''
	-- str = str:gsub('\n','')
	-- sidData = dumpTable(str)
	sidData, decodeOK = json.decode(str)
	decodeOK = decodeOK or 'OK'
	if decodeOK ~= 'OK' then
		LogHG('sidData json.decode1:' .. decodeOK)
		sidData = {}
	end
	-- LogHG("GetDeviceDetails sidData2: " .. dumpTable(sidData)) 
	
	-- local geo = {}
	-- geo = {['id'] = 'latitude', ['value'] = luup.longitude or 0} 
	-- LogHG("GetDeviceDetails geoData1: " .. table.concat(geo)) 
	-- table.insert(geoData, geo)
	-- geo = {['id'] = 'latitude', ['value'] = luup.latitude or 0} 
	-- LogHG("GetDeviceDetails geoData2: " .. table.concat(geo)) 
	-- table.insert(geoData, geo)
	-- geo = {['id'] = 'city', ['value'] = luup.city or 0} 
	
	-- table.insert(geoData, geo)
	
	geoData = {
		['longitude'] = luup.longitude or 0,
		['latitude'] = luup.latitude or 0,
		['city'] = luup.city or 'nowhere',		
		['timezone'] = luup.timezone or 0,				
		['tempFormat'] = luup.variable_get( SID.HG, "tempFormat", pdev) or '',
	}
	--LogHG("GetDeviceDetails geoData1: " .. table.concat(geoData)) 
	--LogHG("GetDeviceDetails geoData2: " .. dumpTable(geoData)) 
	--geoData = {}
	
	for i, v in ipairs(VARIABLES) do
		if v.enabled == 'checked' and modelData[id] == nil then
			local val = 0
			local key = v.key
			local comm = 0     
			local device_type, manufacturer, model, roomNum, roomName, time_created

			local id = tonumber(v.deviceId)        

			key =  luup.attr_get('name', id) or v.key or v.deviceId
			device_type =  luup.attr_get('device_type', id) or 'empty'
			--LogHG("GetDeviceDetails adding device:" .. id .. '/device_type:' .. device_type) 
			manufacturer =  luup.attr_get('manufacturer', id) or 'empty'
			--LogHG("GetDeviceDetails adding device:" .. id .. '/manufacturer:' .. manufacturer) 
			model =  luup.attr_get('model', id) or 'empty'
			--LogHG("GetDeviceDetails adding device:" .. id .. '/model:' .. model) 
			roomNum = luup.attr_get('room', id) or 0
			roomNum = tonumber(roomNum) or 0
			--LogHG("GetDeviceDetails adding device:" .. id .. '/roomNum:' .. roomNum) 
			roomName =  luup.rooms[roomNum] or 'House'
			--LogHG("GetDeviceDetails adding device:" .. id .. '/roomName:' .. roomName) 
			time_created =  luup.attr_get('time_created', id) or 'empty'
			--LogHG("GetDeviceDetails adding device:" .. id .. '/time_created:' .. time_created) 
			--LogHG("GetDeviceDetails adding device:" .. id .. '/key:' .. key .. '/manuf:' .. manufacturer .. '/model:' .. model .. '/roomName:' .. roomName .. '/time_created:' .. time_created ) 
			xpcall(function() AddPairDevicesHG(id, key, device_type, manufacturer, model, roomNum, roomName, time_created) end, errorhandlerHG)
			
			count = count + 1
		end
	end

	LogHG("GetDeviceDetails collected devices: " .. count) 

	return count
end
function AddPairDevicesHG(id, key, device_type, manufacturer, model, roomNum, roomName, time_created)
	local itemExtended = {}
	id = tostring(id)
	
	for i, v in pairs(modelData) do
		if v.id == id then
			if (DEBUG == 1) then LogHG(' AddPairDevices exists1: ' .. i .. '/' .. v.id) end
			return
		end
	end
	
	if modelData[id] ~= nil then
		if (DEBUG == 1) then LogHG(' AddPairDevices doesnt exists2: ' .. id) end
	end

	itemExtended = {['id'] = id, ['key'] = key, ['device_type'] = device_type, ['manufacturer'] = manufacturer, ['model'] = model, ['roomNum'] = roomNum, ['roomName'] = roomName, ['createdAt'] = time_created } 
	
	modelData[id] = itemExtended
	--modelData[id] = itemExtended
	--if (DEBUG == 1) then
	--LogHG(' AddPairDevices itemsExtendedHG1: ' .. id .. '/' .. (table.concat(modelData[id]) or 'empty')	)
		--LogHG(' AddPairDevices itemsExtendedHG1: ' .. id .. '/' .. (table.concat(modelData[#modelData]) or 'empty')	)
	--end

	return true
end

-- collect events
local function GetNewEvents(lastnewHG, current)
	count = 0
	local total = 0
	local sender = 'new'
	--local current = os.time()
  
	for i, v in ipairs(VARIABLES) do
		if (v.enabled == 'checked') then
			v.deviceId = tonumber(v.deviceId)
			local val = 0      
			local key = v.key
			local lastSeen = 0
			local comm = 0
			local item = {}
			        		
			if v.deviceId == nil then
				LogHG('HG GetNewEvents VARS: ' .. (v.deviceId or 'empty') .. ' v.serviceId ' .. v.serviceId)
			end
			
			comm = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailure', v.deviceId) or 0
			comm = tonumber(comm)
			if (comm ~= 0) then
				val = 'offline'
				lastSeen = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailureTime', v.deviceId) or current     
				--LogHG('HG GetNewEvents:' .. count .. ' device: ' .. v.deviceId .. ' lastSeen:' .. lastSeen .. ' offline: ' .. comm)      
			else
				val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
				if (v.serviceId == "urn:micasaverde-com:serviceId:HaDevice1") then  
					lastSeen = luup.variable_get(v.serviceId, 'BatteryDate', v.deviceId) or current    
				elseif (v.serviceId == 'urn:micasaverde-com:serviceId:EnergyMetering1') then
					lastSeen = luup.variable_get(v.serviceId, 'KWHReading', v.deviceId) or current
				elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and tonumber(val) == 1) then
					lastSeen = luup.variable_get(v.serviceId, 'LastTrip', v.deviceId) or current
				elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and tonumber(val) == 0) then
					--lastSeen = luup.variable_get(v.serviceId, 'LastWakeup', v.deviceId) or current
					lastSeen = current
				else
					lastSeen = current
				end
			end
			lastSeen = tonumber(lastSeen)

			--LogHG("GetNewEvents collected var0: " .. count .. ' lastSeen ' .. lastSeen .. ' dev: ' .. v.deviceId .. '/' .. v.serviceVar .. ' val: ' .. val)

			if (lastSeen > lastnewHG) then		
				count = AddPairHG(1000*lastSeen, v.deviceId, nil, v.serviceVar, val, v.key, sender )
			end

		end
	end

	if (DEBUG == 1) then LogHG("GetNewEvents collected vars: " .. #itemsExtendedHG .. '/' .. count) end
	-- if (DEBUG) then LogHG("collected Ext vars: " .. #itemsExtendedHG .. ' table: ' .. json.encode(itemsExtended)) end
	return count
end
local function GetCurrentEvents(lastfull, current)
	local count = 0
	local total = 0
	local sender = 'current'
	-- we will collect everything
	itemsSecondaryHG = {}

	for i, v in ipairs(VARIABLES) do
		if (v.enabled == 'checked') then
			v.deviceId = tonumber(v.deviceId)       
			local val = 0
			local key = v.key
			local comm = 0     
			local roomNam, roomName
			
			--LogHG('HG GetCurrentEvents VARS: ' .. (v.deviceId or 'empty') .. ' v.serviceId ' .. v.serviceId)

			 
			comm = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailure', v.deviceId) or 0
			comm = tonumber(comm) or 0

			if (comm == 0) then
				val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
				val = tostring(val)
				--key = luup.variable_get('urn:micasaverde-com:serviceId:ZWaveDevice1', 'ConfiguredName', v.deviceId) or v.key
				key =  luup.attr_get ('name', tonumber(v.deviceId)) or v.key or v.deviceId
				--roomNum =  luup.attr_get ('room', tonumber(v.deviceId)) or 0
				--roomNum = tonumber(roomNum)
				--roomName =  luup.rooms[roomNum] or 'House'
				--LogHG('GetCurrentEvents: ' .. status)
				status, count = xpcall(function() return AddPairHG(1000*current, v.deviceId, v.serviceId, v.serviceVar, val, key, sender) end, errorhandlerHG)
			else      
				status, count = xpcall(function() return AddPairHG(1000*current, v.deviceId, v.serviceId, 'activity', 'offline', v.key, sender ) end, errorhandlerHG)
			LogHG('HG log offline: ' .. v.deviceId .. ' offline ' .. comm)
			end

			
		end
	end

	LogHG("GetCurrentEvents collected vars: " .. count) 

	return count
end
function AddPairHG(last, id, service, var, value, key, sender, roomNum, roomName)
	
	if var == nil or id == nil then
		LogHG('ERRRRRRR AddPair started id: ' .. (id or "empty") .. ' var: ' .. (var or "empty"))
	end	
	
	local s
	local itemExtended = {}
	local itemSec = {}
	local itemKey = var..id
	local oldValue =  itemsSecondaryOldHG[itemKey] or 'empty'

	
	if oldValue == value then
		if (DEBUG == 1) then 
			LogHG('AddPair SAME, key: ' .. id .. '/' .. var .. '/' .. (key or "watched") .. ' value: ' .. (value or "empty") .. '\n\n')
		end
		itemsSecondaryHG[itemKey] = value
		-- for current events we send everything
		if sender == 'new' then
			return count
		end
	end
	
	if key == nil then
		itemExtended = {['time'] = last, ['id'] = id, ['service'] = service, ['type'] = var, ['value'] = value}
		itemSec = {['id'] = id, ['type'] = var, ['value'] = value}	
		itemsSecondaryHG[itemKey] = value
	else
		itemExtended = {['time'] = last, ['id'] = id, ['service'] = service, ['type'] = var, ['value'] = value, ['key'] = key, ['roomNum'] = roomNum, ['roomName'] = roomName } 
		itemSec = {['id'] = id, ['type'] = var, ['value'] = value}	
		itemsSecondaryHG[itemKey] = value
	end
	
	itemsExtendedHG[#itemsExtendedHG + 1] = itemExtended
	count = count + 1
	
	if (DEBUG == 1) then
		LogHG(' AddPair itemsExtendedHG1: ' .. itemKey .. ' key:' .. key .. ' val: ' .. oldValue .. '/' .. itemsSecondaryHG[itemKey])	
	end
	--LogHG(' AddPair itemsExtendedHG2: ' .. itemKey .. ' item: ' .. table.concat(itemExtended) .. ' 2:' .. table.concat(itemSec) .. ' 3:' .. table.concat(itemsSecondaryHG) .. ' full:' .. table.concat(itemsExtendedHG[#itemsExtendedHG]))		
	--LogHG(' AddPair itemsExtendedHG3: ' .. itemKey .. ' item: ' .. table.concat(itemExtended) .. ' 2:' .. table.concat(itemSec) .. ' 3:' .. table.concat(itemsSecondaryHG))		
	-- if key == '' or key == nil then
		-- LogHG(' AddPair ended key: ' .. id .. '/' .. var .. ' ' .. (key or "watched") .. ' value: ' .. (value or "empty"))
		--LogHG(' AddPair itemExtended: ' .. table.concat(itemsExtendedHG))
		--luup.log(s)
		-- LogHG(' AddPair itemsExtendedHG: ' .. table.concat(itemsExtendedHG[#itemsExtendedHG]))
		--luup.log(s)
	-- end

	return count
end

function SendDataHG(reason, current, lastnewHG, lastfull, interval)

	LogHG("SendDataHG. Start sending data " .. reason .. ' between dates ' .. lastnewHG .. ' ' .. current )
	
	local showcode = ''
	local code = 0
	local rtOff = false
	local oldInterval = interval

	local payload = {}
	DEBUG = luup.variable_get(SID.HG, "DEBUG", pdev) or 0
	DEBUG = tonumber(DEBUG)		
	local hubId = luup.pk_accesspoint
	local NODE_ID = luup.variable_get(SID.HG, "DeviceNode", pdev) or '1'

	--LogHG("SendDataHG. Start sending data sidData" .. dumpTable(sidData) )
	
	payload['apiKey'] = API_KEY 
	payload["node"] = NODE_ID 
	payload['app'] = "Vera"
	payload["version"] = version
	payload["hubId"] = hubId
	payload["debug"] = DEBUG
	payload["interval"] = math.floor(interval/60+0.5) .. 'm'
	payload["sender"] = reason
	payload["current"] = current
	payload["lastnew"] = lastnewHG
	payload["lastfull"] = lastfull
	--payload["sid"] = sidData 	
	--payload["geo"] = geoData 	
	--payload["devices"] = modelData 	
	payload["events"] = itemsExtendedHG 	
	
	local jsonGo, encodeOK = json.encode(payload)
	encodeOK = encodeOK or 'OK'
	if encodeOK ~= 'OK' then
		LogHG('SendDataHG jsonGo encode:' .. encodeOK)
	end	
	
	--if DEBUG == 1 then LogHG('SendDataHG start payload: ' .. jsonGo) end  
  
	code, interval = sendRequestHookHG(reason, current, lastnewHG, lastfull, payload, jsonGo, interval, DEBUG)  
	if DEBUG == 1 then LogHG('SendDataHG end code: ' .. code) end  

	if code ~= 200 then
		LogHG('SendDataHG failed status: ' .. (code or 'empty') .. ' url: ' .. SRV_URL_POST)
	end

	if (code == 0) then
		showcode = 'Not running (0)'
	elseif (code == 200) then
		showcode = 'OK (code:200)'
		lastnewHG = tonumber(current)
	elseif code == 204 then
		--interval = 60*60
		showcode = 'No data received(204), interval was updated to once an hour. Update reporting sensors and restart a plugin'	
	elseif code == 205 then
		--interval = 60*60*24
		showcode = 'Your API key is wrong (205), interval was updated to once a day. Update your API key and restart a plugin'	
	elseif code == 401 then
		-- interval = 60*60*24
		showcode = 'Your API key is wrong (401), interval was updated to once a day. Update your API key and restart a plugin'	
	elseif code == 402 then
		interval = interval + 30
		rtOff = true
		showcode = 'You are using frequent sending requiring payment (402). Reporting interval was increased by 30 secs, new: ' .. interval
	elseif code == 404 then
		--interval = interval + 30
		showcode = 'Server is offline'
	elseif code == 429 then
		interval = interval + 30
		showcode = 'You are using frequent sending requiring payment (429). Reporting interval was increased by 30 secs, new: ' .. interval
	elseif code == 501 then
		showcode = 'Server returned 501. Some issue on the receiving side (501)'
	else
		showcode = 'Unknown status was returned: ' .. (code or 'empty')
	end
  
	luup.variable_set( SID.HG, "lastRun", showcode, pdev )
	if (rtOff) then
		luup.variable_set( SID.HG, "realTime", 0, pdev )
	end
	if (code ~= httpRes) then
		httpRes = code
	end		
	if code == 200 then
		local commfailure = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', "CommFailure", pdev) or 0
		commfailure = tonumber(commfailure)
		if (commfailure == 1) then
			luup.variable_set('urn:micasaverde-com:serviceId:HaDevice1', "CommFailure", 0, pdev)
		end
	end
	LogHG('SendDataHG: ' .. showcode)

	return showcode, lastnewHG, interval
end
function sendRequestHookHG(sender, current, lastnewHG, lastfull, payload, jsonGo, interval, DEBUG)
  
	local response_body1 = {}
	local response_body2 = {}
	-- local response_body2 = {}
	local res, res1, res2, response_headers, monitors, serverRes  
	local status = 'waiting'
	local code = 0
	local code1 = 0
	local code2 = 0 
	local body = {}
	local rTable, decodeOK
	local decodeTry = 1

	enabled = luup.variable_get(SID.HG, "Enabled", pdev) or 0
	enabled = tonumber(enabled) or 0
	devEnabled = luup.variable_get(SID.HG, "Dev", pdev) or 0
	devEnabled = tonumber(devEnabled) or 0
	local showDev = luup.variable_get(SID.HG, "showDev", pdev) or 0
	showDev = tonumber(showDev)

	if DEBUG == 1 then
		LogHG('sendRequestHook start with payload: ' .. (jsonGo or 'empty') .. 'enabled:' .. enabled .. 'devEnabled:' .. devEnabled)
	end
  
	if enabled == 1 then
		LogHG(' prod enabled: ' .. enabled)
		res1, code1, response_headers, status = http.request{
			method = "POST",
			url = SRV_URL_POST,		
			headers = {
				["Content-Type"] = "application/json",
				["Content-Length"] = jsonGo:len()
			},
			source = ltn12.source.string(jsonGo),
			sink = ltn12.sink.table(response_body1)
		}
		code1 = tonumber(code1) or 'empty'	
		status = status or 'empty'	
		luup.sleep(1000);
		--response_body1 = response_body1 or {}
		if code1 == 200 then
			LogHG('Prod response code: ' .. code1.. ' status: ' .. status)
			-- if (DEBUG == 1) then 
				-- rTable, decodeOK = json.decode(table.concat())
				-- decodeOK = decodeOK or 'OK'				
				-- LogHG('ServerResponse prod rTable: ' .. decodeOK or 'OK' .. ' table: ' .. rTable['env'] or 'env' )	
			-- end
		else
			LogHG('Prod response code: ' .. code1.. ' status: ' .. status)
			LogHG('Prod Response body: ' .. table.concat(response_body1) .. '\n')	
		end
		
		--res1 = response_body1[0] or response_body1[1]
	end
  
	if devEnabled == 1 then
		LogHG(' dev enabled: ' .. devEnabled)	
		res2, code2, response_headers, status = http.request{
			method = "POST",
			url = DEV_URL_POST,		
			headers = {
				["Content-Type"] = "application/json",
				["Content-Length"] = jsonGo:len()
			},
			source = ltn12.source.string(jsonGo),
			sink = ltn12.sink.table(response_body2)
		}
		code2 = tonumber(code2) or 'empty'	
		status = status or 'empty'	
		luup.sleep(1000);
		-- response_body2 = response_body2 or {}
		if code2 == 200 then
			LogHG('Dev response code: ' .. code2.. ' status: ' .. status)
			if response_body2 == nil then
				LogHG('ServerResponse dev NIL: ' .. dumpTable(response_body2) or 'no body' )		
			-- elseif (DEBUG == 1) then 
				-- LogHG('ServerResponse dev: ' .. dumpTable(response_body2) or 'no body')	
				-- rTable, decodeOK = json.decode(table.concat())
				-- decodeOK = decodeOK or 'OK'				
				-- LogHG('ServerResponse dev rTable: ' .. decodeOK or 'OK' .. ' table: ' .. rTable['env'] or 'env' )		
			end
		else
			LogHG('Dev response code: ' .. code2.. ' status: ' .. status)
			LogHG('Dev Response body: ' .. table.concat(response_body2) .. '\n')	
		end
		--res2 = response_body2[0] or response_body2[1]
	end
	
	luup.sleep(1000);
  
	if (showDev == 1) then	
		code = code2 or code1 or 0
		body = response_body2 or response_body1 or {}
		res = res2 or res1 or 'empty res'
	else
		code = code1 or 0
		body = response_body1 or {}
		res = res1 or 'empty res'
	end
	
	LogHG('sendRequestHook end = ' .. code .. ' ' .. code1 .. '/' .. code2 .. ' status:' .. status .. ' res: ' .. res or 'no res')	
	
	rTable, decodeOK = json.decode(body[0])	
	decodeOK = decodeOK or 'OK'
	--LogHG('json.decode1:' .. decodeOK)
	if decodeOK ~= 'OK' then
		rTable, decodeOK = json.decode(body[1])
		decodeOK = decodeOK or 'OK'
		decodeTry = 2
	end
	if decodeOK ~= 'OK' then
		rTable, decodeOK = json.decode(table.concat(body))
		decodeOK = decodeOK or 'OK'
		decodeTry = 3
	end
	--LogHG('json.decode2:' .. decodeOK)
	if decodeOK ~= 'OK' then
		rTable, decodeOK = json.decode(body)
		decodeOK = decodeOK or 'OK'
		decodeTry = 4
	end
	LogHG('json.decode:' .. decodeOK .. ' on ' .. decodeTry .. ' try')
	
	if decodeOK == 'OK' then
		rTable = rTable or {}	
		LogHG('ServerResponse env: ' .. (rTable['env'] or 'env'))			
		LogHG('ServerResponse monitors: ' .. (rTable['monitors'] or '0'))		
		LogHG('ServerResponse count: ' .. json.encode(rTable['count'] or {}))
		uploadedHG = rTable['monitors'] or ''		
		
		if rTable['interval'] then
			interval = tonumber(json.encode(rTable['interval'])) or interval
			LogHG('ServerResponse new interval: ' .. interval)
		end
		if rTable['realTime'] then
			local realTime = tonumber(json.encode(rTable['realTime'])) or 0
			luup.variable_set(SID.HG, "realTime", realTime, pdev)
			LogHG('ServerResponse new real time: ' .. realTime)
		end	
	else 		
		LogHG('ServerResponse decode ERR: ' .. decodeOK .. ', body: ' .. dumpTable(body) or 'no body' .. ' ' .. dumpTable(body) or 'no body')
	end
	serverRes = dumpTable(body) or table.concat(body) or '{[1]="no server response"}'
	
	--LogHG('ServerResponse secondary: ' .. table.concat(itemsSecondaryHG))
	
	if code ~= 200 then
		LogHG('ServerResponse no updated code: ' .. code)
		luup.variable_set( SID.HG, "ServerResponse", 'server code: ' .. code, pdev)    
	elseif decodeOK ~= 'OK' then 
		luup.variable_set( SID.HG, "ServerResponse", serverRes, pdev)    
	elseif DEBUG == 1 then 
		luup.variable_set( SID.HG, "ServerResponse", json.encode(rTable), pdev)    
	else
		rTable['details'] = ''
		luup.variable_set( SID.HG, "ServerResponse", json.encode(rTable), pdev)   
		LogHG('ServerResponse updated: ' .. dumpTable(rTable))
	end

	return code, interval
end  
function sendRequestCurlHG(sender, current, lastnewHG, lastfull, payload, jsonGo, interval, DEBUG)
  
	local response_body1 = {}
	local response_body2 = {}
	-- local response_body2 = {}
	local res, res1, res2, response_headers, monitors  
	local status = 'waiting'
	local code = 0
	local code1 = 0
	local code2 = 0 
	local body = {}

	enabled = luup.variable_get(SID.HG, "Enabled", pdev) or 0
	enabled = tonumber(enabled) or 0
	devEnabled = luup.variable_get(SID.HG, "Dev", pdev) or 0
	devEnabled = tonumber(devEnabled) or 0
	local showDev = luup.variable_get(SID.HG, "showDev", pdev) or 0
	showDev = tonumber(showDev)

	if DEBUG == 1 then
		LogHG('sendRequestHook start with payload: ' .. (jsonGo or 'empty') .. 'enabled:' .. enabled .. 'devEnabled:' .. devEnabled)
	end
  
	if devEnabled == 1 then
		LogHG(' dev enabled: ' .. devEnabled)
		--res, code2, response_headers, status = https.request{
		
		local command = "curl "

		-- if(noCertCheck == 1) then
			-- command = command .. "-k "
		-- end
		--command = command .. " -s -H 'Content-Type: application/json' -s "..path.." -d '"..payload.."'"
		-- command = command .. " -k -s -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d  "..jsonGo.." "..DEV_URL_POST.."'"
		
		-- res = command
		
		-- local f = io.popen(command, 'r')
		-- local out = f:read('*all')
		-- f:close()
		
		-- res = tostring(out)
		-- res = res:gsub( "\"", "")
		-- LogHG('CURL:' .. (res or 'empty'))		
			
		-- res, status, code2 = luup.inet.request { 
			-- url = DEV_SSL_POST,
			-- headers = {accept = "application/json"},
			-- timeout = 60,
			-- 'data-raw' = jsonGo
		-- }
		-- luup.log(string.format("HundredGraphs Got curl code: %s, HTTP code: %s, response: %s", tostring(res), tostring(code2), tostring(status):gsub('\n','') ))

		--local request_body = { secret = "asecret", to = "test0@gmail.com", device = null, priority = "high", payload = jsonGo }
		-- local request_body = jsonGo
		code2 = tonumber(code2) or 'empty'	
		status = status or 'empty'
		status = status:gsub('\n','')
		

		--LogHG('Dev Response body: ' .. res .. '\n\n\n')
		--LogHG('Dev response code: ' .. code2 .. ' status: ' .. status)  
		
		if code2 == 200 then
			LogHG('Dev response code: ' .. code2 .. ' status: ' .. status)
		else
			LogHG('Dev response code: ' .. code2 .. ' status: ' .. status .. ' res: ' .. (res or 'empty'))
			--LogHG('Dev response code: '  .. code2 .. ' status: ' .. status .. ' jsonGo: ' .. jsonGo)
			LogHG('Dev Response body: ' .. (dumpTable(response_body2)):gsub('\n','') .. ' headers: ' .. (dumpTable(response_headers)):gsub('\n','') .. '\n')		
		end

		res2 = response_body2[0] or response_body2[1]

		-- if DEBUG == 1 then
			-- LogHG('Response dev1:' .. (dumpTable(response_body2)):gsub('\n','') .. '\n\n\n')
		-- end
	end
  
	if (showDev == 1) then	
		code = code2 or code1 or 0
		body = response_body2 or response_body1 or {}
		res = res2 or res1 or '{}'
	else
		code = code1 or 0
		body = response_body1 or {}
		res = res1 or '{}'
	end
	
	LogHG('sendRequestHook end = ' .. code .. ' ' .. code1 .. '/' .. code2 .. ' status:' .. status)	
	
	local rTable, decodeOK = json.decode(body)
	decodeOK = decodeOK or 'OK'
	--LogHG('json.decode1:' .. decodeOK)
	if decodeOK ~= 'OK' then
		rTable, decodeOK = json.decode(body[0])
		decodeOK = decodeOK or 'OK'
	end
	--LogHG('json.decode2:' .. decodeOK)
	if decodeOK ~= 'OK' then
		rTable, decodeOK = json.decode(table.concat(body))
		decodeOK = decodeOK or 'OK'
	end
	LogHG('json.decode3:' .. decodeOK)
	
	if decodeOK == 'OK' then
		rTable = rTable or {}	
		LogHG('ServerResponse env: ' .. (rTable['env'] or 'env'))		
		LogHG('ServerResponse monitors: ' .. (rTable['monitors'] or '0'))
		LogHG('ServerResponse count: ' .. json.encode(rTable['count'] or {}))
		
		if rTable['interval'] then
			interval = tonumber(json.encode(rTable['interval'])) or interval
			LogHG('ServerResponse new interval: ' .. interval)
		end
		if rTable['realTime'] then
			local realTime = tonumber(json.encode(rTable['realTime'])) or 0
			luup.variable_set(SID.HG, "realTime", realTime, pdev)
			LogHG('ServerResponse new real time: ' .. realTime)
		end	
	else 
		LogHG('ServerResponse decode ERR: ' .. decodeOK .. ', body: ' .. table.concat(body))
	end
	
	--LogHG('ServerResponse secondary: ' .. table.concat(itemsSecondaryHG))
	
	if code ~= 200 then
		LogHG('ServerResponse no updated code: ' .. code)
	elseif decodeOK ~= 'OK' or DEBUG == 1 then 
		luup.variable_set( SID.HG, "ServerResponse", table.concat(body), pdev)    
	else
		rTable['details'] = ''
		luup.variable_set( SID.HG, "ServerResponse", json.encode(rTable), pdev)   
	end

	return code, interval
end  
function ResetDataHG()
	items = {}

	itemsExtendedOldHG = itemsExtendedHG
	itemsExtendedHG = {}
	itemsSecondaryOldHG = itemsSecondaryHG
	itemsSecondaryHG = {}
	modelData = {}
	sidData = {}

	count = 0
	LogHG('ResetDataHG done')
	end

function HGTimerOnce()
  count = 0
  local code = 0
  local current = os.time()
  lastfull = 0
  lastnewHG = 0
  count = GetCurrentEvents(lastfull, current)
  code = SendDataHG('HGTimerOnce', current, lastnewHG, lastfull) or 501
end
function HGTimer()
	iter = iter + 1
	local sender
	local count = 0
	local current = tonumber(os.time())
	local code = 0
	local showcode = 'Running'

	LogHG('HG HGTimer start: ' .. interval)
	luup.device_message(pdev, -2, 'initializing', 1, 'startup');
	luup.device_message(pdev, -2, 'success', 1, 'HGTimer');
	luup.device_message(pdev, 1, 'uploading', 0, 'HGTimer');

	API_KEY = luup.variable_get( SID.HG, "API", pdev ) or 'empty'
	enabled = luup.variable_get(SID.HG, "Enabled", pdev) or 0
	devEnabled = luup.variable_get(SID.HG, "Dev", pdev) or 0
	DEBUG = luup.variable_get(SID.HG, "DEBUG", pdev) or 0
    
	if API_KEY == 'empty' then  
		showcode = 'Switched off!!! wrong API key: '		
		code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled .. ' showcode: ' .. showcode
		LogHG('HGTimer: ' .. code)
		luup.variable_set( SID.HG, "lastRun", code, pdev )
		--luup.variable_set( SID.HG, "running", 0, pdev )
		return false
	elseif interval == 'empty' then
		showcode = 'No interval set'
		code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled .. ' showcode: ' .. showcode
		LogHG('HGTimer: ' .. code)
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		--luup.variable_set( SID.HG, "running", 0, pdev )    
		return false
	elseif enabled == 0 and devEnabled == 0 then
		showcode = 'Disabled'
		code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled .. ' showcode: ' .. showcode
		LogHG('HGTimer: ' .. code)
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		--luup.variable_set( SID.HG, "running", 0, pdev )    
		luup.call_timer("HGTimer", 1, interval, "", interval)
		return
		--return false
	else
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
	end
    
	-- send device details once per day
	if (current - lastdetails >= 60*60*24*2) then  
		sender = 'GetDeviceDetails'
		status, count = xpcall(function() return GetDeviceDetails() end, errorhandlerHG )
		if (status) then
			status = 'success'
		else
			status = 'failed'
		end
		LogHG('HGTimer getting GetDeviceDetails: ' .. status .. ' ' .. #modelData .. '/' .. (count or 0))
		lastdetails = current
	end
	
	-- send events
	if (current - lastfull >= 60*60*4) then  
		sender = 'GetCurrentEvents'
		status, count = xpcall(function() return GetCurrentEvents(lastfull, current) end, errorhandlerHG )
		if (status) then
			status = 'success'
		else
			status = 'failed'
		end
		LogHG('HGTimer getting GetCurrentEvents: ' .. status .. ' ' .. #itemsExtendedHG .. '/' .. (count or 0))
		lastfull = current
		luup.variable_set( SID.HG, "lastFull", lastfull, pdev )
	else  
		sender = 'GetNewEvents'
		--ogHG('HGTimer getting GetNewEvents')
		--lastfull = tonumber(current)
		status, count = xpcall(function() return GetNewEvents(lastnewHG, current) end, errorhandlerHG ) 
		LogHG('HGTimer getting GetNewEvents: ' .. #itemsExtendedHG .. '/' .. (count or 0))
	end
  
	-- if there are new, send 'em
	if count > 0 then
		showcode, lastnewHG, interval = SendDataHG(sender, current, lastnewHG, lastfull, interval)
		-- local function sendIt()
		-- showcode, lastnewHG = SendDataHG(sender, current, lastnewHG, lastfull)
		-- end
		-- xpcall(sendIt, errorhandlerHG)
		ResetDataHG()  
	else
		showcode = ' No data to report'
		LogHG('HGTimer: ' .. showcode)   
	end
	
	-- update lastRun res so user knows
	luup.variable_set( SID.HG, "lastRun", showcode, pdev )
	luup.variable_set( SID.HG, "lastPush", current, pdev )
	--luup.variable_set( SID.HG, "running", 1, pdev )    
	
	-- call timer again
	luup.device_message(pdev, -2, 'uploading', 1, 'HGTimer');
	luup.device_message(pdev, 4, 'success', 45, 'HGTimer');
	local res = luup.call_timer("HGTimer", 1, interval, "", interval)
	local runtime = tonumber(os.time()) - current 

	LogHG(sender .. ' Uploaded ' .. uploadedHG .. '/' .. count .. ' events, in ' .. runtime .. 'sec, next in ' .. interval .. 'sec, res timer' .. res)

	return true
end

_G.reloadHG = reloadHG
_G.UpdateDebugHG = UpdateDebugHG
_G.HGTimerOnce = HGTimerOnce
_G.HGTimer = HGTimer
_G.UpdateVariablesHG = UpdateVariablesHG
_G.UpdateAPIHG = UpdateAPIHG
_G.UpdateNodeIdHG = UpdateNodeIdHG
_G.UpdateIntervalHG = UpdateIntervalHG
_G.UpdateStartHG = UpdateStartHG
_G.UpdateStartVersionHG = UpdateStartVersionHG
_G.watchDevicesHG = watchDevicesHG
_G.SendDataHG = SendDataHG
_G.ResetDataHG = ResetDataHG
_G.UpdateRealHG = UpdateRealHG
_G.AddPairHG = AddPairHG
_G.errorhandlerHG = errorhandlerHG

function startup(lul_device)
	lul_device = lul_device
	pdev = tonumber(lul_device)
	luup.variable_set( SID.HG, "ERR", '', pdev )
	luup.variable_set( SID.HG, "Reload", false, pdev )
	luup.variable_set( SID.HG, "showDev", '', pdev )
	luup.variable_set( SID.HG, "commfailure", '', pdev )
	luup.variable_set( SID.HG, "running", '', pdev )
	luup.variable_set( SID.HG, "ServerResponse", '', pdev )
	
	LogHG("starting with version: " .. version .. ' interval: ' .. interval .. ' device: ' .. lul_device )
	luup.device_message(pdev, 1, 'initializing', 60, 'startup');
	
	xpcall(initHG, errorhandlerHG )

	--LogHG("startup: " .. version .. ' interval: ' .. interval .. ' lul_device ' .. lul_device )
	local deviceData = luup.variable_get( SID.HG, "DeviceData", pdev )
	deviceData = deviceData or '{}'
	LogHG("Started with deviceData: " .. deviceData)
	if (deviceData == '{}' or deviceData == '') then
		VARIABLES = {}
		--luup.variable_set(SID.HG, "Interval", 3600, pdev)		
	else		
		status, VARIABLES = xpcall(function() return splitTable(deviceData) end, errorhandlerHG )
		-- VARIABLES = splitTable(deviceData)
		-- local textVar = table.concat(VARIABLES) or '{}'
		-- if (status) then
			-- LogHG("Started with success VARIABLES: " .. textVar)
		-- else
			-- LogHG("Started with failed VARIABLES: " .. textVar)
		-- end	
	end

	--LogHG("startup2: " .. version .. ' interval: ' .. interval .. ' lul_device ' .. lul_device )

	enabled = luup.variable_get( SID.HG, "Enabled", pdev ) or 0
	enabled = tonumber(enabled)
	devEnabled = luup.variable_get( SID.HG, "Dev", pdev ) or 0
	devEnabled = tonumber(enabled)

	--LogHG("startup3: " .. version .. ' interval: ' .. interval .. ' lul_device ' .. lul_device )

	NODE_ID = luup.variable_get( SID.HG, "DeviceNode", pdev ) or '1'
	API_KEY = luup.variable_get( SID.HG, "API", pdev )
	if (API_KEY == nil) then
	luup.variable_set( SID.HG, "API", 'empty', pdev )
	API_KEY = 'empty'
	else
	LogHG('Initial API_KEY: ' .. API_KEY)
	end  
	--BASE_URL = SRV_URL .. API_KEY

	luup.variable_watch("reloadHG", SID.HG, "Reload", pdev)
	luup.variable_watch("UpdateVariablesHG", SID.HG, "DeviceData", pdev)
	luup.variable_watch("UpdateVariablesHG", SID.HG, "DeviceData2", pdev)
	luup.variable_watch("UpdateAPIHG", SID.HG, "API", pdev)
	luup.variable_watch("UpdateIntervalHG", SID.HG, "Interval", pdev)
	luup.variable_watch("UpdateStartHG", SID.HG, "Enabled", pdev)
	luup.variable_watch("UpdateStartHG", SID.HG, "Dev", pdev)
	luup.variable_watch("UpdateNodeIdHG", SID.HG, "DeviceNode", pdev)
	luup.variable_watch("UpdateRealHG", SID.HG, "realTime", pdev)
	luup.variable_watch("UpdateDebugHG", SID.HG, "DEBUG", pdev)

	if (VARIABLES) then
		xpcall(function() GetWatchDevices(VARIABLES) end, errorhandlerHG )
	end
	LogHG("Started with version " .. version)
	
	xpcall(HGTimer, errorhandlerHG )
	
	return true
end

LogHG(version .. "*********************************************** ")


-- startup()
-- HGTimer()

return true