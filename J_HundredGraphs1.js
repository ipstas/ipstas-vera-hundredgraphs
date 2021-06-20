var versionHG = "...";

var HundredGraphs = (function (api) {
    let myModule = {};   
    let device;// = api.getCpanelDeviceId();
	let API;
    const uuid = '4d494342-5342-5645-01e6-000002fb37e3';    
    const SID_HG = 'urn:hundredgraphs-com:serviceId:HundredGraphs1';
    const SID_ALL = [
        {
            type: 'PM',
            serviceId: "urn:micasaverde-com:serviceId:EnergyMetering1",
            serviceVar: "Watts",
        },
        {
            type: 'PM2',
            serviceId: "urn:micasaverde-com:serviceId:EnergyMetering1",
            serviceVar: "KWH",
        },
        {
            type: 'PM3',
            serviceId: "urn:upnp-org:serviceId:Dimming1",
            serviceVar: "LoadLevelStatus",
        },
        {
            type: 'PM4',
            serviceId: "urn:upnp-org:serviceId:SwitchPower1",
            serviceVar: "Status",
        },
/* 		{
            type: 'SW',
            serviceId: "urn:upnp-org:serviceId:SwitchPower1",
            serviceVar: "Status",
        }, */
        {
            type: 'SES',
            serviceId: "urn:micasaverde-com:serviceId:SecuritySensor1",
            serviceVar: "Tripped",
        },
        {
            type:'TMP',
            serviceId: "urn:upnp-org:serviceId:TemperatureSensor1",
            serviceVar: "CurrentTemperature",
        },
        {
            type: 'HUM',
            serviceId: "urn:micasaverde-com:serviceId:HumiditySensor1",
            serviceVar: "CurrentLevel",
        },
        {
            type: 'LUX',
            serviceId: "urn:micasaverde-com:serviceId:LightSensor1",
            serviceVar: "CurrentLevel",
        },
        {
            type: 'THM',
            serviceId: "urn:micasaverde-com:serviceId:HVAC_OperatingState1",
            serviceVar: "ModeState",
        },
        {
            type: 'FAN',
            serviceId: "urn:upnp-org:serviceId:HVAC_FanOperatingMode1",
            serviceVar: "FanStatus",
        },
        {
            type: 'LOCK',
            serviceId: "urn:micasaverde-com:serviceId:DoorLock1",
            serviceVar: "Status",
        },
        {
            type: 'BTR',
            serviceId: "urn:micasaverde-com:serviceId:HaDevice1",
            serviceVar: "BatteryLevel",
        },
        {
            type: 'SYS1',
            serviceId: "urn:cd-jackson-com:serviceId:SystemMonitor",
            serviceVar: "uptimeTotal",
        },
        {
            type: 'SYS2',
            serviceId: "urn:cd-jackson-com:serviceId:SystemMonitor",
            serviceVar: "memoryFree",
        },
        {
            type: 'SYS3',
            serviceId: "urn:cd-jackson-com:serviceId:SystemMonitor",
            serviceVar: "cpuLoad1",
        },
    ];

    let hg_deviceData = [];
    let hg_sids = [];
    let hg_node = 1;  
    let enabled = 0;
    let serverResponse = 'no response yet';
    let lastRun = 'no response yet';
    let devEnabled =  0;
	let DEBUG = 0;
	//console.log('HG start:', device, SID_HG, enabled, devEnabled, versionHG);
	
	function getDevice(){
		//if (device) return; 
		try{
			device = device || api.getCpanelDeviceId();
			versionHG = api.getDeviceState(device, SID_HG, "version");
			API = api.getDeviceState(device, SID_HG, "API");
			enabled = api.getDeviceState(device, SID_HG, "Enabled");
			devEnabled = api.getDeviceState(device, SID_HG, "Dev");
			DEBUG = api.getDeviceState(device, SID_HG, "DEBUG");
			if ((!devEnabled || devEnabled == '') && device)
				api.setDeviceStatePersistent(device, SID_HG, "Dev", 0, {dynamic: true});
			console.log('HG getDevice:', device, SID_HG, enabled, devEnabled, versionHG);
		}catch(e){
			Utils.logError('Error in MyPlugin.getDevice(): ' + e);
		}
	}
	function setAPI(){
		try{
			API = document.getElementById("setAPI").value;
			api.setDeviceStatePersistent(device, SID_HG, "API", API, {dynamic: true});
			about();
			//console.log('HG getDevice:', device, SID_HG, enabled, devEnabled, versionHG);
		}catch(e){
			Utils.logError('Error in MyPlugin.setAPI(): ' + e);
		}
	}
	
	function energyHG(){
		try {
			var html = '';
			html += '<iframe src="https://www.hundredgraphs.com/energyVera" width="100%" height="600px" allowfullscreen></iframe>';
			api.setCpanelContent(html);
		} catch (e) {
			Utils.logError('Error in MyPlugin.energyHG(): ' + e);
		}				
	}
	
	function aboutSet(){
		function setClick(set, change){
			try {
				let res = api.setDeviceStatePersistent(device, SID_HG , set, change,{dynamic: true})
				console.log('HG about device:', set, 'change:', change, 'res:', res);
			}catch(err){
				console.warn('HG about device:', err, 'set:', set, 'change:', change);
			}
		}
		
		try {
			enabled = api.getDeviceState(device, SID_HG, "Enabled") || 0;
			lastRun = api.getDeviceState(device, SID_HG, "lastRun") || '';			
			try{
				serverResponse = api.getDeviceState(device, SID_HG, "ServerResponse") || '';		
				serverResponse = JSON.parse(serverResponse);
				serverResponse = JSON.stringify(serverResponse, undefined, 2);
			}catch(err){
				console.warn('HG about serverResponse err:', err, '\nserverResponse:', serverResponse);
			}
			devEnabled = api.getDeviceState(device, SID_HG, "Dev") || 0;
			enabled = parseInt(enabled);
			devEnabled = parseInt(devEnabled);
			DEBUG = parseInt(DEBUG);
			versionHG = api.getDeviceState(device, SID_HG, "version");		
			console.log('HG about device:', device, SID_HG, API, 'enabled:', enabled, 'devenabled:', devEnabled, 'version:', versionHG);
			var html = '<p>Read the full docs at <a href="https://www.hundredgraphs.com/apidocs" target=_blank>HundredGraphs API</a></p>';
			html += '<p><ul>';
			html += '<li>Grab your API KEY from <a href="https://www.hundredgraphs.com/settings" target=_blank>HG Settings</a> and then set it here</li>';
			html += '<li>Select your devices in tab Devices</li>';
			html += '<li>Set your reporting interval (600+ sec for free account or 60+ sec if you have paid)</li>';
			html += '<li>If you need any custom devices not preconfigured for you, check <b>Custom Vars</b> tab</li>';
			html += '<li>Update Node if required (each reporting hub, ie Vera, needs its own node)</b> tab</li>';
			html += '<li>You are all set</li>';
			html += '</ul></p>';
			html += '<p>API KEY: <input type="text" id="setAPI" class="ds-input" name="setAPI" value=' + API + '> <input type="button" class="btn btn-info" value="Set" onClick="HundredGraphs.setAPI()" /></p>';
			html += '<p>SID_HG: ' + SID_HG + '</p>';
			html += '<p>If you have an idea or need support with the plugin or service, check the thread at <a href="https://community.ezlo.com/t/free-graphs-for-your-temp-power-sensors/205588" target=_blank">Vera Community HundredGraphs plugin help</a></p>';
			html += '<p>or send us a message at <a href="https://www.hundredgraphs.com/about?get=contactForm" target=_blank>HundredGraphs Contact</a></p>';
			html += '<p>We are listening!</p>';
			
			let check, change, setVar;

			setVar = 'Enabled';
			if (enabled) 
				check = 'checked', change = 0;
			else 
				check = false, change = 1;								
			try{			
				//html += 'Debug: '+DEBUG+' <input type="checkbox" value="'+check+'" onClick="setClick(set,change)"';
				html += 'Enabled <input type="checkbox" '+check+' onClick="api.setDeviceStatePersistent(\''+device+'\',\''+SID_HG+'\',\''+setVar+'\','+change+', {dynamic: true})"';			
				console.log('HG set:', setVar, change, api.getDeviceState(device, SID_HG, setVar));	
				html += '<br/>';
			}catch(err){
				console.warn('HG about device err:', err, html);
			}	
			html += '<p>Server Response: ' + lastRun + '</p>';
			html += '<p>Details: <pre><code>' + serverResponse + '</code></pre></p>';
			
			html += '<p>';
			html += '<br/>You usually dont need these';
			html += '<div>Version: ' + versionHG + '</div>';
			setVar = 'Dev';
			if (devEnabled) 
				check = 'checked', change = 0;
			else 
				check = false, change = 1;								
			try{			
				//html += 'Debug: '+DEBUG+' <input type="checkbox" value="'+check+'" onClick="setClick(set,change)"';
				html += '<div>If you want us to check your data it will send it to our debugging server</div>';
				html += '<div>Dev <input type="checkbox" '+check+' onClick="api.setDeviceStatePersistent(\''+device+'\',\''+SID_HG+'\',\''+setVar+'\','+change+', {dynamic: true})"';			
				console.log('HG set:', setVar, change, api.getDeviceState(device, SID_HG, setVar));	
				html += '</div>';
			}catch(err){
				console.warn('HG about device err:', err, html);
			}
				
			setVar = 'DEBUG';
			if (DEBUG) 
				check = 'checked', change = 0;
			else 
				check = false, change = 1;						
			try{
				//html += 'Debug: '+DEBUG+' <input type="checkbox" value="'+check+'" onClick="setClick(set,change)"';
				html += '<div>This will show extra details here and in logs</div>';
				html += '<div>Debug <input type="checkbox" '+check+' onClick="api.setDeviceStatePersistent('+device+',\''+SID_HG+'\',\''+setVar+'\','+change+', {dynamic: true})"';
				html += '</div>';
				console.log('HG set:', setVar, change, api.getDeviceState(device, SID_HG, setVar));		
			}catch(err){
				console.warn('HG about device err:', err, html);
			}
			html += '</p>';
			
			api.setCpanelContent(html);
		} catch (e) {
			Utils.logError('Error in MyPlugin.aboutSet(): ' + e);
		}				
	}
    function about() {
		let res = getDevice();
		if (!res) {
			setTimeout(function(){
				aboutSet();				
			}, 1000);
		} else {
			aboutSet();
		}
    }
	
    function readCustom(){
        try{
            if (hg_sids && hg_sids.length)
                return hg_sids;
            // if no hg_sids yet check SID_ALL var
            var deviceData = api.getDeviceState(device, SID_HG, "SidData");
            // if no saved var yet use default SID_ALL
            if (!deviceData || deviceData == '') 
                return hg_sids = JSON.parse(JSON.stringify(SID_ALL));
            // use saved SID_ALL
            deviceData = deviceData.split(';');
            //var s = [];
            //console.log('HundredGraphs running readCustom. deviceData:', deviceData);
            for (let d of deviceData) {
                // Get the intervals.
                var item = {};
                //console.log('HG1: ', d);       
                //console.log('HG1b: ', typeof attr, attr);
                if (d){
                    for (let j of d.split(',')) {
                        var key, val;               
                        key = j.split('=')[0];
                        val = j.split('=')[1];
                        if (!key || key == ' ') return;
                        key = key.trim();
                        if (!val) val = false;
                        item[key] = val;
                        //console.log('HG2: ', item, j);       
                    }
                    hg_sids.push(item);
                }
            }
            //console.log('HundredGraphs. hg_sids:', hg_sids, 'SID_ALL:', SID_ALL, 'api:', api.getDeviceState(device, SID_HG, "SID_ALL"));
            return hg_sids;
        } catch(e){
            console.warn('HundredGraphs. hg_sids err:', e);
            return SID_ALL;
        }
    }

    function resetDevices() {
        hg_deviceData = [];
        api.setDeviceStatePersistent(device, SID_HG, "DeviceData", '', 0);
        //console.log('HundredGraphs. DeviceData was reset');
        var html = "<div> Devices were reset </div>";
        html += '<p>';
        html += '<input type="button" class="btn btn-info" value="Get Devices" onClick="HundredGraphs.getListDevices()" style="margin-left:60%" />';
        html += '</p>';
        api.setCpanelContent(html);
        //getListDevices();
    }
    function getListDevices(){
        var deviceData = api.getUserData().devices;
        var devsids = readCustom();
        try{
            for (let item of deviceData){
                if (item.id){
                    for (let checkIt of devsids){
                        for (let attr of item.states) {
                            if (attr.service == checkIt.serviceId && attr.variable == checkIt.serviceVar){
                                if (item.id){
                                    console.log('HundredGraphs found', checkIt.serviceVar, 'device:', item.id, item.name);
                                    var p = {
                                        type: checkIt.type,
                                        deviceId: item.id,
                                        key: item.name,
                                        serviceId: checkIt.serviceId,
                                        serviceVar: checkIt.serviceVar,
                                        enabled: false,
										burst: false
                                    }
									if (attr.variable == 'Watts' || attr.variable == 'KWH' || attr.variable == 'Tripped' || attr.variable == 'BatteryLevel' || attr.variable == 'BatteryLevel' )
										p.enabled = 'checked';
                                    hg_deviceData.push(p);                                   
                                }
                            }                    
                        }
                    }
                    //console.log();
                }
            }         
            hg_deviceData = hg_deviceData.sort(function(a, b){
                var res = a.type == b.type ? 0 : +(a.type > b.type) || -1;
                //console.log('sort res', res);
                return res;
            });   
			var html = '';
			html += '<p>';
			html += 'New devices were discovered: ' + hg_deviceData.length;
			html += '</p>';
			html += '<p>';
			html += '<input type="button" class="btn btn-info" value="Show Devices" onClick="HundredGraphs.showDevices()"/>';
			html += '</p>';
			api.setCpanelContent(html);
			getListDevices
			console.log('HundredGraphs populated hg_deviceData:', hg_deviceData.length, 'of', deviceData.length);
        }catch(e){
            console.error('HundredGraphs getListDevices err:', e);
        }
        //console.log('HundredGraphs found PM devices:', hg_deviceData.length, 'of', deviceData.length);
    }

    function updateEnabled(idx, object) {
        hg_deviceData[idx].enabled = (object.checked === true) ? "checked" : "";
        //console.log('HG enabled sw: ', hg_deviceData[idx]);
    }
    function burstEnabled(idx, object) {
        hg_deviceData[idx].burst = (object.checked === true) ? "checked" : "";
        console.log('HG enabled sw: ', hg_deviceData[idx]);
    }

    function unpackDeviceData(device) {
        hg_node = api.getDeviceState(device, SID_HG, "DeviceNode") || 1;
        var deviceData;
        try {
            //console.log('HundredGraphs running unpackDeviceData for:', device, 'initial:', hg_deviceData);
            hg_deviceData = [];

            deviceData = api.getDeviceState(device, SID_HG, "DeviceData");
            if (!deviceData || deviceData === undefined || deviceData === "") {
                return console.log('HundredGraphs empty variable for:', device, 'DeviceData:', deviceData, 'dev2:', api.getDeviceState(device, SID_HG, "DeviceData"));
            }                    
            deviceData = deviceData.split(';');
            //console.log('HundredGraphs running unpackDeviceData. deviceData:', deviceData);
            for (var i = 0; i < deviceData.length; i++) {
                // Get the intervals.
                var item = {};
                var attr = deviceData[i].toString();
                attr = deviceData[i].split(',');
                for (var j = 0; j < attr.length; j++) {
                    var key, val;                
                    key = attr[j].split('=')[0];
                    if (!key || key == ' ') return;
                    key = key.trim();
                    val = attr[j].split('=')[1];
                    if (!val) val = false;
                    item[key] = val;
                }
				//if (item?.id)
				hg_deviceData.push(item);
            }
			hg_deviceData = hg_deviceData.filter(function(el) { if (el.key) return el; });
            for (var i = 0; i < hg_deviceData.length; i++) {
                if (!hg_deviceData[i].type){
                    for (let checkIt of hg_sids){
                        if (hg_deviceData[i].serviceId == checkIt.serviceId){
                            hg_deviceData[i].type = checkIt.type;
                        }             
                    }
                }
            }
			//hg_deviceData.sort((a, b) => a.type.localeCompare(b.type) || a.key.localeCompare(b.key) );
            console.log('[HundredGraphs] unpackDeviceData hg_deviceData: ', hg_deviceData);
        } catch(e){
            console.error('HundredGraphs err:', e, 'deviceData:', deviceData, 'hg_deviceData:', hg_deviceData);
            Utils.logError('Error in HG.unpackDeviceData(): ' + e);
        }
    }
    function packDeviceData(){
        //console.log('{HundredGraphs packDeviceData} hg_deviceData: ', hg_deviceData);
		try{
			hg_node = document.getElementById("deviceNode").value;
			api.setDeviceStatePersistent(device, SID_HG, "DeviceNode", hg_node);
			var deviceData = '';
			var html = '';
			html += '<div class="favorites_device_busy_device_overlay"><div class="round_loading deviceCpanelBusySpinner"></div></div>';
			api.setCpanelContent(html);       
			for (let item of hg_deviceData){
				//console.log('{HundredGraphs packDeviceData} item: ', item);
				item.enabled = item.enabled || false;
				item.burst = item.burst || false;
				if (item?.deviceId)
					deviceData = deviceData + 'type=' + item.type + ',deviceId=' + item.deviceId + ',key=' + item.key + ',serviceId=' + item.serviceId + ',serviceVar=' + item.serviceVar + ',enabled=' + item.enabled + ',burst=' + item.burst + ';\n';
			}
			function htmlSuccess(){
				html += '<p id="status_data" style="width:90%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:red">Devices are NOT saved</p>';
				html += '<input type="button" class="btn btn-warning" value="Try Again" onClick="HundredGraphs.showDevices()"/>';
				//alert('Devices save failed')
				api.setCpanelContent(html); 
				console.log('{HundredGraphs packDeviceData} onFailure deviceData saved:', false);
				//showDevices();				
			}
			function htmlFailure(){
				//console.log('{HundredGraphs packDeviceData} onSuccess deviceData saved:', true);
				html += '<p id="status_data" style="width:90%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:blue">';
				html += 'Devices are saved ';
				html += '<input type="button" class="btn btn-success" value="OK" onClick="HundredGraphs.showDevices()"/>';				
				html += '</p>';
				
				api.setCpanelContent(html); 			
			}
			//console.log('{HundredGraphs packDeviceData} deviceData: ', deviceData);
			function reiterate(){
				n++;
				let savedData = api.getDeviceState(device, SID_HG, "DeviceData"));
				console.log('[saving data'
				if (savedData == deviceData) {
					htmlSuccess()
				} else if (n > 100) {
					htmlFailure()
				}				
			}
			function stopIt(intervalId){
				clearInterval(intervalId);
				if (savedData == deviceData) 
					htmlSuccess()
				else 
					htmlFailure()					
			}
			function onSuccess(){
				htmlSuccess()
			}
			function onFailure(){
				let n = 0				
				let savedData = api.getDeviceState(device, SID_HG, "DeviceData"));
				if (savedData == deviceData)
					return; 
				var intervalId = setInterval(reiterate(), 5000);
				setTimeout(stopIt(intervalId), 60000);					
			}
		
			api.setDeviceStatePersistent(device, SID_HG, "DeviceData", deviceData, {onSuccess: onSuccess, onFailure: onFailure});			
			return true;
		}catch(err){
			console.warn('{HundredGraphs packDeviceData} err:', err);
		}
    }
 
    function resetSID_ALL(){
        //console.log('{HundredGraphs resetSID_ALL} SID_ALL: ', SID_ALL);
        hg_sids = [];
		var html = '';
		html += '<div class="favorites_device_busy_device_overlay"><div class="round_loading deviceCpanelBusySpinner"></div></div>';
		api.setCpanelContent(html);
		function onSuccess(){
            //console.log('{HundredGraphs packSID_ALL} deviceData reset: ', true);
            customDevices();		
            return true;
		}
        api.setDeviceStatePersistent(device, SID_HG, "SidData", '', {onSuccess: onSuccess});		     		
    }
    function packSID_ALL(){
        console.log('{HundredGraphs packSID_ALL} SID_ALL: ', SID_ALL);
        var deviceData = '';
		var html = '';
		html += '<div class="favorites_device_busy_device_overlay"><div class="round_loading deviceCpanelBusySpinner"></div></div>';
		api.setCpanelContent(html);
        for (let item of hg_sids){
            //console.log('{HundredGraphs packSID_ALL} item: ', item);
            deviceData = deviceData + 'type=' + item.type + ',serviceVar=' + item.serviceVar + ',serviceId=' + item.serviceId + ';';
        }
        //console.log('{HundredGraphs packSID_ALL} deviceData: ', deviceData);
		function onSuccess(){
            //console.log('{HundredGraphs packSID_ALL} deviceData saved: ', true);
            customDevices();
            return true;
		}
        api.setDeviceStatePersistent(device, SID_HG, "SidData", deviceData, {onSuccess: onSuccess});			
    }
    function addSID(){        
        let item = {};    
        item.serviceVar = document.getElementById("serviceVar").value;			
        item.serviceId = document.getElementById("serviceId").value;
		item.type = item.serviceVar;
		//item.type = 'Custom';
        hg_sids.push(item);			
        return packSID_ALL();
    }
    function delSID(){
        //console.log('{HundredGraphs addSID} SID_ALL: ', SID_ALL);
        let item = {};      
        item.serviceVar = document.getElementById("serviceVar").value;			
        item.serviceId = document.getElementById("serviceId").value;
		item.type = item.serviceVar;
		//item.type = 'Custom';
        hg_sids.push(item);			
        customDevices();
		return true;
    }

    function customDevices() {
		getDevice();
        var devsids = readCustom();
        try {
            var html = '';
            //device = device || api.getCpanelDeviceId();
            //console.log('[HundredGraphs customDevices] variables and servic IDs:', devsids);

            if (devsids && devsids.length > 0) {
                // Area to display statuses and error messages.
                html += '<p id="status_display" style="width:95%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:black"></p>';

                html += '<table style="width:95%; position:relative; margin-left:auto; margin-right:auto">';

                // Show titles
                html += '<tr>';
                html += '<td style="font-weight:bold; text-align:center; width:15%">Type</td>';
                html += '<td style="font-weight:bold; text-align:center; width:30%">serviceVar</td>';
                html += '<td style="font-weight:bold; text-align:center; width:45%">serviceID</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%"></td>';
                html += '</tr>';

                // Show device list
                var i = 0;
                for (i = 0; i < devsids.length; i++) {
                    html += '<tr id="cst_"' + i + '>'; 
                    html += '<td style="width:15%; padding-right: 1%;">' + devsids[i].type + '</td>';
                    html += '<td style="width:30%; padding-right: 1%;">' + devsids[i].serviceVar + '</td>';
                    html += '<td style="width:45%; padding-right: 1%;">' + devsids[i].serviceId + '</td>';
                    // if (devsids[i].type == 'Custom')
                    //     html += '<td style="width:10%"><div class="btn btn-danger btn-sm" onClick="HundredGraphs.delSID()">Del</div></td>';
                    // else
                    html += '<td style="width:10%"></td>';
                    html += '</td>';
                    html += '</tr>';
                    //console.log('HundredGraphs variables and servic IDs:', i, devsids[i]);
                }

                // Add custom vars
                i++;
                html += '<tr id="cst_"' + i + '>'; 
                html += '<td style="width:15%; padding-right: 1%;">Custom</td>';
                html += '<td style="width:30%; padding-right: 1%;"><input type="text" id="serviceVar" class="form-control ds-input" name="serviceVar"></td>';
                html += '<td style="width:45%; padding-right: 1%;"><input type="text" id="serviceId" class="form-control ds-input" name="serviceId"></td>';
                html += '<td style="width:10%"><div class="btn btn-info btn-sm" onClick="HundredGraphs.addSID()">Add</div></td>';
                html += '</td>';
                html += '</tr>';

                // Create empty row
                html += '<tr>';
                html += '<td colspan="4"><br /></td>';
                html += '</tr>';
                
                html += '</table>';
                
                // Display the button
                html += '<p>';
                //html += '<input type="button" class="btn btn-success" value="Save" onClick="HundredGraphs.packSID_ALL()" />&nbsp';
                html += '<input type="button" class="btn btn-danger" value="Reset" onClick="HundredGraphs.resetSID_ALL()" />';
                html += '</p>';  
                
            } else {
                console.warn('[HundredGraphs custom] variables and servic IDs empty:', devsids);
                html += '<p id="status_data" style="width:90%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:red">Variables not found</p>';	
                html += '<p style="margin-left:10px; margin-top:10px">No saved serviceVars for logger id #' + device + '</p>';
                html += '<p style="margin-left:10px; margin-top:10px">devsids: ' + devsids + '</p>';             
            }
            api.setCpanelContent(html);
        } catch (e) {
            console.warn('Error in HG.customDevices(): ', e);
            Utils.logError('Error in HG.customDevices(): ' + e);
        }
    }      
    
    function showDevices() {
		getDevice();
        try {
            var html = '';
            //device = device || api.getCpanelDeviceId();
            if (!hg_deviceData.length)
				unpackDeviceData(device);
/* 			hg_deviceData = hg_deviceData.sort(function(a, b) {
				//return (b.key.toUpperCase() - a.key.toUpperCase() || b.type - a.type);
				
				return (b.key.toUpperCase() - a.key.toUpperCase() );
			});
 */			
			
			//console.log('HundredGraphs unpacked devs0:', hg_deviceData);
/* 			hg_deviceData.map(o=>{
				//console.log('HundredGraphs unpacked devs0 map:', o);
				//if (o.type && o.key) return o
			}) */
			hg_deviceData = hg_deviceData.filter(function(el) { if (el.key) return el; });
			try{
				hg_deviceData.sort((a, b) => a.type.localeCompare(b.type) || a.key.localeCompare(b.key) );
			}catch(err){
				console.warn('HundredGraphs unpacked devs err:', err, hg_deviceData);
			}
			//window.hg_deviceData = hg_deviceData;
            //console.log('HundredGraphs unpacked devs:', hg_deviceData);

            var deviceNode = api.getDeviceState(device, SID_HG, "DeviceNode");

            if (hg_deviceData.length > 0) {
				
				var deviceData = api.getDeviceState(device, SID_HG, "DeviceData");
				if (!deviceData || deviceData == ""){			
					//console.warn('HundredGraphs deviceData:', deviceData);
					html += '<p id="status_data" style="width:90%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:red">Devices are not saved</p>';	
				}
                // Area to display statuses and error messages.
                html += '<p id="status_display" style="width:90%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:black"></p>';
                html += '<p id="" style="">Node: <input type="text" id="deviceNode" class="form-control ds-input" style="max-width: 60px;display: inline;" name="deviceNode" value=' + hg_node + ' oninput="this.value = this.value.replace(/[^0-9.]/g, \'\').replace(/(\..*)\./g, \'$1\');"> numerical only</p>';

                // show devices
                html += '<br\><table style="width:90%; position:relative; margin-left:auto; margin-right:auto">';
                // Show titles
                html += '<tr>';
                html += '<td style="font-weight:bold; text-align:center; width:35%">Type</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%">Device #</td>';
                html += '<td style="font-weight:bold; text-align:center; width:35%">Device name</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%">enabled</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%">Burst</td>';
                html += '</tr>';

                // Show device list
                var i = 0;
                for (i = 0; i < hg_deviceData.length; i++) {
                    html += '<tr>'; 
                    html += '<td style="padding-left:1%">' + hg_deviceData[i].serviceVar + '</td>';
                    html += '<td style="">' + hg_deviceData[i].deviceId + '</td>';
                    html += '<td style="">' + api.getDisplayedDeviceName(hg_deviceData[i].deviceId) + '</td>';
                    html += '<td><input type="checkbox" value="' + hg_deviceData[i].devNum + '" onClick="HundredGraphs.updateEnabled(' + i + ', this)" ' + hg_deviceData[i].enabled + ' style="margin-left:42%" /></td>';
					html += '<td><input type="checkbox" value="' + hg_deviceData[i].devNum + '" onClick="HundredGraphs.burstEnabled(' + i + ', this)" ' + hg_deviceData[i].burst + ' style="margin-left:42%" /></td>';
                    html += '</tr>';
                }

                // Create empty row
                html += '<tr>';
                html += '<td colspan="4"><br /></td>';
                html += '</tr>';
                html += '</table>';

                // Display the button
                html += '<p>';
                html += '<input type="button" class="btn btn-success" value="Save" onClick="HundredGraphs.packDeviceData()"/>&nbsp';
                html += '<input type="button" class="btn btn-danger" value="Reset" onClick="HundredGraphs.resetDevices()" />';
                html += '</p>';  
				if (!deviceData || deviceData == ""){			
					html += '<p id="status_data" style="width:90%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:red">Devices are not saved</p>';	
					console.log('HG deviceData:', deviceData);
				}
            } else {
                var deviceData = api.getDeviceState(device, SID_HG, "DeviceData");
                //getListDevices();
                deviceData = deviceData || 'empty';
                //console.log('HG3: ', device, 'hcg:', hg_deviceData, 'luldata:', deviceData );
                html += '<p style="margin-left:10px; margin-top:10px">No saved devices for logger id #' + device + '</p>';
                html += '<p style="margin-left:10px; margin-top:10px">DeviceData: ' + hg_deviceData.length + ' ' + deviceData + '</p>'; 
                html += '<p>';
                html += '<input type="button" class="btn btn-info" value="Get Devices" onClick="HundredGraphs.getListDevices()" style="margin-left:60%" />';
                html += '</p>';                   
            }

            api.setCpanelContent(html);
        } catch (e) {
            Utils.logError('Error in HG.showDevices(): ' + e);
        }
    }  

    myModule = {
        uuid: uuid,
        about: about,
        getDevice: getDevice,
        setAPI: setAPI,
        getListDevices: getListDevices,
        updateEnabled: updateEnabled,
		burstEnabled: burstEnabled,
        customDevices: customDevices,
        energyHG: energyHG,
        showDevices: showDevices,
        packSID_ALL: packSID_ALL,
        resetSID_ALL: resetSID_ALL,
        addSID: addSID,
        delSID: delSID,
        packDeviceData: packDeviceData,
        resetDevices: resetDevices
    };
    return myModule;
})(api);
