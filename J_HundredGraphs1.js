var HundredGraphs = (function (api) {
	var serviceId = 'urn:hundredgraphs-com:serviceId:HundredGraphs1';
    var uuid = '4d494342-5342-5645-01e6-000002fb37e3';
    var myModule = {};
    
    function about() {
        try {              
            var html = '<div>This is all about me !</div>';
            api.setCpanelContent(html);
        } catch (e) {
            Utils.logError('Error in MyPlugin.about(): ' + e);
        }
    }

    myModule = {
        uuid: uuid,
        about: about
    };
    return myModule;
})(api);