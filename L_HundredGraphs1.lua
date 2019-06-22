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

local MYSID = "urn:hundredgraphs-com:serviceId:HundredGraphs1"
local MYTYPE = "urn:hundredgraphs-com:service:HundredGraphs:1"
local pdev

-- API Key
local API_KEY = "P8tRMZ6t" -- grab that KEY from your settings on https://www.hundredgraphs.com/settings
local NODE_ID = 1
local TOTAL = 'Total'

-- Log debug messages
local DEBUG = true -- if you want to see results in the log on Vera 
local remotedebug = false -- remote log, you probably don't need that

local env = '[' .. pkg .. ']'
local Log = function (text) luup.log(env .. ' Logger: ' .. (text or "empty")) end
-- local lastFullUpload = 0

local items = {} -- contains items: { time, deviceId, value }

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
	{ key="Energy", deviceId = 301, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=false }, 
	{ key="Energy2", deviceId = 301, serviceId='urn:micasaverde-com:serviceId:EnergyMetering1', serviceVar="Watts", countTotal=true }, 
	{ key='Lock', deviceId=437, serviceId="urn:micasaverde-com:serviceId:HaDevice1", serviceVar="BatteryLevel"},
	{ key='Temperature', deviceId=355, serviceId="urn:upnp-org:serviceId:TemperatureSensor1", serviceVar="CurrentTemperature"},
	{ key='Tripped', deviceId=331, serviceId="urn:micasaverde-com:serviceId:MotionSensor1", serviceVar="Tripped"},
	{ key='Humidity', deviceId=318, serviceId="urn:micasaverde-com:serviceId:HumiditySensor1", serviceVar="CurrentLevel"},
	{ key='BedroomHum', deviceId=385, serviceId="urn:micasaverde-com:serviceId:HumiditySensor1", serviceVar="CurrentLevel"},
	{ key='TempDiff', calculate=function() return cDiff(427, 316, "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature") end, serviceVar="CurrentTemperature" } -- Send a calculated value
--	{ key='House B', deviceId=13, serviceId="urn:upnp-org:serviceId:SwitchPower1", serviceVar="Status"}, -- Send switch status
--	{ key='Computer', calculate=function() return (IsComputerPingSensorTripped() and 38 or 1) end, serviceVar="Watts" }, -- Send variable value
--	{ key='Other', calculate=function() return 15 end, serviceVar="Watts" } -- Send a constant value
}


-- You shouldn't need to change anything below this line --
local version = '6.19.2019'
local updateInterval = 600
local env = '[' .. pkg .. ']'
local p = print
local https = require "ssl.https"
local http = require('socket.http')
https.TIMEOUT = 3
http.TIMEOUT = 3

local BASE_URL = "https://www.hundredgraphs.com/api?key=" .. API_KEY
local Log = function (text) luup.log(env .. ' Logger: ' .. (text or "empty")) end

local items = {} -- contains items: { time, deviceId, value }

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

function HGTimer(interval)
	interval = interval or updateInterval
	PopulateVars()
	local code = SendData()
	code = tonumber(code)
	luup.variable_set( MYSID, "lastRun", code, pdev )
	if (code == 401) then
		Log(' server returned 401, your API key is wrong, HGTimer was stopped, check your lua file ')  
		interval = 100000
	elseif (code == 204) then
		Log(' server returned 204, no data, HGTimer was stopped, check your lua file ') 
		interval = false
	else
		local res = luup.call_timer("HGTimer", 1, interval, "", interval)
	end
	if (DEBUG) then Log(' next in ' .. interval) end
	return true
end

-- Set or reset the current tripped state
local function setInterval( interval, lul_device )
	D("trip(%1,%2)", flag, lul_device)
	local val = flag and 1 or 0
	local currTrip = getVarNumeric( "Tripped", 0, lul_device, SECURITYSID )
	if currTrip ~= val then
		luup.variable_set( MYSID, "Interval", val, lul_device )
		-- We don't need to worry about LastTrip or ArmedTripped, as Luup manages them.
		-- Note, the semantics of ArmedTripped are such that it changes only when Armed=1
		-- AND there's an edge (change) to Tripped. If Armed is changed from 0 to 1,
		-- ArmedTripped is not changed, even if Tripped=1 at that moment; it will change
		-- only when Tripped is explicitly set.
	end
	--[[ TripInhibit is our copy of Tripped, because Luup will change Tripped
		 behind our back when AutoUntrip > 0--it will reset Tripped after
		 that many seconds, but then we would turn around and set it again.
		 We don't want to do that until Tripped resets because WE want
		 it reset, so we use TripInhibit to lock ourselves out until then. --]]
	-- luup.variable_set( MYSID, "TripInhibit", val, pdev )
end

_G.HGTimerOnce = HGTimerOnce
_G.HGTimer = HGTimer

function startup(lul_device)
	pdev = lul_device

	local enabled = luup.variable_get( MYSID, "Enabled", val, pdev )	 
	local interval = luup.variable_get( MYSID, "Interval", val, pdev )
	if (interval == nil) then
		interval = updateInterval
		luup.variable_set( MYSID, "Interval", interval, pdev )
	end

	Log(' Starting from plugin, ' .. MYSID .. ' dev: ' .. (pdev  or "empty") .. ' enabled: ' .. (enabled or 0) .. ' interval: ' .. interval)  
	HGTimer(interval) return true
end

if (DEBUG) then Log(" *********************************************** ") end
if (DEBUG) then Log(" started with version " .. version .. " updateInterval " .. updateInterval) end

return true