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
local version = '2.10'

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
}
local SRV = {
	["PM"] = "Watts",
	["PM2"] = "KWH",
	["SES"] = "Tripped",
	["TMP"] = "CurrentTemperature",
	["HUM"] = "CurrentLevel",
	["THM"] = "ModeState"
}


--local device
local pdev

-- API Key
-- local API_KEY = "AABBCCDD" -- grab that KEY from your settings on https://www.hundredgraphs.com/settings
local API_KEY
local NODE_ID
local TOTAL = 'Total'
local SRV_URL = "https://www.hundredgraphs.com/api?key=" 
local DEV_URL_POST = "http://dev.hundredgraphs.com/hook/" 
local SRV_URL_POST = "http://www.hundredgraphs.com/hook/" 

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
local interval = 'empty'
local httpRes = 0

local count = 0

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
	local enabled = luup.variable_get( SID.HG, "Enabled", pdev )
	if enabled == nil then
		luup.variable_set( SID.HG, "Enabled", 0, pdev )
	end
	local devEnabled = luup.variable_get( SID.HG, "Dev", pdev )
	if devEnabled == nil then
		luup.variable_set( SID.HG, "Enabled", 0, pdev )
	end
	local ver = luup.variable_get( SID.HG, "version", pdev ) or 'empty'
	if ver ~= version then
		luup.variable_set(SID.HG, "version", version, pdev)
	end
end
function UpdateStartHG()	
	local last = luup.variable_get( SID.HG, "running", pdev )
	last = tonumber(last)
	Log(' switch was switched. If running: ' .. last)
	if (last == 0) then
		local enabled = luup.variable_get( SID.HG, "Enabled", pdev ) or 0
		enabled = tonumber(enabled)
		local devEnabled = luup.variable_get( SID.HG, "Dev", pdev ) or 0
		devEnabled = tonumber(devEnabled)
		Log('running: ' .. last .. ', enabled: ' .. enabled .. ', dev enabled: ' .. devEnabled)
		if (enabled == 1 or devEnabled == 1) then
			Log('Starting HGTimer')
			HGTimer()
		end
	end
end
function UpdateStartVersionHG()	
	version = luup.variable_get( SID.HG, "version", pdev ) or ''
	Log(' version was updated: ' .. version)
	return version
end

function UpdateVariablesHG()
	local deviceData = luup.variable_get(SID.HG, "DeviceData", pdev) 
	-- Log( " Watched device data: " .. (deviceData or "empty"))
	if (deviceData == nil or deviceData == '') then return end
	VARIABLES = split(deviceData)
	-- Log( " Updated VARIABLES: " .. dumpTable(VARIABLES))
	-- Log( " Updated VARIABLES2: " .. dumpTable(VARIABLES2))
end

function UpdateAPIHG()
	API_KEY = luup.variable_get(SID.HG, "API", pdev)
	Log( " Watched API_KEY: " .. API_KEY )
end

function UpdateIntervalHG()
	local int = luup.variable_get(SID.HG, "Interval", pdev) or 'empty'
	-- if interval == ''
	-- then
		-- luup.variable_set( SID.HG, "Interval", 600, pdev )		
		-- interval = 600
	-- end
	interval = tonumber(int) or 'empty'
	if interval == 'empty' then
		Log( " Setting Interval (wrong): " .. interval .. ' int: ' .. int)
	elseif (interval < 60) then
		interval = 'empty'
		Log( " Setting Interval (wrong): " .. interval .. ' int: ' .. int)
		luup.variable_set(SID.HG, "Interval", interval, pdev)
	else
		Log( " Setting Interval (right): " .. interval .. ' int: ' .. int)
	end	
	Log( " Watched Interval: " .. interval .. ' int: ' .. int)
	return interval
end

function UpdateNodeId()
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

local function sendRequestHook(events)
	
	local response_body1 = {} 
	local response_body2 = {}
	local res, code, code1, code2, response_headers, status, payload
	
	local hubId = luup.pk_accesspoint

	local enabled = luup.variable_get(SID.HG, "Enabled", pdev) 
	NODE_ID = NODE_ID or luup.variable_get(SID.HG, "DeviceNode", pdev)  or 1
	payload = '{"apiKey":"' .. API_KEY .. '","app":"Vera","version":"'.. version .. '","hubId":"' .. hubId ..'","interval":"'.. interval .. '","node":"' .. NODE_ID .. '","events":'..events..'}' 	
	
	if enabled == 1 or enabled == '1' then
		Log(' prod enabled: ' .. (enabled or empty))
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
		
		Log('Post response code = ' .. code1 .. '   status = ' .. (status or 'empty').. ' response body: = ' .. table.concat(response_body1) .. '\n')
		if (code1 ~= 200) then
			Log('Prod Payload was: ' .. payload)
		end
	end
	
	local devEnabled = luup.variable_get(SID.HG, "Dev", pdev) 
	
	if devEnabled == 1 or devEnabled == '1' then
		Log(' dev enabled: ' .. (devEnabled or empty))
		res, code2, response_headers, status = https.request{
			url = DEV_URL_POST,
			method = "POST",
			headers = {
				["Content-Type"] = "application/json",
				["Content-Length"] = payload:len()
			},
			source = ltn12.source.string(payload),
			sink = ltn12.sink.table(response_body2)
		}	
		Log('Post response DEV code = ' .. DEV_URL_POST .. ' ' .. code2 .. '   status = ' .. (status or 'empty').. ' response body: = ' .. table.concat((response_body2 or {})) .. '\n')
		if (code2 ~= 200) then
			Log('Dev Payload was: ' .. payload)
		end
	end
	
	code = code1 or code2
	
	--luup.task('Response: = ' .. table.concat(response_body) .. ' code = ' .. code .. '   status = ' .. status,1,'Sample POST request with JSON data',-1)

	return code
end	


local function sendRequestOld(data)
	
	local parameters = "&debug=" .. tostring(remotedebug) .. "&version=" .. tostring(version) .. "&node=" .. tostring(NODE_ID) .. "&json=" .. data
	local url = BASE_URL .. parameters
	if (DEBUG) then Log(" sending data: " .. parameters) end
	local res, code, response_headers, status = https.request{
		url = url,
		protocol = "tlsv1_2",
	}
	
	Log('Status Old: ' .. (code or 'empty') .. ' url: ' .. BASE_URL .. '\n')

	return code
end	
	
local function SendData()
	if (DEBUG) then Log(" Start sending data ") end
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
	PopulateVars()
	return SendData()
end

function HGTimer()
	local code = 0
	local showcode = ''
	local int = luup.variable_get( SID.HG, "Interval", pdev) or 'empty'
	Log('HG HGTimer start: ' .. interval .. ' ' .. int)
	
	API_KEY = luup.variable_get( SID.HG, "API", pdev ) or 'empty'
	local enabled = luup.variable_get(SID.HG, "Enabled", pdev) or 0
	enabled = tonumber(enabled)
	local devEnabled = luup.variable_get(SID.HG, "Dev", pdev) or 0
	devEnabled = tonumber(devEnabled)
		
	if API_KEY == 'empty' then
		code = 'Switched off!!! wrong API key: ' .. API_KEY .. ' for dev #' .. (pdev or 'empty')
		Log(code) 
		Log('HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled) 
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		luup.variable_set( SID.HG, "running", 0, pdev )
		return false
	elseif interval == 'empty' then
		code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled
		Log(code) 
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		luup.variable_set( SID.HG, "running", 0, pdev )		
		return false
	elseif enabled == 0 and devEnabled == 0 then
		code = 'HGTimes is off. enabled: ' .. enabled .. ' dev: ' .. devEnabled
		Log(code) 
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		luup.variable_set( SID.HG, "running", 0, pdev )		
		return false
	end
		
	BASE_URL = SRV_URL .. API_KEY
	count = PopulateVars() 
	
	if count > 0 then
		code = SendData()
	else
		showcode = ' No data to report'
		Log(code) 
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		return false
	end

	if (code == 200) then
		showcode = 'OK'
	elseif code == nil then
		showcode = 'server returned empty code' 
	elseif code == 204 then
		showcode = ' server returned 204 (no data), interval was updated to once a day. Update reporting sensors and restart a plugin'
		updateInterval = interval
		interval = 86400000
	elseif code == 401 then
		showcode = ' server returned 401, your API key is wrong, interval was updated to once a day. Update reporting sensors and restart a plugin'
		updateInterval = interval
		interval = 86400000
	elseif code == 402 then
		showcode = ' server returned 402, you are using extended features requiring payment. Reporting interval was switched to 600 secs'
		updateInterval = interval
		interval = 600
	else
		showcode = ' unknown send status was returned: ' .. (code or 'empty') 
	end
	Log(showcode) 

	if (code ~= httpRes) then
		httpRes = code
		luup.variable_set( SID.HG, "lastRun", showcode, pdev )
		if code == 200 then
			local commfailure = luup.variable_get(SID.HG, "CommFailure", pdev) 
			if commfailure == "1" then 
				luup.log("Device "..pdev.." has CommFailure="..commfailure..". set it to 0") 
				luup.variable_set(SID.HG, "CommFailure", "0", pdev) 
				luup.call_action(SID.HG, "Reload", {}, 0) 
			end 
		end
	end
	
	local res = luup.call_timer("HGTimer", 1, interval, "", interval)
	luup.variable_set( SID.HG, "running", 1, pdev )
	if (DEBUG) then Log(' next in ' .. interval) end

	return true
end

_G.HGTimerOnce = HGTimerOnce
_G.HGTimer = HGTimer
_G.UpdateVariablesHG = UpdateVariablesHG
_G.UpdateAPIHG = UpdateAPIHG
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

	local enabled = luup.variable_get( SID.HG, "Enabled", pdev )	 
	
	NODE_ID = luup.variable_get( SID.HG, "DeviceNode", pdev ) or '1'
	API_KEY = luup.variable_get( SID.HG, "API", pdev )
	if (API_KEY == nil) then
		luup.variable_set( SID.HG, "API", 'empty', pdev )
		API_KEY = 'empty'
	else
		Log('Initial API_KEY: ' .. API_KEY)
	end	
	BASE_URL = SRV_URL .. API_KEY
	
	if (DEBUG) then Log(" Started with version " .. version) end

	luup.variable_watch("UpdateVariablesHG", SID.HG, "DeviceData", pdev)
	luup.variable_watch("UpdateVariablesHG", SID.HG, "DeviceData2", pdev)
	luup.variable_watch("UpdateAPIHG", SID.HG, "API", pdev)
	luup.variable_watch("UpdateIntervalHG", SID.HG, "Interval", pdev)
	luup.variable_watch("UpdateStartHG", SID.HG, "Enabled", pdev)
	luup.variable_watch("UpdateStartHG", SID.HG, "Dev", pdev)
	--luup.variable_watch("UpdateStartVersionHG", SID.HG, "version", pdev)
	luup.variable_watch("UpdateDeviceNode", SID.HG, "DeviceNode", pdev)
	
	-- Log(' Started from plugin, ' .. SID.HG .. ' dev: ' .. (pdev  or "empty") .. ' enabled: ' .. (enabled or 'disabled') .. ' API_KEY: ' .. API_KEY)  
	HGTimer() 
	return true
end

if (DEBUG) then Log(" *********************************************** ") end


-- startup()

return true