const version = "2.3";

var HundredGraphs = (function (api) {
    let myModule = {};   
    const device = api.getCpanelDeviceId();  
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
            type: 'THM',
            serviceId: "urn:micasaverde-com:serviceId:HVAC_OperatingState1",
            serviceVar: "ModeState",
        },
        {
            type: 'LOCK',
            serviceId: "urn:micasaverde-com:serviceId:DoorLock1",
            serviceVar: "Status",
        },
    ];

    let hg_deviceData = [];
    let hg_sids = [];
    let hg_node = 1;

    api.setDeviceStatePersistent(device, SID_HG, "version", version, 0);
    
    function about() {
        try {              
            var html = '<p>Read the full docs at <a href="https://www.hundredgraphs.com/apidocs" target=_blank>HundredGraphs API</a></p>';
            html += '<p><ul>';
            html += '<li>Grab your API KEY from <a href="https://www.hundredgraphs.com/settings" target=_blank>HG Settings</a> and then set it in Advanced/Variables</li>';
            html += '<li>Select your devices in tab Devices</li>';
            html += '<li>Set your reporting interval</li>';
            html += '<li>If you need any custom devices not preconfigured for you, check <b>Custom Vars</b> tab</li>';
            html += '<li>Update Node if required (each reporting device, ie Vera, needs its own node)</b> tab</li>';
            html += '<li>You are all set</li>';
            html += '</ul></p>';
            html += '<p>SID_HG: ' + SID_HG + '</p>';
            html += '<p>If you need support with the plugin, check the thread at <a href="https://community.getvera.com/t/free-graphs-for-your-temp-power-sensors" target=_blank">Vera Community HundredGraphs plugin help</a></p>';
            html += '<p>or send us a message at <a href="https://www.hundredgraphs.com/about?get=contactForm" target=_blank>HundredGraphs Contact</a></p>';
            html += '<p>Version: ' + version + '</p>';
            api.setCpanelContent(html);
        } catch (e) {
            Utils.logError('Error in MyPlugin.about(): ' + e);
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

    function updateEnabled(idx, object) {
        hg_deviceData[idx].enabled = (object.checked === true) ? "checked" : "";
        //console.log('HG enabled sw: ', hg_deviceData[idx]);
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
                                    console.warn('HundredGraphs found', checkIt.serviceVar, 'device:', item.id, item.name);
                                    var p = {
                                        type: checkIt.type,
                                        deviceId: item.id,
                                        key: item.name,
                                        serviceId: checkIt.serviceId,
                                        serviceVar: checkIt.serviceVar,
                                        enabled: false
                                    }
									if (attr.variable == 'Watts' || attr.variable == 'KWH')
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
			//showDevices();
        }catch(e){
            console.error('HundredGraphs getListDevices err:', e);
        }
        console.log('HundredGraphs found PM devices:', hg_deviceData.length, 'of', deviceData.length);
    }

    function unpackDeviceData(device) {
        hg_node = api.getDeviceState(device, SID_HG, "DeviceNode") || 1;
        var deviceData;
        try {
            console.log('HundredGraphs running unpackDeviceData for:', device, 'initial:', hg_deviceData);
            hg_deviceData = [];

            deviceData = api.getDeviceState(device, SID_HG, "DeviceData");
            if (deviceData === undefined || deviceData === "" || !deviceData) {
                return console.log('HundredGraphs empty variable for:', device, 'DeviceData:', deviceData, 'dev2:', api.getDeviceState(device, SID_HG, "DeviceData"));
            }                    
            deviceData = deviceData.split(';');
            console.log('HundredGraphs running unpackDeviceData. deviceData:', deviceData);
            for (var i = 0; i < deviceData.length; i++) {
                // Get the intervals.
                var item = {};
                var attr = deviceData[i].toString();
                //_console('HG1: ' + i + ' ' + deviceData[i]);       
                attr = deviceData[i].split(',');
                //console.log('HG1b: ', typeof attr, attr);
                for (var j = 0; j < attr.length; j++) {
                    var key, val;
                    
                    key = attr[j].split('=')[0];
                    if (!key || key == ' ') return;
                    key = key.trim();
                    val = attr[j].split('=')[1];
                    if (!val) val = false;
                    item[key] = val;
                    //console.log('HG2: ', j, item, attr[j]);
                }
                hg_deviceData.push(item);
            }
            for (var i = 0; i < hg_deviceData.length; i++) {
                if (!hg_deviceData[i].type){
                    for (let checkIt of hg_sids){
                        if (hg_deviceData[i].serviceId == checkIt.serviceId){
                            hg_deviceData[i].type = checkIt.type;
                        }             
                    }
                }
            }
            hg_deviceData = hg_deviceData.sort(function(a, b){
                var res = a.type == b.type ? 0 : +(a.type > b.type) || -1;
                return res;
            }); 
            console.log('HundredGraphs hg_deviceData: ', hg_deviceData);
        } catch(e){
            console.error('HundredGraphs err:', e, 'deviceData:', deviceData, 'hg_deviceData:', hg_deviceData);
            Utils.logError('Error in HG.unpackDeviceData(): ' + e);
        }
    }

    function packDeviceData(){
        //console.log('{HundredGraphs packDeviceData} hg_deviceData: ', hg_deviceData);
        hg_node = document.getElementById("deviceNode").value;
        api.setDeviceStatePersistent(device, SID_HG, "DeviceNode", hg_node);
        var deviceData = '';
		var html = '';
		html += '<div class="favorites_device_busy_device_overlay"><div class="round_loading deviceCpanelBusySpinner"></div></div>';
        api.setCpanelContent(html);       
        for (let item of hg_deviceData){
            //console.log('{HundredGraphs packDeviceData} item: ', item);
            deviceData = deviceData + 'type=' + item.type + ',deviceId=' + item.deviceId + ',key=' + item.key + ',serviceId=' + item.serviceId + ',serviceVar=' + item.serviceVar + ',enabled=' + item.enabled + ';';
        }
        console.log('{HundredGraphs packDeviceData} deviceData: ', deviceData);
		function onSuccess(){
			//console.log('{HundredGraphs packDeviceData} deviceData saved: ', true);
			showDevices();		
		}
        api.setDeviceStatePersistent(device, SID_HG, "DeviceData", deviceData, {onSuccess: onSuccess});			
		return true;
    }
 
    function resetSID_ALL(){
        console.log('{HundredGraphs resetSID_ALL} SID_ALL: ', SID_ALL);
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
        item.type = 'Custom';
        item.serviceVar = document.getElementById("serviceVar").value;			
        item.serviceId = document.getElementById("serviceId").value;
        hg_sids.push(item);			
        return packSID_ALL();
    }
    function delSID(){
        console.log('{HundredGraphs addSID} SID_ALL: ', SID_ALL);
        let item = {};
        item.type = 'Custom';
        item.serviceVar = document.getElementById("serviceVar").value;			
        item.serviceId = document.getElementById("serviceId").value;
        hg_sids.push(item);			
        customDevices();
		return true;
    }

    function customDevices() {
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
        try {
            var html = '';
            //device = device || api.getCpanelDeviceId();
            if (!hg_deviceData.length)
				unpackDeviceData(device);
            //console.log('HundredGraphs unpacked devs:', hg_deviceData);

            var deviceNode = api.getDeviceState(device, SID_HG, "DeviceNode");

            if (hg_deviceData.length > 0) {
				
				var deviceData = api.getDeviceState(device, SID_HG, "DeviceData");
				if (!deviceData || deviceData == ""){			
					console.warn('HundredGraphs deviceData:', deviceData);
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
                html += '<td style="font-weight:bold; text-align:center; width:20%">Device #</td>';
                html += '<td style="font-weight:bold; text-align:center; width:35%">Device name</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%">Enabled</td>';
                html += '</tr>';

                // Show device list
                var i = 0;
                for (i = 0; i < hg_deviceData.length; i++) {
                    html += '<tr>'; 
                    html += '<td style="padding-left:1%">' + hg_deviceData[i].serviceVar + '</td>';
                    html += '<td style="">' + hg_deviceData[i].deviceId + '</td>';
                    html += '<td style="">' + api.getDisplayedDeviceName(hg_deviceData[i].deviceId) + '</td>';
                    html += '<td><input type="checkbox" value="' + hg_deviceData[i].devNum + '" onClick="HundredGraphs.updateEnabled(' + i + ', this)" ' + hg_deviceData[i].enabled + ' style="margin-left:42%" /></td>';
                    html += '</td>';
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
        getListDevices: getListDevices,
        updateEnabled: updateEnabled,
        customDevices: customDevices,
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