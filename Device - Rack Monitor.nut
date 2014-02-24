//Device code for Rack Monitor
//Monitors Ambient Temparature, Humidity and Door status


//Setup program constants
PollTimer <- 10.0    //Time between sensor polls in seconds
SendTimer <- 30.0 //Time between sending data to the server agent in seconds
SendTimerStart <- 0 //Use to mark the start of send time period
Open <- 1; //Set door open status value
Closed <- 0; //Set door closed status value
DoorOpenStart <- 0.0;  //Initialise door open time counter
DataCount <- 0; //Initialise datacounte variable to calculate averave values
On <- 1;
Off <- 0;
PowerCycleTime <- 30;




//Setup data tables
//Setup variables to track current values
Data <- {DeviceName = "", AmbTemp = 0.0, Humidity = 0.0, LightLevel = 0, DoorTime = 0.0, DoorState=0.0, BatteryV=0.0,SSID="Blank"};
//Setup variable to track cumulative values between sending to the server agent
Cumulative <- {DeviceName = "", AmbTemp = 0.0, Humidity = 0.0, LightLevel = 0, DoorTime = 0.0, DoorState=0.0,BatteryV=0.0,SSID="Blank"};
//Setup calculated variable to send to the server agent
ServerData <- {DeviceName = "", AmbTemp = 0.0, Humidity = 0.0, LightLevel = 0, DoorTime = 0.0, DoorState=0.0,BatteryV=0.0,SSID="Blank"};


//Setup LCD Display
//LCD <- hardware.uart57;
//LCD.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);

//setup door sensor
PinDoor <- hardware.pin2;

//setup humidity sensor input
PinHumidity <- hardware.pin8;
PinHumidity.configure(ANALOG_IN);
humidity_const <- 0.033; //constant for sensor


//setup ambient temperature input
BalanceRes <- 9850;  //Using the actual measured value of the resistor
PinAmbTemp <- hardware.pin9;
PinAmbTemp.configure(ANALOG_IN);

//Setup RGB LED pins and constants
LED_PowerOn <- 1.0;
LED_PowerOff <- 0.5;
LED_DoorOpen <- 1.0;
LED_DoorClosed <- 0.0;

PinLEDPower <- hardware.pin7;
PinLEDPower.configure(PWM_OUT,1.0/400,LED_PowerOn);
PinLEDDoor <- hardware.pin5;
PinLEDDoor.configure(PWM_OUT,0.0,0.0);

Switch01 <- hardware.pin1;
Switch01.configure(DIGITAL_OUT);
PowerCycleTime <- 30;

//Store WiFi Name
ServerData.SSID = imp.getssid();

/*
//******Start of LCD screen functions
//clears the screen
function clearScreen(){
    //server.log("Clear Screen");
    LCD.write(0xFE);
    LCD.write(0x01); 
}

function counter()
{
  //this function prints a simple counter that counts to 10
  clearScreen();
  for (local i = 0; i <= 10; i++) {
    LCD.write(format("Counter = %d",i));
    imp.sleep(0.5);
    clearScreen();
  }
}

function selectLineOne()
{ 
  //puts the cursor at line 0 char 0.
  LCD.write(0xFE); //command flag
  LCD.write(128); //position
}
 
function selectLineTwo()
{ 
  //puts the cursor at line 0 char 0.
  LCD.write(0xFE); //command flag
  LCD.write(192); //position
}
 
function moveCursorRightOne()
{
  //moves the cursor right one space
  LCD.write(0xFE); //command flag
  LCD.write(20); // 0x14
}
 
function moveCursorLeftOne()
{
  //moves the cursor left one space
  LCD.write(0xFE); //command flag
  LCD.write(16); // 0x10
}
 
function scrollRight()
{
  //same as moveCursorRightOne
  LCD.write(0xFE); //command flag
  LCD.write(20); // 0x14
}
 
function scrollLeft()
{
  //same as moveCursorLeftOne
  LCD.write(0xFE); //command flag
  LCD.write(24); // 0x18
}
 
function turnDisplayOff()
{
  //this tunrs the display off, but leaves the backlight on. 
  LCD.write(0xFE); //command flag
  LCD.write(8); // 0x08
}
 
function turnDisplayOn()
{
  //this turns the dispaly back ON
  LCD.write(0xFE); //command flag
  LCD.write(12); // 0x0C
}
 
function underlineCursorOn()
{
  //turns the underline cursor on
  LCD.write(0xFE); //command flag
  LCD.write(14); // 0x0E
}
 
function underlineCursorOff()
{
  //turns the underline cursor off
  LCD.write(0xFE); //command flag
  LCD.write(12); // 0x0C
}
 
function boxCursorOn()
{
  //this turns the box cursor on
  LCD.write(0xFE); //command flag
  LCD.write(13); // 0x0D
}
 
function boxCursorOff()
{
  //this turns the box cursor off
  LCD.write(0xFE); //command flag
  LCD.write(12); // 0x0C
}
 
function toggleSplash()
{
  //this toggles the spalsh screenif off send this to turn onif on send this to turn off
  LCD.write(0x7C); //command flag = 124 dec
  LCD.write(9); // 0x09
}

// 128 = OFF, 157 = Fully ON, everything inbetween = varied brightnbess  
function backlight(brightness)
{
  //this function takes an int between 128-157 and turns the backlight on accordingly
  LCD.write(0x7C); //NOTE THE DIFFERENT COMMAND FLAG = 124 dec
  LCD.write(brightness); // any value between 128 and 157 or 0x80 and 0x9D
}

//*****End of LCD Screen functions

*/

//Write current temp and mumidity to the LCD Screen
function LCDWriteTempHumid(Temp,Humid){
    clearScreen();
    selectLineOne();
    LCD.write(format("Temp     %2.2fC",Temp));
    
    selectLineTwo();
    LCD.write(format("Humidity %2.2f%%",Humid));
    
}

//Rounding function
function RoundNum(Num,Digits){
    local IntPart = math.floor(Num);
    local FloatPart = (Num-IntPart);
    FloatPart = math.floor(FloatPart * math.pow(10,Digits))/(math.pow(10,Digits));
    local FinalNum = IntPart + FloatPart;
    return(FinalNum);
}

//This function runs when the status of the door changes.
function DoorChange(){
    server.log("DoorChange:Door Status Changed");
    imp.sleep(1.0);  //Wait 1,000ms for debounce
    local DoorTmp = PinDoor.read();
    agent.send("DoorChanged", DoorTmp);
    if (DoorTmp == Open){
        Data.DoorState = 1;
        server.log("Door Opened");
        DoorOpenStart = hardware.millis();
        PinLEDDoor.configure(PWM_OUT,1.0,1.0);
        //turnDisplayOn();
        //backlight(154);
        //clearScreen();
       // LCD.write("Door Open")
       // imp.sleep(0.5);
        //LCDWriteTempHumid(Data.AmbTemp,Data.Humidity);
        
    }
    else {
        Data.DoorState = 0;
        Data.DoorTime = (hardware.millis() - DoorOpenStart)/1000;
        server.log("Door closed and was open for " + Data.DoorTime + " seconds.");
        PinLEDDoor.configure(PWM_OUT,0.0,0.0);
        
        //Reset door timers
        Data.DoorTime = 0;
        Cumulative.DoorTime=0;
        DoorOpenStart = 0;
    }
}

//Reads the door state
function ReadDoor() {
    local DoorTmp = PinDoor.read();
    DoorOpenStart = DoorOpenStart == 0 ? hardware.millis() : DoorOpenStart;
    if (DoorTmp == Open){
        PinLEDDoor.configure(PWM_OUT,1.0,LED_DoorOpen);
        local TmpTime = (hardware.millis() - DoorOpenStart)/1000.0;
        server.log("TmpTime = " + TmpTime);
        return(TmpTime);
    }
    else {
        PinLEDDoor.configure(PWM_OUT,0.0,LED_DoorClosed);
        return(0);
    }

}

//Reads the current temperature from the ambient sensor.
function ReadAmbTemp() {
    local R1 = (65536.0 * BalanceRes/PinAmbTemp.read()) - BalanceRes;
    local R1 = math.log(R1);
    local Temp = 1 / (0.001129148 + (0.000234125 * R1) + (0.0000000876741 * R1 * R1 * R1));
    //server.log(format("Kelvin = %.2f",Temp));
    Temp=Temp-273.15;
    //server.log(format("Celcuis = %.2f",Temp));
    return(Temp);
}

//Reads the current humidity from the humidity sensor
function ReadHumidity() {
    local HumidTmp = ((hardware.voltage()/65536.0)*PinHumidity.read())/humidity_const;
    //server.log("Humidity = " + HumidTmp);
    return(HumidTmp);
}

//Reads the current light level from the onboard light sensor
function ReadLightLevel() {
    return(RoundNum((hardware.lightlevel().tofloat()/65536.0)*100,1));
}

// sends data to the server
function SendData() {
    // send sensor data to agent
    //server.log("Ambient Temp = "+ ServerData.AmbTemp);
   // server.log("Humidity = "+ ServerData.Humidity);
    //server.log("Light Level = " + ServerData.LightLevel);
   // server.log("Door Time = " + ServerData.DoorTime);
    //server.log("Door Cumulative Time = " + Cumulative.DoorTime);
    //server.log("Door State = " + ServerData.DoorState);
    agent.send("DataSend", ServerData);
    
}

//Reads all sensor values
function SensorRead() {
    Data.AmbTemp = RoundNum(ReadAmbTemp(),2);
    Data.Humidity = RoundNum(ReadHumidity(),2);
    Data.LightLevel = ReadLightLevel();
    Data.DoorTime = ReadDoor();
    Data.BatteryV = hardware.voltage();
    server.log("SensorRead:Data.DoorTime = " + Data.DoorTime);
    
}

//Controls the power switches
function PowerSwitch(PwrCommand){
    server.log(format("PowerSwitch:Command = %s Component = %s Type = %s",PwrCommand.Command,PwrCommand.Component,PwrCommand.Type));
    switch (PwrCommand.Type) {
        case "On" :
        server.log("PowerSwitch: On")
        server.log(format("PowerAwitch:Command = turn %s %s",PwrCommand.Component,PwrCommand.Type));
        switch (PwrCommand.Component){
            
            case "Switch01" :
            Switch01.write(On);
            break;
        }
        break;
        
        case "Off" :
        server.log("PowerAwitch: Off")
        server.log(format("PowerAwitch:Command = turn %s %s",PwrCommand.Component,PwrCommand.Type));
        switch (PwrCommand.Component){
            
            case "Switch01" :
            Switch01.write(Off);
            break;
        }
        break;
        
        case "Cycle" :
        server.log("PowerAwitch: Cycle")
        server.log(format("PowerAwitch:Command = turn %s %s",PwrCommand.Component,PwrCommand.Type));
        switch (PwrCommand.Component){
            
            case "Switch01" :
            Switch01.write(Off);
            imp.sleep(PowerCycleTime);
            Switch01.write(On);
            break;
        }
        break;
    }
}

//This is the programs main control loop
function MainLoop(){
    //server.log("Main Loop Start");
    //Initialise send timer
    SendTimerStart = SendTimerStart == 0 ? hardware.millis() : SendTimerStart;
    PinLEDPower.configure(PWM_OUT,1.0/4000,0.5);
    
    //Read all sensors
    SensorRead();
    //Increment cumulative values to calculate averages later
    DataCount ++;
    Cumulative.AmbTemp += Data.AmbTemp;
    Cumulative.Humidity += Data.Humidity;
    Cumulative.LightLevel += Data.LightLevel;
    Cumulative.DoorTime = Data.DoorTime;
    Cumulative.BatteryV += Data.BatteryV;
    server.log("MainLoop:Cumulative.DoorTime = " + Cumulative.DoorTime + " Seconds");
    

    //server.log(format("Count = %d, AmbTemp = %2.2f, Humidity = %2.2f, Lightlevel = %2.2f, DoorTime = %2.2f, Cumulative DoorTime = %2.2f",DataCount, Cumulative.AmbTemp, Cumulative.Humidity, Cumulative.LightLevel, Cumulative.DoorTime,Cumulative.DoorTime));

    //Write values to the LCD Screen only if the door is open
    if (Data.DoorState == Open) {
        //turnDisplayOn();
        //backlight(154);
        //clearScreen();
       // LCD.write("Door Open")
        //imp.sleep(0.5);
        //LCDWriteTempHumid(Data.AmbTemp,Data.Humidity);
    }
    else {
        //clearScreen();
        //backlight(129);
        //LCD.write("Door Closed");
       // imp.sleep(1.0);
       // clearScreen();
        //LCDWriteTempHumid(Data.AmbTemp,Data.Humidity);
        //turnDisplayOff();
       
    }
    
    //Check to see if it is time to send data to the server, if yes then calucluate average values and send to server.
    if ((hardware.millis() - SendTimerStart) > (SendTimer * 1000.0)){
        //Calculate average values to send to the server
        ServerData.AmbTemp = RoundNum(Cumulative.AmbTemp/DataCount,2);
        ServerData.Humidity = RoundNum(Cumulative.Humidity/DataCount,2);
        ServerData.LightLevel = RoundNum(Cumulative.LightLevel/DataCount,2);
        ServerData.BatteryV = RoundNum(Cumulative.BatteryV/DataCount,2);
        
        //For Door open time, send cumulative and current open time data in minutes
        ServerData.DoorTime = RoundNum(Cumulative.DoorTime / 60.0,2);
        server.log("Server.DoorTime = " + ServerData.DoorTime);
        server.log("Cumilative.DoorTime = " + Cumulative.DoorTime);
        server.log("Hardware voltage = " + ServerData.BatteryV);
       
        
        ServerData.DoorState = Data.DoorState;
        
        //Reset counter and cumulative values
        DataCount = 0;
        Cumulative.AmbTemp = 0;
        Cumulative.Humidity = 0;
        Cumulative.LightLevel = 0;
        Cumulative.BatteryV = 0;
        //Cumulative.DoorTime = 0;
        
        SendData();
        SendTimerStart = hardware.millis();
    }
    
    //Wait for poll time before running again
    imp.wakeup(PollTimer, MainLoop);
    
    
}

//Setup interupt handler for door state change
PinDoor.configure(DIGITAL_IN_PULLUP,DoorChange); 


// Send harware ID on request from the agend
agent.on("GetHardwareID", function(SendHardwareID) {
    // immediately send a reply with hardware ID
    agent.send("SendHardwareID", hardware.getdeviceid());
}); 

agent.on("PowerSwitch",PowerSwitch);

MainLoop();
