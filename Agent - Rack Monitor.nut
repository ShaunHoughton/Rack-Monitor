//Agent program for Rack Monitor


//Manage data save and restore from persistent storage

Data <- server.load();

HardwareID <- "";

device.send("GetHardwareID",HardwareID);

server.log(split(http.agenturl(), "/").top());

//Setup valid power switches and commands, first character is a space to prevent 0 on test logic
SwitchList <- " Switch01";
SwitchCommands <- " On,Off,Cycle";

// make sure data is valid 
if (!("AmbTemp" in Data)) {
    server.log("Initialise persistent data");
   Data <- {AmbTemp={Name="Ambient Temperature", Now=20.0, Max=20.0, Min=50.0, AlertHigh=30.0, AlertLow=10.0},
        Humidity={Name="Humidity", Now=50.0, Max=50.0, Min=100.0, AlertHigh=90.0, AlertLow=30.0},
        LightLevel={Name="Light Level", Now=50.0, Max=50.0, Min=30.0, AlertHigh=90.0, AlertLow=30.0},
        DoorTime={Name="Door Open Time", Now=0.0, Max=0.0, Min=0.0, AlertHigh=2.0, AlertLow=-1.0},
        DoorState={Name="Door State", Now="Closed", Max="Closed", Min="Closed", AlertHigh=" ", AlertLow=" "},
        BatteryV={Name="Battery Voltage", Now=3.3, Max=3.3, Min=3.3, AlertHigh=4.0, AlertLow=3.0},
        DeviceInfo={Name="New_Device",Location="Default",ContactNo = "Default",ContactName="Default",SSID="Blank"}};
}

server.save(Data);


foreach(idx,val in Data){
    server.log(idx + " = " + val);
    foreach(idx1,val1 in Data[idx]){
        server.log(idx1 + " = " + val1);
    }
    
}

//Setup constants for sending to Prowl
const PROWL_KEY = "8992275cba3e320996da436efab0c4b7281b9383";
const PROWL_URL = "https://api.prowlapp.com/publicapi";
const PROWL_APP = "Rack Monitor";

//Setup constnats for sending to Zapier
const ZAP_URL = "https://zapier.com/hooks/catch/n/9i5kn/";

//Setup Xively class for sending and receiving Xively feeds
Xively <- {};  // this makes a 'namespace'


class Xively.Client {
    ApiKey = null;
    triggers = [];

	constructor(apiKey) {
		this.ApiKey = apiKey;
	}
	
	/*****************************************
	 * method: PUT
	 * IN:
	 *   feed: a XivelyFeed we are pushing to
	 *   ApiKey: Your Xively API Key
	 * OUT:
	 *   HttpResponse object from Xively
	 *   200 and no body is success
	 *****************************************/
	function Put(feed){
		local url = "https://api.xively.com/v2/feeds/" + feed.FeedID + ".json";
		local headers = { "X-ApiKey" : ApiKey, "Content-Type":"application/json", "User-Agent" : "Xively-Imp-Lib/1.0" };
		local request = http.put(url, headers, feed.ToJson());
        //server.log("json = " + feed.ToJson());
        return request.sendsync();
	}
	
	/*****************************************
	 * method: GET
	 * IN:
	 *   feed: a XivelyFeed we fulling from
	 *   ApiKey: Your Xively API Key
	 * OUT:
	 *   An updated XivelyFeed object on success
	 *   null on failure
	 *****************************************/
	function Get(feed){
		local url = "https://api.xively.com/v2/feeds/" + feed.FeedID + ".json";
		local headers = { "X-ApiKey" : ApiKey, "User-Agent" : "xively-Imp-Lib/1.0" };
		local request = http.get(url, headers);
		local response = request.sendsync();
		if(response.statuscode != 200) {
			server.log("error sending message: " + response.body);
			return null;
		}
	
		local channel = http.jsondecode(response.body);
		for (local i = 0; i < channel.datastreams.len(); i++) {
			for (local j = 0; j < feed.Channels.len(); j++) {
				if (channel.datastreams[i].id == feed.Channels[j].id) {
					feed.Channels[j].current_value = channel.datastreams[i].current_value;
					break;
				}
			}
		}
	
		return feed;
	}

}
    

class Xively.Feed{
    FeedID = null;
    Channels = null;
    
    constructor(feedID, channels){
        this.FeedID = feedID;
        this.Channels = channels;
    }
    
    function GetFeedID() {
        return FeedID;
    }

    function ToJson() {
        local json = "{ \"datastreams\": [";
        for (local i = 0; i < this.Channels.len(); i++)
        {
            json += this.Channels[i].ToJson();
            if (i < this.Channels.len() - 1) json += ",";
        }
        json += "] }";
        //server.log("Feed JSON =" + json);
        return json;
    }
}

class Xively.Channel {
    id = null;
    current_value = null;
    
    constructor(_id) {
        this.id = _id;
    }
    
    function Set(value) { 
    	this.current_value = value; 
    }
    
    function Get() { 
    	return this.current_value; 
    }
    
    function ToJson() { 
    	return http.jsonencode({id = this.id, current_value = this.current_value }); 
    }
}

//Setup constants for Xively feeds
xively_FEED_ID <- "217048746";
xively_API_KEY <- "7zI5tg6nYSe1mbDodLYCSyOBjtk8S49yGrHerHJ4ON2jpLWH";

//Setup Ambient Temperature Xively channel and Feeds
xively_AmbTemp_ID <- "Ambient_Temperature";
xively_AmbTempChannel <- Xively.Channel(xively_AmbTemp_ID);
xively_AmbTempFeed <- Xively.Feed (xively_FEED_ID, [xively_AmbTempChannel]);

//Setup Humidity Xively channel and Feeds
xively_Humidity_ID <- "Humidity";
xively_HumidityChannel <- Xively.Channel(xively_Humidity_ID);
xively_HumidityFeed <- Xively.Feed (xively_FEED_ID, [xively_HumidityChannel]);

//Setup Light Level Xively channel and Feeds
xively_Light_ID <- "Light_Level";
xively_LightChannel <- Xively.Channel(xively_Light_ID);
xively_LightFeed <- Xively.Feed (xively_FEED_ID, [xively_LightChannel]);

//Setup Door State Xively channel and Feeds
xively_Door_ID <- "Door_State";
xively_DoorChannel <- Xively.Channel(xively_Door_ID);
xively_DoorFeed <- Xively.Feed (xively_FEED_ID, [xively_DoorChannel]);

//Setup Door Open Time Xively channel and Feeds
xively_DoorTime_ID <- "Door_Open_Time";
xively_DoorTimeChannel <- Xively.Channel(xively_DoorTime_ID);
xively_DoorTimeFeed <- Xively.Feed (xively_FEED_ID, [xively_DoorTimeChannel]);

//Setup Battery Voltage Xively channel and Feeds
xively_BatteryV_ID <- "Battery_Voltage";
xively_BatteryVChannel <- Xively.Channel(xively_BatteryV_ID);
xively_BatteryVFeed <- Xively.Feed (xively_FEED_ID, [xively_BatteryVChannel]);

//Function to send alerts via prowl  
function send_to_prowl(short="Short description", long="Longer description") {
    local data = {apikey=PROWL_KEY, url=http.agenturl(), application=PROWL_APP, event=short, description=long};
    http.post(PROWL_URL+"/add?" + http.urlencode(data), {}, "").sendasync(function(res) {
        if (res.statuscode != 200) {
            server.error("Prowl failed: " + res.statuscode + " => " + res.body);
        }
    })
}

//Function to send alerts via Zapier
function SendToZAP(ZapDeviceName, ZapSensor,ZapValue) {
    server.log("SentToZAP:" + ZapDeviceName);
    local data = {Rack_Name = ZapDeviceName, Sensor = ZapSensor, Value = ZapValue};
    local Jdata = http.jsonencode(data);
    local url = ZAP_URL;
	local headers = {"Content-Type":"application/json"};
	local request = http.put(url, headers, Jdata);
    //server.log("json = " + feed.ToJson());
    local response = request.sendsync();
    if (response.statuscode != 200){
        server.log("Zapier response Status code = " + response.statuscode);
    }
}

//Function to send sensor values to Xively
function SendToXively (DataSend){
    //Send Ambient Temperature to Xively
    xively_AmbTempChannel.Set(DataSend.AmbTemp);
    //server.log("Sending Ambient Temp to Xively");
    local response = x_client.Put(xively_AmbTempFeed)
    if (response.statuscode != 200){
        server.log("Xively response Status code = " + response.statuscode);
    }
    
    //Send Humidity to Xively
    xively_HumidityChannel.Set(DataSend.Humidity);
    //server.log("Sending Humidity to Xively");
    local response = x_client.Put(xively_HumidityFeed)
    if (response.statuscode != 200){
        server.log("Xively response Status code = " + response.statuscode);
    }
    
    //Send light level to Xively
    xively_LightChannel.Set(DataSend.LightLevel);
    //server.log("Sending Light Level to Xively");
    local response = x_client.Put(xively_LightFeed)
    if (response.statuscode != 200){
        server.log("Xively response Status code = " + response.statuscode);
    }
    
    //Send Door State to Xively
    xively_DoorChannel.Set(DataSend.DoorState);
    //server.log("Sending Door State to Xively");
    local response = x_client.Put(xively_DoorFeed)
    if (response.statuscode != 200){
        server.log("Xively response Status code = " + response.statuscode);
    }
    
    //Send Door Open Time to Xively
    xively_DoorTimeChannel.Set(DataSend.DoorTime);
    //server.log("Sending Door Time State to Xively");
    local response = x_client.Put(xively_DoorTimeFeed)
    if (response.statuscode != 200){
        server.log("Xively response Status code = " + response.statuscode);
    }
    
    //Send BatteryV level to Xively
    xively_BatteryVChannel.Set(DataSend.BatteryV);
    //server.log("Sending Light Level to Xively");
    local response = x_client.Put(xively_BatteryVFeed)
    if (response.statuscode != 200){
        server.log("Xively response Status code = " + response.statuscode);
    }
}

function ManageMaxMin(DataCheck,DataIn){

    DataCheck.Now = DataIn;
    //Check and set Max Value
    //server.log("Before: Max = " + DataCheck.Max + " Now = " + DataCheck.Now);
    DataCheck.Max = DataCheck.Max < DataCheck.Now ? DataCheck.Now : DataCheck.Max;
    //server.log("After: Max = " + DataCheck.Max + " Now = " + DataCheck.Now);
    
    //Check and set Min Value
    //server.log("Before: Min = " + DataCheck.Min + " Now = " + DataCheck.Now);
    DataCheck.Min = DataCheck.Min.tofloat() > DataCheck.Now ? DataCheck.Now : DataCheck.Min;
    //server.log("After: Min = " + DataCheck.Max + " Now = " + DataCheck.Now);
    return (DataCheck);
}

function AlertCheck (DataAlert, DataIn){
    //DataAlert.Now = DataIn;
    server.log(DataAlert.Name +" " + DataAlert.Now + " Alert = " + DataAlert.AlertHigh);
    if (DataAlert.AlertHigh.tofloat() <= DataAlert.Now){
        local ErrorString = DataAlert.Name + " has reached " + DataAlert.Now;
        server.log ("****" + ErrorString);
        send_to_prowl("High Alert: " + Data.DeviceInfo.Name,ErrorString);
    }
    if (DataAlert.AlertLow.tofloat() >= DataAlert.Now){
        local ErrorString = DataAlert.Name + " has reached " + DataAlert.Now;
        server.log ("****" + ErrorString);
       send_to_prowl("Low Alert: "+ Data.DeviceInfo.Name,ErrorString);
    }
    
}

function ResetData (ReSetRequest,ReSetResponse) {
    server.log("Function Command = ResetData");
    
    switch (ReSetRequest.query.Component){
        
        case "All":
            foreach(idx,val in Data){
                server.log(idx + " = " + val);
                Data[idx]["Max"] = Data[idx]["Now"];
                Data[idx]["Min"] = Data[idx]["Now"];
                server.log(Data[idx].Max + " "  + Data[idx].Now);
                server.log(Data[idx].Min + " "  + Data[idx].Now);
            }
            ReSetResponse.send(200, "Reset all Max/Min values");
            break;
    
        default:
        if(ReSetRequest.query.Component in Data && ReSetRequest.query.Type in Data[ReSetRequest.query.Component]){
            Data[ReSetRequest.query.Component][ReSetRequest.query.Type] = Data[ReSetRequest.query.Component]["Now"];
            server.log("Set " + ReSetRequest.query.Component + " " + ReSetRequest.query.Type + " " +  Data[ReSetRequest.query.Component][ReSetRequest.query.Type]);
            ReSetResponse.send(200, "Set " + ReSetRequest.query.Component + " " + ReSetRequest.query.Type + " " +  Data[ReSetRequest.query.Component][ReSetRequest.query.Type]);
        } 
    
        else {
        server.log("****Invalid Component or Type in request");
        ReSetResponse.send(404, "Invalid Component or Type in request");
        }
    }
}


function RecvData(DataRecv){   
    //Manage Max and Min values for tracked data
    Data.AmbTemp = ManageMaxMin(Data.AmbTemp,DataRecv.AmbTemp);
    Data.Humidity = ManageMaxMin(Data.Humidity,DataRecv.Humidity);
    Data.DoorTime = ManageMaxMin(Data.DoorTime,DataRecv.DoorTime);
    Data.BatteryV = ManageMaxMin(Data.BatteryV,DataRecv.BatteryV);
    
    //Check to see if any thresholds have been breached
    AlertCheck (Data.AmbTemp,DataRecv.AmbTemp);
    AlertCheck (Data.Humidity,DataRecv.Humidity);
    AlertCheck (Data.DoorTime,DataRecv.DoorTime);
    AlertCheck (Data.BatteryV,DataRecv.BatteryV);
  
    
    
    //Set local DoorState to received DoorStat
    Data.DoorState.Now = DataRecv.DoorState ? "Open" : "Closed";
    
    //Save SSID to local variable
    Data.DeviceInfo.SSID = DataRecv.SSID;
    server.log("SSID = " + Data.DeviceInfo.SSID);
    
    //Send data to Xively
     SendToXively (DataRecv);
     server.save(Data);
     
}

function DoorStateChange(DoorNewState) {
    //Set local DoorState to received DoorStat
    Data.DoorState.Now = DoorNewState ? "Open" : "Closed";
    
    //Send Door State to Xively
    xively_DoorChannel.Set(DoorNewState);
    //server.log("Sending Door State to Xively");
    local response = x_client.Put(xively_DoorFeed)
    if (response.statuscode != 200){
        server.log("****Xively Response Status code = " + response.statuscode);
    }
    
    //Send Door State to Zapier
     server.log("Send to Zap called with DataRecv.DeviceName");
     SendToZAP(Data.DeviceInfo.Name,"Door",Data.DoorState.Now);
     
     send_to_prowl("Door Alert: " + Data.DeviceInfo.Name,"Door is now " + Data.DoorState.Now);
    
}

function GetValues (GetRequest,GetResponse) {
    server.log("Function Command = GetValue");
    //foreach(idx,val in GetResponse){
    //    server.log(idx + " = " + val);
    //}
    if(GetRequest.query.Component in Data && GetRequest.query.Type in Data[GetRequest.query.Component]){
        
        if(typeof Data[GetRequest.query.Component][GetRequest.query.Type] == "string"){
            server.log("String value requested");
            GetResponse.send(200, Data[GetRequest.query.Component][GetRequest.query.Type]);
        }
        else{
            server.log("Not DoorState " + GetRequest.query.Component);
            server.log(format("Get %s = %2.1f",GetRequest.query.Component,Data[GetRequest.query.Component][GetRequest.query.Type]));
            GetResponse.send(200, format("%2.1f",Data[GetRequest.query.Component][GetRequest.query.Type]));
        }
    } 
    else {
        server.log("****Invalid Component or Type in GetValues request");
        GetResponse.send(404, "Invalid Component or Type in request");
    }
}

function SetValue (SetRequest,SetResponse) {
    //server.log("Function Command = SetValue");
    if(SetRequest.query.Component in Data && SetRequest.query.Type in Data[SetRequest.query.Component]){
        Data[SetRequest.query.Component][SetRequest.query.Type] = SetRequest.query.Value;
        server.log("Set " + SetRequest.query.Component + " " + SetRequest.query.Type + " " + SetRequest.query.Value);
        SetResponse.send(200, "Set " + SetRequest.query.Component + " " + SetRequest.query.Type + " " + SetRequest.query.Value );
        server.save(Data);
    } 
    else {
        server.log("****Invalid Component or Type in request");
        SetResponse.send(404, "Invalid Component or Type in request");
    }     }


function PowerSwitch(PwrRequest,PwrResponse){
    //server.log("Function Command = SetValue");
    server.log(SwitchList.find(PwrRequest.query.Component));
    server.log(SwitchList);
    server.log(PwrRequest.query.Component);
    
    //Check to see if the Component and Type are valid
    if(SwitchList.find(PwrRequest.query.Component) && SwitchCommands.find(PwrRequest.query.Type)){
        device.send("PowerSwitch",PwrRequest.query);
        PwrResponse.send(200, "Set " + PwrRequest.query.Component + " " + PwrRequest.query.Type + " ");
    } 
    else {
        server.log("****Invalid Component or Type in request" +" " + PwrRequest.query.Component + " " + PwrRequest.query.Type);
        PwrResponse.send(404, "Invalid Component or Type in request" +" " + PwrRequest.query.Component + " " + PwrRequest.query.Type);
    }     
}


function requestHandler(request, response) {
  server.log("HTTP Request received");
  server.log("Method is " + request.method);
  //foreach(index,val in request.query) {
  //   server.log(index + " = " + val);
  //  }
  
    switch (request.query.Command) {
        case "GetValue" :
        server.log("Main Command = GetValue");
        GetValues(request,response);
        break;
        
        case "SetValue" :
        server.log("Main Command = SetValue");
        SetValue(request,response);
        //response.send(200,"Main Command = SetValue");
        break;
        
        case "ResetData" :
        server.log("Main Command = ResetData");
        ResetData(request,response);
        //response.send(200,"Main Command = ResetData");
        break;
        
        case "PowerSwitch" :
        server.log("Main Command = PowerSwitch");
        PowerSwitch(request,response);
        //response.send(200,"Main Command = ResetData");
        break;
        
        default:
        server.log("****Invalid command in request" + request.query.Command);
        response.send(404, "Invalid command in request" + request.query.Command)
        break;
        
    }
    server.save(Data);
}

function RecvHardwareID(RecvHardwareID){
    HardwareID = RecvHardwareID;
    server.log("RecvHardwareID:HardwareID = " + HardwareID);
}

//Setup Xively client
x_client <- Xively.Client(xively_API_KEY);

//Setup device handlers
device.on("DoorChanged", DoorStateChange);
device.on("DataSend", RecvData);
device.on("SendHardwareID", RecvHardwareID); 

//Setup HTTP request handler
http.onrequest(requestHandler);
