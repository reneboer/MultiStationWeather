# MultiStationWeather
Vera and openLuup plugin to get weather data from your favourite Weather Station. This can be used as replacement for the DarkSky weather plugin as Apple decided to stop with that service end 2021.

Currently supported weather stations: 
- DarkSky
- Wunder Ground
- Accu Weather
- Open Weather
- Ambient Weather
- Buien radar (Dutch weathr only)

Additional sugestions are welcome, but you will need to help with testing.

For the icons and the Icon variable to the values from [The Weather Company](https://docs.google.com/document/d/1qpc4QN3YDpGDGGNYVINh7tfeulcZ4fxPSC5f4KzpR_U) are used. You can use the Icon variable as indication of teh current weather type (clear, rain, etc.).

## Settings
First select the Weather provider you want to use and if needed have an access key for. Selecting the weather provider will display all settings relevant.

* Latitude, longitude: For most you have to provide the latitude, longitude for the location you want to weather of. This will default to the location set for your Vera.
* Forecast days: If the weather provider includes forcast data, select the number of days to include in the forecast. Day one (1) is today.
* Update interval: Select the interval to request updates. Note that some providers have a limit on the number of requests per day/week/month.

### DarkSky
Home Page : www.darksky.net
You will need an API key. This can no longer be obtained and is only included for backward compatibility.

