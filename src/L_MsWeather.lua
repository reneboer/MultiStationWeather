ABOUT = {
	NAME = "Multi Weather Station",
	VERSION = "1.1",
	DESCRIPTION = "Multi Weather Station plugin",
	AUTHOR = "Rene Boer"
}	
--[[
Icons based on Wunderground. Information : https://docs.google.com/document/d/1qpc4QN3YDpGDGGNYVINh7tfeulcZ4fxPSC5f4KzpR_U/edit

Version 1.1 2021-04-1
	- Added KNMI (weerlive, NL) weather provider
	- No longer using S_GenericSensor.xml as it limits SDATA possibilities
	- Fix for Precipitation update
	- Fix for Wundergrouns metric_si units
	- More generic functions, less code per provider
	- Minor fixes

Version 1.0 2021-03-17 
	- First GA version
	- Change in Display Line settings directly reflected after Luup reload.
	- Added Air Quality values (OpenWeather only)
	
Version 0.2 2021-03-16 - Beta version for public testing
Version 0.1 2021-02-25 - Alpha version for testing

https://www.visualcrossing.com/resources/documentation/weather-api/how-to-replace-the-dark-sky-api/

--]]

-- plugin general variables
local https = require("ssl.https")
local ltn12 = require("ltn12")
local dkjson = require("dkjson")
local cjson	= nil
pcall(function ()
	-- Install via LuaRocks: luarocks install lua-cjson
	cjson	= require("cjson")
	if not cjson.decode then cjson = nil end
end)
local zlib = nil
pcall(function()
	-- Install package: sudo apt-get install lua-zlib
	zlib = require('zlib')
	if not zlib.inflate then zlib = nil end
end)

local SID_Weather 	= "urn:upnp-rboer-com:serviceId:Weather1"
local SID_WeatherM 	= "urn:upnp-rboer-com:serviceId:WeatherMetric1"
local SID_Security 	= "urn:micasaverde-com:serviceId:SecuritySensor1"
local SID_Humid 	= "urn:micasaverde-com:serviceId:HumiditySensor1"
local SID_UV	 	= "urn:micasaverde-com:serviceId:LightSensor1"
local SID_HA	 	= "urn:micasaverde-com:serviceId:HaDevice1"
local SID_Baro 		= "urn:upnp-org:serviceId:BarometerSensor1"
local SID_Temp 		= "urn:upnp-org:serviceId:TemperatureSensor1"
local SID_Generic	= "urn:micasaverde-com:serviceId:GenericSensor1"
local SID_AltUI 	= "urn:upnp-org:serviceId:altui1"


local this_device = nil

-- these are the configuration and their default values
local MS = {
	Provider = 0,
	Key = "",
	ApplicationKey = "",
	Latitude = "",
	Longitude = "",
	StationID = 0,
	StationName = "",
	Period = 1800,	-- data refresh interval in seconds
	Units = "",
	ForecastDays = 2,
	DispLine1 = 1,
	DispLine2 = 2,
	ChildDev = "",
	RainSensor = 0,  -- Can support rain alarm for US,CA,UK (for NL we could use buienradar).
	Language = "en", -- default language
	IconsProvider = "Thanks to TWC icons at https://docs.google.com/document/d/1qpc4QN3YDpGDGGNYVINh7tfeulcZ4fxPSC5f4KzpR_U",
	Documentation = "https://github.com/reneboer/MsWeather/wiki",
	LogLevel = 1,
	Version = ABOUT.VERSION
}

local static_Vars = "|IconsProvider|Documentation|Version|"

-- this is the table used to map any providers output elements with the conversion rules and child details.
local VariablesMap = {
	currently = {
		["CurrentApparentTemperature"] = {decimal = 1, childKey = "A", childID = nil},
		["CurrentCloudCover"] = {decimal = 0, childKey = "C", childID = nil},
		["CurrentDewPoint"] = {decimal = 1, childKey = "D", initVal = 0, childID = nil},
		["CurrentHumidity"] = {decimal = 0, childKey = "H", childID = nil},
		["Icon"] = {},
		["CurrentOzone"] = {childKey = "O", childID = nil},
		["CurrentCO"] = {decimal = 0, childKey = "X", childID = nil},
		["CurrentNO"] = {},
		["CurrentNO2"] = {},
		["CurrentSO2"] = {},
		["CurrentNH3"] = {},
		["CurrentPM25"] = {},
		["CurrentPM10"] = {},
		["CurrentAirQuality"] = {childKey = "Q", childID = nil},
		["CurrentuvIndex"] = {childKey = "U", childID = nil},
		["CurrentVisibility"] = {decimal = 3, childKey = "V", childID = nil},
		["CurrentPrecipIntensity"] = {childKey = "R", childID = nil},
		["CurrentPrecipProbability"] = {decimal = 0},
		["CurrentPrecipType"] = {},
		["CurrentPressure"] = {decimal = 0, childKey = "P", childID = nil},
		["CurrentConditions"] = {},
		["CurrentTemperature"] = {decimal = 1, childKey = "T", childID = nil},
		["LastUpdate"] = {},
		["CurrentSunrise"] =  {},
		["CurrentSunset"] =  {},
		["CurrentWindDirection"] =  {},
		["CurrentWindBearing"] =  {},
		["CurrentWindSpeed"] = {decimal = 1, childKey = "W", childID = nil},
		["CurrentWindGust"] = {decimal = 1},
		["WeekConditions"] = {},
		["ReportedUnits"] = {}
	},	
	forecast = { 
		["Pressure"] = {decimal = 0},
		["Conditions"] = {},
		["Ozone"] = {},
		["uvIndex"] = {},
		["uvIndexTime"] = {},
		["Visibility"] = {decimal = 3},
		["PrecipIntensity"] = {},
		["PrecipIntensityMax"] = {},
		["PrecipProbability"] = {decimal = 0},
		["SunProbability"] = {decimal = 0},
		["PrecipType"] = {},
		["MaxTemp"] = {decimal = 1},
		["MinTemp"] = {decimal = 1},
		["HighTemp"] = {decimal = 1},
		["LowTemp"] = {decimal = 1},
		["ApparentMaxTemp"] = {decimal = 1},
		["ApparentMinTemp"] = {decimal = 1},
		["Icon"] = {},
		["CloudCover"] = {decimal = 0},
		["DewPoint"] = {decimal = 1},
		["Humidity"] = {decimal = 0},
		["WindDirection"] =  {},
		["WindBearing"] =  {},
		["WindSpeed"] = {decimal = 1},
		["WindGust"] = {decimal = 1},
		["Sunrise"] =  {},
		["Sunset"] =  {}
	}
}
local languageMap = {
	["en"] = "en-US", ["ar"] = "ar-AE", ["bg"] = "bg-BG", ["bn"] = "bn-IN", ["bs"] = "bs-BA", ["cs"] = "cs-CZ",
	["da"] = "da-DK", ["nl"] = "nl-NL", ["de"] = "de-DE", ["el"] = "el-GR", ["es"] = "es-ES", ["et"] = "et-EE",
	["fi"] = "fi-FI", ["fr"] = "fr-FR", ["he"] = "he-IL", ["hi"] = "hi-IN", ["hr"] = "hr-HR", ["hu"] = "hu-HU",
	["id"] = "in-ID", ["is"] = "is-IS", ["it"] = "it-IT", ["ja"] = "ja-JP", ["ko"] = "ko-KR", ["lv"] = "lv-LV",
	["no"] = "no-NO", ["pa"] = "pa-PK", ["pl"] = "pl-PL", ["pt"] = "pt-PT", ["ro"] = "ro-RO", ["ru"] = "ru-RU",
	["sk"] = "sk-SK", ["sl"] = "sl-SI", ["sr"] = "sr-RS", ["sv"] = "sv-SE", ["tr"] = "tr-TR", ["uk"] = "uk-UA"
}

-- Mapping of data to display in ALTUI DisplayLines 1 & 2.
-- Keep definitions in sync with JS code.
local DisplayMap = {
	[1] = {{ prefix = "", var = "CurrentConditions" }},
	[2] = {{ prefix = "Pressure: ", var = "CurrentPressure"}},
	[3] = {{ prefix = "Last update: ", var = "LastUpdate" }},
    [4] = {{ prefix = "Wind: ", var = "CurrentWindSpeed" },{ prefix = "Gust: ", var = "CurrentWindGust" },{ prefix = "Bearing: ", var = "CurrentWindBearing" }},
    [5] = {{ prefix = "Ozone: ", var = "CurrentOzone" },{ prefix = "UV Index: ", var = "CurrentuvIndex" }},
    [6] = {{ prefix = "Current Temperature: ", var = "CurrentTemperature" }},
    [7] = {{ prefix = "Apparent Temperature: ", var = "CurrentApparentTemperature" }},
    [8] = {{ prefix = "Current Cloud Cover: ", var = "CurrentCloudCover" }},
    [9] = {{ prefix = "Precip: ", var = "CurrentPrecipType" },{ prefix = "Prob.: ", var = "CurrentPrecipProbability" },{ prefix = "Intensity: ", var = "CurrentPrecipIntensity" }},
    [10] = {{ prefix = "Humidity: ", var = "CurrentHumidity" },{ prefix = "Dew Point: ", var = "CurrentDewPoint" }},
    [11] = {{ prefix = "AQI: ", var = "CurrentAirQuality" },{ prefix = "PM2.5: ", var = "CurrentPM25" },{ prefix = "PM10: ", var = "CurrentPM10" }},
    [12] = {{ prefix = "Co: ", var = "CurrentCO" },{ prefix = "No: ", var = "CurrentNO" },{ prefix = "No2: ", var = "CurrentNO2" }}
}
-- for writing to Luup variables, need serviceId and variable name for each sensor type
-- for creating child devices also need device xml filename
local SensorInfo = setmetatable (
  {	
    ['A'] = { deviceXML = "D_TemperatureSensor1.xml", serviceId = SID_Temp, variable = "CurrentTemperature", name="Apparent Temp."},
    ['D'] = { deviceXML = "D_TemperatureSensor1.xml", serviceId = SID_Temp, variable = "CurrentTemperature", name="Dewpoint"},
    ['T'] = { deviceXML = "D_TemperatureSensor1.xml", serviceId = SID_Temp, variable = "CurrentTemperature", name="Temperature"},
    ['H'] = { deviceXML = "D_HumiditySensor1.xml", serviceId = SID_Humid, variable = "CurrentLevel", name="Humidity"},
    ['U'] = { deviceXML = "D_LightSensor1.xml", deviceJSON = "D_UVSensor1.json", serviceId = SID_UV, variable = "CurrentLevel", name="UV Index"},
    ['P'] = { deviceXML = "D_MsWeatherMetric.xml", serviceId = SID_WeatherM, variable = "CurrentLevel", icon = 1 , name="Pressure"},
    ['O'] = { deviceXML = "D_MsWeatherMetric.xml", serviceId = SID_WeatherM, variable = "CurrentLevel", icon = 2 , name="Ozone"},
    ['V'] = { deviceXML = "D_MsWeatherMetric.xml", serviceId = SID_WeatherM, variable = "CurrentLevel", icon = 3 , name="Visibility"},
    ['W'] = { deviceXML = "D_MsWeatherMetric.xml", serviceId = SID_WeatherM, variable = "CurrentLevel", icon = 4 , name="Wind"},
    ['R'] = { deviceXML = "D_MsWeatherMetric.xml", serviceId = SID_WeatherM, variable = "CurrentLevel", icon = 5 , name="Precipitation"},
    ['Q'] = { deviceXML = "D_MsWeatherMetric.xml", serviceId = SID_WeatherM, variable = "CurrentLevel", icon = 6 , name="Air Quality"},
    ['X'] = { deviceXML = "D_MsWeatherMetric.xml", serviceId = SID_WeatherM, variable = "CurrentLevel", icon = 6 , name="Air Quality values"}
  },
  {__index = function ()  -- default for everything else
      return { deviceXML = "D_MsWeatherMetric.xml", serviceId = SID_WeatherM, variable = "CurrentLevel"} 
    end
  }
)


---------------------------------------------------------------------------------------------
-- Utility functions
---------------------------------------------------------------------------------------------
local log
local var
local utils
local json

-- Wrapper for more solid handling for cjson as it trows a bit more errors that I'd like.
local function jsonAPI()
local is_cj, is_dk

	local function clean_cjson_nulls (x)    -- 2020.05.20  replace any cjson.null with nil. To use, maybe, thanks akbooer.
		for n,v in pairs (x) do
			if type(v) == "table" then 
				clean_cjson_nulls (v) 
			elseif v == cjson.null then 
				x[n] = nil
			end
		end
	end
		
	local function _init()
		is_cj = type(cjson) == "table"
		is_dk = type(dkjson) == "table"
--		is_cj, cjson = pcall(require, "cjson")
--		is_dk, dkjson = pcall(require, "dkjson")
	end
	
	local function _decode(data)
		if is_cj then
			local ok, res = pcall(cjson.decode, data)
			if ok then return res end
		end
		local res, pos, msg = dkjson.decode(data)
		return res, msg
	end
	
	local function _encode(data)
		-- No special chekcing required as we must pass valid data our selfs
		if is_cj then
			return cjson.encode(data)
		else
			return dkjson.encode(data)
		end
	end
	
	return {
		Initialize = _init,
		decode = _decode,
		encode = _encode
	}
end


-- API getting and setting variables and attributes from Vera more efficient.
local function varAPI()
	local def_sid, def_dev = '', 0
	
	local function _init(sid,dev)
		def_sid = sid
		def_dev = dev
	end
	
	-- Get variable value
	local function _get(name, sid, device)
		local value = luup.variable_get(sid or def_sid, name, tonumber(device or def_dev))
		return (value or '')
	end

	-- Get variable value as number type
	local function _getnum(name, sid, device)
		local value = luup.variable_get(sid or def_sid, name, tonumber(device or def_dev))
		local num = tonumber(value,10)
		return (num or 0)
	end
	
	-- Set variable value
	local function _set(name, value, sid, device)
		local sid = sid or def_sid
		local device = tonumber(device or def_dev)
		local old = luup.variable_get(sid, name, device)
		if (tostring(value) ~= tostring(old or '')) then 
			luup.variable_set(sid, name, value, device)
		end
	end

	-- create missing variable with default value or return existing
	local function _default(name, default, sid, device)
		local sid = sid or def_sid
		local device = tonumber(device or def_dev)
		local value = luup.variable_get(sid, name, device) 
		if (not value) then
			value = default	or ''
			luup.variable_set(sid, name, value, device)	
		end
		return value
	end
	
	-- Get an attribute value, try to return as number value if applicable
	local function _getattr(name, device)
		local value = luup.attr_get(name, tonumber(device or def_dev))
		local nv = tonumber(value,10)
		return (nv or value)
	end

	-- Set an attribute
	local function _setattr(name, value, device)
		local val = _getattr(name, device)
		if val ~= value then 
			luup.attr_set(name, value, tonumber(device or def_dev))
		end	
	end
	
	return {
		Get = _get,
		Set = _set,
		GetNumber = _getnum,
		Default = _default,
		GetAttribute = _getattr,
		SetAttribute = _setattr,
		Initialize = _init
	}
end

-- API to handle basic logging and debug messaging
local function logAPI()
local def_level = 1
local def_prefix = ''
local def_name = 'log'
local def_debug = false
local def_file = false
local max_length = 100
local onOpenLuup = false
local taskHandle = -1

	local function _update(level)
		if level > 100 then
			def_file = true
			def_debug = true
			def_level = 10
		elseif level > 10 then
			def_debug = true
			def_file = false
			def_level = 10
		else
			def_file = false
			def_debug = false
			def_level = level
		end
	end	

	local function _init(prefix, level,onol)
		_update(level)
		def_prefix = prefix
		def_name = prefix:gsub(" ","")
		onOpenLuup = onol
	end	
	
	-- Build loggin string safely up to given lenght. If only one string given, then do not format because of length limitations.
	local function prot_format(ln,str,...)
		local msg = ""
		if arg[1] then 
			_, msg = pcall(string.format, str, unpack(arg))
		else 
			msg = str or "no text"
		end 
		if ln > 0 then
			return msg:sub(1,ln)
		else
			return msg
		end	
	end	
	local function _log(...) 
		if (def_level >= 10) then
			luup.log(def_prefix .. ": " .. prot_format(max_length,...), 50) 
		end	
	end	
	
	local function _info(...) 
		if (def_level >= 8) then
			luup.log(def_prefix .. "_info: " .. prot_format(max_length,...), 8) 
		end	
	end	

	local function _warning(...) 
		if (def_level >= 2) then
			luup.log(def_prefix .. "_warning: " .. prot_format(max_length,...), 2) 
		end	
	end	

	local function _error(...) 
		if (def_level >= 1) then
			luup.log(def_prefix .. "_error: " .. prot_format(max_length,...), 1) 
		end	
	end	

	local function _debug(...)
		if def_debug then
			luup.log(def_prefix .. "_debug: " .. prot_format(-1,...), 50) 
		end	
	end
	
	-- Write to file for detailed analysis
	local function _logfile(...)
		if def_file then
			local fh = io.open("/tmp/log/"..def_name..".log","a")
			local msg = prot_format(-1,...)
			fh:write(msg)
			fh:write("\n")
			fh:close()
		end	
	end
	
	local function _devmessage(devID, isError, timeout, ...)
		local message =  prot_format(60,...)
		local status = isError and 2 or 4
		-- Standard device message cannot be erased. Need to do a reload if message w/o timeout need to be removed. Rely on caller to trigger that.
		if onOpenLuup then
			taskHandle = luup.task(message, status, def_prefix, taskHandle)
			if timeout ~= 0 then
				luup.call_delay("logAPI_clearTask", timeout, "", false)
			else
				taskHandle = -1
			end
		else
			luup.device_message(devID, status, message, timeout, def_prefix)
		end	
	end
	
	local function logAPI_clearTask()
		luup.task("", 4, def_prefix, taskHandle)
		taskHandle = -1
	end
	_G.logAPI_clearTask = logAPI_clearTask
	
	return {
		Initialize = _init,
		Error = _error,
		Warning = _warning,
		Info = _info,
		Log = _log,
		Debug = _debug,
		Update = _update,
		LogFile = _logfile,
		DeviceMessage = _devmessage
	}
end 

-- API to handle some Util functions
local function utilsAPI()
local _UI5 = 5
local _UI6 = 6
local _UI7 = 7
local _UI8 = 8
local _OpenLuup = 99

  local function _init()
  end  

  -- See what system we are running on, some Vera or OpenLuup
  local function _getui()
    if (luup.attr_get("openLuup",0) ~= nil) then
      return _OpenLuup
    else
      return luup.version_major
    end
    return _UI7
  end
  
  local function _getmemoryused()
    return math.floor(collectgarbage "count")         -- app's own memory usage in kB
  end
  
  local function _setluupfailure(status,devID)
    if (luup.version_major < 7) then status = status ~= 0 end        -- fix UI5 status type
    luup.set_failure(status,devID)
  end

  -- Luup Reload function for UI5,6 and 7
  local function _luup_reload()
    if (luup.version_major < 6) then 
      luup.call_action("urn:micasaverde-com:serviceId:HomeAutomationGateway1", "Reload", {}, 0)
    else
      luup.reload()
    end
  end
  
  return {
    Initialize = _init,
    ReloadLuup = _luup_reload,
    GetMemoryUsed = _getmemoryused,
    SetLuupFailure = _setluupfailure,
    GetUI = _getui,
    IsUI5 = _UI5,
    IsUI6 = _UI6,
    IsUI7 = _UI7,
    IsUI8 = _UI8,
    IsOpenLuup = _OpenLuup
  }
end 

-- Need wrapper for Vera UI7.31 to set TLS protocol. Sadly tls1.2 is not supported on the Lite.
-- Also supports gzip to reduce network load if lua_zlib is installed.
local function HttpsGet(strURL)
	if (utils.GetUI() ~= utils.IsOpenLuup) and (not luup.model) then
		-- Older try to user curl
		local bdy,cde,hdrs = 1, 200, nil
		local p = io.popen("curl -k -s -m 15 -o - '" .. strURL .. "'")
		local result = p:read("*a")
		p:close()
		return bdy,cde,hdrs,result
	else
		-- Newer veras we can use http module
		local bodys = {}
		local headers = {}
		if zlib then
			headers["accept-encoding"] = "gzip, deflate"
		else
			headers["accept-encoding"] = "deflate"
		end
		local bdy,cde,hdrs,stts = https.request{
			url = strURL, 
			method = 'GET',
			headers = headers,
			protocol = "any",
			options =  {"all", "no_sslv2", "no_sslv3"},
            verify = "none",
			sink=ltn12.sink.table(bodys)
		}
		local enc = hdrs["content-encoding"] or "none"
		if type(bodys) == 'table' then bodys = table.concat(bodys) end
		if zlib and string.find(enc, "gzip") then
			bodys = zlib.inflate()(bodys)
		end
		return bdy,cde,hdrs,bodys
	end
end

-- Insert found value into table
local function insert_value(tab, varName, value, iconMap)
	local ti = table.insert
	local mult = nil
	local def = nil
	local vn = nil
	if type(varName) == "table" then
		mult = varName.multiplier
		def = varName.default
		vn = varName.name
	else
		vn = varName
	end
	if value then
		if mult then
			value = tonumber(value) * mult
		elseif vn == "Icon" and iconMap then 
			value = iconMap[value] or 44
		end
--		log.Debug("Insert key %s, value %s", vn, value)
		ti(tab, {vn, value})
		return true
	else
		if def then
--			log.Debug("Insert key %s, default value %s", vn, def)
			ti(tab, {vn, def})
			return true
		end
		return false
	end
end

-- Do nested key mapping. 
local function key_map(tkey, curItems, confMap)
	local function key_map_sub(key, curItems)
		local value = nil
		if key:find("%.") then
			local x = curItems
			for field in key:gmatch "[^%.%[%]]+" do
				x = x[tonumber(field) or field]
				if not x then return nil end
			end
			value = x
		else
			value = curItems[key]
		end
		return value
	end
	-- Look for key conversions
	if confMap then
		-- Substitude part of key if needed.
		if type(confMap.sub) == "table" and #confMap.sub == 2 then
			if tkey:find(confMap.sub[1]) then
				tkey = tkey:gsub(confMap.sub[1], confMap.sub[2])
--log.Debug("  sub %s with %s, resulting key %s",confMap.sub[1], confMap.sub[2], tkey)
			end
		end
		-- Prefix key if needed.
		if type(confMap.prfx) == "string" then
			tkey = confMap.prfx .. tkey
--log.Debug("  prefix with %s, resulting key %s",confMap.prfx,tkey)
		end
	end
	local value = nil
	if tkey:find("|") then
		if tkey:sub(1,2) == "o|" then
			-- Use either key as value
			local key1,key2 = tkey:match("o|([%w_]-)|([%w_]+)")
			if curItems[key1] then
				value = key1
			elseif curItems[key2] then
				value = key2
			end
		else
			-- Get value of either key. If missing there is none, i.e. zero.
			local key1,key2 = tkey:match("([%w_%.]-)|([%w_%.]+)")
			value = key_map_sub(key1, curItems) or key_map_sub(key2, curItems)
		end
	else
		value = key_map_sub(tkey, curItems)
	end
	if confMap and confMap.ppf then
		value = confMap.ppf(tkey, value)
	end
	return value
end

-- Process one day data and map
local function parse_input_day(input, varMap, iconMap, confMap)
	local res = {}
	for tkey, varName in pairs(varMap) do
		-- See if complex mapping is needed
		local value = key_map(tkey, input, confMap)
		if not insert_value(res, varName, value, iconMap) then
			log.Debug("Key not found %s",tkey)
		end
	end
	return res
end

-- Table of Weather providers with init and update functions
-- Must match providerMap in J_MsWeather.js
local ProviderMap = {
	[1] = {	name = "Dark Sky", 
			init = function()
				-- Check for required settings
				complete = MS.Latitude ~= "" and MS.Longitude ~= "" and MS.Key ~= "" and MS.Units ~= "" and MS.Language ~= ""
				if not complete then
					var.Set("DisplayLine1", "Complete settings first.", SID_AltUI)
					log.Error("DarkSky setup is not completed.")
				end	
				var.Set("ProviderName", "DarkSky")
				var.Set("ProviderURL", "darksky.net")
				return complete
			end, 
			update = function()
				local urltemplate = "https://api.darksky.net/forecast/%s/%s,%s?lang=%s&units=%s&exclude=hourly,alerts"
				local url = string.format(urltemplate, MS.Key, MS.Latitude, MS.Longitude, MS.Language, MS.Units)
				-- See if user wants forecast, if not eliminate daily from request
				if MS.ForecastDays == 0 then url = url .. ",daily" end
				-- If there is no rain sensor we do not need minutely data
				if MS.RainSensor == 0 then url = url .. ",minutely" end
				log.Debug("calling DarkSky API with url = %s", url)
				local wdata, retcode, headers, res = HttpsGet(url)
				local err = (retcode ~=200)
				if err then -- something wrong happened (website down, wrong key or location)
					log.Error("DarkSky API call failed with http code = %s", tostring(retcode))
					return false, res
				end
				log.Debug(res)
				local data, err = json.decode(res)
				if not data then
					log.Error("DarkSky API json decode error = %s", tostring(err)) 
					return false, "Invalid data"
				end

				-- this is the table used to map any providers output elements with the plugin variables
				local currentlyMap = { 
						["apparentTemperature"] = "CurrentApparentTemperature",
						["cloudCover"] = { name = "CurrentCloudCover", multiplier = 100 },
						["dewPoint"] = "CurrentDewPoint",
						["humidity"] = { name = "CurrentHumidity", multiplier = 100 },
						["icon"] = "Icon",
						["ozone"] = "CurrentOzone",
						["uvIndex"] = "CurrentuvIndex",
						["visibility"] = "CurrentVisibility",
						["precipIntensity"] = "CurrentPrecipIntensity",
						["precipProbability"] = { name = "CurrentPrecipProbability", multiplier = 100 },
						["precipType"] = "CurrentPrecipType",
						["pressure"] = "CurrentPressure",
						["summary"] = "CurrentConditions",
						["temperature"] = "CurrentTemperature",
						["time"] = "LastUpdate",
						["sunriseTime"] = "CurrentSunrise",
						["sunsetTime"] = "CurrentSunset",
						["windBearing"] = "CurrentWindBearing",
						["windSpeed"] = "CurrentWindSpeed",
						["windGust"] = "CurrentWindGust"
				}
				local forecastMap = { 
						["pressure"] = "Pressure",
						["summary"] = "Conditions",
						["ozone"] = "Ozone",
						["uvIndex"] = "uvIndex",
						["visibility"] = "Visibility",
						["precipIntensity"] = "PrecipIntensity",
						["precipIntensityMax"] = "PrecipIntensityMax",
						["precipProbability"] = { name = "PrecipProbability", multiplier = 100 },
						["precipType"] = "PrecipType",
						["temperatureMax"] = "MaxTemp",
						["temperatureMin"] = "MinTemp",
						["temperatureHigh"] = "HighTemp",
						["temperatureLow"] = "LowTemp",
						["apparentTemperatureMax"] = "ApparentMaxTemp",
						["apparentTemperatureMin"] = "ApparentMinTemp",
						["icon"] = "Icon",
						["cloudCover"] = { name = "CloudCover", multiplier = 100 },
						["dewPoint"] = "DewPoint",
						["humidity"] = { name = "Humidity", multiplier = 100 },
						["sunriseTime"] = "Sunrise",
						["sunsetTime"] = "Sunset",
						["windBearing"] = "WindBearing",
						["windSpeed"] = "WindSpeed",
						["windGust"] = "WindGust"
				}
				local iconMap = {
					["clear-day"] = 32, ["clear-night"] = 31, ["rain"] = 12, ["snow"] = 16, ["sleet"] = 18, ["wind"] = 24,
					["fog"] = 20, ["cloudy"] = 26, ["partly-cloudy-day"] = 30, ["partly-cloudy-night"] = 29, ["hail"] = 17,
					["thunderstorm"] = 4, ["tornado"] = 1
				}
				
				local varContainer = {}
				-- Get the currently values we are interested in.
				local curItems = data.currently
				if curItems then
					varContainer.currently = parse_input_day(curItems, currentlyMap, iconMap)
				else
					log.Warning("No currently data")
				end
				-- Get the forecast data the user wants
				if MS.ForecastDays > 0 then
					varContainer.forecast = {}
					for fd = 1, MS.ForecastDays do
						local curDay = data.daily.data[fd]
						if curDay then
							varContainer.forecast[fd] = parse_input_day(curDay, forecastMap, iconMap)
						else
							log.Warning("No daily data for day "..fd)
						end
					end
				else
					log.Debug("No forecast data configured")
				end
				return true, varContainer
			end
		},
	[2] = {	name = "Weather Underground",
			init = function()
				-- Check for required settings
				complete = MS.Latitude ~= "" and MS.Longitude ~= "" and MS.Key ~= "" and MS.StationID ~= ""
				if not complete then
					var.Set("DisplayLine1", "Complete settings first.", SID_AltUI)
					log.Error("Weather Underground setup is not completed.")
				end	
				var.Set("ProviderName", "WunderGround")
				var.Set("ProviderURL", "www.wunderground.com")
				return complete
			end, 
			update = function()
				-- Update for local station
				--https://github.com/timuckun/wunderground-web-component/blob/main/weather_underground_web_component.js
				-- https://docs.google.com/document/d/1KGb8bTVYRsNgljnNH67AMhckY8AQT2FVwZ9urj8SWBs/edit#
				local lang = languageMap[MS.Language] or "en-US"
				local urltemplate = "https://api.weather.com/v2/pws/observations/current?numericPrecision=decimal&stationId=%s&format=json&units=%s&apiKey=%s"
				local url = string.format(urltemplate, MS.StationName, MS.Units, MS.Key)
				log.Debug("calling Wunder Ground API with url = %s", url)
				local wdata, retcode, headers, res = HttpsGet(url)
				local err = (retcode ~=200)
				if err then -- something wrong happened (website down, wrong key or location)
					log.Error("Wunder Ground API call failed with http code = %s", tostring(retcode))
					return false, res
				end
				log.Debug(res)
				local data, pos, msg = dkjson.decode(res)  -- Response can include null values, do not use cjson.
				if not data then
					log.Error("Wunder Ground API json decode error = %s", tostring(msg)) 
					return false, "Invalid data"
				end

				-- this is the table used to map any providers output elements with the plugin variables
				local currentlyMap = { 
						["units.heatIndex"] = "CurrentApparentTemperature",
--						[""] = "CurrentCloudCover",
						["units.dewpt"] = "CurrentDewPoint",
						["humidity"] = "CurrentHumidity",
--						[""] = "Icon",
--						[""] = "CurrentOzone",
						["uv"] = "CurrentuvIndex",
--						[""] = "CurrentVisibility",
						["units.precipRate"] = "CurrentPrecipIntensity",
--						[""] = "CurrentPrecipProbability",
--						[""] = "CurrentPrecipType",
						["units.pressure"] = "CurrentPressure",
--						[""] = "CurrentConditions",
						["units.temp"] = "CurrentTemperature",
						["epoch"] = "LastUpdate",
--						[""] = "CurrentSunrise",
--						[""] = "CurrentSunset",
						["winddir"] =  "CurrentWindBearing",
						["units.windSpeed"] = "CurrentWindSpeed",
						["units.windGust"] = "CurrentWindGust"
				}
				local forecastMap = { 
--						[""] = "Pressure",
						["narrative"] = "Conditions",
--						[""] = "Ozone",
						["daypart.1.uvIndex"] = "uvIndex",
--						[""] = "Visibility",
						["qpf"] = "PrecipIntensity",
--						["precipIntensityMax"] = "PrecipIntensityMax",
						["daypart.1.precipChance"] = "PrecipProbability",
						["daypart.1.precipType"] = "PrecipType",
						["temperatureMax"] = "MaxTemp",
						["temperatureMin"] = "MinTemp",
						["daypart.1.temperatureHeatIndex"] = "ApparentMaxTemp",
						["daypart.1.temperatureWindChill"] = "ApparentMinTemp",
						["daypart.1.iconCode"] = "Icon",
						["daypart.1.cloudCover"] = "CloudCover",
--						[""] = "DewPoint",
						["sunriseTimeUtc"] = "Sunrise",
						["sunsetTimeUtc"] = "Sunset",
						["daypart.1.relativeHumidity"] = "Humidity",
						["daypart.1.windDirection"] =  "WindBearing",
						["daypart.1.windSpeed"] = "WindSpeed",
--						[""] = "WindGust"
				}
				
				local varContainer = {}
				-- Get the currently values we are interested in.
				local curItems = data.observations[1]
				-- We need to change string .units. in key to right value
				local confMap = {
					sub = {"units.", (MS.Units == "m" and "metric." or (MS.Units == "e" and "imperial." or (MS.Units == "s" and "metric_si." or "uk_hybrid.")))}
				}
				if curItems then
					varContainer.currently = parse_input_day(curItems, currentlyMap, iconMap, confMap)
				else
					log.Warning("No current data")
				end

				if MS.ForecastDays > 0 then
					-- We check forecast only once an hour even if poll rate is higher.
					local lastfcUpdate = var.GetNumber("LastForecastTS")
					local now = os.time()
					local tt = os.date("*t", now)
					if (now - lastfcUpdate) < 3600 then
						log.Info("Skipping Wunder Ground forecast request. Last update was %s seconds ago.", now - lastfcUpdate)
						return true, varContainer
					end
					var.Set("LastForecastTS", now)
					-- Get forecast data
					local days = 3
					if MS.ForecastDays > 3 then days = 5 end
					if MS.ForecastDays > 5 then days = 7 end
					local urltemplate = "https://api.weather.com/v3/wx/forecast/daily/%sday?geocode=%s,%s&format=json&language=%s&units=%s&apiKey=%s"
					local url = string.format(urltemplate, days, MS.Latitude, MS.Longitude, lang, MS.Units, MS.Key)
					log.Debug("calling Wunder Ground API with url = %s", url)
					local wdata, retcode, headers, res = HttpsGet(url)
					local err = (retcode ~=200)
					if err then -- something wrong happened (website down, wrong key or location)
						log.Error("Wunder Ground API call failed with http code = %s", tostring(retcode))
						return false, res
					end
					log.Debug(res)
					local data, pos, msg = dkjson.decode(res)  -- Response can include null values, do not use cjson.
					if not data then
						log.Error("Wunder Ground API json decode error = %s", tostring(msg)) 
						return false, "Invalid data"
					end
					
					varContainer.forecast = {}
					local curDay = data
					for fd = 1, MS.ForecastDays do
						if curDay then
							local confMap = {
								ppf = function(key, value)
									local res = value
									if value then 
										if key:find("daypart.1") then
											res = value[(fd-1)*2+1]
										else
											res = value[fd]
										end
									end
									return res
								end
							}
							varContainer.forecast[fd] = parse_input_day(curDay, forecastMap, iconMap, confMap)
						else
							log.Warning("No daily data for day "..fd)
						end
					end
				end
				return true, varContainer
			end
		},
	[3] = {	name = "OpenWeather",
			init = function()
				-- Check for required settings
				complete = MS.Latitude ~= "" and MS.Longitude ~= "" and MS.Key ~= ""
				if not complete then
					var.Set("DisplayLine1", "Complete settings first.", SID_AltUI)
					log.Error("OpenWeather setup is not completed.")
				end	
				var.Set("ProviderName", "OpenWeather")
				var.Set("ProviderURL", "www.openweathermap.org")
				return complete
			end, 
			update = function()
				local urltemplate = "https://api.openweathermap.org/data/2.5/onecall?lat=%s&lon=%s&units=%s&lang=%s&appid=%s&exclude=hourly"
				local url = string.format(urltemplate, MS.Latitude, MS.Longitude, MS.Units, MS.Language, MS.Key)
				-- See if user wants forecast, if not eliminate daily from request
				if MS.ForecastDays == 0 then url = url .. ",daily" end
				-- If there is no rain sensor we do not need minutely data
				if MS.RainSensor == 0 then url = url .. ",minutely" end
				log.Debug("calling OpenWeather API with url = %s", url)
				local wdata, retcode, headers, res = HttpsGet(url)
				local err = (retcode ~=200)
				if err then -- something wrong happened (website down, wrong key or location)
					log.Error("OpenWeather API call failed with http code = %s", tostring(retcode))
					return false, res
				end
				-- this is the table used to map any providers output elements with the plugin variables
				local currentlyMap = { 
						["feels_like"] = "CurrentApparentTemperature",
						["clouds"] = "CurrentCloudCover",
						["dew_point"] = "CurrentDewPoint",
						["humidity"] = "CurrentHumidity",
						["weather.1.icon"] = "Icon",
--						[""] = "CurrentOzone",
						["uvi"] = "CurrentuvIndex",
						["visibility"] = { name = "CurrentVisibility", multiplier = 0.001 },
						["rain.1h|snow.1h"] = { name = "CurrentPrecipIntensity", default = 0 },
--						[""] = "CurrentPrecipProbability",
						["o|rain|snow"] =  { name = "CurrentPrecipType", default = "None" },
						["pressure"] = "CurrentPressure",
						["weather.1.description"] = "CurrentConditions",
						["temp"] = "CurrentTemperature",
						["dt"] = "LastUpdate",
						["sunrise"] = "CurrentSunrise",
						["sunset"] = "CurrentSunset",
						["wind_deg"] = "CurrentWindBearing",
						["wind_speed"] = "CurrentWindSpeed",
						["wind_gust"] = "CurrentWindGust"
					}
				local forecastMap = { 
						["pressure"] = "Pressure",
						["weather.1.description"] = "Conditions",
--						[""] = "Ozone",
						["uvi"] = "uvIndex",
--						[""] = "Visibility",
						["rain|snow"] = { name = "PrecipIntensity", default = 0 },
--						[""] = "PrecipIntensityMax",
						["pop"] = "PrecipProbability",
						["o|rain|snow"] = { name = "PrecipType", default = "None" },
						["temp.max"] = "MaxTemp",
						["temp.min"] = "MinTemp",
						["temp.day"] = "HighTemp",
						["temp.night"] = "LowTemp",
						["feels_like.day"] = "ApparentMaxTemp",
						["feels_like.night"] = "ApparentMinTemp",
						["weather.1.icon"] = "Icon",
						["clouds"] = "CloudCover",
						["dew_point"] = "DewPoint",
						["humidity"] = "Humidity",
						["sunrise"] = "Sunrise",
						["sunset"] = "Sunset",
						["wind_deg"] = "WindBearing",
						["wind_speed"] = "WindSpeed",
						["wind_gust"] = "WindGust"
				}
				local iconMap = {
					["01d"] = 32, ["01n"] = 31, ["02d"] = 34, ["02n"] = 33, ["03d"] = 30, ["03n"] = 29, ["04d"] = 28,
					["04n"] = 29, ["09d"] = 11, ["09n"] = 11, ["11d"] = 38, ["11n"] = 47, ["13d"] = 16, ["13n"] = 16,
					["50d"] = 20, ["50n"] = 20
				}
				local airMap = {
					["components.o3"] = "CurrentOzone",
					["components.co"] = "CurrentCO",
					["components.no"] = "CurrentNO",
					["components.no2"] = "CurrentNO2",
					["components.so2"] = "CurrentSO2",
					["components.nh3"] = "CurrentNH3",
					["components.pm10"] = "CurrentPM10",
					["components.pm2_5"] = "CurrentPM25",
					["main.aqi"] = "CurrentAirQuality"
				}

				log.Debug(res)
				local data, err = json.decode(res)
				if not data then
					log.Error("OpenWeather API json decode error = %s", tostring(err)) 
					return false, "Invalid data"
				end
				local varContainer = {}
				-- Get the currently values we are interested in.
				local curItems = data.current
				if curItems then
					varContainer.currently = parse_input_day(curItems, currentlyMap, iconMap)
				else
					log.Warning("No current data")
				end
				-- Get the forecast data the user wants
				if MS.ForecastDays > 0 then
					varContainer.forecast = {}
					for fd = 1, MS.ForecastDays do
						local curDay = data.daily[fd]
						if curDay then
							varContainer.forecast[fd] = parse_input_day(curDay, forecastMap, iconMap)
						else
							log.Warning("No daily data for day "..fd)
						end
					end
				else
					log.Debug("No forecast data configured")
				end
				-- Get Air current quality data.
				local urltemplate = "https://api.openweathermap.org/data/2.5/air_pollution?lat=%s&lon=%s&appid=%s"
				local url = string.format(urltemplate, MS.Latitude, MS.Longitude, MS.Key)
				log.Debug("calling OpenWeather API with url = %s", url)
				local wdata, retcode, headers, res = HttpsGet(url)
				local err = (retcode ~=200)
				if err then -- something wrong happened (website down, wrong key or location)
					log.Error("OpenWeather API call failed with http code = %s", tostring(retcode))
					return true, varContainer
				end
				log.Debug(res)
				local data, err = json.decode(res)
				if not data then
					log.Error("OpenWeather API json decode error = %s", tostring(err)) 
					return true, varContainer
				end
				-- Get the currently values we are interested in.
				local curItems = data.list
				if curItems then curItems = data.list[1] end
				if curItems then
					local ti = table.insert
					local confMap = { 
						ppf = function(key,value)
							local res = value
							if key == "main.aqi" then
								local map = {"Good","Fair","Moderate","Poor","Very Poor"}
								res = map[value]
							end
							return res
						end
					}
					local aqt = parse_input_day(curItems, airMap, nil, confMap)
					-- Merge with currently data
					for _, value in ipairs(aqt) do
						ti(varContainer.currently, value)
					end
				else
					log.Warning("No air quality data")
				end
				return true, varContainer
			end
		},
	[4] = {	name = "Accu Weather",
			init = function()
				-- Check for required settings
				complete = MS.Latitude ~= "" and MS.Longitude ~= "" and MS.Key ~= ""
				if not complete then
					var.Set("DisplayLine1", "Complete settings first.", SID_AltUI)
					log.Error("Accu Weather setup is not completed.")
				end	
				var.Set("ProvderName", "Accu Weather")
				var.Set("ProvderURL", "www.accuweater.com")
				return complete
			end, 
			update = function()
				-- See if we need to pull the correct location ID. This is stored in StationName
				if MS.StationName == "" then
					local urltemplate = "http://dataservice.accuweather.com/locations/v1/cities/geoposition/search?apikey=%s&q=%s,%s"
					local url = string.format(urltemplate, MS.Key, MS.Latitude, MS.Longitude)
					log.Debug("calling AccuWeather API with url = %s", url)
					local wdata, retcode, headers, res = HttpsGet(url)
					local err = (retcode ~=200)
					if err then -- something wrong happened (website down, wrong key or location)
						log.Error("AccuWeather API call failed with http code = %s", tostring(retcode))
						return false, res
					end
					log.Debug(res)
					local data, err = json.decode(res)
					if not data then
						log.Error("AccuWeather API json decode error = %s", tostring(err))
						return false, "Invalid data"
					end
					if data.Key then 
						var.Set("StationName", data.Key)
						MS.StationName = data.Key
					end
				end
				if MS.StationName == "" then
					log.Error("AccuWeather failed to get location code")
					return false, "No location code"
				end
				-- Get current weather
				local urltemplate = "http://dataservice.accuweather.com/currentconditions/v1/%s?apikey=%s&details=true&language=%s"
				local url = string.format(urltemplate, MS.StationName, MS.Key, MS.Language)
				log.Debug("calling AccuWeather API with url = %s", url)
				local wdata, retcode, headers, res = HttpsGet(url)
				local err = (retcode ~=200)
				if err then -- something wrong happened (website down, wrong key or location)
					log.Error("AccuWeather API call failed with http code = %s", tostring(retcode))
					return false, res
				end
				log.Debug(res)
				local data, err = json.decode(res)
				if not data then
					log.Error("AccuWeather API json decode error = %s", tostring(err))
					return false, "Invalid data"
				end
				local currentlyMap = { 
						["ApparentTemperature.units.Value"] = "CurrentApparentTemperature",
						["CloudCover"] = "CurrentCloudCover",
						["DewPoint.units.Value"] = "CurrentDewPoint",
						["RelativeHumidity"] = "CurrentHumidity",
						["WeatherIcon"] = "Icon",
--						[""] = "CurrentOzone",
						["UVIndex"] = "CurrentuvIndex",
						["Visibility.units.Value"] = "CurrentVisibility",
						["Precip1hr.units.Value"] = {name = "CurrentPrecipIntensity", default = 0},
--						[""] = "CurrentPrecipProbability",
						["PrecipitationType"] = {name = "CurrentPrecipType", default = "None"},
						["Pressure.units.Value"] = "CurrentPressure",
						["WeatherText"] = "CurrentConditions",
						["Temperature.units.Value"] = "CurrentTemperature",
						["EpochTime"] = "LastUpdate",
--						[""] = "CurrentSunrise",
--						[""] = "CurrentSunset",
						["Wind.Direction.Degrees"] =  "CurrentWindBearing",
						["Wind.Speed.units.Value"] = "CurrentWindSpeed",
						["WindGust.Speed.units.Value"] = "CurrentWindGust"
				}
				local forecastMap = { 
--						[""] = "Pressure",
						["Day.ShortPhrase"] = "Conditions",
--						[""] = "Ozone",
--						[""] = "uvIndex",
--						[""] = "Visibility",
						["Day.PrecipitationIntensity"] = {name = "PrecipIntensity", default = 0},
						["Day.TotalLiquid.Value"] = "PrecipIntensityMax",
						["Day.PrecipitationProbability"] = "PrecipProbability",
						["Day.PrecipitationType"] = {name = "PrecipType", default = "None"},
						["Temperature.Maximum.Value"] = "MaxTemp",
						["Temperature.Minimum.Value"] = "MinTemp",
--						[""] = "HighTemp",
--						[""] = "LowTemp",
						["RealFeelTemperature.Maximum.Value"] = "ApparentMaxTemp",
						["RealFeelTemperature.Minimum.Value"] = "ApparentMinTemp",
						["Day.Icon"] = "Icon",
						["Day.CloudCover"] = "CloudCover",
--						[""] = "DewPoint",
--						[""] = "Humidity",
						["Sun.Rise"] = "Sunrise",
						["Sun.Set"] = "Sunset",
						["Day.Wind.Direction.Degrees"] =  "WindBearing",
						["Day.Wind.Speed.Value"] = "WindSpeed",
						["Day.WindGust.Speed.Value"] = "WindGust"
				}
				local iconMap = {
					[1] = 32, [2] = 34, [3] = 30, [4] = 30, [5] = 21, [6] = 28, [7] = 26, [8] = 26, [11] = 20,
					[12] = 11, [13] = 39, [14] = 39, [15] = 4, [16] = 38, [17] = 37, [18] = 12, [19] = 13, [20] = 13,
					[21] = 13, [22] = 16, [23] = 41, [24] = 10, [25] = 18, [26] = 10, [29] = 5, [30] = 36, [31] = 44,
					[32] = 24, [33] = 31, [34] = 33, [35] = 29, [36] = 33, [37] = 33, [38] = 27, [39] = 12, [40] = 12,
					[41] = 47, [42] = 47, [43] = 13, [44] = 13
				}

				local varContainer = {}
				-- Get the currently values we are interested in.
				local curItems = data[1]
				-- We need to change string .units. in key to right value
				local confMap = {
					sub = {".units.", (MS.Units == "m" and ".Metric." or ".Imperial.")},
					ppf = function(key, value)
						local res = value
						if value and key:find("Sun.") then
							local y,m,d,h,n,s = string.match(value,"(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
							res = os.time({year=y,month=m,day=d,hour=h,min=n,sec=s})
						end
						return res
					end
				}
				if curItems then
					varContainer.currently = parse_input_day(curItems, currentlyMap, iconMap, confMap)
				else
					log.Warning("No current data")
				end
				
				-- Get the forecast data the user wants
				if MS.ForecastDays > 0 then
					-- We check forecast only twice a day at the 6th or 18th hour due to limited requests per day.
					local lastfcUpdate = var.GetNumber("LastForecastTS")
					local now = os.time()
					local tt = os.date("*t", now)
					if not ((tt.hour == 6 or tt.hour == 18) and ((now - lastfcUpdate) > 7200)) and ((now - lastfcUpdate) < 43200) then
						log.Info("Skipping AccuWeather forecast request. Last update was %s seconds ago.", now - lastfcUpdate)
						return true, varContainer
					end
					var.Set("LastForecastTS", now)
					local urltemplate = "http://dataservice.accuweather.com/forecasts/v1/daily/5day/%s?apikey=%s&details=true&metric=%s&language=%s"
					local url = string.format(urltemplate, MS.StationName, MS.Key, tostring(MS.Units == "m"), MS.Language)
					log.Debug("calling AccuWeather API with url = %s", url)
					local wdata, retcode, headers, res = HttpsGet(url)
					local err = (retcode ~=200)
					if err then -- something wrong happened (website down, wrong key or location)
						log.Error("AccuWeather API call failed with http code = %s", tostring(retcode))
						return false, res
					end
					log.Debug(res)
					local data, err = json.decode(res)
					if not data then
						log.Error("AccuWeather API json decode error = %s", tostring(err))
						return false, "Invalid data"
					end
					varContainer.forecast = {}
					confMap.sub = nil
					for fd = 1, MS.ForecastDays do
						local curDay = data.DailyForecasts[fd]
						if curDay then
							varContainer.forecast[fd] = parse_input_day(curDay, forecastMap, iconMap, confMap)
						else
							log.Warning("No daily data for day "..fd)
						end
					end
				else
					log.Debug("No forecast data configured")
				end
				return true, varContainer
			end
		},
	[5] = {	name = "AmbientWeather",
			init = function()
				-- Check for required settings
				complete = MS.Units ~= "" and MS.Key ~= "" and MS.ApplicationKey ~= ""
				if not complete then
					var.Set("DisplayLine1", "Complete settings first.", SID_AltUI)
					log.Error("AmbientWeather setup is not completed.")
				end	
				var.Set("ProvderName", "AmbientWeather")
				var.Set("ProvderURL", "www.ambientweather.com")
				return complete
			end, 
			update = function()
				local urltemplate = "https://api.ambientweather.net/v1/devices?applicationKey=%sapiKey=%s"
				local url = string.format(urltemplate, MS.ApplicationKey, MS.Key)
				log.Debug("calling AmbientWeather API with url = %s", url)
				local wdata, retcode, headers, res = HttpsGet(url)
				local err = (retcode ~=200)
				if err then -- something wrong happened (website down, wrong key or location)
					log.Error("AmbientWeather API call failed with http code = %s", tostring(retcode))
					return false, err
				end
				
				-- this is the table used to map any providers output elements with the plugin variables
				local currentlyMap = { 
						["feelsLike"] = "CurrentApparentTemperature",
--						[""] = "CurrentCloudCover",
						["dewPoint"] = "CurrentDewPoint",
						["humidity"] = "CurrentHumidity",
--						[""] = "Icon",
--						[""] = "CurrentOzone",
						["uv"] = "CurrentuvIndex",
--						[""] = "CurrentVisibility",
						["hourlyrainin"] = "CurrentPrecipIntensity",
--						[""] = "CurrentPrecipProbability",
--						[""] = "CurrentPrecipType",
						["baromabsin"] = "CurrentPressure",
--						[""] = "CurrentConditions",
						["tempf"] = "CurrentTemperature",
						["dateutc"] = "LastUpdate",
						["winddir"] =  "CurrentWindBearing",
						["windspeedmph"] = "CurrentWindSpeed",
						["windgustmph"] = "CurrentWindGust"
				}
				local forecastMap = { 
						-- No forcecast data provided.
						--https://ambientweather.com/amweatherbridge.html
				}
				log.Debug(res)
				local data, err = json.decode(res)
				if not data then
					log.Error("AmbientWeather API json decode error = %s", tostring(err)) 
					return false, "Invalid data"
				end
				local varContainer = {}
				-- Get station/devices list
				local stationID = MS.StationID
				local stationList = {}
				local id = 0
				local curItems = nil
				for _, station in ipairs(data) do
					if station.info then
						ti(stationList, {v = id, l = station.info["name"]})
						if id == stationID then
							curItems = station
						end
						id = id + 1
					end
				end
				var.Set("StationList", json.encode(stationList))
				-- Get the currently values we are interested in.
				if curItems then curItems = curItems.lastData end
				if curItems then
					varContainer.currently = parse_input_day(curItems, currentlyMap, iconMap)
				else
					log.Warning("No currently data")
				end
				-- No forecast data the
				return true, varContainer
			end
		},
	[6] = {	name = "PWS Weather",
			init = function()
				-- Check for required settings
				var.Set("ProvderName", "PWSWeater")
				var.Set("ProvderURL", "www.pwsweather.com")
				return MS.Latitude ~= "" and MS.Longitude ~= ""
			end, 
			update = function()
				local urltemplate = ""
				return false, "Not implemented"
				-- https://api.aerisapi.com/conditions/52,5?&format=json&from=now&to=now&client_id=CLIENT_ID&client_secret=CLIENT_SECRET
				-- Can have aerisweather for forecast https://www.pwsweather.com/contributor-plan
			end
		},
	[311] = {	name = "KNMI (NL)",
			init = function()
				-- Check for required settings
				complete = MS.Latitude ~= "" and MS.Longitude ~= "" and MS.Key ~= ""
				if not complete then
					var.Set("DisplayLine1", "Complete settings first.", SID_AltUI)
					log.Error("KNMI setup is not completed.")
				end	
				var.Set("ProvderName", "KNMI")
				var.Set("ProvderURL", "www.weerlive.nl")
				return complete
			end, 
			update = function()
				local urltemplate = "http://weerlive.nl/api/json-data-10min.php?key=%s&locatie=%s,%s"
				local url = string.format(urltemplate, MS.Key, MS.Latitude, MS.Longitude)
				log.Debug("calling Weerlive API with url = %s", url)
				local wdata, retcode, headers, res = HttpsGet(url)
				local err = (retcode ~=200)
				if err then -- something wrong happened (website down, wrong key or location)
					log.Error("Weerlive API call failed with http code = %s", tostring(retcode))
					return false, res
				end
				-- this is the table used to map any providers output elements with the plugin variables
				local currentlyMap = { 
						["gtemp"] = "CurrentApparentTemperature",
						["clouds"] = "CurrentCloudCover",
						["dauwp"] = "CurrentDewPoint",
						["lv"] = "CurrentHumidity",
						["image"] = "Icon",
--						[""] = "CurrentOzone",
--						[""] = "CurrentuvIndex",
						["zicht"] = "CurrentVisibility",
--						[""] = "CurrentPrecipIntensity",
--						[""] = "CurrentPrecipProbability",
--						[""] = "CurrentPrecipType",
						["luchtd"] = "CurrentPressure",
						["samenv"] = "CurrentConditions",
						["temp"] = "CurrentTemperature",
--						[""] = "LastUpdate",
						["windr"] =  "CurrentWindDirection",
--						[""] =  "CurrentWindBearing",
						["winds"] = "CurrentWindSpeed"
--						[""] = "CurrentWindGust"
				}
				local forecastMap = { 
						["pressure"] = "Pressure",
--						[""] = "Conditions",
--						[""] = "Ozone",
--						[""] = "uvIndex",
--						[""] = "Visibility",
--						[""] = "PrecipIntensity",
--						[""] = "PrecipIntensityMax",
						["neerslag"] = "PrecipProbability",
						["zon"] = "SunProbability",
--						[""] = "PrecipType",
						["tmax"] = "MaxTemp",
						["tmin"] = "MinTemp",
--						[""] = "HighTemp",
--						[""] = "LowTemp",
--						[""] = "ApparentMaxTemp",
--						[""] = "ApparentMinTemp",
						["weer"] = "Icon",
--						[""] = "CloudCover",
--						[""] = "DewPoint",
--						[""] = "Humidity",
						["windr"] =  "WindDirection",
--						[""] =  "WindBearing",
						["windk"] = "WindSpeed"
--						[""] = "WindGust"
				}
				local iconMap = {
					["zonnig"] = 32, ["bliksem"] = 4, ["regen"] = 12, ["buien"] = 11, ["hagel"] = 17, ["mist"] = 20, ["sneeuw"] = 16,
					["bewolkt"] = 29, ["halfbewolkt"] = 30, ["zwaarbewolkt"] = 26, ["nachtmist"] = 20, ["helderenacht"] = 31, ["wolkennacht"] = 27
				}
				log.Debug(res)
				local data, err = json.decode(res)
				if not data then
					log.Error("Weerlive API json decode error = %s", tostring(err)) 
					return false, "Invalid data"
				end
				local varContainer = {}
				-- Get the currently values we are interested in.
				local curItems = data.liveweer
				if curItems then curItems = curItems[1] end
				if curItems then
					varContainer.currently = parse_input_day(curItems, currentlyMap, iconMap)
				else
					log.Warning("No current data")
				end
				-- Get the forecast data the user wants
				if MS.ForecastDays > 0 then
					varContainer.forecast = {}
					for fd = 1, MS.ForecastDays do
						local curDay = curItems
						local confMap = { prfx = "d"..fd }
						if curDay then
							varContainer.forecast[fd] = parse_input_day(curDay, forecastMap, iconMap, confMap)
						else
							log.Warning("No daily data for day "..fd)
						end
					end
				else
					log.Debug("No forecast data configured")
				end
				return true, varContainer
			end
		},
	[312] = {
			name = "Buienradar (NL)",
			init = function()
				-- Check for required settings
				var.Set("ProviderName", "Buienradar")
				var.Set("ProviderURL", "www.buienradar.nl")
				return MS.Latitude ~= "" and MS.Longitude ~= ""
			end, 
			update = function()
				local defaultStationID = 6260 -- Use De Bilt if we cannot find a close one
				local url = "https://data.buienradar.nl/2.0/feed/json"
				log.Debug("calling Buienradar API with url = %s", url)
				local wdata, retcode, headers, res = HttpsGet(url)
				local err = (retcode ~=200)
				if err then -- something wrong happened (website down, wrong key or location)
					log.Error("Buienradar API call failed with http code = %s", tostring(retcode))
					return false, err
				end
				-- this is the table used to map any providers output elements with the plugin variables
				local currentlyMap = { 
						["feeltemperature"] = "CurrentApparentTemperature",
						["humidity"] = "CurrentHumidity",
						["graphUrl"] = "Icon",
						["sunpower"] = { name = "CurrentuvIndex", multiplier = 0.01 },
						["visibility"] = { name = "CurrentVisibility", multiplier = 0.001 },
						["precipitation"] = "CurrentPrecipIntensity",
						["airpressure"] = "CurrentPressure",
						["temperature"] = "CurrentTemperature",
						["timestamp"] = "LastUpdate",
						["winddirection"] =  "CurrentWindDirection",
						["winddirectiondegrees"] =  "CurrentWindBearing",
						["windspeed"] = "CurrentWindSpeed",
						["windgusts"] = "CurrentWindGust",
						["weatherdescription"] = "CurrentConditions"
				}
				local forecastMap = { 
						["weatherdescription"] = "Conditions",
						["sunChance"] = "SunProbability",
						["mmRainMin"] = "PrecipIntensity",
						["mmRainMax"] = "PrecipIntensityMax",
						["rainChance"] = "PrecipProbability",
						["maxtemperatureMax"] = "MaxTemp",
						["mintemperatureMin"] = "MinTemp",
						["windDirection"] =  "WindDirection",
						["wind"] = "WindSpeed",
				}
				local iconMap = {
					["a"] = 32, ["b"] = 34, ["c"] = 26, ["d"] = 20, ["f"] = 39, ["g"] = 38, ["h"] = 39, ["i"] = 14, ["j"] = 30, ["k"] = 39,
					["l"] = 40, ["m"] = 40, ["n"] = 20, ["o"] = 30, ["p"] = 26, ["q"] = 40, ["r"] = 30, ["s"] = 4, ["t"] = 14, ["u"] = 13,
					["v"] = 16, ["w"] = 5, ["aa"] = 31, ["bb"] = 33, ["cc"] = 26, ["dd"] = 20, ["ff"] = 45, ["gg"] = 47, ["hh"] = 45,
					["ii"] = 14, ["jj"] = 29, ["kk"] = 45, ["ll"] = 40, ["mm"] = 40, ["nn"] = 20, ["oo"] = 29, ["pp"] = 26, ["qq"] = 40,
					["rr"] = 29, ["ss"] = 4, ["tt"] = 14, ["uu"] = 13, ["vv"] = 16, ["ww"] = 5,
				}
				log.Debug(res)
				local data, err = json.decode(res)
				if not data then
					log.Error("Buienradar API json decode error = %s", tostring(err)) 
					return false, "Invalid data"
				end
				local varContainer = {}
				-- Get the currently values we are interested in.
				local stations = data.actual.stationmeasurements
				local curItems = nil
				if stations then
					-- Find station to use and collect curent availble stations
					local stationID = MS.StationID
					if stationID == 0 then stationID = defaultStationID end -- Default is De Bilt
					local stationList = {}
					local ti = table.insert
					for _, station in ipairs(stations) do
						ti(stationList, {v = station["stationid"], l = station["stationname"]})
						if station["stationid"] == stationID then
							curItems = station
						end
					end
					var.Set("StationList", json.encode(stationList))
				end
				if curItems then
					local confMap = { 
						ppf = function(key, value)
							local res = value
							if key == "graphUrl" then
								-- Map icon url, to icon value
								local ssub = string.sub
								local icn_str = ssub(value, -2)
								if ssub(icn_str,1,1) == "/" then
									icn_str = ssub(icn_str,2)
								end
								res = icn_str
							elseif key == "timestamp" then
								local y,m,d,h,n,s = string.match(value,"(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
								res = os.time({year=y,month=m,day=d,hour=h,min=n,sec=s})
							end
							return res
						end
					}
					varContainer.currently = parse_input_day(curItems, currentlyMap, iconMap, confMap)
				else
					log.Warning("No currently data")
				end
				-- Get the forecast data the user wants
				if MS.ForecastDays > 0 then
					varContainer.forecast = {}
					for fd = 1, MS.ForecastDays do
						local curDay = data.forecast.fivedayforecast[fd]
						if curDay then
							varContainer.forecast[fd] = parse_input_day(curDay, forecastMap, iconMap)
						else
							log.Warning("No daily data for day "..fd)
						end
					end
				else
					log.Debug("No forecast data configured")
				end
				return true, varContainer
			end
		}
}


-- processes and parses the MS data into device variables 
local function setvariables(variable, varmap, value, prefix)
	if not prefix then prefix = "" end
	if varmap.pattern then value = string.gsub(value, varmap.pattern, "") end
--	if varmap.multiplier then value = value * varmap.multiplier end
	if varmap.decimal then value = math.floor(value * 10^varmap.decimal + .5) / 10^varmap.decimal end
	var.Set(prefix..variable, value, varmap.serviceId)
	if varmap.childID then -- we update the child device as well
		local c = varmap.childKey
		var.Set(SensorInfo[c].variable, value, SensorInfo[c].serviceId, varmap.childID)
		-- Set display values for generic sensors
		if c == "W" or c == "Q" or c == "X" or c == "R" then
			luup.call_delay("MS_UpdateMultiDataItem",2,c..varmap.childID)
		else
			var.Set("DisplayLine1", value, SID_AltUI, varmap.childID)
			var.Set("DisplayLine1", value, SID_WeatherM, varmap.childID)
		end
	end
--[[
		if MS.RainSensor == 1 then
			-- the option of a virtual rain sensor is on, so we set the rain flags based on the trigger levels
			log.Debug("DEBUG: IntensityTrigger = %d - ProbabilityTrigger = %d", MS.PrecipIntensityTrigger, MS.PrecipProbabilityTrigger) 
			if key == "currently_precipIntensity" and tonumber(value) >= tonumber(MS.PrecipIntensityTrigger)
				then rain_intensity_trigger = tonumber(value) >= tonumber(MS.PrecipIntensityTrigger) 
			elseif key == "currently_precipProbability" and tonumber(value) >= tonumber(MS.PrecipProbabilityTrigger)
				then rain_probability_trigger = tonumber(value) >= tonumber(MS.PrecipProbabilityTrigger) end
			end
	end
]]
	return true
end

-- Update a multi data item with a slight delay so all parameters are updated
function MS_UpdateMultiDataItem(data)
	local sf,ss = string.format, string.sub
	
	local item = ss(data,1,1)
	local ID = tonumber(ss(data,2))
	local si = SensorInfo[item]
	local dl1, dl2 = "", ""
	if item == "W" then
		log.Debug("Updating wind data for child device "..ID)
		local ws = var.GetNumber("CurrentWindSpeed")
		local wg = var.GetNumber("CurrentWindGust")
		local wb = var.GetNumber("CurrentWindBearing")
		if si then var.Set(si.variable, ws, si.serviceId, ID) end
		dl1 = sf("Speed %.1f, Gust %.1f ",ws,wg)
		dl2 = sf("Bearing %d ",wb)
	elseif item == "Q" then
		log.Debug("Updating air quality data for child device "..ID)
		local aqi = var.Get("CurrentAirQuality")
		local pm10 = var.GetNumber("CurrentPM10")
		local pm25 = var.GetNumber("CurrentPM25")
		if si then var.Set(si.variable, aqi, si.serviceId, ID) end
		dl1 = sf("Air Qual. Ind. %s",aqi)
		dl2 = sf("Fine part. %.2f, Coarse part. %.2f",pm25,pm10)
	elseif item == "X" then
		log.Debug("Updating air quality 2 data for child device "..ID)
		local co = var.GetNumber("CurrentCO")
		local no = var.GetNumber("CurrentNO")
		local no2 = var.GetNumber("CurrentNO2")
		local so2 = var.GetNumber("CurrentSO2")
		local nh3 = var.GetNumber("CurrentNH3")
		dl1 = sf("CO %d, NO %.2f, NO2 %.2f",co,no,no2)
		dl2 = sf("NH3 %.2f, SO2 %.2f",so2,nh3)
	elseif item == "R" then
		log.Debug("Updating rain data for child device "..ID)
		local pp = var.GetNumber("CurrentPrecipProbability")
		local pi = var.GetNumber("CurrentPrecipIntensity")
		local pt = var.Get("CurrentPrecipType")
		if si then var.Set(si.variable, pi, si.serviceId, ID) end
		if pi > 0 then
			dl1 = sf("Type %s ",pt)
			dl2 = sf("Probability %d%%, Intensity %.2f",pp,pi)
		else
			dl1 = "No Precipitation expected"
		end
	end
	var.Set("DisplayLine1", dl1, SID_AltUI, ID)
	var.Set("DisplayLine1", dl1, SID_WeatherM, ID)
	var.Set("DisplayLine2", dl2, SID_AltUI, ID)
	var.Set("DisplayLine2", dl2, SID_WeatherM, ID)
end

-- Build display line based on user preference
local function displayLine(linenum)
	local tc, ti = table.concat, table.insert
	local txtTab = {}
	local dispIdx = var.GetNumber("DispLine"..linenum)
	if dispIdx ~= 0 then
		for k,v in ipairs(DisplayMap[dispIdx]) do
			local val = var.Get(v.var,v.sid)
			if val ~= '' then
				if v.var == "LastUpdate" then
					val = os.date("%d %b, %H:%M",val)
				end
				ti(txtTab, v.prefix .. val)
			end    
		end
		if #txtTab ~= 0 then
			var.Set("DisplayLine"..linenum, tc(txtTab, ", "), SID_AltUI)
		else
			log.Warning("No information found for DisplayLine"..linenum)
			var.Set("DisplayLine"..linenum, "No data", SID_AltUI)
		end    
	else
		log.Warning("No configuration set for DisplayLine"..linenum)
	end
end

-- call the Provider update function
local function MS_GetData()
	if ProviderMap[MS.Provider] then
		local res, data =  ProviderMap[MS.Provider].update() 
		if not res then
			var.Set("DisplayLine1", "Update for provider "..MS.Provider.." failed. "..data, SID_AltUI) 
			return false
		end
		-- Get the currently values and update variables they map to.
		local curData = data.currently
		if curData then
			log.Debug("Provider returned %d current variables to update", #curData)
			for _, value in ipairs(curData) do
				local var, val = value[1], value[2]
				if var and val then
					if VariablesMap.currently[var] then
						setvariables(var, VariablesMap.currently[var], val)
					else
						log.Error("Provider tries to update unknown currently variable %s.", var)
					end     
				else
					log.Error("Provider tries to update incomplete currently variable %s.", var or "missing")
				end
			end
			-- If no update time from provider, use now.
			if not curData.LastUpdate then
				var.Set("LastUpdate", os.time())
			end
		else
			log.Error("No currently data")
		end

		-- Get the currently values and update variables they map to.
		local fcData = data.forecast
		if fcData then
			for fd = 1, MS.ForecastDays do
				if fcData[fd] then
					local prefix = ""
					if fd == 1 then
						prefix = "Today"
					elseif fd == 2 then	
						prefix = "Tomorrow"
					else
						prefix = "Forecast."..fd.."."
					end
					local fcDay = fcData[fd]
					if fcDay then
						log.Debug("Provider returned %d forecast variables to update", #fcDay)
						for _, value in ipairs(fcDay) do
							local var, val = value[1], value[2]
							if var and val then
								if VariablesMap.forecast[var] then
									setvariables(var, VariablesMap.forecast[var], val, prefix)
								else
									log.Error("Provider tries to update unknown forecast variable %s.", var)
								end
							else
								log.Error("Provider tries to update incomplete forecast variable %s.", var or "missing")
							end
						end
					end
				else
					log.Warning("No forecast data for day %d from provider.", fd)
				end
			end
		else
			log.Info("No forecast data")
		end

		-- Update display for ALTUI
		displayLine(1)
		displayLine(2)
		return true
	else
		var.Set("DisplayLine1", "No supported provider selected.", SID_AltUI) 
		return false
	end
end

-- check if device configuration parameters are current
local function check_param_updates()
local tvalue

	for key, value in pairs(MS) do
		tvalue = var.Get(key)
		log.Debug("Updateting variable %s value from %s to %s", key, value, tvalue)
		if string.find(static_Vars, "|"..key.."|") and tvalue ~= value then
			-- reset the static device variables to their build-in default in case new version changed these   
			tvalue = ""
		end  
		if tvalue == "" then
			if key == "Latitude" and value == "" then -- new set up, initialize latitude from controller info
				value = var.GetAttribute("latitude", 0)
				MS[key] = value
			end
			if key == "Longitude" and value == "" then -- new set up, initialize longitude from controller info
				value = var.GetAttribute("longitude", 0)
				MS[key] = value
			end
			var.Set(key, value) -- device newly created... need to initialize variables
		else
			-- Convert to numeric if applicable
			local nv = tonumber(tvalue,10)
			tvalue = (nv or tvalue)
			if tvalue ~= value then MS[key] = tvalue end
		end
	end
end

-- poll Weather provider on a periodic basis
-- Plan the polls on the minute value plus little offset.
-- 1 Min poll at 30 sec past the next minute
-- 5 - 30 Min poll at 1 past
-- 1 - 3 hr poll at 5 past
function Weather_delay_callback()
	local lpTS = var.GetNumber("LastPollTS")
	local nextPollTS = 0
	local now = os.time()
	if MS.Period == 60 then
		nextPollTS = now - math.fmod(now, 60) + 90
	elseif MS.Period >= 300 and MS.Period <= 1800 then
		nextPollTS = now - math.fmod(now, MS.Period) + MS.Period + 60
	else 
		nextPollTS = now - math.fmod(now, 3600) + MS.Period + 300
	end
	if nextPollTS > 0 then
		log.Debug("Calculated next poll at %s in %s seconds.", os.date("%Y-%m-%d %X", nextPollTS), nextPollTS - now)
		luup.call_delay ("Weather_delay_callback", nextPollTS - now)
	else
		log.Warning("Could not calculate optimum next poll time. Using set interval of %s seconds.", MS.Period)
		luup.call_delay ("Weather_delay_callback", MS.Period)
	end
	-- See if we are within window due to Luup restart. If so skip to avoid to frequent polls burning API quota.
	if (nextPollTS - lpTS) >= MS.Period then
		var.Set("LastPollTS", now)
		MS_GetData() -- get weather data
	else
		log.Debug("Skipping poll as last poll was %s seconds ago, within interval of %s.", nextPollTS - lpTS, MS.Period)
		-- Update display for ALTUI to reflect change in settings.
		displayLine(1)
		displayLine(2)
	end
end

-- creates/initializes and registers the default Temperature & Humidity children devices
-- and the optional virtual rain sensor child device
local function createchildren()
	local childSensors = var.Get("ChildDev")
	local makeChild = {}
	if childSensors ~= "" then
		log.Debug("Looking to create child sensor devices for %s", childSensors)
		childSensors = childSensors ..","
		-- Look at currently definitions for sensors that can have a child.
 	    for tkey, value in pairs(VariablesMap.currently) do
			for c in childSensors:gmatch("%w,") do			-- looking for individual (uppercase) letters followed by comma.
				c = c:sub(1,1)
				if value.childKey == c then
					makeChild[c] = tkey
					break
				end
			end
		end
	else
		log.Info("No child sensor devices to create.")
	end
	
	local children = luup.chdev.start(this_device)
	for c, tkey in pairs(makeChild) do
		local sensor = VariablesMap.currently[tkey]
		local sensorInfo = SensorInfo[c]
		log.Debug("Adding sensor type %s for %s", c, tkey)
		-- Make unique altid so we can handle multiple plugins installed
		local altid = "MSW"..c..this_device
		local name = "MSW-"..(sensorInfo.name or sensor.variable)
		local vartable = {
			SID_HA..",HideDeleteButton=1",
			sensorInfo.serviceId..","..sensorInfo.variable.."=0"
		}
		-- Add icon var to variables if set
		if sensorInfo.icon then
			table.insert(vartable, SID_Weather..",IconSet="..sensorInfo.icon)
		end
		-- Set specific JSON attribute (for UV Index device)
		if sensorInfo.deviceJSON then	
			table.insert(vartable, ",device_json="..sensorInfo.deviceJSON)
		end

		log.Debug("Child device id " .. altid .. " (" .. name .. ")")
		luup.chdev.append(
			this_device, 						-- parent (this device)
			children, 							-- pointer from above "start" call
			altid,								-- child Alt ID
			name,								-- child device description 
			"", 								-- serviceId (keep blank for UI7 restart avoidance)
			sensorInfo.deviceXML,				-- device file for given device
			"",									-- Implementation file
			table.concat(vartable,"\n"),		-- parameters to set 
			embed,								-- child devices can go in any room or not
			false)								-- child devices is not hidden
	end
	luup.chdev.sync(this_device, children)
			
	-- When all child sensors are there, configure them
	for deviceNo, d in pairs (luup.devices) do	-- pick up the child device numbers from their IDs
		if d.device_num_parent == this_device then
			local c = string.sub(d.id,4,4)	-- childKey is in altid
			local tkey = makeChild[string.sub(d.id,4,4)]
			if tkey then
				local sensor = VariablesMap.currently[tkey]
				sensor.childID = deviceNo
			end
		end
	end	
end

-- Update the log level.
function MS_SetLogLevel(logLevel)
	local level = tonumber(logLevel,10) or 1
	var.Set("LogLevel", level)
	log.Update(level)
end

-- device init sequence, called from the device implementation file
function init(lul_device)
	this_device = lul_device
	json = jsonAPI()
	log = logAPI()
	var = varAPI()
	utils = utilsAPI()
	json.Initialize()
	var.Initialize(SID_Weather, this_device)
	var.Default("LogLevel", 1)
	log.Initialize(ABOUT.NAME, var.GetNumber("LogLevel"), (utils.GetUI() == utils.IsOpenLuup or utils.GetUI() == utils.IsUI5))
	log.Info("device startup")
	check_param_updates()
	createchildren(this_device)
	-- See if user disabled plug-in 
	if var.GetAttribute("disabled") == 1 then
		log.Warning("Init: Plug-in version - DISABLED")
		var.Set("DisplayLine2", "Disabled. ", SID_AltUI)
		-- Still create any child devices so we do not loose configurations.
		utils.SetLuupFailure(0, PlugIn.THIS_DEVICE)
		return true, "Plug-in disabled attribute set", ABOUT.NAME
	end
	var.Default("StationList", "{}")
	var.Default("LastPollTS", 0)
	if MS.Provider > 0 then
		if ProviderMap[MS.Provider].init() then
			local curMsg = var.Get("DisplayLine1", SID_AltUI)
			if curMsg == "Complete settings first." then
				var.Set("DisplayLine1", "Waiting for first update...", SID_AltUI)
			end
			luup.call_delay ("Weather_delay_callback", 10)
			log.Info("device started")
			luup.set_failure (0)                        -- all's well with the world
			return true, "OK", ABOUT.NAME
		else
			var.Set("DisplayLine1", "Setup failed.", SID_AltUI)
			log.Error("Provider Init function failed.")
			luup.set_failure (2)                        -- say it's an authentication error
			return false, "Initialization failed", ABOUT.NAME
		end
	else
		var.Set("DisplayLine1", "Complete settings first.", SID_AltUI)
		log.Error("Provider is not yet selected.")
		luup.set_failure (2)                        -- say it's an authentication error
		return false, "No provider selected", ABOUT.NAME
	end
end
