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
local version = '3.6'

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
function errorhandlerHG( err )
   luup.log( "ERROR:" .. err )
end

-- not used anymore
local function TableInsert(item)
  Log( " Inserting item data: " .. item )
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
local function splitTable(str)
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
  Log( " New device data: " .. deviceData )
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
  if (DEBUG == 1) then Log(" sending data: " .. parameters) end
  local res, code, response_headers, status = https.request{
    url = url,
    protocol = "tlsv1_2",
  }
  
  Log('Status Old: ' .. (code or 'empty') .. ' url: ' .. BASE_URL .. '\n')

  return code
end  


function initHG()
  Log( " Init started " .. enabled .. ' ' .. version .. ' ' .. devEnabled .. ' ' .. interval .. ' ' .. DEBUG .. ' ' )
  luup.variable_set(SID.HG, "version", version, pdev)
  enabled = luup.variable_get( SID.HG, "Enabled", pdev ) or 0
  devEnabled = luup.variable_get( SID.HG, "Dev", pdev ) or 0
  interval = luup.variable_get( SID.HG, "Interval", pdev ) or 0
  interval = tonumber(interval)
  if interval < 60 then
    interval = 3600
    luup.variable_set(SID.HG, "Interval", interval, pdev)    
  end
  DEBUG = luup.variable_get( SID.HG, "DEBUG", pdev )
  if DEBUG == nil then
    luup.variable_set(SID.HG, "DEBUG", 0, pdev)
    DEBUG = 0
  else
    DEBUG = tonumber(DEBUG)
  end
  realTime = luup.variable_get( SID.HG, "realTime", pdev )
  if realTime == nil then
    luup.variable_set(SID.HG, "realTime", 0, pdev)
    realTime = 0
  else
    realTime = tonumber(realTime)
  end
  Log( " Init done en:" .. enabled .. ' dev:' .. devEnabled .. ' interval:' .. interval .. ' DEBUG:' .. DEBUG .. ' ' )
end

function UpdateStartHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)  
  if lul_variable == 'Enabled' then
    enabled = tonumber(lul_value_new or 0)
  elseif lul_variable == 'Dev' then
    devEnabled = tonumber(lul_value_new or 0)
  end
  
  -- local running = luup.variable_get( SID.HG, "running", pdev ) or 0
  -- running = tonumber(running)
  
  -- Log('running was:' .. running .. 'enabled: ' .. enabled .. ', dev enabled: ' .. devEnabled)
  -- if (running == 0) then
    -- if (enabled == 1 or devEnabled == 1) then
      -- Log('Starting HGTimer')
      -- HGTimer()
    -- end
  -- end
  Log('running was:' .. lul_value_old .. ' now:' .. lul_value_new .. ' enabled: ' .. enabled .. ', dev enabled: ' .. devEnabled)
  luup.reload()
  
end
function UpdateStartVersionHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)  
  version = luup.variable_get( SID.HG, "version", pdev ) or ''
  Log(' version was updated: ' .. version)
  return version
end
function UpdateAPIHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  API_KEY = luup.variable_get(SID.HG, "API", pdev) or 'empty'
  Log( " Watched API_KEY: " .. API_KEY )
end
function UpdateIntervalHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  interval = tonumber(lul_value_new) or 3600
  if (interval < 60) then
    interval = 65
    Log( " Setting Interval (wrong): " .. interval)
    luup.variable_set(SID.HG, "Interval", interval, pdev)
  else
    Log( " Setting Interval (right): " .. interval)
  end  
  Log( ' Watched Interval: ' .. interval)
  luup.reload()
  return interval
end
function UpdateVariablesHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  -- local deviceData = luup.variable_get(SID.HG, "DeviceData", pdev) or ''
  -- if deviceData == '' then return end
  -- VARIABLES = splitTable(deviceData)
  Log( " Updated devices: " .. lul_device .. ' var: ' .. lul_variable .. '\n')
  luup.call_delay(luup.reload(), 60)
  
  --luup.call_action("urn:micasaverde-com:serviceId:HomeAutomationGateway1", "Reload", {}, 0)
  -- GetWatchDevices(VARIABLES)
  -- Log( " Updated VARIABLES2: " .. dumpTable(VARIABLES2))
end
function UpdateNodeIdHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  NODE_ID = luup.variable_get(SID.HG, "DeviceNode", pdev) or '1'
  Log( " Watched NODE_ID: " .. NODE_ID )
end
function UpdateRealHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  realTime = tonumber(lul_value_new) or 0
  Log( " Watched realTime change: " .. realTime)
  --Log( " Watched realTime change: " .. lul_device .. ' ' .. lul_service .. ' ' .. lul_variable .. ' ' .. lul_value_new )
end
function UpdateDebugHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  DEBUG = tonumber(lul_value_new) or 0
  Log( " Watched DEBUG change: " .. DEBUG)
  --Log( " Watched DEBUG change: " .. lul_device .. ' ' .. lul_service .. ' ' .. lul_variable .. ' ' .. lul_value_new )
end

local function GetWatchDevices(VARIABLES)
  count = 0
  local total = 0
  local current = os.time()
  
  for i, v in ipairs(VARIABLES) do
    if (v.enabled == 'checked' and v.burst == 'checked') then              
      luup.variable_watch("watchDevicesHG", v.serviceId, v.serviceVar, tonumber(v.deviceId))
      Log(" Watching device added: " .. v.deviceId .. ' ' .. v.serviceVar .. ' ' .. v.key)
      count = count + 1
    end
  end

  Log(" Watching devices: " .. count)
  return count
end
function watchDevicesHG(lul_device, lul_service, lul_variable, lul_value_old, lul_value_new)
  local rt = realTime
  local status = -1
  local id = tonumber(lul_device) or 0
  local var = tostring(lul_variable)
  local current = os.time()
  local itemExtended

  local old = tostring(lul_value_old) or 0
  local val = tostring(lul_value_new) or 0

  -- Log( " Watched devices found: " .. id .. '/' .. var .. ' val:' .. old .. '/' .. val )
  --luup.log(tostring(lul_value_old))
  --luup.log(tostring(lul_value_new))

  if (id ~= 0) then
    --status, err, ret = xpcall( AddPairHG(1000*current, id, var, val), errorhandlerHG )  
    itemExtended = {['time'] = 1000*current, ['id'] = id, ['type'] = var, ['value'] = val}
    itemsExtendedHG[#itemsExtendedHG + 1] = itemExtended
    -- Log('[watchDevicesHG] table size:' .. (#itemsExtendedHG or 0))
    --status = pcall(AddPairHG(1000*current, id, var, val))
    -- luup.log(status)
    -- luup.log(err)
    -- luup.log(ret)
    -- if (status) then
    -- luup.log('HundredTest AddPair succ '  .. id .. '/' .. var .. ' val:' .. old .. '/' .. val .. '\n\n')
    -- else
    -- luup.log('HundredTest AddPair fail '  .. id .. '/' .. var .. ' val:' .. old .. '/' .. val .. '\n\n')
    -- end
  end
  
  Log( "Watched collected:" .. (#itemsExtendedHG or 0) .. ' real?:' .. rt .. ' id:' .. id .. '/' .. var .. ' val:' .. old .. '/' .. val .. '\n')
  
  if realTime == 1 then  
    SendDataHG('realTime')
    ResetDataHG()
  end
  
end

local function GetNewEvents(lastnew, current)
  count = 0
  local total = 0
  --local current = os.time()
  
  for i, v in ipairs(VARIABLES) do
    if (v.enabled == 'checked') then
      local val = 0      
      local last = 0
      local comm = 0
      v.deviceId = tonumber(v.deviceId)        

      --val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
      comm = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailure', v.deviceId) or 0
      comm = tonumber(comm)
      if (comm ~= 0) then
        val = 'offline'
        last = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', 'CommFailureTime', v.deviceId) or current     
        Log('HG GetNewEvents:' .. count .. ' device: ' .. v.deviceId .. ' last:' .. last .. ' offline: ' .. comm)      
      else
        val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
        if (v.serviceId == "urn:micasaverde-com:serviceId:HaDevice1") then  
          last = luup.variable_get(v.serviceId, 'BatteryDate', v.deviceId) or current    
        elseif (v.serviceId == 'urn:micasaverde-com:serviceId:EnergyMetering1') then
          last = luup.variable_get(v.serviceId, 'KWHReading', v.deviceId) or current
        elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and tonumber(val) == 1) then
          last = luup.variable_get(v.serviceId, 'LastTrip', v.deviceId) or current
        elseif (v.serviceId == 'urn:micasaverde-com:serviceId:SecuritySensor1' and tonumber(val) == 0) then
          --last = luup.variable_get(v.serviceId, 'LastWakeup', v.deviceId) or current
          last = current
        else
          last = current
        end
      end
      last = tonumber(last)
      
      --Log("GetNewEvents collected var0: " .. count .. ' last ' .. last .. ' dev: ' .. v.deviceId .. '/' .. v.serviceVar .. ' val: ' .. val)
      
      if (last > lastnew) then
        --last = 1000 * last

        if (DEBUG == 1) then
          Log("GetNewEvents collected var1: " .. count .. ' last ' .. last .. ' lastnew ' .. lastnew .. ' device:' .. v.deviceId .. '/' .. v.serviceVar .. ' val: ' .. val)
        end
        
        AddPairHG(1000*last, v.deviceId, v.serviceVar, val, v.key )
        count = count + 1
      end
      
      if (DEBUG == 1) then Log("GetNewEvents collected var2: " .. count .. ' ' .. v.deviceId .. ' ' .. val) end
    end
  end
  --AddPairHG(current, TOTAL, 'Watts', total,  'Total' )
  if (DEBUG == 1) then Log("GetNewEvents collected vars: " .. count) end
  -- if (DEBUG) then Log(" collected Ext vars: " .. #itemsExtendedHG .. ' table: ' .. json.encode(itemsExtended)) end
  return count
end
local function GetCurrentEvents(lastfull, current)
  count = 0
  local total = 0
  --local current = os.time()
  
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
    key =  luup.attr_get ('name', tonumber(v.deviceId)) or v.key
    roomNum =  luup.attr_get ('room', tonumber(v.deviceId)) or 0
    roomNum = tonumber(roomNum)
    roomName =  luup.rooms[roomNum] or 'House'
        --status = xpcall( AddPairHG(current, v.deviceId, v.serviceVar, val, v.key), myerrorhandler )
        --Log('GetCurrentEvents: ' .. status)
        
    --xpcall( AddPairHG(1000*current, v.deviceId, v.serviceVar, val, v.key ), errorhandlerHG )
    AddPairHG(1000*current, v.deviceId, v.serviceVar, val, key, roomNum, roomName )
      else      
    --xpcall( AddPairHG(1000*current, v.deviceId, 'activity', 'offline', v.key ), errorhandlerHG )
    AddPairHG(1000*current, v.deviceId, 'activity', 'offline', v.key )
        Log('HG log offline: ' .. v.deviceId .. ' offline ' .. comm)
      end

      count = count + 1
    end
  end
  --AddPairHG(1000*current, TOTAL, 'Watts', total,  'Total' )
  if (DEBUG == 1) then Log("GetCurrentEvents collected vars: " .. count) end

  return count
end

function AddPairHG(last, id, var, value, key, roomNum, roomName)
  --Log(' AddPair started key: ' .. (key or "empty") .. ' value: ' .. (value or "empty"))
  local s
  local itemExtended = {}
  if key == nil then
    itemExtended = {['time'] = last, ['id'] = id, ['type'] = var, ['value'] = value}
  else
    itemExtended = {['time'] = last, ['id'] = id, ['type'] = var, ['value'] = value, ['key'] = key, ['roomNum'] = roomNum, ['roomName'] = roomName } 
  end
    itemsExtendedHG[#itemsExtendedHG + 1] = itemExtended

  -- if key == '' or key == nil then
    -- Log(' AddPair ended key: ' .. id .. '/' .. var .. ' ' .. (key or "watched") .. ' value: ' .. (value or "empty"))
    --Log(' AddPair itemExtended: ' .. table.concat(itemsExtendedHG))
    --luup.log(s)
    -- Log(' AddPair itemsExtendedHG: ' .. table.concat(itemsExtendedHG[#itemsExtendedHG]))
    --luup.log(s)
  -- end

  return true
end

local function sendRequestHook(sender, current, lastnew, lastfull, payload, interval, DEBUG)
  
  local response_body1 = {}
  local response_body2 = {}
  -- local response_body2 = {}
  local body, res, res1, res2, code, code1, code2, response_headers, status, monitors  

  enabled = luup.variable_get(SID.HG, "Enabled", pdev) or 0
  enabled = tonumber(enabled) or 0
  devEnabled = luup.variable_get(SID.HG, "Dev", pdev) or 0
  devEnabled = tonumber(devEnabled) or 0

  if DEBUG == 1 then
    Log('sendRequestHook start with payload: ' .. payload or 'empty')
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
      sink = ltn12.sink.table(response_body1)
    }
    code1 = tonumber(code1) or 501  
    status = status or 'empty'

    --Log('Prod Response body: ' .. res .. '\n\n\n')
    --Log('Prod response code: ' .. code1 .. ' status: ' .. status)  
    
    if code1 == 200 then
      Log('Prod response code: ' .. code1.. ' status: ' .. status)
    else
      Log('Prod response code: '  .. cod1 .. ' status: ' .. status .. ' payload: ' .. payload)
      Log('Prod Response body: ' .. table.concat(response_body1) .. '\n')  
    end

    res2 = response_body2[0] or response_body2[1]

    if DEBUG == 1 then
      Log('Response Prod1:' .. table.concat(response_body1) .. '\n\n\n')
      Log('Response Prod2:' .. (res or 'empty res') .. '\n\n\n')
    end
  end
  
  if devEnabled == 1 then
    Log(' dev enabled: ' .. devEnabled)
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

    --Log('Dev Response body: ' .. res .. '\n\n\n')
    --Log('Dev response code: ' .. code2 .. ' status: ' .. status)  
    
    if code1 == 200 then
      Log('Dev response code: ' .. code2 .. ' status: ' .. status)
    else
      Log('Dev response code: '  .. code2 .. ' status: ' .. status .. ' payload: ' .. payload)
      Log('Dev Response body: ' .. table.concat(response_body2) .. '\n')    
    end

    res2 = response_body2[0] or response_body2[1]

    if DEBUG == 1 then
      Log('Response dev1:' .. table.concat(response_body2) .. '\n\n\n')
      Log('Response dev2:' .. (res or 'empty res') .. '\n\n\n')    
    end
  end
  
  code = code1 or code2 or 0
  Log('sendRequestHook end = ' .. code .. ' status:' .. status)
  body = response_body2 or response_body2 or {}
  
  res = res1 or res2 or '{}'
  local rTable, msg = json.decode(res)
  msg = msg or 'OK'
  Log('json.decode:' .. msg)
  
  if msg == 'OK' then
    rTable = rTable or {}  
    Log('Response env: ' .. (rTable['env'] or 'env'))    
    Log('Response monitors: ' .. (rTable['monitors'] or '0'))
    Log('Response count: ' .. json.encode(rTable['count'] or {}))
    
    if rTable['interval'] then
      interval = tonumber(json.encode(rTable['interval'])) or interval
      Log('Response new interval: ' .. interval)
    end
    if rTable['rt'] then
      local rt = tonumber(json.encode(rTable['rt'])) or 0
      luup.variable_set(SID.HG, "realTime", rt, pdev)
      Log('Response new real time: ' .. rt)
    end
    
  end
  
  if msg ~= 'OK' or DEBUG == 1 then 
    luup.variable_set( SID.HG, "ServerResponse", table.concat(body), pdev)    
  else
    rTable['details'] = ''
    luup.variable_set( SID.HG, "ServerResponse", json.encode(rTable), pdev)   
  end

  return code, interval
end  

function SendDataHG(reason, current, lastnew, lastfull, interval)

  Log(" SendDataHG. Start sending data " .. reason .. ' between dates ' .. lastnew .. ' ' .. current )
  local showcode = ''
  local code = 0
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
  payload["lastnew"] = lastnew
  payload["lastfull"] = lastfull
  
  payload["events"] = itemsExtendedHG   
  local jsonGo = json.encode(payload)
  --if DEBUG == 1 then Log('SendDataHG start payload: ' .. jsonGo) end  
  
  code, interval = sendRequestHook(reason, current, lastnew, lastfull, jsonGo, interval, DEBUG)  
  if DEBUG == 1 then Log('SendDataHG end code: ' .. code) end  

  if code ~= 200 then
    Log('SendDataHG failed status: ' .. (code or 'empty') .. ' url: ' .. SRV_URL_POST)
  end

  if (code == 0) then
    showcode = 'Not running (0)'
  elseif (code == 200) then
    showcode = 'OK (code:200)'
    lastnew = tonumber(current)
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
    showcode = 'You are using frequent sending requiring payment (402). Reporting interval was increased by 30 secs, new: ' .. interval
  elseif code == 429 then
    interval = interval + 30
    showcode = 'You are using frequent sending requiring payment (429). Reporting interval was increased by 30 secs, new: ' .. interval
  elseif code == 501 then
    showcode = 'Server returned 501. Some issue on the receiving side (501)'
  else
    showcode = 'Unknown status was returned: ' .. (code or 'empty')
  end
  
  luup.variable_set( SID.HG, "lastRun", showcode, pdev )

  if (code ~= httpRes) then
    httpRes = code

    if code == 200 then
      local commfailure = luup.variable_get('urn:micasaverde-com:serviceId:HaDevice1', "CommFailure", pdev) or 0
      commfailure = tonumber(commfailure)
      if (commfailure == 1) then
        luup.variable_set('urn:micasaverde-com:serviceId:HaDevice1', "CommFailure", 0, pdev)
      end
    end
  end
  Log('SendDataHG: ' .. showcode)

  return showcode, lastnew, interval
end
function ResetDataHG()
  items = {}
  itemsExtendedHG = {}
  count = 0
  Log('ResetDataHG done')
end

function HGTimerOnce()
  count = 0
  local code = 0
  local current = os.time()
  lastfull = 0
  lastnew = 0
  count = GetCurrentEvents(lastfull, current)
  code = SendDataHG('HGTimerOnce', current, lastnew, lastfull) or 501
end
function HGTimer()
  iter = iter + 1
  local sender
  local count = 0
  local current = tonumber(os.time())
  local code = 0
  local showcode = 'Running'

  Log('HG HGTimer start: ' .. interval)

  API_KEY = luup.variable_get( SID.HG, "API", pdev ) or 'empty'
  enabled = luup.variable_get(SID.HG, "Enabled", pdev) or 0
  devEnabled = luup.variable_get(SID.HG, "Dev", pdev) or 0
  DEBUG = luup.variable_get(SID.HG, "DEBUG", pdev) or 0
    
  if API_KEY == 'empty' then  
    showcode = 'Switched off!!! wrong API key: '    
    code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled .. ' showcode: ' .. showcode
    Log('HGTimer: ' .. code)
    luup.variable_set( SID.HG, "lastRun", code, pdev )
    --luup.variable_set( SID.HG, "running", 0, pdev )
    return false
  elseif interval == 'empty' then
    showcode = 'No interval set'
    code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled .. ' showcode: ' .. showcode
    Log('HGTimer: ' .. code)
    luup.variable_set( SID.HG, "lastRun", showcode, pdev )
    --luup.variable_set( SID.HG, "running", 0, pdev )    
    return false
  elseif enabled == 0 and devEnabled == 0 then
    showcode = 'Disabled'
    code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled .. ' showcode: ' .. showcode
    Log('HGTimer: ' .. code)
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
  if (current - lastfull > 60*60*3) then  
    sender = 'GetCurrentEvents'
    count = GetCurrentEvents(lastfull, current)
    Log('HGTimer getting GetCurrentEvents: ' .. count)
    lastfull = current
    luup.variable_set( SID.HG, "lastFull", lastfull, pdev )
  else  
    sender = 'GetNewEvents'
    Log('HGTimer getting GetNewEvents')
    --lastfull = tonumber(current)
    count = GetNewEvents(lastnew, current)
    Log('HGTimer getting GetNewEvents: ' .. count)
  end
  
  -- if there are new, send 'em
  if count > 0 then
    showcode, lastnew, interval = SendDataHG(sender, current, lastnew, lastfull, interval)
    -- local function sendIt()
    -- showcode, lastnew = SendDataHG(sender, current, lastnew, lastfull)
    -- end
    -- xpcall(sendIt, errorhandlerHG)
    ResetDataHG()  
  else
    showcode = ' No data to report'
    Log('HGTimer: ' .. showcode)   
  end
  
  -- update lastRun res so user knows
  luup.variable_set( SID.HG, "lastRun", showcode, pdev )
  luup.variable_set( SID.HG, "lastPush", current, pdev )
  --luup.variable_set( SID.HG, "running", 1, pdev )    
  
  -- call timer again
  local res = luup.call_timer("HGTimer", 1, interval, "", interval)

  Log(' Uploaded ' .. count .. ' events, next in ' .. interval .. ' sec, res ' .. res)

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
  --Log(" startup0: " .. version .. ' interval: ' .. interval .. ' lul_device ' .. lul_device )

  initHG()

  --Log(" startup: " .. version .. ' interval: ' .. interval .. ' lul_device ' .. lul_device )
  local deviceData = luup.variable_get( SID.HG, "DeviceData", pdev ) or ""
  if (deviceData == "" or deviceData == '-') then
  VARIABLES = {}
  luup.variable_set(SID.HG, "Interval", 3600, pdev)
  Log(" Started with no devices, version: " .. version .. ' interval: ' .. interval)
  else
  VARIABLES = splitTable(deviceData)
  end

  --Log(" startup2: " .. version .. ' interval: ' .. interval .. ' lul_device ' .. lul_device )

  enabled = luup.variable_get( SID.HG, "Enabled", pdev ) or 0
  enabled = tonumber(enabled)
  devEnabled = luup.variable_get( SID.HG, "Dev", pdev ) or 0
  devEnabled = tonumber(enabled)

  --Log(" startup3: " .. version .. ' interval: ' .. interval .. ' lul_device ' .. lul_device )

  NODE_ID = luup.variable_get( SID.HG, "DeviceNode", pdev ) or '1'
  API_KEY = luup.variable_get( SID.HG, "API", pdev )
  if (API_KEY == nil) then
  luup.variable_set( SID.HG, "API", 'empty', pdev )
  API_KEY = 'empty'
  else
  Log('Initial API_KEY: ' .. API_KEY)
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

  GetWatchDevices(VARIABLES)

  -- luup.variable_watch("watchDevicesHG", 'urn:micasaverde-com:serviceId:SecuritySensor1', "Tripped", '618')

  Log(" Started with version " .. version)

  HGTimer()
  return true
end

Log(" *********************************************** ")


-- startup()
-- HGTimer()

return true
