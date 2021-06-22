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
local version = '3.8'

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
local DEV_URL_POST = "http://dev.hundredgraphs.com/hook/"

-- Log debug messages
local DEBUG = 0 -- if you want to see results in the log on Vera
local remotedebug = false -- remote log, you probably don't need that

-- local lastFullUpload = 0

local items = {} -- contains items: { time, deviceId, value }
itemsExtendedHG = {} -- contains items: { time, deviceId, value }
itemsExtendedOldHG = {} -- contains items: { time, deviceId, value }
itemsSecondaryHG = {} -- contains items: { time, deviceId, value }
itemsSecondaryOldHG = {} -- contains items: { time, deviceId, value }
local g_deviceData = {}
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
lastnewHG = 0

local p = print
local https = require "ssl.https"
local http = require('socket.http')
https.TIMEOUT = 5
http.TIMEOUT = 60


local BASE_URL = ""

function errorhandlerHG( err )
   luup.log( "[HundredGraphs Logger] ERROR: " .. err )
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

function UpdateStartHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)  
  if lul_variable == 'Enabled' then
    enabled = tonumber(lul_value_new or 0)
  elseif lul_variable == 'Dev' then
    devEnabled = tonumber(lul_value_new or 0)
  end
  
  lul_value_old = lul_value_old or 0
  lul_value_new = lul_value_new or 0
  
  LogHG('running was:' .. lul_value_old .. ' now:' .. lul_value_new .. ' enabled: ' .. enabled .. ', dev enabled: ' .. devEnabled)
  luup.reload()
  
end
function UpdateStartVersionHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)  
  version = luup.variable_get( SID.HG, "version", pdev ) or ''
  LogHG(' version was updated: ' .. version)
  return version
end
function UpdateAPIHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  API_KEY = luup.variable_get(SID.HG, "API", pdev) or 'empty'
  LogHG("Watched API_KEY: " .. API_KEY )
end
function UpdateIntervalHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  interval = tonumber(lul_value_new) or 3600
  if (interval < 60) then
    interval = 65
    LogHG("Setting Interval (wrong): " .. interval)
    luup.variable_set(SID.HG, "Interval", interval, pdev)
  else
    LogHG("Setting Interval (right): " .. interval)
  end  
  LogHG( ' Watched Interval: ' .. interval)
  luup.reload()
  return interval
end
function UpdateVariablesHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  -- local deviceData = luup.variable_get(SID.HG, "DeviceData", pdev) or ''
  -- if deviceData == '' then return end
  -- VARIABLES = splitTable(deviceData)
  LogHG("Updated devices: " .. lul_device .. ' var: ' .. lul_variable .. '\n')
  luup.call_delay(luup.reload(), 80)
  
  --luup.call_action("urn:micasaverde-com:serviceId:HomeAutomationGateway1", "Reload", {}, 0)
  -- GetWatchDevices(VARIABLES)
  -- LogHG("Updated VARIABLES2: " .. dumpTable(VARIABLES2))
end
function UpdateNodeIdHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  NODE_ID = luup.variable_get(SID.HG, "DeviceNode", pdev) or '1'
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
	--LogHG("Start Splitting: " .. str)
	for line in str.gmatch(str, pat) do
		local item = {}
		line = string.gsub(line, ';', '')
		--LogHG("Splitting line: " .. line)
		pat = '([^,]+)'
		for ins in line.gmatch(line, pat) do
			ins = string.gsub(ins, ',', '')
			local res = {}
			for key, value in string.gmatch(ins, "([^&=]+)=([^&=]+)") do
				key = string.gsub(key, ' ', '')
				--Log ('key: ' .. key .. ' value: ' .. value)
				item[key]=value
			end
			--LogHG(' Solitting ins: ' .. ins)
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
      luup.variable_watch("watchDevicesHG", v.serviceId, v.serviceVar, tonumber(v.deviceId))
      LogHG("Watching device added: " .. v.deviceId .. ' ' .. v.serviceVar .. ' ' .. v.key)
      count = count + 1
    end
  end

  LogHG("Watching devices: " .. count)
  return count
end
function watchDevicesHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
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
		--status, err, ret = xpcall( AddPairHG(1000*current, id, var, val), errorhandlerHG )	
		itemExtended = {['time'] = 1000*current, ['id'] = id, ['type'] = var, ['value'] = val}
		itemsExtendedHG[#itemsExtendedHG + 1] = itemExtended
	end
	
	LogHG("Watched collected:" .. (#itemsExtendedHG or 0) .. ' real?:' .. realTime .. ' id:' .. id .. '/' .. var .. ' val:' .. old .. '/' .. val .. '\n')
	
	if realTime == 1 then  
		SendDataHG('realTime')
		ResetDataHG()
		lastnewHG = tonumber(current)
	end
  
end

local function GetNewEvents(lastnewHG, current)
  count = 0
  local total = 0
  
  --local current = os.time()
  
  for i, v in ipairs(VARIABLES) do
    if (v.enabled == 'checked') then
      local val = 0      
      local lastSeen = 0
      local comm = 0
	  local item = {}
      v.deviceId = tonumber(v.deviceId)        

      --val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
      comm = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailure', v.deviceId) or 0
      comm = tonumber(comm)
      if (comm ~= 0) then
        val = 'offline'
        lastSeen = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailureTime', v.deviceId) or current     
        LogHG('HG GetNewEvents:' .. count .. ' device: ' .. v.deviceId .. ' lastSeen:' .. lastSeen .. ' offline: ' .. comm)      
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
		AddPairHG(1000*lastSeen, v.deviceId, v.serviceVar, val, v.key )
		count = count + 1
      end
      
    end
  end
 
  --AddPairHG(current, TOTAL, 'Watts', total,  'Total' )
  if (DEBUG == 1) then LogHG("GetNewEvents collected vars: " .. #itemsExtendedHG .. '/' .. count) end
  -- if (DEBUG) then LogHG("collected Ext vars: " .. #itemsExtendedHG .. ' table: ' .. json.encode(itemsExtended)) end
  return count
end
local function GetCurrentEvents(lastfull, current)
  local count = 0
  local total = 0
  -- we will collect everything
  itemsSecondaryHG = {}
  
  for i, v in ipairs(VARIABLES) do
    if (v.enabled == 'checked') then
		local val = 0
		local key = v.key
		local comm = 0     
		local roomNam, roomName

      v.deviceId = tonumber(v.deviceId)        
      comm = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailure', v.deviceId) or 0
      comm = tonumber(comm) or 0
      
      if (comm == 0) then
        val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
        val = tostring(val)
		--key = luup.variable_get('urn:micasaverde-com:serviceId:ZWaveDevice1', 'ConfiguredName', v.deviceId) or v.key
		key =  luup.attr_get ('name', tonumber(v.deviceId)) or v.key or v.deviceId
		roomNum =  luup.attr_get ('room', tonumber(v.deviceId)) or 0
		roomNum = tonumber(roomNum)
		roomName =  luup.rooms[roomNum] or 'House'
        --status = xpcall( AddPairHG(current, v.deviceId, v.serviceVar, val, v.key), myerrorhandler )
        --LogHG('GetCurrentEvents: ' .. status)
        
		--xpcall( AddPairHG(1000*current, v.deviceId, v.serviceVar, val, v.key ), errorhandlerHG )
		xpcall(function() AddPairHG(1000*current, v.deviceId, v.serviceVar, val, key, roomNum, roomName ) end, errorhandlerHG)
      else      
		--xpcall( AddPairHG(1000*current, v.deviceId, 'activity', 'offline', v.key ), errorhandlerHG )
		xpcall(function() AddPairHG(1000*current, v.deviceId, 'activity', 'offline', v.key ) end, errorhandlerHG)
        LogHG('HG log offline: ' .. v.deviceId .. ' offline ' .. comm)
      end

      count = count + 1
    end
  end
  --AddPairHG(1000*current, TOTAL, 'Watts', total,  'Total' )
  --if (DEBUG == 1) then 
  LogHG("GetCurrentEvents collected vars: " .. count) 
  --end

  return count
end

function AddPairHG(last, id, var, value, key, roomNum, roomName)
	--LogHG(' AddPair started key: ' .. (key or "empty") .. ' value: ' .. (value or "empty"))
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
		return 
	end
	
	if key == nil then
		itemExtended = {['time'] = last, ['id'] = id, ['type'] = var, ['value'] = value}
		itemSec = {['id'] = id, ['type'] = var, ['value'] = value}	
		itemsSecondaryHG[itemKey] = value
	else
		itemExtended = {['time'] = last, ['id'] = id, ['type'] = var, ['value'] = value, ['key'] = key, ['roomNum'] = roomNum, ['roomName'] = roomName } 
		itemSec = {['id'] = id, ['type'] = var, ['value'] = value}	
		itemsSecondaryHG[itemKey] = value
	end
	
	itemsExtendedHG[#itemsExtendedHG + 1] = itemExtended
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

	return true
end

local function sendRequestHook(sender, current, lastnewHG, lastfull, payload, interval, DEBUG)
  
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
		LogHG('sendRequestHook start with payload: ' .. payload or 'empty')
	end
  
	if enabled == 1 then
		LogHG(' prod enabled: ' .. enabled)
		res, code1, response_headers, status = http.request{
			url = SRV_URL_POST,
			method = "POST",
			headers = {
				["Content-Type"] = "application/json",
				["Content-Length"] = payload:len()
			},
			source = ltn12.source.string(payload),
			sink = ltn12.sink.table(response_body1)
		}
		code1 = tonumber(code1) or 501	
		status = status or 'empty'

		--LogHG('Prod Response body: ' .. res .. '\n\n\n')
		--LogHG('Prod response code: ' .. code1 .. ' status: ' .. status)  
		
		if code1 == 200 then
			LogHG('Prod response code: ' .. code1.. ' status: ' .. status)
		else
			LogHG('Prod response code: '  .. code1 .. ' status: ' .. status .. ' payload: ' .. payload)
			LogHG('Prod Response body: ' .. table.concat(response_body1) .. '\n')	
		end

		res1 = response_body2[0] or response_body2[1]

		if DEBUG == 1 then
			LogHG('Response Prod1:' .. table.concat(response_body1) .. '\n\n\n')
			--LogHG('Response Prod2:' .. (res2 or 'empty res') .. '\n\n\n')
		end
	end
  
	if devEnabled == 1 then
		LogHG(' dev enabled: ' .. devEnabled)
		res, code2, response_headers, status = http.request{
			url = DEV_URL_POST,
			method = "POST",
			headers = {
				["Content-Type"] = "application/json",
				["Content-Length"] = payload:len()
			},
			source = ltn12.source.string(payload),
			sink = ltn12.sink.table(response_body2)
		}
		code2 = tonumber(code2) or 501	
		status = status or 'empty'

		--LogHG('Dev Response body: ' .. res .. '\n\n\n')
		--LogHG('Dev response code: ' .. code2 .. ' status: ' .. status)  
		
		if code2 == 200 then
			LogHG('Dev response code: ' .. code2 .. ' status: ' .. status)
		else
			LogHG('Dev response code: '  .. code2 .. ' status: ' .. status .. ' payload: ' .. payload)
			LogHG('Dev Response body: ' .. table.concat(response_body2) .. '\n')		
		end

		res2 = response_body2[0] or response_body2[1]

		if DEBUG == 1 then
			LogHG('Response dev1:' .. table.concat(response_body2) .. '\n\n\n')
			--LogHG('Response dev2:' .. (res2 or 'empty res') .. '\n\n\n')	  
		end
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
	
	payload["events"] = itemsExtendedHG 	
	local jsonGo = json.encode(payload)
	--if DEBUG == 1 then LogHG('SendDataHG start payload: ' .. jsonGo) end  
  
	code, interval = sendRequestHook(reason, current, lastnewHG, lastfull, jsonGo, interval, DEBUG)  
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
function ResetDataHG()
  items = {}
  
  itemsExtendedOldHG = itemsExtendedHG
  itemsExtendedHG = {}
  itemsSecondaryOldHG = itemsSecondaryHG
  itemsSecondaryHG = {}
  
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
		return false
	else
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
	end
    
  -- BASE_URL = SRV_URL .. API_KEY
  --if (iter == 6) then
  
  --lastfull = current

	-- get current if 3 hrs passed, otherwise get new since lastcheck
	--if (VARIABLES == {})
	if (current - lastfull >= 60*60*2) then  
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
		LogHG('HGTimer getting GetNewEvents')
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
	local res = luup.call_timer("HGTimer", 1, interval, "", interval)
	local runtime = tonumber(os.time()) - current 

	LogHG(' Uploaded ' .. #itemsExtendedHG .. '/' .. count .. ' events, in .. ' .. runtime .. ' next in ' .. interval .. ' sec, res ' .. res)

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
_G.watchDevicesHG = watchDevicesHG
_G.SendDataHG = SendDataHG
_G.ResetDataHG = ResetDataHG
_G.UpdateRealHG = UpdateRealHG
_G.AddPairHG = AddPairHG
_G.errorhandlerHG = errorhandlerHG

function startup(lul_device)
	lul_device = lul_device
	pdev = tonumber(lul_device)
	--LogHG("startup0: " .. version .. ' interval: ' .. interval .. ' lul_device ' .. lul_device )

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

LogHG("*********************************************** ")


-- startup()
-- HGTimer()

return true