# MultiStationWeather
Vera and openLuup plugin to get weather data from your favourite Weather Station. This can be used as replacement for the DarkSky weather plugin as Apple decided to stop with that service end 2021.

Currently supported weather stations: 
- DarkSky
- Wunder Ground
- Accu Weather
- Open Weather
- Ambient Weather
- Buienradar (the Netherlands only)

Additional suggestions are welcome, but you will need to help with testing.

For the icons and the Icon variable to the values from [The Weather Company](https://docs.google.com/document/d/1qpc4QN3YDpGDGGNYVINh7tfeulcZ4fxPSC5f4KzpR_U) are used. You can use the Icon variable as indication of the current weather type (clear, rain, etc.). Note that the Icon variable values are different than in the DarkSky plugin.

## Installation
Install the plugin from either the ALTUI AppStore or from the Mios App Market.

For openLuup it is recommended to install cjson (luarocks install lua-cjson) and zlib (sudo apt-get install lua-zlib). This will give some better performance on the, sometimes, large sets of data returned.

## Settings
First select the Weather provider you want to use and if needed have an access key for. Selecting the weather provider will display all settings relevant.

* Latitude, longitude: For most you have to provide the latitude, longitude for the location you want to weather of. This will default to the location set for your Vera.
* Forecast days: if the weather provider includes forecast data, select the number of days to include in the forecast. Day one (1) is today.
* Update interval: select the interval to request updates. Note that some providers have a limit on the number of requests per day/week/month. The minimal interval value will avoid over requesting as long as this is the only use of your key.
* Units: the units to report in. Most providers support Metric or Imperial.
* Language: the language to report in when supported.
* Display Line 1/2: select the values you want to show on in the main device window.
* Child devices: you can create child devices to show different values in a separate device. These you can then use in scenes, Reactor etc.
* Log level: control the level of details that get written to the Vera Log file. Leave at Error unless you need to find out why things are not working as expected.

### DarkSky
Home Page : www.darksky.net
You will need an API key. This can no longer be obtained and is only included for backward compatibility with the DarkSky plugin.

**Current Weather Variables included**: CurrentApparentTemperature, CurrentCloudCover, CurrentDewPoint, CurrentHumidity, Icon, CurrentOzone, CurrentuvIndex, CurrentVisibility, CurrentPrecipIntensity,	CurrentPrecipProbability, CurrentPrecipType, CurrentPressure, CurrentConditions, CurrentTemperature, LastUpdate, CurrentWindBearing, CurrentWindSpeed, CurrentWindGust, CurrentSunset, CurrentSunrise

**Forecast Weather Variables included**: Pressure, Conditions, Ozone, uvIndex, Visibility, PrecipIntensity, PrecipIntensityMax, PrecipProbability, PrecipType, MaxTemp, MinTemp, HighTemp, LowTemp, ApparentMaxTemp, ApparentMinTemp, Icon, CloudCover, DewPoint, Humidity, WindBearing, WindSpeed, WindGust, Sunset, Sunrise

### Weather Underground
Home page : www.wunderground.com
There are no free keys for Wunder ground. However, they work with many suppliers of Personal Weather Stations (PWS). So, if you have a PWS you could apply for a Wunder ground key and use the data from you own PWS for the current weather conditions. See https://www.wunderground.com/pws/overview for more details.
* Provider Key: The key you got from WunderGround
* Station name: The name of the station to use for the current weather, ideally your own station.
The forecast data is refreshed only 5 past each hour even if the update interval is set quicker.

**Current Weather Variables included**: CurrentApparentTemperature, CurrentDewPoint, CurrentHumidity, Icon, CurrentuvIndex, CurrentPrecipIntensity,	CurrentPressure, CurrentTemperature, LastUpdate, CurrentWindBearing, CurrentWindSpeed, CurrentWindGust

**Forecast Weather Variables included**: Conditions, uvIndex, PrecipIntensity, PrecipProbability, PrecipType, MaxTemp, MinTemp, ApparentMaxTemp, ApparentMinTemp, Icon, CloudCover, DewPoint, Humidity, WindBearing, WindSpeed, Sunrise, Sunset

### OpenWeather
Home page : www.openweathermap.org
This is a good replacement for DarkSky. You can get a free provider key that allows for 1M requests per month, more than sufficient for this use.
Note that the Standard units will report the temperature in Kelvin, so you probably want to make sure to select Metric or Imperial.

**Current Weather Variables included**: CurrentApparentTemperature, CurrentCloudCover, CurrentDewPoint, CurrentHumidity, Icon, CurrentuvIndex, CurrentVisibility, CurrentPrecipIntensity,	CurrentPrecipType, CurrentPressure, CurrentConditions, CurrentTemperature, LastUpdate, CurrentWindBearing, CurrentWindSpeed, CurrentWindGust, CurrentOzone, CurrentAirQuality, CurrentCO, CurrentNO, CurrentNO2, CurrentSO2, CurrentNH3, CurrentPM25, CurrentPM10, CurrentSunrise, CurrentSunset.

**Forecast Weather Variables included**: Pressure, Conditions, uvIndex, Visibility, PrecipIntensity, PrecipProbability, PrecipType, MaxTemp, MinTemp, HighTemp, LowTemp, ApparentMaxTemp, ApparentMinTemp, Icon, CloudCover, DewPoint, Humidity, WindBearing, WindSpeed, WindGust, Sunrise, Sunset

### Accu Weather
Home page : www.accuweather.com
You can register for a free Provider key at https://developer.accuweather.com/apis. Do note that the free API only allows for 50 requests per day, that is one per 30 minutes max. However, to get the forecast data a second request is required. Because of this the forecast data only gets updated at 6AM (6:00) and 6PM (18:00).
In the Settings you see the Station name. If this is not populated, a look up will be done for the best station based on the latitude/longitude values. When you want to report on a different location, you must empty the Station Name value.

**Current Weather Variables included**: CurrentApparentTemperature, CurrentCloudCover, CurrentDewPoint, CurrentHumidity, Icon, CurrentuvIndex, CurrentVisibility, CurrentPrecipIntensity,	CurrentPrecipType, CurrentPressure, CurrentConditions, CurrentTemperature, LastUpdate, CurrentWindBearing, CurrentWindSpeed, CurrentWindGust

**Forecast Weather Variables included**: Conditions, PrecipIntensity, PrecipIntensityMax, PrecipProbability, PrecipType, MaxTemp, MinTemp, ApparentMaxTemp, ApparentMinTemp, Icon, CloudCover, WindBearing, WindSpeed, WindGust, Sunrise, Sunset

### Ambient Weather
Home Page : www.ambientweather.net
You can register for an Provider and application key if you have a Personal Weather Station. This API allows for very frequent updates. On the negative, there is no support for icons and no forecast data.
If you have multiple PWS on your account, you can select the station in the settings.

**Current Weather Variables included**: CurrentApparentTemperature, CurrentDewPoint, CurrentHumidity, CurrentuvIndex, CurrentPrecipIntensity,	CurrentPressure, CurrentTemperature, LastUpdate, CurrentWindBearing, CurrentWindSpeed, CurrentWindGust

**Forecast Weather Variables included**: No forecast included.

### Buienradar (the Netherlands only)
Home page : www.buienradar.nl
This is a Dutch weather provider for local weater and forecasts. There is no need for registration. Initially only Station Name De Bilt will be in the settings. After the first refresh you can select a station closer to your desired location.

**Current Weather Variables included**: CurrentApparentTemperature, CurrentHumidity, Icon, CurrentuvIndex, CurrentVisibility, CurrentPrecipIntensity,	CurrentPressure, CurrentConditions, CurrentTemperature, LastUpdate, CurrentWindBearing, CurrentWindSpeed, CurrentWindGust

**Forecast Weather Variables included**: Conditions, PrecipIntensity, PrecipIntensityMax, PrecipProbability, MaxTemp, MinTemp, WindSpeed, SunProbability

### KNMI (the Netherlands only)
Home page : www.weerlive.nl
This is the Dutch national weather provider for local weater and forecasts. You have to apply for an API key. The number of returned parameters is fairly limited and there is only today ant tomorrow for forecast.

**Current Weather Variables included**: CurrentApparentTemperature, CurrentHumidity, Icon, CurrentuvIndex, CurrentVisibility, CurrentPrecipIntensity,	CurrentPressure, CurrentConditions, CurrentTemperature, LastUpdate, CurrentWindBearing, CurrentWindSpeed, CurrentWindGust

**Forecast Weather Variables included**: Conditions, PrecipIntensity, PrecipIntensityMax, PrecipProbability, MaxTemp, MinTemp, WindSpeed, SunProbability
