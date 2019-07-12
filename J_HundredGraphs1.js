var HundredGraphs = (function (api) {
    var myModule = {};
    var version = "1.7";

    var uuid = '4d494342-5342-5645-01e6-000002fb37e3';
    var device = api.getCpanelDeviceId();    
    
    var SID_HG = 'urn:hundredgraphs-com:serviceId:HundredGraphs1';
    var SID = [
        {
            type: 'PM',
            serviceId: "urn:micasaverde-com:serviceId:EnergyMetering1",
            serviceVar: "Watts",
        },
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
    ];


    
    var hcg_deviceData = [];
    
    function about() {
        try {              
            var html = '<div>Read the full docs at <a href="https://www.hundredgraphs.com/apidocs" target=_blank>HundredGraphs API</a></div>';
            html += '<div>Grab your API KEY from <a href="https://www.hundredgraphs.com/settings" target=_blank>HG Settings</a></div>';
            html += '<div>SID_HG = ' + SID_HG + '</div>';
            api.setCpanelContent(html);
        } catch (e) {
            Utils.logError('Error in MyPlugin.about(): ' + e);
        }
    }

    function resetDevices() {
        hcg_deviceData = [];
        api.setDeviceStatePersistent(device, SID_HG, "DeviceData", '', 0);
        console.log('HundredGraphs. DeviceData was reset');
        var html = "<div> Devices were reset </div>";
        html += '<p>';
        html += '<input type="button" value="Show Devices" onClick="HundredGraphs.showDevices()" style="margin-left:60%" />';
        html += '</p>';
        api.setCpanelContent(html);
        getListDevices();
    }

    function updateEnabled(idx, object) {
        hcg_deviceData[idx].enabled = (object.checked === true) ? "checked" : "";
        console.log('HG enabled sw: ', hcg_deviceData[idx]);
    }

    function getListDevices(){
        var deviceData = api.getUserData().devices;
        try{
            for (item of deviceData){
                //console.log('HundredGraphs checking dev:', item.id, item.name, item.states);
                if (item.id ){
                    //console.log('HundredGraphs checking item.id:', item.id, item.states);
                    for (attr of item.states){
                        for (checkIt of SID) {
                            //console.log('HundredGraphs checking attr:', item.id, checkIt.serviceId, attr);
                            if (attr.service == checkIt.serviceId){
                                if (item.id){
                                    console.warn('HundredGraphs found', checkIt.serviceVar, 'device:', item.id, item.name);
                                    var item = {
                                        type: checkIt.type,
                                        deviceId: item.id,
                                        key: item.name,
                                        serviceId: checkIt.serviceId,
                                        serviceVar: checkIt.serviceVar,
                                        enabled: false
                                    }
                                    hcg_deviceData.push(item);                                   
                                }

                            }                    
                        }
                    }
                    console.log();
                }
            }         
            hcg_deviceData = hcg_deviceData.sort(function(a, b){
                var res = a.type == b.type ? 0 : +(a.type > b.type) || -1;
                //console.log('sort res', res);
                return res;
            });   
        }catch(e){
            console.error('HundredGraphs getListDevices err:', e);
        }
        console.log('HundredGraphs found PM devices:', hcg_deviceData.length, 'of', deviceData.length);
    }

    function unpackDeviceData(device) {
        var deviceData;
        try {
            console.log('HundredGraphs running unpackDeviceData for:', device, 'initial:', hcg_deviceData);
            hcg_deviceData = [];

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
                hcg_deviceData.push(item);
            }
            for (var i = 0; i < hcg_deviceData.length; i++) {
                if (!hcg_deviceData[i].type){
                    for (checkIt of SID){
                        if (hcg_deviceData[i].serviceId == checkIt.serviceId){
                            hcg_deviceData[i].type = checkIt.type;
                        }             
                    }
                }
            }
            hcg_deviceData = hcg_deviceData.sort(function(a, b){
                var res = a.type == b.type ? 0 : +(a.type > b.type) || -1;
                return res;
            }); 
            console.log('HundredGraphs hcg_deviceData: ', hcg_deviceData);
        } catch(e){
            console.error('HundredGraphs err:', e, 'deviceData:', deviceData, 'hcg_deviceData:', hcg_deviceData);
            Utils.logError('Error in HG.unpackDeviceData(): ' + e);
        }
    }

    function packDeviceData(){
        console.log('{HundredGraphs packDeviceData} hcg_deviceData: ', hcg_deviceData);
        var deviceData = '';
        for (item of hcg_deviceData){
            console.log('{HundredGraphs packDeviceData} item: ', item);
            deviceData = deviceData + 'type=' + item.type + ',deviceId=' + item.deviceId + ',key=' + item.key + ',serviceId=' + item.serviceId + ',serviceVar=' + item.serviceVar + ',enabled=' + item.enabled + ';';
        }
        console.log('{HundredGraphs packDeviceData} deviceData: ', deviceData);
        api.setDeviceStatePersistent(device, SID_HG, "DeviceData", deviceData, 0);
    }

    
    function showDevices() {
        try {
            var html = '';
            device = device || api.getCpanelDeviceId();
            unpackDeviceData(device);
            console.log('HundredGraphs unpacked devs:', hcg_deviceData);

            if (hcg_deviceData.length > 0) {
                // Area to display statuses and error messages.
                html += '<p id="status_display" style="width:90%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:black"></div>';

                html += '<table style="width:90%; position:relative; margin-left:auto; margin-right:auto">';

                // Show titles
                html += '<tr>';
                html += '<td style="font-weight:bold; text-align:center; width:30%">Type</td>';
                html += '<td style="font-weight:bold; text-align:center; width:30%">Device #</td>';
                html += '<td style="font-weight:bold; text-align:center; width:30%">Device name</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%">Enabled</td>';
                html += '</tr>';

                // Show device list
                for (var i = 0; i < hcg_deviceData.length; i++) {
                    html += '<tr>'; 
                    html += '<td style="padding-left:5%">' + hcg_deviceData[i].type + '</td>';
                    html += '<td style="">' + hcg_deviceData[i].deviceId + '</td>';
                    html += '<td style="">' + api.getDisplayedDeviceName(hcg_deviceData[i].deviceId) + '</td>';
                    html += '<td><input type="checkbox" value="' + hcg_deviceData[i].devNum + '" onClick="HundredGraphs.updateEnabled(' + i + ', this)" ' + hcg_deviceData[i].enabled + ' style="margin-left:42%" /></td>';
                    html += '</td>';
                    html += '</tr>';
                }

                // Create empty row
                html += '<tr>';
                html += '<td colspan="4"><br /></td>';
                html += '</tr>';

                // Display the 'Update' button
                html += '<tr>';
                html += '<td colspan="3"><input type="button" value="Save" onClick="HundredGraphs.packDeviceData()" style="margin-left:60%" /></td>';
                html += '</tr>';
                html += '<p>';
                html += '<input type="button" value="Reset Devices" onClick="HundredGraphs.resetDevices()" style="margin-left:60%" />';
                html += '</p>';  

                html += '</table>';
            } else {
                var deviceData = api.getDeviceState(device, SID_HG, "DeviceData");
                getListDevices();
                deviceData = deviceData || 'empty';
                console.log('HG3: ', device, 'hcg:', hcg_deviceData, 'luldata:', deviceData );
                html += '<p style="margin-left:10px; margin-top:10px">No power reporting devices for ' + device + '</p>';
                html += '<p style="margin-left:10px; margin-top:10px">DeviceData: ' + hcg_deviceData.length + ' ' + deviceData + '</p>';
                 
                html += '<p>';
                html += '<input type="button" value="Get Devices" onClick="HundredGraphs.packDeviceData()" style="margin-left:60%" />';
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
        showDevices: showDevices,
        packDeviceData: packDeviceData,
        resetDevices: resetDevices
    };
    return myModule;
})(api);