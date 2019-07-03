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

local SID = {
	["HG"] = "urn:hundredgraphs-com:serviceId:HundredGraphs1",
	["PM"] = "urn:micasaverde-com:serviceId:EnergyMetering1",
	["SES"] = "urn:micasaverde-com:serviceId:SecuritySensor1"
}
local SRV = {
	["PM"] = "Watts",
	["TMP"] = "urn:micasaverde-com:serviceId:SecuritySensor1"
}


--local MYTYPE = "urn:hundredgraphs-com:service:HundredGraphs:1"
local pdev

-- API Key
-- local API_KEY = "P8tRMZ6t" -- grab that KEY from your settings on https://www.hundredgraphs.com/settings
local API_KEY
local NODE_ID = 1
local TOTAL = 'Total'

-- Log debug messages
local DEBUG = true -- if you want to see results in the log on Vera 
local remotedebug = false -- remote log, you probably don't need that

local env = '[' .. pkg .. ']'
local Log = function (text) luup.log(env .. ' Logger: ' .. (text or "empty")) end
-- local lastFullUpload = 0

local items = {} -- contains items: { time, deviceId, value }
local g_deviceData = {}

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
local VARIABLES = {
	{ key="House", deviceId = 301, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=false }, -- Send device energy
	{ key="HouseA", deviceId = 303, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=false }, 
	{ key="HouseB", deviceId = 304, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=false }, 
	{ key="Aquarium", deviceId = 286, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true }, 
	{ key="pwr08", deviceId = 281, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true }, 
	{ key="pwr04", deviceId = 285, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true },
	{ key="pwr10_blue", deviceId = 376, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true },
	{ key="pwr11_green", deviceId = 377, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true },
	{ key='EntranceBtr', deviceId=331, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	{ key='GarageBtr', deviceId=320, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	{ key='OfficeBtr', deviceId=354, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	{ key='LivingBtr', deviceId=315, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	{ key='MaxBtr', deviceId=367, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	{ key='BedroomBtr', deviceId=382, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	{ key='LockBtr', deviceId=437, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	{ key='GarageTmp', deviceId=475, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	{ key='OfficeTmp', deviceId=355, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	{ key='MaxTmp', deviceId=368, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	{ key='BedroomTmp', deviceId=383, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	{ key='LivingTmp', deviceId=316, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	{ key='WeatherTmp', deviceId=427, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	{ key='EntranceSns', deviceId=331, serviceId="urn:micasaverde-com:serviceId:MotionSensor1", serviceVar="Tripped"},
	{ key='GarageSns', deviceId=320, serviceId="urn:micasaverde-com:serviceId:SecuritySensor1", serviceVar="Tripped"},
	{ key='OfficeSns', deviceId=354, serviceId="urn:micasaverde-com:serviceId:MotionSensor1", serviceVar="Tripped"},
	{ key='GarageHum', deviceId=318, serviceId="urn:micasaverde-com:serviceId:HumiditySensor1", serviceVar="CurrentLevel"},
	{ key='BedroomHum', deviceId=385, serviceId="urn:micasaverde-com:serviceId:HumiditySensor1", serviceVar="CurrentLevel"},
	{ key='TempDiff', calculate=function() return cDiff(427, 316, "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature") end, serviceVar="CurrentTemperature" } -- Send a calculated value
--	{ key='House B', deviceId=13, serviceId="urn:upnp-org:serviceId:SwitchPower1", serviceVar="Status"}, -- Send switch status
--	{ key='Computer', calculate=function() return (IsComputerPingSensorTripped() and 38 or 1) end, serviceVar="Watts" }, -- Send variable value
--	{ key='Other', calculate=function() return 15 end, serviceVar="Watts" } -- Send a constant value
}


-- You shouldn't need to change anything below this line --
local version = '6.19.2019'
local updateInterval = 600
local interval = 600
local env = '[' .. pkg .. ']'
local p = print
local https = require "ssl.https"
local http = require('socket.http')
https.TIMEOUT = 3
http.TIMEOUT = 3

local BASE_URL = "https://www.hundredgraphs.com/api?key=" 
local Log = function (text) luup.log(env .. ' Logger: ' .. (text or "empty")) end

local function UpdateDeviceData()
	local deviceData = ""
	local deviceData2 = ""
	local items = {}
	for devNum, info in pairs( g_deviceData ) do
		-- dDEVICE_ID,iINACTIVITY_PERIOD,sPERIOD1_START,ePERIOD1_END,...,sPERIODn_START,ePERIODn_END,nNOTIFICATIONS_ENABLED
		local item = "deviceId=".. devNum
		item = item ..",key=".. info.key
		item = item ..",serviceId=".. info.serviceId
		item = item ..",serviceVar=".. info.serviceVar
		-- for indexp, key in pairs(info.key) do
		-- 	item = item ..",key=".. key
		-- end
		-- for indexp, serviceId in pairs(info.serviceId) do
		-- 	item = item ..",serviceId=".. serviceId
		-- end
		-- for indexp, serviceVar in pairs(info.serviceVar) do
		-- 	item = item ..",serviceVar=".. serviceVar
		-- end
		item = item ..",enabled=".. (info.enabled and "1" or "0")
		table.insert( items, item )
		deviceData = deviceData .. item .. '; '
	end
	deviceData2 = table.concat( items, ';' )
	Log( " New device data: " .. deviceData .. " data2: " .. deviceData2 )
	luup.variable_set( SID.HG, "DeviceData", deviceData, pdev )
	luup.variable_set( SID.HG, "DeviceData2", deviceData2, pdev )
end

local function AddPair(key, value)
	local item = string.format("%s:%s", key, value)
	items[#items + 1] = item
end

local function SerializeData()
	local dataText = "{" .. table.concat(items, ",") .. "}"
	return dataText
end

local function ResetData()
	items = {}
end

local function SendData()
	local data = SerializeData()
	local parameters = "&debug=" .. tostring(remotedebug) .. "&version=" .. tostring(version) .. "&node=" .. tostring(NODE_ID) .. "&json=" .. data
	local url = BASE_URL .. parameters
	if (DEBUG) then Log(" sending data: " .. parameters) end
	local _, code = https.request{
		url = url,
		protocol = "tlsv1_2",
	}
	ResetData()
	Log(" sent data status: " .. code)
	return code
end

local function PopulateVars()
	local total = 0
	local count = 0
	for i, v in ipairs(VARIABLES) do
		local val
		if v.deviceId then
			val = luup.variable_get(v.serviceId, v.serviceVar, v.deviceId)
		elseif v.calculate then
			val = v.calculate()
		end
		val = tonumber(val) or 0
		if v.countTotal == true then
			total = total + val
		end
		val = tostring(val)
		AddPair(v.key, val)
		count = count + 1
	end
	AddPair(TOTAL, total)
	if (DEBUG) then Log(" collected vars: " .. count) end
end

function HGTimerOnce()
	PopulateVars()
	return SendData()
end

function HGTimer()

	interval = luup.variable_get( SID.HG, "Interval", pdev )
	if (interval == nil) then
		interval = updateInterval
		luup.variable_set( SID.HG, "Interval", interval, pdev )
	end
	interval = tonumber(interval)
	
	API_KEY = luup.variable_get( SID.HG, "API", pdev )
	
	if (API_KEY == nil or API_KEY == 'empty' ) then
		interval = 600
		luup.call_timer("HGTimer", 1, interval, "", interval)	
		if (DEBUG) then Log(' wrong API key: ' .. (API_KEY or "empty")) end
		return
	else
		BASE_URL = "https://www.hundredgraphs.com/api?key=" .. API_KEY
	end	

	PopulateVars()
	local code = SendData()
	code = tonumber(code)
	
	-- if (code == 200) then
	-- 	code = 'OK'
	-- else
	if (code == 401) then
		luup.variable_set( SID.HG, "Enabled", 0, pdev )
		Log(' server returned 401, your API key is wrong, HGTimer was stopped, check your lua file ')  
		interval = 100000
	elseif (code == 204) then
		luup.variable_set( SID.HG, "Enabled", 0, pdev )
		Log(' server returned 204, no data, HGTimer was stopped, check your lua file ') 
		interval = 100000
	else
		local res = luup.call_timer("HGTimer", 1, interval, "", interval)
	end
	
	luup.variable_set( SID.HG, "lastRun", code, pdev )
	if (DEBUG) then Log(' next in ' .. interval) end
	return true
end

_G.HGTimerOnce = HGTimerOnce
_G.HGTimer = HGTimer

function startup(lul_device)
	pdev = lul_device

	local deviceData = luup.variable_get( SID.HG, "DeviceData", pdev ) or ""
	if (DEBUG) then Log(" current dev data: " .. deviceData) end
	if deviceData == "" then
		-- Get the list of power meters.
		-- local g_deviceData = {}
		local SID = {
			["HG"] = "urn:hundredgraphs-com:serviceId:HundredGraphs1",
			["PM"] = "urn:micasaverde-com:serviceId:EnergyMetering1",
			["SES"] = "urn:micasaverde-com:serviceId:SecuritySensor1"
		}
		luup.log("HundredGraphs: SID: " .. SID.HG)
		for devNum, devAttr in pairs( luup.devices ) do		
			local val = luup.variable_get(SID.PM, SRV.PM, devNum)
			if (val ~= nil) then	
				--local desc = luup.variable_get(SID.PM, "description", devNum)			
				luup.log("HundredGraphs: Device #" .. devNum .. " desc: " .. devAttr.description .. " KWH:" .. val)
				for k2, v2 in pairs(devAttr) do
					luup.log("HundredGraphs: Device #" .. devNum .. ":" .. k2 .. " = " .. tostring(v2))			
				end
					-- The device is a power meter.
					--debug( " Adding device #".. devNum .."-".. devAttr.description )
				g_deviceData[devNum] = {}
				g_deviceData[devNum].key = devAttr.description
				g_deviceData[devNum].serviceId = SID.PM
				g_deviceData[devNum].serviceVar =SRV.PM
				g_deviceData[devNum].enabled = false
				luup.log('')
			end
		end
	else
		luup.log("HundredGraphs: existing deviceData: " .. deviceData)
	end

	UpdateDeviceData()

	local enabled = luup.variable_get( SID.HG, "Enabled", pdev )	 
	
	API_KEY = luup.variable_get( SID.HG, "API", pdev )
	if (API_KEY == nil) then
		luup.variable_set( SID.HG, "API", 'empty', pdev )
		API_KEY = 'empty'
	end	
	BASE_URL = "https://www.hundredgraphs.com/api?key=" .. API_KEY
	
	-- Log(' Started from plugin, ' .. SID.HG .. ' dev: ' .. (pdev  or "empty") .. ' enabled: ' .. (enabled or 'disabled') .. ' API_KEY: ' .. API_KEY)  
	HGTimer() 
	return true
end

if (DEBUG) then Log(" *********************************************** ") end
if (DEBUG) then Log(" Started with version " .. version) end

return true