var versionHG = '...';


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
	



    let deviceDataHG = [];
    let sidsHG = [];
	//window.deviceDataHG = deviceDataHG;
    //let deviceData = [];
    let hg_sids = [];
    let hg_node = 1;  
    let enabled = 0;
    let serverResponse = 'no response yet';
    let lastRun = 'no response yet';
    let devEnabled =  0;
	let DEBUG = 0;
	let stateHG = '';
	let html = '';
	//console.log('HG start:', device, SID_HG, enabled, devEnabled, versionHG);

	let comVars =  api.getDeviceState(device, SID_HG, "ComVars") || ['KWH', 'Watts', 'LoadLevelStatus', 'Status', 'Tripped', 'CurrentTemperature', 'CurrentLevel', 'ModeState', 'FanStatus', 'BatteryLevel', 'uptimeTotal', 'memoryFree', 'cpuLoad1'];
	let sids = api.getDeviceState(device, SID_HG, "SIDs");
	sidsHG = JSON.parse(sids) || [];
		
	const sortBy = (key) => {
		return (a, b) => (a[key] > b[key]) ? 1 : ((b[key] > a[key]) ? -1 : 0);
	};	
	const sortBy2 = (key, key2) => {
		return (a, b) => (a[key] > b[key]) ? 1 : ((b[key] > a[key]) ? -1 : a[key2] > b[key2]) ? 1 : ((b[key2] > a[key2]) ? -1 : 0);
	};
	const sortByNeg = (key) => {
		return (a, b) => (a[key] > b[key]) ? -1 : ((b[key] > a[key]) ? 1 : 0);
	};	


	function setClick(set, change, htmlId){
		try {
			let res = api.setDeviceStatePersistent(device, SID_HG , set, change,{dynamic: true})
			document.getElementById(htmlId).value = change;
			//console.log('HG about device:', set, 'change:', change, 'res:', res);
		}catch(err){
			console.warn('HG about device:', err, 'set:', set, 'change:', change);
		}
	}	
	function getDevice(){
		//if (device) return; 
		//Utils.logError('Error in HG.unpackDeviceData() test: ' + 'test');
		try{
			device = device || api.getCpanelDeviceId();
			versionHG = api.getDeviceState(device, SID_HG, "version");
			API = api.getDeviceState(device, SID_HG, "API");
			enabled = api.getDeviceState(device, SID_HG, "Enabled");
			devEnabled = api.getDeviceState(device, SID_HG, "Dev");
			DEBUG = api.getDeviceState(device, SID_HG, "DEBUG");
			if ((!devEnabled || devEnabled == '') && device)
				api.setDeviceStatePersistent(device, SID_HG, "Dev", 0, {dynamic: true});
			//console.log('HG getDevice:', device, SID_HG, enabled, devEnabled, versionHG);
			return device;
		}catch(e){
			Utils.logError('Error in MyPlugin.getDevice(): ' + e);
		}
	}
	function setAPI(){

		try{
			function onSuccess(caller){
				//console.log('[setAPI] success', API, api.getDeviceState(device, SID_HG, "API"));
				stateHG = 'green'
				document.getElementById("setAPI").style.background = stateHG;
				document.getElementById("state").style.background = stateHG;
				document.getElementById("state").style.display = 'block';
				//document.getElementById("state").style.color = 'stateHG';
				document.getElementById("state").innerHTML = "set OK";
			}
			function onFailure(caller){
				console.warn('[setAPI] failed', API, api.getDeviceState(device, SID_HG, "API"));	
				stateHG = 'red'
				document.getElementById("setAPI").style.background = stateHG;		
				document.getElementById("state").style.background = stateHG;
				document.getElementById("state").style.display = 'block';			
				//document.getElementById("state").style.color = 'stateHG';		
				document.getElementById("state").innerHTML = "set Failed";
			}
			API = document.getElementById("setAPI").value;
			api.setDeviceStatePersistent(device, SID_HG, "API", API, {dynamic: true, onSuccess: onSuccess, onFailure: onFailure});
			//document.getElementById("setAPI").value = API;

			//about();
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
		if (!device) return console.warn('[HG] no device');
		console.log('[HG aboutSet] device:', device, SID_HG);
		stateHG = stateHG || 'NOT YET';
		versionHG = api.getDeviceState(device, SID_HG, "version") || 'version coming';	
		API = api.getDeviceState(device, SID_HG, "API");
		enabled = api.getDeviceState(device, SID_HG, "Enabled") || 0;	
		devEnabled = api.getDeviceState(device, SID_HG, "Dev") || 0;			
		DEBUG = api.getDeviceState(device, SID_HG, "DEBUG") || 0;
		lastRun = api.getDeviceState(device, SID_HG, "lastRun") || '';		
		lastErr = api.getDeviceState(device, SID_HG, "ERR") || '';		
		
		serverResponse = api.getDeviceState(device, SID_HG, "ServerResponse") || 'no response yet';
		console.log('HG about serverResponse:', serverResponse);
		enabled = parseInt(enabled);
		devEnabled = parseInt(devEnabled);		
		DEBUG = parseInt(DEBUG);
				
		serverResponse = JSON.parse(serverResponse);
		serverResponse = JSON.stringify(serverResponse, undefined, 2);

		console.log('HG about device:', device, SID_HG, API, 'enabled:', enabled, 'devenabled:', devEnabled, 'version:', versionHG);
		html = '<p id="state" style="display:none; padding:10px">' + stateHG + '</p>';
			
		html += '<p>Read the full docs at <a href="https://www.hundredgraphs.com/apidocs" target=_blank>HundredGraphs API</a></p>';
		html += '<p><ul>';
		html += '<li>Grab your API KEY from <a href="https://www.hundredgraphs.com/settings" target=_blank>HG Settings</a> and then set it here</li>';
		html += '<li>Select your devices in tab Devices</li>';
		html += '<li>Set your reporting interval (600+ sec for free account or 60+ sec if you have paid)</li>';
		html += '<li>If you need any custom devices not preconfigured for you, check <b>serviceIDs</b> tab</li>';
		html += '<li>Update Node if required (each reporting hub, ie Vera, needs its own node)</b> tab</li>';
		html += '<li>You are all set</li>';
		html += '</ul></p>';

		html += '<p>If you have an idea or need some support with the plugin or service, check the thread at <a href="https://community.ezlo.com/t/free-graphs-for-your-temp-power-sensors/205588" target=_blank">Vera Community HundredGraphs plugin help</a></p>';
		html += '<p>or send us a message at <a href="https://www.hundredgraphs.com/about?get=contactForm" target=_blank>HundredGraphs Contact</a></p>';
		html += '<p>We love hearing from you!</p>';
		
		html += '<div>Version: ' + versionHG + '</div>';
		html += '<div>API KEY: <input type="text" id="setAPI" class="ds-input" name="setAPI" value=' + API + '> <input type="button" class="btn btn-info" value="Set" onClick="HundredGraphs.setAPI()" /></div>';
		
		
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
		
		html += '<p>You usually dont need these</p>';
		html += '<div>SID_HG: ' + SID_HG + '</div>';		
		
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
		
		html += '<div>Last error: ' + lastErr + '</div>';
		
		api.setCpanelContent(html);
		
	}
    function about() {
		let res = getDevice();
		//aboutSet();
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
			
			hg_sids.forEach(o=>	comVars.push(x.serviceVar));
			
			comVars = [...new Set(comVars)];
			comVars = comVars.sort();
			api.setDeviceStatePersistent(device, SID_HG, "ComVars", comVars);			
            return hg_sids;
        } catch(e){
            console.warn('HundredGraphs. hg_sids err:', e);
            return SID_ALL;
        }
    }

    function sidEnabled(variable) {
		console.log('HG sidEnabled: ', variable, sidsHG);
        //deviceDataHG[idx].enabled = (object.checked === true) ? "checked" : "";
        //
		let sids = sidsHG.map(item=>{
			if (item.serviceVar == variable) {
				item.enabled = !item.enabled;
/* 				for (let p of pairs) {
					if (item.serviceVar == p.serviceVar)
						console.log('[HundredGraphs customDevices] inside:', item, p);
 					if (item.serviceVar == p.serviceVar && item.serviceVar == p.serviceVar && item.serviceId.indexOf(p.serviceId) < 0)
						item.serviceId.push(p.serviceId); 
				}	 */		
			}
			return item;
		});
		console.log('[HundredGraphs sidEnabled] sids:', sids);
		
		sidsHG = sids.concat().sort(sortByNeg('serviceVar'));	
		sidsHG = sids.concat().sort(sortByNeg('enabled'));	
		sids = sidsHG.filter(o=>o.enabled);
		sids = JSON.stringify(sids, undefined, 2)
		HundredGraphs.selectServiceID();
		api.setDeviceStatePersistent(device, SID_HG , 'SIDs' , sids, {dynamic: true})
    }
    function updateEnabled(idx, object) {
        deviceDataHG[idx].enabled = (object.checked === true) ? "checked" : "";
        //console.log('HG enabled sw: ', deviceDataHG[idx]);
    }
    function burstEnabled(idx, object) {
        deviceDataHG[idx].burst = (object.checked === true) ? "checked" : "";
        console.log('HG enabled sw: ', deviceDataHG[idx]);
    }

    function resetSID_ALL(){
        //console.log('{HundredGraphs resetSID_ALL} SID_ALL: ', SID_ALL);
		sidsHG = [];
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
        //console.log('{HundredGraphs packSID_ALL} SID_ALL: ', SID_ALL);
        var deviceData = '';
		var html = '';
		html += '<div class="favorites_device_busy_device_overlay"><div class="round_loading deviceCpanelBusySpinner"></div></div>';
		api.setCpanelContent(html);
        for (let item of hg_sids){
            //console.log('{HundredGraphs packSID_ALL} item: ', item);
            deviceData = deviceData + 'type=' + item.type + ',serviceVar=' + item.serviceVar + ',serviceId=' + item.serviceId + ';\n';
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

    function selectServiceID() {
		//sidsHG = [];
		getDevice();
		let oldsids = readCustom();
		//console.log('oldsids', oldsids);
		
		let allData = api.getUserData().devices;
		
		let states = allData.map(function(x){
			return x.states
		});
		states = states.flat();	
		let pairs = []
		for (let state of states) {
			if (pairs.findIndex( o => (o.service == state.service && o.variable == state.variable)) < 0) {
				let p = {
					serviceId: state.service,
					serviceVar: state.variable
				}
/* 				if (comVars.indexOf(p.variable) > -1)
					p.enabled = true; */
				pairs.push(p)				
			}
		}
		
/* 		let urns = states.map(function(x){
			return x.service
		});
		urns = [...new Set(urns)];	 */	
		
		let vars = states.map(function(x){
			return x.variable
		});

		
		vars = [...new Set(vars)];
		vars = vars.sort();

		for (let v of vars){
			if (sidsHG.findIndex( o => (o.serviceVar == v)) < 0) {
				let item = {
					serviceVar: v, 
					enabled: false, 
					serviceId: []
				};
				if (comVars.indexOf(v) > -1)
					item.enabled = true;
/* 				for (let pair of pairs) {
					if (v == pair.serviceVar && item.serviceId.indexOf(pair.serviceId) < 0)
						item.serviceId.push(pair.serviceId)
				}		 */	
				sidsHG.push(item);
			} else {

			}
		}

		let sids = sidsHG.map(item=>{
			if (item.enabled) {
				for (let p of pairs) {
					if (item.serviceVar == p.serviceVar)
						console.log('[HundredGraphs customDevices] inside:', item, p);
 					if (item.serviceVar == p.serviceVar && item.serviceVar == p.serviceVar && item.serviceId.indexOf(p.serviceId) < 0)
						item.serviceId.push(p.serviceId); 
				}			
			}
			return item;
		});
		console.log('[HundredGraphs customDevices] sids:', sids);
		
		sidsHG = sids.concat().sort(sortByNeg('enabled'));		
		
        try {
            html = '<p>We consider these variables common and they come preconfigured</p>';
			html += '<p>If you change them, you need to rediscover devices again</p>';
			for (let v of comVars){
				html += '<span class=" label-info badge">'+v+'</span> ';
			}
            html += '<p>But you can also select others</p>';
            //device = device || api.getCpanelDeviceId();
            //console.log('[HundredGraphs customDevices] variables and servic IDs:', devsids);

            if (vars?.length > 0) {
                // Area to display statuses and error messages.
                html += '<p id="status_display" style="width:95%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:black"></p>';

                html += '<table style="width:95%; position:relative; margin-left:auto; margin-right:auto">';

                // Show titles
                html += '<tr>';
                html += '<td style="font-weight:bold; text-align:center; width:30%">serviceVar</td>';
                html += '<td style="font-weight:bold; text-align:center; width:45%">serviceID</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%"></td>';
                html += '</tr>';

                // Show device list
                var i = 0;
                for (let sid of sidsHG) {
					let enabled;
					if (sid.enabled)
						enabled = 'checked';
					let service = 'service';
                    html += '<tr id="cst_"' + i + '>'; 
                    html += '<td style="width:30%; padding-right: 1%;">' + sid.serviceVar + '</td>';
                    html += '<td style="width:70%; padding-right: 1%;">';
					if (enabled)
						for (let s of sid.serviceId) {
							s = s.split(':');
							html += s[s.length-1] + '</br>'; 
						}
					else
						html += 'enable to see services';
					html += '</td>';
					html += '<td><input type="checkbox" value="' + sid.serviceVar + '" onClick="HundredGraphs.sidEnabled(\'' + sid.serviceVar + '\')" ' + enabled + ' style="margin-left:42%" /></td>';
                    html += '<td style="width:10%"></td>';
                    html += '</td>';
                    html += '</tr>';
                }

                // Create empty row
                html += '<tr>';
                html += '<td colspan="4"><br /></td>';
                html += '</tr>';
                
                html += '</table>';
                
/*                 // Display the button
                html += '<p>';
                //html += '<input type="button" class="btn btn-success" value="Save" onClick="HundredGraphs.packSID_ALL()" />&nbsp';
                html += '<input type="button" class="btn btn-danger" value="Reset" onClick="HundredGraphs.resetSID_ALL()" />';
                html += '</p>';   */
                
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

    function resetDevices() {
        deviceDataHG = [];
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
		console.log('HundredGraphs getListDevices:', deviceDataHG?.length);
		if (!deviceDataHG?.length && device)
			unpackDeviceData(device);
        let allData = api.getUserData().devices;
		let deviceData = deviceDataHG;
        var devsids = sidsHG;
		window.devsids = devsids;
		let count = 0;
        try{
            for (let item of allData){           
				for (let attr of item.states) {
					//let index1 = devsids.findIndex( o => (o.serviceId == attr.service && o.serviceVar == attr.variable));
					let savedSid = devsids.find(o => (o.serviceVar == attr.variable && o.enabled))
					if (savedSid) {
						let device = api.getDeviceObject(item.id);
						let type = device.device_type.split(':');
						type = type[type.length - 2 ];
						console.log('HundredGraphs found', attr.variable, 'device:', item.id, item.name);
						var p = {
							deviceId: item.id,
							type: type,			
							key: item.name,
							serviceId: attr.service,
							serviceVar: attr.variable,
							enabled: false,
							burst: false,
							n: true
						}
						if (p.serviceVar == 'Watts' || p.serviceVar == 'KWH' || p.serviceVar == 'Tripped' || p.serviceVar == 'BatteryLevel' || p.serviceVar == 'CurrentTemperature' )
							p.enabled = 'checked';
						if (!deviceData?.length) {
							//p.n = true;
							deviceDataHG.push(p);   
							count++;
							console.log('HundredGraphs deviceData pushed1:', p, '#', count, 'of', allData.length);
						} else {
							let index2 = deviceData.findIndex( o => (o.deviceId == p.deviceId && o.serviceVar == p.serviceVar));
							//p.n = true;
							//p.enabled = 'false';
							if (index2 < 0) 											
								count++, deviceDataHG.push(p);
							console.log('HundredGraphs deviceDataHG pushed2:', index2, p, '#', count, 'of', allData.length);
						}                           
					} else if (attr.variable == 'Watts'){
						console.log('HundredGraphs savedSid NOT found', attr.variable, attr.service, 'device:', item, '\ndevsids:', devsids);
					}
				}
            }         
			if (deviceDataHG?.length){
				deviceDataHG = deviceDataHG.concat().sort(sortBy('name'));	
				deviceDataHG = deviceDataHG.concat().sort(sortBy('serviceVar'));	
			}
		
			html = '<p>';
			html += 'New devices were discovered: ' + count;
			html += '</p>';
			html += '<p>';
			html += '<input type="button" class="btn btn-info" value="Show Devices" onClick="HundredGraphs.showDevices()"/>';
			html += '</p>';
			api.setCpanelContent(html);
			console.log('HundredGraphs populated deviceDataHG:', deviceDataHG.length, 'of', allData.length);
        }catch(e){
            console.error('HundredGraphs getListDevices err:', e);
        }
        //console.log('HundredGraphs found PM devices:', deviceDataHG.length, 'of', allData.length);
    }
    function getListDevicesOld(){
		console.log('HundredGraphs getListDevices:', deviceDataHG?.length);
		if (!deviceDataHG?.length && device)
			unpackDeviceData(device);
        let allData = api.getUserData().devices;
		let deviceData = deviceDataHG;
        var devsids = readCustom();
		window.devsids = devsids;
		let count = 0;
        try{
            for (let item of allData){           
				for (let attr of item.states) {
					//let index1 = devsids.findIndex( o => (o.serviceId == attr.service && o.serviceVar == attr.variable));
					let savedSid = devsids.find(o => (o.serviceId == attr.service && o.serviceVar == attr.variable))
					if (savedSid) {
						console.log('HundredGraphs found', attr.variable, 'device:', item.id, item.name);
						var p = {
							deviceId: item.id,
							type: savedSid.type,			
							key: item.name,
							serviceId: attr.service,
							serviceVar: attr.variable,
							enabled: false,
							burst: false,
							n: true
						}
						if (p.serviceVar == 'Watts' || p.serviceVar == 'KWH' || p.serviceVar == 'Tripped' || p.serviceVar == 'BatteryLevel' || p.serviceVar == 'CurrentTemperature' )
							p.enabled = 'checked';
						if (!deviceData?.length) {
							//p.n = true;
							deviceDataHG.push(p);   
							count++;
							console.log('HundredGraphs deviceData pushed1:', p, '#', count, 'of', allData.length);
						} else {
							let index2 = deviceData.findIndex( o => (o.deviceId == p.deviceId && o.serviceVar == p.serviceVar));
							//p.n = true;
							//p.enabled = 'false';
							if (index2 < 0) 											
								count++, deviceDataHG.push(p);
							console.log('HundredGraphs deviceDataHG pushed2:', index2, p, '#', count, 'of', allData.length);
						}                           
					} else if (attr.variable == 'Watts'){
						console.log('HundredGraphs NOT found', index1, attr.variable, attr.service, 'device:', item, '\ndevsids:', devsids);
					}
				}
            }         
			if (deviceDataHG?.length)
				deviceDataHG = deviceDataHG.sort(function(a, b){
					var res = a.type == b.type ? 0 : +(a.type > b.type) || -1;
					return res;
				});   
			
			html = '<p>';
			html += 'New devices were discovered: ' + count;
			html += '</p>';
			html += '<p>';
			html += '<input type="button" class="btn btn-info" value="Show Devices" onClick="HundredGraphs.showDevices()"/>';
			html += '</p>';
			api.setCpanelContent(html);
			console.log('HundredGraphs populated deviceDataHG:', deviceDataHG.length, 'of', allData.length);
        }catch(e){
            console.error('HundredGraphs getListDevices err:', e);
        }
        //console.log('HundredGraphs found PM devices:', deviceDataHG.length, 'of', allData.length);
    }
    function unpackDeviceData(device) {
        hg_node = api.getDeviceState(device, SID_HG, "DeviceNode") || 1;
        let deviceData;
		deviceDataHG = [];
        
		try {
            console.log('HundredGraphs running unpackDeviceData for:', device, 'initial:', deviceDataHG);
           
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
                    //if (!key || key == ' '|| key == '') return;
                    key = key.trim();
                    val = attr[j].split('=')[1];
                    if (!val) val = false;
                    item[key] = val;
                }
				if (item.deviceId)
					deviceDataHG.push(item);
            }
			console.log('[HundredGraphs] unpackDeviceData middle deviceDataHG: ', deviceDataHG);
			deviceDataHG = deviceDataHG.map(el => { 
				//el.key = el.key || api.getDisplayedDeviceName(el.deviceId);
				for (let checkIt of hg_sids){
					if (el.serviceId == checkIt.serviceId)
						el.type = checkIt.type;
				}
				return el;
			});
			console.log('[HundredGraphs] unpackDeviceData middle2 deviceDataHG: ', deviceDataHG);
			

            console.log('[HundredGraphs] unpackDeviceData end deviceDataHG: ', deviceDataHG);
        } catch(e){
            console.error('HundredGraphs err:', e, 'deviceData:', deviceData, 'deviceDataHG:', deviceDataHG);
            Utils.logError('Error in HG.unpackDeviceData(): ' + e);
        }
    }
    function packDeviceData(){
		
        let deviceData = '';
		let stateHG;
		let savedData;
		
		function htmlSuccess(){
			stateHG = 'green'
			document.getElementById("spinner").style.display = 'none';
			document.getElementById("stateDevs").style.display = 'block';
			document.getElementById("stateDevs").style.color = stateHG;
			document.getElementById("stateDevs").innerHTML = "Devices are saved";
			document.getElementById("saveDevs").style.color = stateHG;
			document.getElementById("saveDevs").value = "OK";
			console.log('{HundredGraphs packDeviceData} deviceData saved:', true);		
		}
		function htmlFailure(){
			stateHG = 'red'
			document.getElementById("spinner").style.display = 'none';
			document.getElementById("stateDevs").style.display = 'block';
			document.getElementById("stateDevs").style.color = stateHG;
			document.getElementById("stateDevs").innerHTML = "Devices NOT saved";
			document.getElementById("saveDevs").style.color = stateHG;
			document.getElementById("saveDevs").value = "Try again";
			console.log('{HundredGraphs packDeviceData} deviceData saved:', false);		
		}
/* 		function reiterate(deviceData, n){
			n++;
			let savedData = api.getDeviceState(device, SID_HG, "DeviceData");
			console.log('[saving data'
			if (savedData == deviceData) {
				return htmlSuccess()
			} else if (n > 100) {
				return htmlFailure()
			}				
		}
		function stopIt(intervalId){
			clearInterval(intervalId);
			if (savedData == deviceData) 
				htmlSuccess()
			else 
				htmlFailure()					
		} */
		function onSuccess(){
			savedData = api.getDeviceState(device, SID_HG, "DeviceData");
			console.log('{HundredGraphs packDeviceData} deviceData onSuccess saved:', savedData == deviceData);
			deviceDataHG = deviceDataHG.map(o=>{
				o.n = false;
				return o;
			});
			htmlSuccess();
		}
		function onFailure(){
			savedData = api.getDeviceState(device, SID_HG, "DeviceData");
			console.log('{HundredGraphs packDeviceData} deviceData onFailure saved:', savedData == deviceData);
			if (savedData != deviceData) {
/* 				let n = 0				
				var intervalId = setInterval(reiterate(deviceData, n), 5000);
				setTimeout(stopIt(intervalId), 60000);			 */
				htmlFailure();
			} else {
				htmlSuccess();
			}	
		}
			
		try{
			document.getElementById("spinner").style.display = 'block';
			const node = document.getElementById("deviceNode").value;
			api.setDeviceStatePersistent(device, SID_HG, "DeviceNode", node);  

			let deviceData = deviceDataHG.filter(o=>o.enabled)
			let out = '';
			for (let item of deviceData){
				//console.log('{HundredGraphs packDeviceData} item: ', item);
				item.enabled = item.enabled || false;
				item.burst = item.burst || false;
				if (item?.deviceId)
					out = out + 'deviceId=' + item.deviceId + ',serviceId=' + item.serviceId + ',serviceVar=' + item.serviceVar + ',enabled=' + item.enabled + ',burst=' + item.burst + ';\n';
			}
			
			console.log('{HundredGraphs packDeviceData} deviceDataHG: ', deviceData.length, deviceDataHG.length);
			document.getElementById("stateDevs").innerHTML = "Saving devices";
			api.setDeviceStatePersistent(device, SID_HG, "DeviceData", out, {onSuccess: onSuccess, onFailure: onFailure});			
			return true;
		}catch(err){
			console.warn('{HundredGraphs packDeviceData} err:', err);
		}
    }
  
    function showDevices() {
		//const allDevices = api.getUserData().devices;
		//const weatherSettings = api.getUserData().weatherSettings;
		

		let deviceData = [];
		let styleColor;
		const savedData = api.getDeviceState(device, SID_HG, "DeviceData");
		
		getDevice();
		
		console.log('HundredGraphs showDevices deviceDataHG:', deviceDataHG);
		if (!deviceDataHG.length)
			unpackDeviceData(device);		

        try {
				
			html = '<p id="state" style="display:none;">' + stateHG + '</p>';
						
			console.log('HundredGraphs showDevices deviceDataHG:', deviceDataHG);
            if (deviceDataHG?.length > 0) {
				
				//now get key from the device if no key present
				deviceData = deviceDataHG.map(o=>{
					if (!o.key || !o.type) {
						let dev = api.getDeviceObject(o.deviceId);
						o.key = dev?.name || 'noname';
						let type = dev?.device_type?.split(':');
						o.type = type[type?.length - 2 ];
					}
					if (o.n)
						o.styleColor = 'lightgreen';
					else
						o.styleColor = 'white';
					console.log('HundredGraphs showDevices map adding key:', o.deviceId, o, api.getDeviceObject(o.deviceId));
					return o;
				});
				
				deviceData = deviceData.concat().sort(sortBy2('serviceVar', 'key'));		
				console.log('HundredGraphs showDevices deviceData:', deviceData);
				
				// Display the button
				html += '<p>'; 
				html += '<div id="stateDevs" style="padding: 10px; background: lightgray;">If you have a lot of devices sometimes they are not saved on 1st run</div>';
				html += '</p>'; 
				html += '<p>'; 
				html += '<input type="button" class="btn btn-info" value="Update Devices" onClick="HundredGraphs.getListDevices()" style="" />&nbsp';
				html += '<input type="button" id="saveDevs" class="btn btn-success" value="Save" onClick="HundredGraphs.packDeviceData()"/>&nbsp';
				html += '<input type="button" class="btn btn-danger" value="Reset" onClick="HundredGraphs.resetDevices()" />';			
				html += '</p>';  
							
                // Area to display statuses and error messages.
                html += '<p id="status_display" style="width:90%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:black"></p>';
                html += '<p id="" style="">Node: <input type="text" id="deviceNode" class="form-control ds-input" style="max-width: 60px;display: inline;" name="deviceNode" value=' + hg_node + ' oninput="this.value = this.value.replace(/[^0-9.]/g, \'\').replace(/(\..*)\./g, \'$1\');"> numerical only</p>';

				html += '<div id="spinner" class="favorites_device_busy_device_overlay" style="display:none;"><div class="round_loading deviceCpanelBusySpinner"></div></div>';

				
                // show devices
                html += '<br\><table style="width:90%; position:relative; margin-left:auto; margin-right:auto">';
                // Show titles
                html += '<tr>';
                html += '<td style="font-weight:bold; text-align:center; width:35%">Type</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%">Variable</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%">Device #</td>';
                html += '<td style="font-weight:bold; text-align:center; width:35%">Device name</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%">enabled</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%">Burst</td>';
                html += '</tr>';

                // Show device list
                var i = 0;
                for (let item of deviceData) {
                    html += '<tr style="background:' + item.styleColor + '">'; 
                    html += '<td style="padding-left:1%">' + item.type + '</td>';
                    html += '<td  ">' + item.serviceVar + '</td>';
                    html += '<td  ">' + item.deviceId + '</td>';
                    html += '<td style="">' + item.key + '</td>';
                    html += '<td><input type="checkbox" value="' + item.devNum + '" onClick="HundredGraphs.updateEnabled(' + i + ', this)" ' + item.enabled + ' style="margin-left:42%" /></td>';
					html += '<td><input type="checkbox" value="' + item.devNum + '" onClick="HundredGraphs.burstEnabled(' + i + ', this)" ' + item.burst + ' style="margin-left:42%" /></td>';
                    html += '</tr>';
                }

                // Create empty row
                html += '<tr>';
                html += '<td colspan="4"><br /></td>';
                html += '</tr>';
                html += '</table>';

				
            } else {
                deviceData = api.getDeviceState(device, SID_HG, "DeviceData");
                //getListDevices();
                deviceData = deviceData || 'empty';
                //console.log('HG3: ', device, 'hcg:', deviceDataHG, 'luldata:', deviceData );
                html += '<p style="margin-left:10px; margin-top:10px">No saved devices for logger id #' + device + '</p>';
                html += '<p style="margin-left:10px; margin-top:10px">DeviceData: ' + deviceDataHG.length + '</p>'; 
                html += '<p style="margin-left:10px; margin-top:10px">' + deviceData + '</p>'; 
                html += '<p>';
                html += '<input type="button" class="btn btn-info" value="Get Devices" onClick="HundredGraphs.getListDevices()" style="margin-left:60%" />';
                html += '</p>';                   
            }
			
			html += '<p id="">If "burst" is enabled, that device will be watched and changes will be collected between uploads. Otherwise only one last value will be collected at the time of the upload.</p>';
			html += '<p id="">Burst is paid feature, but every plan (includeing Free Forever) has 200 bursts per month. We suggest to use burst enabled for Tripped devices since they can change their state few times per minute.</p>';

            api.setCpanelContent(html);
        } catch (e) {
            Utils.logError('Error in HG.showDevices(): ' + e);
        }
    }  

    myModule = {
		setClick: setClick,
        uuid: uuid,
        about: about,
		aboutSet: aboutSet,
        getDevice: getDevice,
        setAPI: setAPI,
		sidEnabled: sidEnabled,
        getListDevices: getListDevices,
        updateEnabled: updateEnabled,
		burstEnabled: burstEnabled,
        selectServiceID: selectServiceID,
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
