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
local version = '1.8'

local ltn12 = require("ltn12")
local library	= require "L_HundredGraphsLibrary"
--local cli   	= library.cli()
--local gviz  	= library.gviz()
local json  	= library.json() 

luup.log('HundredGraphs json version' .. (json.version or 'empty'))

local SID = {
	["HG"] = "urn:hundredgraphs-com:serviceId:HundredGraphs1",
	["PM"] = "urn:micasaverde-com:serviceId:EnergyMetering1",
	["SES"] = "urn:micasaverde-com:serviceId:SecuritySensor1",
	["HUM"] = "urn:micasaverde-com:serviceId:HumiditySensor1",
	["TMP"] = "urn:upnp-org:serviceId:TemperatureSensor1"
}
local SRV = {
	["PM"] = "Watts",
	["SES"] = "Tripped",
	["TMP"] = "CurrentTemperature",
	["HUM"] = "CurrentLevel"
}


--local device
local pdev

-- API Key
-- local API_KEY = "AABBCCDD" -- grab that KEY from your settings on https://www.hundredgraphs.com/settings
local API_KEY
local NODE_ID = 1
local TOTAL = 'Total'
local SRV_URL = "https://www.hundredgraphs.com/api?key=" 
local SRV_URL_POST = "http://dev.hundredgraphs.com/hook/" 

-- Log debug messages
local DEBUG = true -- if you want to see results in the log on Vera 
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

local updateInterval = 600
local interval = 600
local httpRes = 0

local count = 0

local p = print
local https = require "ssl.https"
local http = require('socket.http')
https.TIMEOUT = 3
http.TIMEOUT = 3


local BASE_URL = ""

local Log = function (text) 
	luup.log('[HundredGraphs2 Logger] ' .. (text or "empty")) 
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

function UpdateVariablesHG()
	local deviceData = luup.variable_get(SID.HG, "DeviceData", pdev) 
	Log( " Watched device data: " .. (deviceData or "empty"))
	if (deviceData == nil or deviceData == '') then return end
	VARIABLES = split(deviceData)
	Log( " Updated VARIABLES: " .. dumpTable(VARIABLES))
	-- Log( " Updated VARIABLES2: " .. dumpTable(VARIABLES2))
end

function UpdateAPIHG()
	API_KEY = luup.variable_get(SID.HG, "API", pdev)
	Log( " Watched API_KEY: " .. API_KEY )
end

function UpdateIntervalHG()
	interval = luup.variable_get(SID.HG, "Interval", pdev)
	Log( " Watched Interval: " .. interval )
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
	if (DEBUG) then Log(" SerializeData: " .. dataText) end
	dataTextExt = json.encode(itemsExtended)
	dataText = string.gsub(dataText, " ", "_")	
	--dataTextExt = string.gsub(dataTextExt, " ", "_")
	if (DEBUG) then Log(" SerializeData Ext: " .. dataTextExt) end
	return dataText, dataTextExt
end

local function ResetData()
	items = {}
	itemsExtended = {}
end

local function AddPair(key, value, var, id)
	if (key == nil or value == nil) then
		Log(' AddPair nil! key: ' .. (key or "empty") .. ' value: ' .. (value or "empty"))
		return
	end
	local item = string.format("%s:%s", key, value)
	local itemExtended = {['device'] = key, ['value'] = value, ['type'] = var, ['id'] = id}
	items[#items + 1] = item
	itemsExtended[#itemsExtended + 1] = itemExtended	
end

local function PopulateVars()
	local total = 0
	count = 0
	for i, v in ipairs(VARIABLES) do
		if (v.enabled == 'checked') then
			local val = ''
			if v.deviceId then
				v.deviceId = tonumber(v.deviceId)
				val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId) or 0
			elseif v.calculate then
				val = v.calculate()
			end
			val = tonumber(val) or 0
			if v.countTotal == true then
				total = total + val
			end
			val = tostring(val)
			AddPair(v.key, val, v.serviceVar, v.deviceId)
			count = count + 1
		end
	end
	AddPair(TOTAL, total, 'Watts', 'Total')
	if (DEBUG) then Log(" collected vars: " .. count) end
	-- if (DEBUG) then Log(" collected Ext vars: " .. #itemsExtended .. ' table: ' .. json.encode(itemsExtended)) end
	return count
end

local function sendRequest(payload)
	local path = SRV_URL_POST
	payload = '{"apiKey":"' .. API_KEY .. '","app":"Vera","version":"'.. version .. '","node":"1","events":'..payload..'}' 	
	--Log('payload: ' .. payload)
	local response_body = {}

	local res, code, response_headers, status = https.request{
		url = path,
		method = "POST",
		headers = {
			--["Authorization"] = "Maybe you need an Authorization header?", 
			["Content-Type"] = "application/json",
			["Content-Length"] = payload:len()
		},
		source = ltn12.source.string(payload),
		sink = ltn12.sink.table(response_body)
	}
	--luup.task('Response: = ' .. table.concat(response_body) .. ' code = ' .. code .. '   status = ' .. status,1,'Sample POST request with JSON data',-1)
	luup.log(status)
	luup.log(table.concat(response_body))
	Log('Post response code = ' .. code .. '   status = ' .. (status or 'empty').. ' response body: = ' .. table.concat(response_body))
	return (status or '0')
end	
	
local function SendData()
	if (DEBUG) then Log(" Start sending data ") end
	local data, dataExt = SerializeData()
	-- if (DEBUG) then Log(" Received SerializeData data for sending: " .. data .. '\nExt: ' .. dataExt) end
	local parameters = "&debug=" .. tostring(remotedebug) .. "&version=" .. tostring(version) .. "&node=" .. tostring(NODE_ID) .. "&json=" .. data
	local parameters2 = "&debug=" .. tostring(remotedebug) .. "&version=" .. tostring(version) .. "&node=" .. tostring(NODE_ID) .. "&json=" .. dataExt
	local url = BASE_URL .. parameters
	local url2 = BASE_URL .. parameters2
	if (DEBUG) then Log(" sending data: " .. parameters) end
	if (DEBUG) then Log(" sending Ext data: " .. dataExt) end
	local res, code, response_headers, status = https.request{
		url = url,
		protocol = "tlsv1_2",
	}

	local status2 = sendRequest(dataExt)
	
	ResetData()
	Log(" sent data status: " .. status .. " ext: " .. status2 .. '\n\n')
	status = tonumber(status)
	if (status ~= 200) then
		Log('Code: ' .. status .. ' url: ' .. url)
	end
	return status
end

function HGTimerOnce()
	PopulateVars()
	return SendData()
end

function HGTimer(interval)
	local status = ''
	interval = interval or luup.variable_get( SID.HG, "Interval", pdev )
	if (interval == nil) then
		interval = updateInterval
		luup.variable_set( SID.HG, "Interval", interval, pdev )
	end
	interval = tonumber(interval)
	
	API_KEY = luup.variable_get( SID.HG, "API", pdev )
	
	if (API_KEY == nil or API_KEY == 'empty' ) then
		interval = 600
		luup.call_timer("HGTimer", 1, interval, "", interval)	
		if (DEBUG) then Log(' wrong API key: ' .. (API_KEY or "empty") .. ' for dev #' .. (pdev or 'empty')) end
		return
	else
		BASE_URL = SRV_URL .. API_KEY
	end	

	count = PopulateVars()
	if (count > 0) then
		status = SendData()
	end

	if (status == 200 and httpRes ~= 200) then
		luup.variable_set( SID.HG, "Enabled", 1, pdev )
	elseif (status == 204) then
		luup.variable_set( SID.HG, "Enabled", 0, pdev )
		Log(' server returned 204, no data, HGTimer was stopped, check your lua file ') 
		interval = 100000
	elseif (status == 401) then
		luup.variable_set( SID.HG, "Enabled", 0, pdev )
		Log(' server returned 401, your API key is wrong, HGTimer was stopped, check your lua file ') 
		interval = 100000
	else
		luup.variable_set( SID.HG, "Enabled", 0, pdev )
		Log(' unknown send status was returned: ' .. status) 
		--interval = 100000		
	end
	local res = luup.call_timer("HGTimer", 1, interval, "", interval)

	if (status ~= httpRes) then
		httpRes = status
		luup.variable_set( SID.HG, "lastRun", status, pdev )
	end
	
	if (DEBUG) then Log(' next in ' .. interval) end
	return true
end

_G.HGTimerOnce = HGTimerOnce
_G.HGTimer = HGTimer

function startup(lul_device)
	lul_device = lul_device or 507
	pdev = tonumber(lul_device)

	local deviceData = luup.variable_get( SID.HG, "DeviceData", pdev ) or ""
	if (DEBUG) then Log(" current dev data: " .. deviceData) end
	if (deviceData == "" or deviceData == '-') then
		VARIABLES = {}
		-- Get the list of power meters.
		for devNum, devAttr in pairs( luup.devices ) do		
			local val = luup.variable_get(SID.PM, SRV.PM, devNum)
			if (val ~= nil) then	
				--local desc = luup.variable_get(SID.PM, "description", devNum)			
				Log("Device #" .. devAttr.id .. " desc: " .. devAttr.description .. " KWH:" .. val)
				local item = {}
				item.type = 'PM'
				item.deviceId = devNum
				item.key = devAttr.description
				item.serviceId = SID.PM
				item.serviceVar = SRV.PM
				item.enabled = "checked"
				table.insert(VARIABLES, item)				
			end
		end
		Log(' Created initial VARIABLES: ' .. dumpTable(VARIABLES))
		deviceData = PackDeviceDataHG()
		Log(' Created initial deviceData: ' .. deviceData)
	else
		UpdateVariablesHG()
		luup.log("HundredGraphs: existing deviceData: " .. deviceData .. " VARS: " .. dumpTable(VARIABLES))
	end

	-- UpdateDeviceDataHG()
	-- UpdateVariablesHG()

	local enabled = luup.variable_get( SID.HG, "Enabled", pdev )	 
	
	API_KEY = luup.variable_get( SID.HG, "API", pdev )
	if (API_KEY == nil) then
		luup.variable_set( SID.HG, "API", 'empty', pdev )
		API_KEY = 'empty'
	else
		Log('Initial API_KEY: ' .. API_KEY)
	end	
	BASE_URL = SRV_URL .. API_KEY

	_G.UpdateVariablesHG = UpdateVariablesHG
	_G.UpdateAPIHG = UpdateAPIHG
	_G.UpdateIntervalHG = UpdateIntervalHG

	luup.variable_watch("UpdateVariablesHG", SID.HG, "DeviceData", pdev)
	luup.variable_watch("UpdateVariablesHG", SID.HG, "DeviceData2", pdev)
	luup.variable_watch("UpdateAPIHG", SID.HG, "API", pdev)
	luup.variable_watch("UpdateIntervalHG", SID.HG, "Interval", pdev)
	
	-- Log(' Started from plugin, ' .. SID.HG .. ' dev: ' .. (pdev  or "empty") .. ' enabled: ' .. (enabled or 'disabled') .. ' API_KEY: ' .. API_KEY)  
	HGTimer() 
	return true
end

if (DEBUG) then Log(" *********************************************** ") end
if (DEBUG) then Log(" Started with version " .. version) end

-- startup()

return true