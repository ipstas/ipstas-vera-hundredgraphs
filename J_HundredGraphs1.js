var HundredGraphs = (function (api) {
    var myModule = {};
    
    var HG_SID = 'urn:hundredgraphs-com:serviceId:HundredGraphs1';
    var uuid = '4d494342-5342-5645-01e6-000002fb37e3';
    var device = api.getCpanelDeviceId();
    
    var hcg_deviceData = [];
    
    function about() {
        try {              
            var html = '<div>This is all about me !</div>';
            html = html + '<div>HG_SID = ' + HG_SID + '</div>';
            api.setCpanelContent(html);
        } catch (e) {
            Utils.logError('Error in MyPlugin.about(): ' + e);
        }
    }

    function updateEnabled(idx, object) {
        hcg_deviceData[idx].enabled = (object.checked === true) ? "checked" : "";
        console.log('HG enabled sw: ', hcg_deviceData[idx]);
    }

    function getListDevices(){
        var deviceData = api.getUserData().devices;
        for (item of deviceData){
            for (attr of item.states){
                var checkIt = 'Watts'
                if (attr.variable == checkIt){
                    console.log('HundredGraphs found PM device:', item.id, item.name);
                    var item = {
                        deviceId: item.id,
                        key: item.name,
                        serviceId: 'urn:micasaverde-com:serviceId:EnergyMetering1',
                        serviceVar: checkIt,
                        enabled: false
                    }
                    hcg_deviceData.push(item)
                }
            }
        }
        console.log('HundredGraphs found PM devices:', hcg_deviceData.length);
    }

    function unpackDeviceData(device) {
        var deviceData;
        try {
            hcg_deviceData = [];

            deviceData = api.getDeviceState(device, HG_SID, "DeviceData");
            if (deviceData === undefined || deviceData === "" || !deviceData) 
                return console.log('HundredGraphs empty variable DeviceData:', deviceData);
            deviceData = deviceData.split(';');
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
                    if (!key) return;
                    key = key.trim();
                    val = attr[j].split('=')[1];
                    if (!val) return;
                    item[key] = val;
                    //console.log('HG2: ', j, item, attr[j]);
                }
                hcg_deviceData.push(item);
            }
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
            deviceData = deviceData + 'deviceId=' + item.deviceId + ',key=' + item.key + ',serviceId=' + item.serviceId + ',serviceVar=' + item.serviceVar + ',enabled=' + item.enabled + ';\n ';
        }
        console.log('{HundredGraphs packDeviceData} deviceData: ', deviceData);
        api.setDeviceStateVariable(device, HG_SID, "DeviceData", deviceData, 0);
    }

    
    function showDevices() {
        try {
            var html = '';

            unpackDeviceData(device);

            if (hcg_deviceData.length > 0) {
                // Area to display statuses and error messages.
                html += '<p id="status_display" style="width:90%; position:relative; margin-left:auto; margin-right:auto; table-layout:fixed; text-align:center; color:black"></div>';

                html += '<table style="width:90%; position:relative; margin-left:auto; margin-right:auto">';

                // Show titles
                html += '<tr>';
                html += '<td style="font-weight:bold; text-align:center; width:30%">Device #</td>';
                html += '<td style="font-weight:bold; text-align:center; width:30%">Device name</td>';
                html += '<td style="font-weight:bold; text-align:center; width:10%"></td>';
                html += '</tr>';

                // Show device list
                for (var i = 0; i < hcg_deviceData.length; i++) {
                    html += '<tr>';
                    html += '<td style="padding-left:5%">' + hcg_deviceData[i].deviceId + '</td>';
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
                html += '<td colspan="3"><input type="button" value="Update" onClick="HundredGraphs.packDeviceData()" style="margin-left:60%" /></td>';
                html += '</tr>';

                html += '</table>';
            } else {
                var deviceData = api.getDeviceState(device, HG_SID, "DeviceData");
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
        packDeviceData: packDeviceData
    };
    return myModule;
})(api);