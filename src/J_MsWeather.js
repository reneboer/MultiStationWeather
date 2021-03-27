//# sourceURL=J_MsWeather.js
/* 
	MsWeather Hub Control UI
	Written by R.Boer. 
	V1.0 27 March 2021
*/
var MsWeather = (function (api) {

	// Constants. Keep in sync with LUA code.
    var _uuid = '12021512-0000-a0a0-b0b0-c0c030303032';
	var SID_Weather = "urn:upnp-rboer-com:serviceId:Weather1";
	var SID_ALTUI = "urn:upnp-org:serviceId:altui1";
	var DIV_PREFIX = "rbMsWeather_";	// Used in HTML div IDs to make them unique for this module
	var MOD_PREFIX = "MsWeather";  		// Must match module name above
	var bOnALTUI = false;
	var providersConf = [				// Provider configurations.
		{ id:1, name:'DarkSky', active:true, key:true, appkey:false, latlon:true, station:false, fcDays:7, units:['auto','si','us','ca','uk2'], language:true, childTypes:'TDHPAOUVWR', displayTypes:[1,2,3,4,5,6,7,8,9,10], period:[300,3600] },
		{ id:2, name:'Weather Underground', active:true, key:true, appkey:false, latlon:true, station:true, fcDays:7, units:['e','m','s','h'], language:true, childTypes:'TDHPAOUVWR', displayTypes:[2,3,4,5,6,7,8,9,10],period:[60,3600] },
		{ id:3, name:'OpenWeather', active:true, key:true, appkey:false, latlon:true, station:false, fcDays:7, units:['metric','imperial','standard'], language:true, childTypes:'TDHOPAUWRQX', displayTypes:[1,2,3,4,5,6,7,8,9,10,11,12],period:[60,3600] },
		{ id:4, name:'Accu Weather', active:true, key:true, appkey:false, latlon:true, station:true, fcDays:7, units:['e','m','h'], language:true, childTypes:'TAUWR', displayTypes:[1,3,4,6,7,8,9],period:[1800,3600,7200] },
		{ id:5, name:'AmbientWeather', active:true, key:true, appkey:true, latlon:false, station:'StationList,0,Device 1', fcDays:7, units:['imperial'], language:false, childTypes:'TDHPAUWR', displayTypes:[2,3,4,6,7,10],period:[10,3600] },
		{ id:6, name:'PWS Weather', active:false, key:true, appkey:true, latlon:false, station:'StationList,0,Device 1', fcDays:7, units:['imperial'], language:false, childTypes:'TDHPAUWR', displayTypes:[2,3,4,6,7,10],period:[10,3600] },
		{ id:312, name:'Buienradar (NL)', active:true, key:false, appkey:false, latlon:false, station:'StationList,6260,Meetstation De Bilt', fcDays:5, units:false, language:false, childTypes:'THPAUV', displayTypes:[1,2,3,4,6,7],period:[60,3600] }
	];
	var forecastOptions = [{v:0,l:'No forecast'},{v:1,l:'One day'},{v:2,l:'Two days'},{v:3,l:'Three days'},{v:4,l:'Four days'},{v:5,l:'Five days'},{v:6,l:'Six days'},{v:7,l:'Seven days'}];
	var periodOptions = [{v:60,l:'1 minute'},{v:300,l:'5 minutes'},{v:900,l:'15 minutes'},{v:1800,l:'30 minutes'},{v:3600,l:'1 hour'},{v:7200,l:'2 hours'},{v:10800,l:'3 hours'}];
	var childDeviceOptions = [{v:'T',l:'Temperature'},{v:'D',l:'Dewpoint'},{v:'H',l:'Humidity'},{v:'P',l:'Pressure'},{v:'A',l:'Apparent Temperature'},{v:'O',l:'Ozone'},{v:'U',l:'UV Index'},{v:'V',l:'Visibility'},{v:'W',l:'Wind Data'},{v:'R',l:'Percipipation Data'},{v:'Q',l:'Air Quality'},{v:'X',l:'Air Quality Details'}];
	var displayOptions = [{v:1,l:'Current Conditions'},{v:2,l:'Current Pressure'},{v:3,l:'Last Update'},{v:4,l:'Wind Speed, Gust and Bearing'},{v:5,l:'Ozone and UV Index'},{v:6,l:'Current Temperature'},{v:7,l:'Apparent Temperature'},{v:8,l:'Current Cloud Cover'},{v:9,l:'Percipipation Type, Probability and Intensity'},{v:10,l:'Humidity and Dew Point'},{v:11,l:'Air Quality'},{v:12,l:'Air Quality Details'}];
	var unitOptions = [{v:'auto',l:'Auto'},{v:'si',l:'System International'},{v:'us',l:'Imperial'},{v:'ca',l:'Canadian'},{v:'uk2',l:'British'},{v:'standard',l:'Standard'},{v:'metric',l:'Metric'},{v:'imperial',l:'Imperial'},{v:'s',l:'System International'},{v:'e',l:'Imperial'},{v:'m',l:'Metric'},{v:'h',l:'British'}];
	var languageOptions = [{v:'ar',l:'Arabic'},{v:'bg',l:'Bulgarian'},{v:'bn',l:'Bengali'},{v:'bs',l:'Bosnian'},{v:'cs',l:'Czech'},{v:'da',l:'Danish'},{v:'nl',l:'Dutch'},{v:'de',l:'German'},{v:'el',l:'Greek'},{v:'en',l:'English'},{v:'es',l:'Spanish'},{v:'et',l:'Estonian'},{v:'fi',l:'Finnish'},{v:'fr',l:'French'},{v:'he',l:'Hebrew'},{v:'hi',l:'Hindi'},{v:'hr',l:'Croatian'},{v:'hu',l:'Hungarian'},{v:'id',l:'Indonesian'},{v:'is',l:'Icelandic'},{v:'it',l:'Italian'},{v:'ja',l:'Japanese'},{v:'ko',l:'Korean'},{v:'lv',l:'Latvian'},{v:'no',l:'Norwegian'},{v:'pa',l:'Punjabi'},{v:'pl',l:'Polish'},{v:'pt',l:'Portuguese'},{v:'ro',l:'Romanian'},{v:'ru',l:'Russian'},{v:'sk',l:'Slovak'},{v:'sl',l:'Slovenian'},{v:'sr',l:'Serbian'},{v:'sv',l:'Swedish'},{v:'tr',l:'Turkish'},{v:'uk',l:'Ukrainian'}];

	// Forward declaration.
    var myModule = {};

    function _onBeforeCpanelClose(args) {
		showBusy(false);
        // do some cleanup...
        console.log(MOD_PREFIX+', handler for before cpanel close');
    }

    function _init() {
        // register to events...
        api.registerEventHandler('on_ui_cpanel_before_close', myModule, 'onBeforeCpanelClose');
		// See if we are on ALTUI
		if (typeof ALTUI_revision=="string") {
			bOnALTUI = true;
		}
    }
	
	// Return HTML for settings tab
	function _Settings() {
		_init();
        try {
			var deviceID = api.getCpanelDeviceId();
			var deviceObj = api.getDeviceObject(deviceID);
			var providerMap = [{'value':0,'label':'Please select...'}];
			var timeUpd = [{'value':0,'label':'Please select...'}];
			var forecastMap = [{'value':0,'label':'No forecast'}];
			var displayMap = [{'value':0,'label':'Please select...'}];
			var stationMap = [{'value':0,'label':'Please select...'}];
			var childDevMap = [{'value':'zz','label':'Please select...'}];
			var unitMap = [{'value':'','label':'Please select...'}];
			var languageMap = [{'value':'en','label':'English'}];
			var logLevel = [{'value':'1','label':'Error'},{'value':'2','label':'Warning'},{'value':'8','label':'Info'},{'value':'11','label':'Debug'}];
			

			var html = '<div class="deviceCpanelSettingsPage">'+
				'<h3>Device #'+deviceID+'&nbsp;&nbsp;&nbsp;'+api.getDisplayedDeviceName(deviceID)+'</h3>';
			if (deviceObj.disabled === '1' || deviceObj.disabled === 1) {
				html += '<br>Plugin is disabled in Attributes.'+
				'</div>';
				api.setCpanelContent(html);
			} else {
				var i = 0;
				var curPrv = parseInt(varGet(deviceID, 'Provider'));
				for(i=0;i<providersConf.length;i++){
					if (providersConf[i].active) {
						providerMap.push({'value':providersConf[i].id, 'label':providersConf[i].name});
					}
				}
				html +=	htmlAddPulldown(deviceID, 'Weather Provider', 'Provider', providerMap)+
				'<div id="'+DIV_PREFIX+deviceID+'div_key" style="display:none" >'+
				htmlAddInput(deviceID, 'Provider Key', 70, 'Key') + 
				'</div>'+
				'<div id="'+DIV_PREFIX+deviceID+'div_appkey" style="display:none" >'+
				htmlAddInput(deviceID, 'Application Key', 70, 'ApplicationKey') + 
				'</div>'+
				'<div id="'+DIV_PREFIX+deviceID+'div_latlon" style="display:none" >'+
				htmlAddInput(deviceID, 'Location Latitude', 10, 'Latitude')+
				htmlAddInput(deviceID, 'Location Longitude', 10, 'Longitude')+
				'</div>'+
				'<div id="'+DIV_PREFIX+deviceID+'div_station_i" style="display:none" >'+
				htmlAddPulldown(deviceID, 'Station Name', 'StationID', stationMap)+
				'</div>'+
				'<div id="'+DIV_PREFIX+deviceID+'div_station_n" style="display:none" >'+
				htmlAddInput(deviceID, 'Station Name', 10, 'StationName')+
				'</div>'+
				'<div id="'+DIV_PREFIX+deviceID+'div_language" style="display:none" >'+
				htmlAddPulldown(deviceID, 'Language', 'Language', languageMap)+
				'</div>'+
				'<div id="'+DIV_PREFIX+deviceID+'div_units" style="display:none" >'+
				htmlAddPulldown(deviceID, 'Units', 'Units', unitMap)+
				'</div>'+
				htmlAddPulldown(deviceID, 'Forecast days', 'ForecastDays', forecastMap)+
				htmlAddPulldown(deviceID, 'Update Interval', 'Period', timeUpd)+
				htmlAddPulldown(deviceID, 'Display line 1', 'DispLine1', displayMap)+
				htmlAddPulldown(deviceID, 'Display line 2', 'DispLine2', displayMap)+
				htmlAddPulldownMultiple(deviceID, 'Child devices', 'ChildDev', childDevMap)+
				htmlAddPulldown(deviceID, 'Log level', 'LogLevel', logLevel)+
				htmlAddButton(deviceID, 'Save Settings', 'UpdateSettings')+
				'</div>'+
				'<script>'+
				' $("#'+DIV_PREFIX+'Provider'+deviceID+'").change(function() {'+
				' '+MOD_PREFIX+'.UpdateDisplay('+deviceID+',parseInt($(this).val()));'+
				' } );'+
				'</script>';

				api.setCpanelContent(html);
				_UpdateDisplay(deviceID, curPrv);
			}
        } catch (e) {
            Utils.logError('Error in '+MOD_PREFIX+'.Settings(): ' + e);
        }
	}
	function _UpdateDisplay(deviceID, prv) {
		// Update the selections based on provider selected
		var i;
		var pl = providersConf.length;
		var provCnf = null;
		for(i=0;i<pl;i++){
			if (providersConf[i].id == prv) {
				provCnf = providersConf[i];
				break;
			}
		}
		if (provCnf !== null) {
			// Hide settings provider does not need
			if (provCnf.key === false) { $('#'+DIV_PREFIX+deviceID+"div_key").fadeOut(); }
			if (provCnf.appkey === false) { $('#'+DIV_PREFIX+deviceID+"div_appkey").fadeOut(); }
			if (provCnf.latlon === false) { $('#'+DIV_PREFIX+deviceID+"div_latlon").fadeOut(); }
			if (provCnf.units === false) { $('#'+DIV_PREFIX+deviceID+"div_units").fadeOut(); }
			if (provCnf.language === false) { $('#'+DIV_PREFIX+deviceID+"div_language").fadeOut(); }
			if (provCnf.station === false) { 
				$('#'+DIV_PREFIX+deviceID+"div_station_n").fadeOut(); 
				$('#'+DIV_PREFIX+deviceID+"div_station_i").fadeOut(); 
			}
			
			// Build forecast days list
			var fcMap = [];
			var ll = provCnf.fcDays;
			for(i=0;i<=ll;i++){
				fcMap.push({value:forecastOptions[i].v, text:forecastOptions[i].l});
			}
			var cfc = varGet(deviceID, 'ForecastDays');
			var $fcl = $('#'+DIV_PREFIX+'ForecastDays'+deviceID);
			$fcl.empty();
			$.each(fcMap, function(index,options) {
				$fcl.append($("<option></option>")
					.attr("value", options.value)
					.prop("selected", (options.value==cfc))
					.text(options.text));
			});
			// Build update frequency list
			var tuMap = [];
			ll = periodOptions.length;
			for(i=0;i<ll;i++){
				if (periodOptions[i].v >= provCnf.period[0] && periodOptions[i].v <= provCnf.period[1]) {
					tuMap.push({value:periodOptions[i].v, text:periodOptions[i].l});
				}	
			}
			var ctu = varGet(deviceID, 'Period');
			var $tul = $('#'+DIV_PREFIX+'Period'+deviceID);
			$tul.empty();
			$.each(tuMap, function(index,options) {
				$tul.append($("<option></option>")
					.attr("value", options.value)
					.prop("selected", (options.value==ctu))
					.text(options.text));
			});
			// Build child devices list
			var cdMap = [];
			ll = childDeviceOptions.length;
			for(i=0;i<ll;i++){
				if (provCnf.childTypes.includes(childDeviceOptions[i].v)) {
					cdMap.push({value:childDeviceOptions[i].v, text:childDeviceOptions[i].l});
				}	
			}
			var ccd = varGet(deviceID, 'ChildDev');
			var $cdl = $('#'+DIV_PREFIX+'ChildDev'+deviceID);
			$cdl.attr("size", cdMap.length);
			$cdl.empty();
			$.each(cdMap, function(index,options) {
				$cdl.append($("<option></option>")
					.attr("value", options.value)
					.prop("selected", (ccd.includes(options.value)))
					.text(options.text));
			});
			// Build diplay line list
			var dlMap = [];
			ll = displayOptions.length;
			for(i=0;i<ll;i++){
				if (provCnf.displayTypes.includes(displayOptions[i].v)) {
					dlMap.push({value:displayOptions[i].v, text:displayOptions[i].l});
				}	
			}
			var cdl1 = varGet(deviceID, 'DispLine1');
			var $dl1l = $('#'+DIV_PREFIX+'DispLine1'+deviceID);
			$dl1l.empty();
			$.each(dlMap, function(index,options) {
				$dl1l.append($("<option></option>")
					.attr("value", options.value)
					.prop("selected", (options.value==cdl1))
					.text(options.text));
			});
			var cdl2 = varGet(deviceID, 'DispLine2');
			var $dl2l = $('#'+DIV_PREFIX+'DispLine2'+deviceID);
			$dl2l.empty();
			$.each(dlMap, function(index,options) {
				$dl2l.append($("<option></option>")
					.attr("value", options.value)
					.prop("selected", (options.value==cdl2))
					.text(options.text));
			});
			if (provCnf.units !== false) {
				// Build forecast days list
				var unMap = [];
				ll = unitOptions.length;
				for(i=0;i<ll;i++){
					if (provCnf.units.includes(unitOptions[i].v)) {
						unMap.push({value:unitOptions[i].v, text:unitOptions[i].l});
					}
				}
				var cun = varGet(deviceID, 'Units');
				var $unl = $('#'+DIV_PREFIX+'Units'+deviceID);
				$unl.empty();
				$.each(unMap, function(index,options) {
					$unl.append($("<option></option>")
						.attr("value", options.value)
						.prop("selected", (options.value==cun))
						.text(options.text));
				});
			}
			if (provCnf.language !== false) {
				// Build forecast days list
				var lgMap = [];
				ll = languageOptions.length;
				for(i=0;i<ll;i++){
					if (true == provCnf.language || provCnf.language.includes(languageOptions[i].v)) {
						lgMap.push({value:languageOptions[i].v, text:languageOptions[i].l});
					}
				}
				var clg = varGet(deviceID, 'Language');
				var $lgl = $('#'+DIV_PREFIX+'Language'+deviceID);
				$lgl.empty();
				$.each(lgMap, function(index,options) {
					$lgl.append($("<option></option>")
						.attr("value", options.value)
						.prop("selected", (options.value==clg))
						.text(options.text));
				});
			}
			if (typeof(provCnf.station) === "string") {
				// Build station names list
				var st = provCnf.station.split(",");
				var stationList = varGet(deviceID, st[0]);
				stationList = JSON.parse(stationList);
				var stMap = [];
				ll = stationList.length;
				if (ll > 0) {
					for(i=0;i<ll;i++){
						stMap.push({value:stationList[i].v, text:stationList[i].l});
					}
				} else {
					stMap.push({value:st[1], text:st[2]});
				}
				var cst = varGet(deviceID, 'StationID');
				var $stl = $('#'+DIV_PREFIX+'StationID'+deviceID);
				$stl.empty();
				$.each(stMap, function(index,options) {
					$stl.append($("<option></option>")
						.attr("value", options.value)
						.prop("selected", (options.value==cst))
						.text(options.text));
				});
			}
			// Show setting fields provider needs
			if (provCnf.key) { $('#'+DIV_PREFIX+deviceID+"div_key").fadeIn(); }
			if (provCnf.appkey) { $('#'+DIV_PREFIX+deviceID+"div_appkey").fadeIn(); }
			if (provCnf.latlon) { $('#'+DIV_PREFIX+deviceID+"div_latlon").fadeIn(); }
			if (provCnf.units !== false) { $('#'+DIV_PREFIX+deviceID+"div_units").fadeIn(); }
			if (provCnf.language !== false) { $('#'+DIV_PREFIX+deviceID+"div_language").fadeIn(); }
			if (provCnf.station !== false) { 
				if (typeof(provCnf.station) === "string") {
					$('#'+DIV_PREFIX+deviceID+"div_station_i").fadeIn(); 
					$('#'+DIV_PREFIX+deviceID+"div_station_n").fadeOut(); 
				} else {
					$('#'+DIV_PREFIX+deviceID+"div_station_n").fadeIn(); 
					$('#'+DIV_PREFIX+deviceID+"div_station_i").fadeOut(); 
				}
			}
		} else {
			// No provider selected, hide fields.
			$('#'+DIV_PREFIX+deviceID+"div_key").fadeOut();
			$('#'+DIV_PREFIX+deviceID+"div_appkey").fadeOut();
			$('#'+DIV_PREFIX+deviceID+"div_latlon").fadeOut();
			$('#'+DIV_PREFIX+deviceID+"div_units").fadeOut();
			$('#'+DIV_PREFIX+deviceID+"div_language").fadeOut();
			$('#'+DIV_PREFIX+deviceID+"div_station_n").fadeOut(); 
			$('#'+DIV_PREFIX+deviceID+"div_station_i").fadeOut(); 
		}
	}
	function _UpdateSettings(deviceID) {
		// Save variable values and trigger reload
		showBusy(true);
		var prv = htmlGetPulldownSelection(deviceID, 'Provider');
		var i;
		var pl = providersConf.length;
		var provCnf = null;
		prv = parseInt(prv);
		for(i=0;i<pl;i++){
			var provCnf = providersConf[i];
			if (providersConf[i].id === prv) {
				provCnf = providersConf[i];
				break;
			}
		}
		varSet(deviceID,'Provider',prv);
		varSet(deviceID,'Key',htmlGetElemVal(deviceID, 'Key'));
		varSet(deviceID,'ApplicationKey',htmlGetElemVal(deviceID, 'ApplicationKey'));
		varSet(deviceID,'Latitude',htmlGetElemVal(deviceID, 'Latitude'));
		varSet(deviceID,'Longitude',htmlGetElemVal(deviceID, 'Longitude'));
		if (provCnf !== null) {
			if (typeof(provCnf.station) === "string") {
				varSet(deviceID,'StationID',htmlGetPulldownSelection(deviceID, 'StationID'));
			} else {
				varSet(deviceID,'StationName',htmlGetElemVal(deviceID, 'StationName'));
			}
		}
		varSet(deviceID,'Period',htmlGetPulldownSelection(deviceID, 'Period'));
		varSet(deviceID,'Language',htmlGetPulldownSelection(deviceID, 'Language'));
		varSet(deviceID,'Units',htmlGetPulldownSelection(deviceID, 'Units'));
		varSet(deviceID,'ForecastDays',htmlGetPulldownSelection(deviceID, 'ForecastDays'));
		varSet(deviceID,'DispLine1',htmlGetPulldownSelection(deviceID, 'DispLine1'));
		varSet(deviceID,'DispLine2',htmlGetPulldownSelection(deviceID, 'DispLine2'));
		var chDev = htmlGetPulldownSelection(deviceID, 'ChildDev');
		varSet(deviceID,'ChildDev',(typeof chDev === 'object')?chDev.join():chDev);
		varSet(deviceID,'LogLevel',htmlGetPulldownSelection(deviceID, 'LogLevel'));
		varSet(deviceID,'DisplayLine1','Waiting for Luup reload', SID_ALTUI);
		application.sendCommandSaveUserData(true);
		setTimeout(function() {
			doReload(deviceID);
			showBusy(false);
			try {
				api.ui.showMessagePopup(Utils.getLangString("ui7_device_cpanel_details_saved_success","Device details saved successfully."),0);
			}
			catch (e) {
				Utils.logError(MOD_PREFIX+': UpdateSettings(): ' + e);
			}
		}, 3000);	
	}

	// Generic HTML wrapper functions.
	// Standard update for plug-in pull down variable. We can handle multiple selections.
	function htmlGetPulldownSelection(di, vr) {
		var value = $('#'+DIV_PREFIX+vr+di).val() || [];
		return (typeof value === 'object')?value.join():value;
	}
	// Get the value of an HTML input field
	function htmlGetElemVal(di,elID) {
		var res;
		try {
			res=$('#'+DIV_PREFIX+elID+di).val();
		}
		catch (e) {	
			res = '';
		}
		return res;
	}
	// Add a standard input for a plug-in variable.
	function htmlAddInput(di, lb, si, vr, sid, df) {
		var val = (typeof df != 'undefined') ? df : varGet(di,vr,sid);
		var html = '<div id="'+DIV_PREFIX+vr+di+'_div" class="clearfix labelInputContainer" >'+
					'<div class="pull-left inputLabel '+((bOnALTUI)?'form-control form-control-sm form-control-plaintext':'')+'" style="width:280px;">'+lb+'</div>'+
					'<div class="pull-left">'+
						'<input class="customInput '+((bOnALTUI)?'altui-ui-input form-control form-control-sm':'')+'" size="'+si+'" id="'+DIV_PREFIX+vr+di+'" type="text" style="width:280px;" value="'+val+'">'+
					'</div>'+
				'</div>';
		return html;
	}
	// Add a standard input for password a plug-in variable.
	function htmlAddPwdInput(di, lb, si, vr, sid, df) {
		var val = (typeof df != 'undefined') ? df : varGet(di,vr,sid);
		var html = '<div id="'+DIV_PREFIX+vr+di+'_div" class="clearfix labelInputContainer" >'+
					'<div class="pull-left inputLabel '+((bOnALTUI)?'form-control form-control-sm form-control-plaintext':'')+'" style="width:280px;">'+lb+'</div>'+
					'<div class="pull-left">'+
						'<input class="customInput '+((bOnALTUI)?'altui-ui-input form-control form-control-sm':'')+'" size="'+si+'" id="'+DIV_PREFIX+vr+di+'" type="text" value="'+val+'">'+
					'</div>'+
				'</div>';
		html += '<div class="clearfix labelInputContainer '+((bOnALTUI)?'form-control form-control-sm form-control-plaintext':'')+'">'+
					'<div class="pull-left inputLabel" style="width:280px;">&nbsp; </div>'+
					'<div class="pull-left '+((bOnALTUI)?'form-check':'')+'" style="width:280px;">'+
						'<input class="pull-left customCheckbox '+((bOnALTUI)?'form-check-input':'')+'" type="checkbox" id="'+DIV_PREFIX+vr+di+'Checkbox">'+
						'<label class="labelForCustomCheckbox '+((bOnALTUI)?'form-check-label':'')+'" for="'+DIV_PREFIX+vr+di+'Checkbox">Show Password</label>'+
					'</div>'+
				'</div>';
		html += '<script type="text/javascript">'+
					'$("#'+DIV_PREFIX+vr+di+'Checkbox").on("change", function() {'+
					' var typ = (this.checked) ? "text" : "password" ; '+
					' $("#'+DIV_PREFIX+vr+di+'").prop("type", typ);'+
					'});'+
				'</script>';
		return html;
	}
	// Add a Save Settings button
	function htmlAddButton(di, lb, cb) {
		html = '<div class="cpanelSaveBtnContainer labelInputContainer clearfix">'+	
			'<input class="vBtn pull-right btn" type="button" value="'+lb+'" onclick="'+MOD_PREFIX+'.'+cb+'(\''+di+'\');"></input>'+
			'</div>';
		return html;
	}
	// Add a label and pulldown selection
	function htmlAddPulldown(di, lb, vr, values) {
		try {
			var selVal = varGet(di, vr);
			var html = '<div id="'+DIV_PREFIX+vr+di+'_div" class="clearfix labelInputContainer">'+
				'<div class="pull-left inputLabel '+((bOnALTUI)?'form-control form-control-sm form-control-plaintext':'')+'" style="width:280px;">'+lb+'</div>'+
				'<div class="pull-left customSelectBoxContainer">'+
				'<select id="'+DIV_PREFIX+vr+di+'" class="customSelectBox '+((bOnALTUI)?'form-control form-control-sm':'')+'" style="width:280px;">';
			for(var i=0;i<values.length;i++){
				html += '<option value="'+values[i].value+'" '+((values[i].value==selVal)?'selected':'')+'>'+values[i].label+'</option>';
			}
			html += '</select>'+
				'</div>'+
				'</div>';
			return html;
		} catch (e) {
			Utils.logError(MOD_PREFIX+': htmlAddPulldown(): ' + e);
			return '';
		}
	}
	// Add a label and multiple selection
	function htmlAddPulldownMultiple(di, lb, vr, values) {
		try {
			var selVal = varGet(di, vr);
			var selected = [];
			if (selVal !== '') {
				selected = selVal.split(',');
			}
			var len = Math.min(7,values.length);
			var html = '<div class="clearfix labelInputContainer">'+
				'<div class="pull-left inputLabel'+((bOnALTUI)?'form-control form-control-sm form-control-plaintext':'')+'" style="width:280px;">'+lb+'</div>'+
				'<div class="pull-left">'+
				'<select size="'+len+'" style="width:280px;" id="'+DIV_PREFIX+vr+di+'" multiple>';
			for(var i=0;i<values.length;i++){
				html+='<option value="'+values[i].value+'" ';
				for (var j=0;j<selected.length;j++) {
					html += ((values[i].value==selected[j])?'selected':'');
				}	
				html +=	'>'+values[i].label+'</option>';
			}
			html += '</select>'+
				'</div>'+
				'</div>';
			return html;
		} catch (e) {
			Utils.logError(MOD_PREFIX+': htmlAddPulldownMultiple(): ' + e);
		}
	}
	// Update variable in user_data and lu_status
	function varSet(deviceID, varID, varVal, sid) {
		if (typeof(sid) == 'undefined') { sid = SID_Weather; }
		api.setDeviceStateVariablePersistent(deviceID, sid, varID, varVal);
	}
	// Get variable value. When variable is not defined, this new api returns false not null.
	function varGet(deviceID, varID, sid) {
		try {
			if (typeof(sid) == 'undefined') { sid = SID_Weather; }
			var res = api.getDeviceState(deviceID, sid, varID);
			if (res !== false && res !== null && res !== 'null' && typeof(res) !== 'undefined') {
				return res;
			} else {
				return '';
			}	
        } catch (e) {
            return '';
        }
	}
	// Show/hide the interface busy indication.
	function showBusy(busy) {
		if (busy === true) {
			try {
				api.ui.showStartupModalLoading(); // version v1.7.437 and up
			} catch (e) {
				myInterface.showStartupModalLoading(); // For ALTUI support.
			}
		} else {
			try {
				api.ui.hideModalLoading(true);
			} catch (e) {
				myInterface.hideModalLoading(true); // For ALTUI support
			}	
		}
	}
	
	// Show message dialog
	function htmlSetMessage(msg,error) {
		try {
			if (error === true) {
				api.ui.showMessagePopupError(msg);
			} else {
				api.ui.showMessagePopup(msg,0);
			}	
		}	
		catch (e) {	
			Utils.logError(MOD_PREFIX+': htmlSetMessage(): ' + e);
		}	
	}

	// Force luup reload.
	function _DoReload(deviceID) {
		application.sendCommandSaveUserData(true);
		showBusy(true);
		htmlSetMessage("Changes to configuration made.<br>Now wait for reload to complete and then refresh your browser page!",false);
		setTimeout(function() {
			api.performLuActionOnDevice(0, "urn:micasaverde-com:serviceId:HomeAutomationGateway1", "Reload", {});
			showBusy(false);
		}, 4000);	
	}
	function doReload(deviceID) {
		api.performLuActionOnDevice(0, "urn:micasaverde-com:serviceId:HomeAutomationGateway1", "Reload", {});
	}

	// Expose interface functions
    myModule = {
		// Internal for panels
        uuid: _uuid,
        init: _init,
        onBeforeCpanelClose: _onBeforeCpanelClose,
		UpdateDisplay: _UpdateDisplay,
		UpdateSettings: _UpdateSettings,
		DoReload: _DoReload,
		
		// For JSON calls
        Settings: _Settings,
    };
    return myModule;
})(api);