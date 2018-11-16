// Matrix Clock
// Copyright 2016-18, Tony Smith

// IMPORTS
// NOTE If you're not using Squinter or an equivalent tool,
// cut and paste the named library's code over the following line
#import "HT16K33MatrixCustom.class.nut"
#import "../generic/utilities.nut"
#import "../generic/disconnect.nut"


// CONSTANTS
const DISCONNECT_TIMEOUT = 60;
const RECONNECT_TIMEOUT = 15;
const TICK_DURATION = 0.5;
const TICK_TOTAL = 4;
const HALF_TICK_TOTAL = 2;
const ALARM_DURATION = 2;
const INITIAL_ANGLE = 0;


// GOLBAL VARIABLES
// Objects
local display = null;
local tickTimer = null;
local syncTimer = null;
local settings = null;
local alarms = [];

// Numeric values
local seconds = 0;
local minutes = 0;
local hours = 0;
local dayw = 0;
local day = 0;
local month = 0;
local year = 0;
local tickCount = 0;
local disTime = 0;

// Runtime flags
local isDisconnected = false;
local isConnecting = false;
local isPM = false;
local isAdvanceSet = false;
local tickFlag = true;
local debug = false;

// Disconnected/connected animation
local ca = [0,7,1,7,1,6,0,6];
local cc = 0;

// Alarms
local alarmState = 0;


// TIME AND DISPLAY CONTROL FUNCTIONS
function clockTick() {
    // This is the main clock loop
    // Queue the function to run again in tickDuration seconds
    tickTimer = imp.wakeup(TICK_DURATION, clockTick);

    // Get the current time from the imp's RTC
    local now = date();
    hours = now.hour;
    minutes = now.min;
    seconds = now.sec;
    dayw = now.wday;
    day = now.day;
    month = now.month;
    year = now.year;

    // Update the value of 'hours' to reflect displayed time
    if (settings.utc) {
        // If UTC is set, add the international time offset
        hours = hours + settings.offset - 12;
        if (hours > 24) {
            hours = hours - 24;
        } else if (hours < 0) {
            hours = hours + 24;
        }
    } else {
        // We are displaying local time -
        // is daylight savings being observed?
        if (settings.bst && utilities.bstCheck()) hours++;
        if (hours > 23) hours = 0;
    }

    // AM or PM?
    isPM = hours > 11 ? true : false;

    // Update the tick counter and flag
    tickCount = tickCount == TICK_TOTAL ? 0 : tickCount + 1;
    tickFlag = tickCount < HALF_TICK_TOTAL ? true : false;

    // ADDED IN 2.1.0
    // Should the display be enabled or not?
    if (settings.timer.isset) {
        local should = shouldShowDisplay();
        if (settings.on != should) {
            // Change the state of the display
            setDisplay(should);
            settings.on = should;
        }
    }

    // Present the current time
    if (settings.on) displayTime();
}

function shouldShowDisplay() {
    // ADDED IN 2.1.0
    // Returns true if the display should be on, false otherwise - default is true / on
    // If we have auto-dimming set, we need only check whether we need to turn the display off
    // NOTE The function should only be called if 'settings.timer.isset' is true, ie. we're
    //      in night mode

    // Assume we will enable the display
    local shouldShow = true;

    // Should we disable the advance? Only if it's set and we've hit the start or end end 
    // of the night period
    // NOTE 'isAdvanceSet' is ONLY set if 'settings.timer.isset' is TRUE
    if (isAdvanceSet) {
        // 'isAdvanceSet' is unset when the next event time (display goes on or off) is reached
        if (hours == settings.timer.on.hour && minutes >= settings.timer.on.min) isAdvanceSet = false;
        if (hours == settings.timer.off.hour && minutes >= settings.timer.on.min) isAdvanceSet = false;
    }

    // Have we crossed into the night period? If so, unset 'shouldShow'
    // Check by converting all times to minutes
    local start = settings.timer.on.hour * 60 + settings.timer.on.min;
    local end = settings.timer.off.hour * 60 + settings.timer.off.min;
    local now = hours * 60 + minutes;
    local delta = end - start;
    
    // End and start times are identical
    if (delta == 0) return !isAdvanceSet;
    
    if (delta > 0) {
        if (now >= start && now < end) shouldShow = false;
    } else {
        if (now >= start || now < end) shouldShow = false;
    }

    // 'isAdvancedSet' inverts the expected state
    return (isAdvanceSet ? !shouldShow : shouldShow);
}

function setDisplay(state) {
    // ADDED IN 2.1.0
    // Power up or power down the display according to the supplied state (true or false)
    if (state) {
        powerUp();
        agent.send("display.state", { "on" : true, "advance" : isAdvanceSet });
        if (debug) server.log("Brightening display at " + format("%02i", hours) + ":" + format("%02i", minutes));
    } else {
        clearDisplay();
        powerDown();
        agent.send("display.state", { "on" : false, "advance" : isAdvanceSet });
        if (debug) server.log("Dimming display at " + format("%02i", hours) + ":" + format("%02i", minutes));
    }
}

function displayTime() {
    // The main function for updating the display
    
    // Set the digit counters a and b
    local a = hours;
    local b = 0;

    // Set the hours
    if (settings.mode) {
        // 24-hour clock
        if (a < 10) {
            display[0].displayChar(48, 3);
            display[1].displayChar(48 + a, 1);
        } else if (a > 9 && a < 20) {
            display[0].displayChar(49, 3);
            display[1].displayChar(38 + a, 1);
        } else if (a > 19) {
            display[0].displayChar(50, 3);
            display[1].displayChar(28 + a, 1);
        }
    } else {
        // 12-hour clock
        if (a == 12 || a == 0 ) {
            display[0].displayChar(49, 3);
            display[1].displayChar(50, 1);
        } else if (a < 10) {
            display[0].displayChar(32, 3);
            display[1].displayChar(48 + a, 1);
        } else if (a == 10 || a == 11) {
            display[0].displayChar(49, 3);
            display[1].displayChar(38 + a, 1);
        } else if (a > 12 && a < 22) {
            display[0].displayChar(32, 3);
            display[1].displayChar(36 + a, 1);
        } else if (a == 22 || a == 23) {
            display[0].displayChar(49, 3);
            display[1].displayChar(26 + a, 1);
        }
    }

    // Set the minutes
    if (minutes > 9) {
        a = minutes;
        while (a >= 0) {
            a = a - 10;
            b++;
        }

        display[2].displayChar(47 + b, 2);
        display[3].displayChar(48 + minutes - (10 * (b - 1)), 0);
    } else {
        display[2].displayChar(48, 2);
        display[3].displayChar(48 + minutes, 0);
    }

    // Is the clock disconnected? If so, flag the fact
    // with a 2x2 square in the top left corner of the display
    if (isDisconnected && !isConnecting) display[0].plot(0, 7, 1).plot(0, 6, 1).plot(1, 7, 1).plot(1, 6, 1);

    // Is the clock connecting? If so, display the fact with animation:
    // A single square circling the 2x2 squares in the top left corner of the display
    if (isConnecting) {
        cc += 2;
        if (cc > 6) cc = 0;
        display[0].plot(ca[cc], ca[cc + 1], 1);
    }

    // AM or PM?
    // Plot a 2x2 square in the bottom right corner of the display
    if (!settings.mode && isPM) display[3].plot(7, 7, 1).plot(7, 6, 1).plot(6, 7, 1).plot(6, 6, 1);

    // UTC
    // Plot a 2x2 square in the top right corner of the display
    if (settings.utc) display[3].plot(7, 1, 1).plot(7, 0, 1).plot(6, 1, 1).plot(6, 0, 1);

    // Check whether the colon should appear
    if (settings.colon) {
        // Colon is set to be displayed. Will it flash?
        if (settings.flash) {
            if (tickFlag) drawColon();
        } else {
            drawColon();
        }
    }

    // Draw the display
    updateDisplay();
}

function drawColon() {
    // Set the colon on the display: two 2x2 squares spanning LEDs 1 and 2
    display[1].plot(7, 6, 1).plot(7, 5, 1);
    display[1].plot(7, 1, 1).plot(7, 2, 1);
    display[2].plot(0, 6, 1).plot(0, 5, 1);
    display[2].plot(0, 1, 1).plot(0, 2, 1);
}

function updateDisplay() {
    // Tell all four LEDs to draw their buffers
    display[0].draw();
    display[1].draw();
    display[2].draw();
    display[3].draw();
}

function powerUp() {
    display[3].powerUp();
    display[2].powerUp();
    display[1].powerUp();
    display[0].powerUp();
}

function powerDown() {
    display[0].powerDown();
    display[1].powerDown();
    display[2].powerDown();
    display[3].powerDown();
}

function setBrightness(br) {
    display[0].setBrightness(br);
    display[1].setBrightness(br);
    display[2].setBrightness(br);
    display[3].setBrightness(br);
}

function clearDisplay() {
    display[0].clearDisplay();
    display[1].clearDisplay();
    display[2].clearDisplay();
    display[3].clearDisplay();
}

function syncText() {
    // Display 'SYNC' after the clock is powered up and until it receives its preferences from the agent
    if (!settings.on) return;
    local letters = [0x53, 0x79, 0x6E, 0x63];
    foreach (index, char in letters) display[index].displayChar(char, 2);
    updateDisplay();
}


// PREFERENCES FUNCTIONS
function setPrefs(prefsTable) {
    // Cancel the 'Sync' display timer if it has yet to fire
    if (debug) server.log("Received preferences from agent");
    if (syncTimer) imp.cancelwakeup(syncTimer);
    syncTimer = null;

    // Set the debug state
    if ("debug" in prefsTable) setDebug(prefsTable.debug);

    // Parse the set-up data table provided by the agent
    settings.mode = prefsTable.hrmode;
    settings.bst = prefsTable.bst;
    settings.flash = prefsTable.flash;
    settings.colon = prefsTable.colon;
    settings.utc = prefsTable.utc;
    settings.offset = prefsTable.utcoffset;
    settings.timer.on.hour = prefsTable.timer.on.hour;
    settings.timer.on.min = prefsTable.timer.on.min;
    settings.timer.off.hour = prefsTable.timer.off.hour;
    settings.timer.off.min = prefsTable.timer.off.min;
    settings.timer.isset = prefsTable.timer.isset;
    isAdvanceSet = prefsTable.timer.isadv;

    // ADDED 2.1.0: Make use of display disable times
    // NOTE We change settings.on, so the the local state record, settings.on,
    //      is correctly updated in the next stanza
    if (settings.timer.isset) {
        local now = date();
        if (now.hour > settings.timer.on.hour || now.hour < settings.timer.off.hour) prefsTable.on = false;
        if (now.hour == settings.timer.off.hour && now.min >= settings.timer.off.min) prefsTable.on = false;
        if (now.hour == settings.timer.on.hour && now.min < settings.timer.on.min) prefsTable.on = false;
    }

    // Set the display state
    if (settings.on != prefsTable.on) setLight(prefsTable.on);

    // Set the brightness
    if (settings.brightness != prefsTable.brightness) {
        settings.brightness = prefsTable.brightness;

        // Only set the brightness now if the display is on
        if (settings.on) setBrightness(prefsTable.brightness);
    }

    // Only call clockTick() if we have come here *before*
    // the main clock loop, which sets tickTimer, has started
    if (tickTimer == null) clockTick();
}

function setMode(value) {
    // This function is called when 12/24 modes are switched by app
    // 'value' is passed in from the agent as a bool
    if (debug) server.log("Setting 24-hour mode " + (value ? "on" : "off"));
    settings.mode = value;
}

function setBST(value) {
    // This function is called when the app sets or unsets BST
    // 'value' is passed in from the agent as a bool
    if (debug) server.log("Setting BST monitoring " + (value? "on" : "off"));
    settings.bst = value;
}

function setUTC(value) {
    // This function is called when the app sets or unsets UTC
    if ("state" in value) {
        settings.utc = value.state;
        if (debug) server.log("Setting UTC " + (value.state ? "on" : "off"));
    }

    if ("offset" in value) settings.offset = value.offset;
}

function setBright(brightness) {
    // This function is called when the app changes the clock's brightness
    // 'brightness' is passed in from the agent as an integer
    if (brightness < 0 || brightness > 15 || brightness == settings.brightness) return;
    if (debug) server.log("Setting display brightness " + brightness);
    settings.brightness = brightness;
    
    // Tell the display(s) to change their brightness
    setBrightness(brightness);
}

function setFlash(value) {
    // This function is called when the app sets or unsets the colon flash
    // 'value' is passed in from the agent as a bool
    if (debug) server.log("Setting colon flash " + (value ? "on" : "off"));
    settings.flash = value;
}

function setColon(value) {
    // This function is called when the app sets or unsets the colon flash
    // 'value' is passed in from the agent as a bool
    if (debug) server.log("Setting colon state " + (value ? "on" : "off"));
    settings.colon = value;
}

function setLight(value) {
    // This function is called when the app turns the clock display on or off
    // 'value' is passed in from the agent as a bool
    if (debug) server.log("Setting light " + (value ? "on" : "off"));
    
    // ADDED IN 2.1.0
    if (settings.timer.isset) {
        // If we're in night mode, we treat this as an advance of the timer
        // NOTE This will cause settings.on to be set elsewhere (see 'clockTick()')
        isAdvanceSet = !isAdvanceSet;
    } else {
        // We're not in night mode, so just turn the light off
        settings.on = value;
        setDisplay(value);        
    }
}

function setDebug(state) {
    // Enable or disble debugging messaging in response to a message from the UI via the agent
    debug = state;
    server.log("Setting device-side debug messages " + (state ? "on" : "off"));
}

function setNight(value) {
    // ADDED IN 2.1.0
    // This function is called when the app enables or disables night mode
    
    // Just set the preference because it will be applied almost immediately
    // via the 'clockTick()' loop
    settings.timer.isset = value;     

    // Disable the timer advance setting as it's only relevant if night mode is
    // on AND it has been triggered since night mode was enabled
    isAdvanceSet = false;

    if (debug) server.log("Setting nightmode " + (value ? "on" : "off"));
}

function setNightTime(data) {
    // ADDED IN 2.1.0
    // Record the times at which the display may turn on and off
    // NOTE The display will not actually change at these times unless
    //      'settings.timer.isset' is set, ie. we're in night mode
    settings.timer.on.hour = data.on.hour;
    settings.timer.on.min = data.on.min;
    settings.timer.off.hour = data.off.hour;
    settings.timer.off.min = data.off.min;
    
    if (debug) server.log("Matrix Clock night dimmer to start at " + format("%02i", settings.timer.on.hour) + ":" + format("%02i", settings.timer.on.min) + " and end at " + format("%02i", settings.timer.off.hour) + ":" + format("%02i", settings.timer.off.min));
}

function setDefaultPrefs() {
    // Initialise the clock's local preferences store
    settings = {};
    settings.on <- true;
    settings.mode <- true;
    settings.bst <- true;
    settings.colon <- true;
    settings.flash <- true;
    settings.brightness <- 15;
    settings.utc <- false;
    settings.offset <- 12;
    settings.alarms <- [];
    settings.timer <- { "on"  : { "hour" : 7,  "min" : 00 }, 
                        "off" : { "hour" : 22, "min" : 30 },
                        "isset" : false };
}


// OFFLINE OPERATION FUNCTIONS
function discHandler(event) {
    // Called if the server connection is broken or re-established
    if ("message" in event) server.log("Connection Manager: " + event.message + " @ " + event.ts.tostring());

    if ("type" in event) {
        if (event.type == "disconnected") {
            isDisconnected = true;
            isConnecting = false;
            disTime = event.ts;
        }

        if (event.type == "connecting") isConnecting = true;

        if (event.type == "connected") {
            // Check for settings changes
            agent.send("clock.get.prefs", 1);
            isDisconnected = false;
            isConnecting = false;
            
            if (disTime != 0) {
                local delta = event.ts - disTime;
                if (debug) server.log("Disconnection duration: " + delta + " seconds");
                disTime = 0;
            }
        }
    }
}


// START PROGRAM

// Load in generic boot message code
#include "../generic/bootmessage.nut"

// Load in default prefs
setDefaultPrefs();

// Set up the network disconnection handler
disconnectionManager.eventCallback = discHandler;
disconnectionManager.reconnectDelay = DISCONNECT_TIMEOUT;
disconnectionManager.reconnectTimeout = RECONNECT_TIMEOUT;
disconnectionManager.start();

// Configure the display bus
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);

// Set up the clock display: 0-3 (L-R)
display = [];
display.append(HT16K33MatrixCustom(hardware.i2c89, 0x70));
display.append(HT16K33MatrixCustom(hardware.i2c89, 0x71));
display.append(HT16K33MatrixCustom(hardware.i2c89, 0x74));
display.append(HT16K33MatrixCustom(hardware.i2c89, 0x75));

// Set the initial brightness and display angle
foreach (face in display) face.init(15, INITIAL_ANGLE);

// Show the ‘sync’ message then give the text no more than
// 30 seconds to appear. If the prefs data comes from the
// agent before then, the text will automatically be cleared
// (and the timer cancelled)
syncText();
syncTimer = imp.wakeup(30.0, clockTick);

// Set up Agent notification response triggers
// First, settings-related actions
agent.on("clock.set.prefs", setPrefs);
agent.on("clock.set.bst", setBST);
agent.on("clock.set.mode", setMode);
agent.on("clock.set.utc", setUTC);
agent.on("clock.set.brightness", setBright);
agent.on("clock.set.flash", setFlash);
agent.on("clock.set.colon", setColon);
agent.on("clock.set.light", setLight);
agent.on("clock.set.debug", setDebug);
//agent.on("clock.set.alarm", setAlarm);
//agent.on("clock.clear.alarm", clearAlarm);
//agent.on("clock.stop.alarm", stopAlarm);
agent.on("clock.set.nightmode", setNight);
agent.on("clock.set.nighttime", setNightTime);

// Next, other actions
agent.on("clock.do.reboot", function(dummy) {
    imp.reset();
});

// Get preferences from server
// NOTE no longer need this here as it's handled via DisconnectManager
// agent.send("clock.get.prefs", true);
// if (debug) server.log("Requesting preferences from agent");