// Matrix Clock
// Copyright 2016-18, Tony Smith

// IMPORTS
#import "../generic/utilities.nut"
#import "../generic/disconnect.nut"
#import "HT16K33MatrixCustom.class.nut"

// CONSTANTS
const DISCONNECT_TIMEOUT = 60;
const RECONNECT_TIMEOUT = 15;
const TICK_DURATION = 0.5;
const INITIAL_ANGLE = 0;

// GLOBALS
local faces = null;
local tickTimer = null;
local syncTimer = null;
local prefs = null;
local isDisconnected = false;
local isConnecting = false;
local tickCount = 0;
local tickFlag = true;
local tickTotal = (1.0 / TICK_DURATION).tointeger() * 2;
local halfTickTotal = tickTotal / 2;
local isPM = false;
local isAdvanceSet = false;
local debug = false;
local ca = [0,7,1,7,1,6,0,6];
local cc = 0;

local seconds = 0;
local minutes = 0;
local hour = 0;
local dayw = 0;
local day = 0;
local month = 0;
local year = 0;

// TIME FUNCTIONS
function getTime() {
    // This is the main clock loop
    // Queue the function to run again in tickDuration seconds
    tickTimer = imp.wakeup(TICK_DURATION, getTime);

    // Get the current time from the RTC and store parameters
    local now = date();
    seconds = now.sec;
    minutes = now.min;
    hour = now.hour;
    dayw = now.wday;
    day = now.day;
    month = now.month;
    year = now.year;

    // Update the value of 'hours' to reflect displayed time
    if (prefs.utc) {
        // If UTC is set, add the international time offset
        hour = hour + prefs.offset - 12;
        if (hour > 24) {
            hour = hour - 24;
        } else if (hour < 0) {
            hour = hour + 24;
        }
    } else {
        // We are displaying local time -
        // is daylight savings being observed?
        if (prefs.bst && utilities.bstCheck()) hour++;
        if (hour > 23) hour = 0;
    }

    // AM or PM?
    isPM = (hour > 11) ? true : false;

    // Update the tick counter
    tickCount++;
    if (tickCount >= tickTotal) tickCount = 0;
    tickFlag = (tickCount < halfTickTotal) ? true : false;

    local shouldShow = showDisplay();
    if (prefs.on != shouldShow) {
        // Change of state
        setDisplay(shouldShow);
        prefs.on = shouldShow;
    }

    // Present the current time
    if (prefs.on) displayTime();
}

function showDisplay() {
    // ADDED IN 2.10
    // Returns true if the display should be on, false otherwise - default is true / on
    // If we have auto-dimming set, we need only check whether we need to turn the display off
    
    // Are we using night mode?
    if (prefs.timer.isset) {
        local shouldShowDisplay = true;
    
        // Disable the advance, if it's set and we've hit the start or end end of the nighttime period
        // NOTE 'isAdvanceSet' is ONLY set if 'prefs.timer.isset' is true
        if (isAdvanceSet) {
            if (hour == prefs.timer.on.hour && minutes >= prefs.timer.on.min) isAdvanceSet = false;
            if (hour == prefs.timer.off.hour && minutes >= prefs.timer.on.min) isAdvanceSet = false;
        }

        // Have we crossed into the nighttime period? If so, unset 'shouldShowDisplay'
        local start = prefs.timer.on.hour * 60 + prefs.timer.on.min;
        local end = prefs.timer.off.hour * 60 + prefs.timer.off.min;
        local now = hour * 60 + minutes;
        local delta = end - start;
        
        // End and start times are identical, so just keep the display on
        if (delta == 0) return !isAdvanceSet;
        
        if (delta > 0) {
            if (now >= start && now < end) shouldShowDisplay = false;
            
        } else {
            if (now >= start || now < end) shouldShowDisplay = false;
        }

        return (isAdvanceSet ? !shouldShowDisplay : shouldShowDisplay);
    }

    // If we're not in night mode, just return the current display state setting
    return prefs.on;
}

function setDisplay(state) {
    if (state) {
        powerUp();
        agent.send("display.state", true);
        if (debug) server.log("Brightening display at " + format("%02i", hour) + ":" + format("%02i", minutes));
    } else {
        clearDisplay();
        powerDown();
        agent.send("display.state", false);
        if (debug) server.log("Dimming display at " + format("%02i", hour) + ":" + format("%02i", minutes));
    }
}

function displayTime() {
    // Note 'hour' already adjusted for BST
    local a = hour;
    local b = 0;

    // Hours
    if (prefs.mode) {
        // 24-hour clock
        if (a < 10) {
            faces[0].displayChar(48, 3);
            faces[1].displayChar(48 + a, 1);
        } else if (a > 9 && a < 20) {
            faces[0].displayChar(49, 3);
            faces[1].displayChar(38 + a, 1);
        } else if (a > 19) {
            faces[0].displayChar(50, 3);
            faces[1].displayChar(28 + a, 1);
        }
    } else {
        // 12-hour clock
        if (a == 12 || a == 0 ) {
            faces[0].displayChar(49, 3);
            faces[1].displayChar(50, 1);
        } else if (a < 10) {
            faces[0].displayChar(32, 3);
            faces[1].displayChar(48 + a, 1);
        } else if (a == 10 || a == 11) {
            faces[0].displayChar(49, 3);
            faces[1].displayChar(38 + a, 1);
        } else if (a > 12 && a < 22) {
            faces[0].displayChar(32, 3);
            faces[1].displayChar(36 + a, 1);
        } else if (a == 22 || a == 23) {
            faces[0].displayChar(49, 3);
            faces[1].displayChar(26 + a, 1);
        }
    }

    // Minutes
    if (minutes > 9) {
        a = minutes;
        while (a >= 0) {
            a = a - 10;
            ++b;
        }

        faces[2].displayChar(47 + b, 2);
        faces[3].displayChar(48 + minutes - (10 * (b - 1)), 0);
    } else {
        faces[2].displayChar(48, 2);
        faces[3].displayChar(48 + minutes, 0);
    }

    // Is the clock disconnected? If so, flag the fact
    if (isDisconnected) faces[0].plot(0, 7, 1).plot(0, 6, 1).plot(1, 7, 1).plot(1, 6, 1);

    // Is the clock connecting? If so, display the fact with animation
    if (isConnecting) {
        cc += 2;
        if (cc > 6) cc = 0;
        faces[0].plot(ca[cc], ca[cc + 1], 0);
    }

    // AM or PM?
    if (!prefs.mode && isPM) faces[3].plot(7, 7, 1).plot(7, 6, 1).plot(6, 7, 1).plot(6, 6, 1);

    // UTC
    if (prefs.utc) faces[3].plot(7, 1, 1).plot(7, 0, 1).plot(6, 1, 1).plot(6, 0, 1);

    // Check whether the colon should appear
    if (prefs.colon) {
        // Colon is set to be displayed. Will it flash?
        if (prefs.flash) {
            if (tickFlag) drawColon();
        } else {
            drawColon();
        }
    }

    updateDisplay();
}

function drawColon() {
    faces[1].plot(7, 6, 1).plot(7, 5, 1);
    faces[1].plot(7, 1, 1).plot(7, 2, 1);
    faces[2].plot(0, 6, 1).plot(0, 5, 1);
    faces[2].plot(0, 1, 1).plot(0, 2, 1);
}

function syncText() {
    if (!prefs.on) return;

    // Display the word 'SYNC' on the LED
    local letters = [83, 121, 110, 99];
    foreach (index, character in letters) faces[index].displayChar(character, 2);
    updateDisplay();
}

function updateDisplay() {
    faces[0].draw();
    faces[1].draw();
    faces[2].draw();
    faces[3].draw();
}

function powerUp() {
    faces[3].powerUp();
    faces[2].powerUp();
    faces[1].powerUp();
    faces[0].powerUp();
}

function powerDown() {
    faces[0].powerDown();
    faces[1].powerDown();
    faces[2].powerDown();
    faces[3].powerDown();
}

function setBrightness(br) {
    faces[0].setBrightness(br);
    faces[1].setBrightness(br);
    faces[2].setBrightness(br);
    faces[3].setBrightness(br);
}

function clearDisplay() {
    faces[0].clearDisplay();
    faces[1].clearDisplay();
    faces[2].clearDisplay();
    faces[3].clearDisplay();
}

// PREFERENCES FUNCTIONS
function setPrefs(settings) {
    // Cancel the 'Sync' display timer if it has yet to fire
    if (debug) server.log("Received preferences from agent");
    if (syncTimer) imp.cancelwakeup(syncTimer);
    syncTimer = null;

    // Parse the set-up data table provided by the agent
    prefs.mode = settings.hrmode;
    prefs.bst = settings.bst;
    prefs.flash = settings.flash;
    prefs.colon = settings.colon;
    prefs.utc = settings.utc;
    prefs.offset = settings.utcoffset;
    prefs.timer.on.hour = settings.timer.on.hour;
    prefs.timer.on.min = settings.timer.on.min;
    prefs.timer.off.hour = settings.timer.off.hour;
    prefs.timer.off.min = settings.timer.off.min;
    prefs.timer.isset = settings.timer.isset;

    // ADDED 2.1.0: Make use of display disable times
    // NOTE We change settings.on, so the the local state record, prefs.on,
    //      is correctly updated in the next stanza
    if (prefs.timer.isset) {
        local now = date();
        if (now.hour > prefs.timer.off.hour || now.hour < prefs.timer.on.hour) settings.on = false;
        if (now.hour == prefs.timer.off.hour && now.min >= prefs.timer.off.min) settings.on = false;
        if (now.hour == prefs.timer.off.hour && now.min < prefs.timer.on.min) settings.on = false;
    }

    // Clear the display
    if (settings.on != prefs.on) setLight(settings.on);

    // Set the brightness
    if (settings.brightness != prefs.brightness) {
        prefs.brightness = settings.brightness;

        // Only set the brightness now if the display is on
        if (prefs.on != 1) setBrightness(prefs.brightness);
    }

    // Only call getTime() if we have come here *before*
    // the main clock loop, which sets tickTimer, has started
    if (tickTimer == null) getTime();
}

function setBST(value) {
    // This function is called when the app sets or unsets BST
    if (debug) server.log("Setting BST monitoring " + (value? "on" : "off"));
    prefs.bst = value;
}

function setMode(value) {
    // This function is called when 12/24 modes are switched by app
    if (debug) server.log("Setting 24-hour mode " + (value ? "on" : "off"));
    prefs.mode = value;
}

function setUTC(value) {
    // This function is called when the app sets or unsets UTC
    if ("state" in value) {
        prefs.utc = value.state;
        if (debug) server.log("Setting UTC " + (value.state ? "on" : "off"));
    }

    if ("offset" in value) prefs.offset = value.offset;
}

function setBright(brightness) {
    // This function is called when the app changes the clock's brightness
    if (debug) server.log("Setting brightness " + brightness);
    if (brightness != prefs.brightness) {
        setBrightness(brightness);
        prefs.brightness = brightness;
    }
}

function setFlash(value) {
    // This function is called when the app sets or unsets the colon flash
    if (debug) server.log("Setting colon flash " + (value ? "on" : "off"));
    prefs.flash = value;
}

function setColon(value) {
    // This function is called when the app sets or unsets the colon flash
    if (debug) server.log("Setting colon state " + (value ? "on" : "off"));
    prefs.colon = value;
}

function setLight(value) {
    // This function is called when the app turns the clock display on or off
    if (debug) server.log("Setting light " + (value ? "on" : "off"));
    
    if (prefs.timer.isset) {
        // If we're in night mode, we treat this as an advance of the timer
        // NOTE This will cause prefs.on to be set elsewhere
        isAdvanceSet = !isAdvanceSet;
    } else {
        // We're not in night mode, so just turn the light off
        prefs.on = value;
        setDisplay(value);        
    }
}

function setNight(value) {
    // This function is called when the app enables or disables night mode
    if (debug) server.log("Setting nightmode " + (value ? "on" : "off"));

    // Just set the preference because it will be applied almost immediately
    // via the getTime() loop
    prefs.timer.isset = value;     

    // Disable the timer advance setting as it's only relevant if night mode is
    // on AND it has been triggered since night mode was enabled
    isAdvanceSet = false;
}

function setNightTime(data) {
    prefs.timer.on.hour = data.on.hour;
    prefs.timer.on.min = data.on.min;
    prefs.timer.off.hour = data.off.hour;
    prefs.timer.off.min = data.off.min;
    
    if (debug) server.log("Matrix Clock night dimmer to start at " + format("%02i", prefs.timer.on.hour) + ":" + format("%02i", prefs.timer.on.min) + " and end at " + format("%02i", prefs.timer.off.hour) + ":" + format("%02i", prefs.timer.off.min));
}


function setDebug(state) {
    debug = state;
    server.log("Setting device debugging " + (state ? "on" : "off"));
}

function setDefaultPrefs() {
    prefs = {};
    prefs.on <- true;
    prefs.mode <- true;
    prefs.bst <- true;
    prefs.colon <- true;
    prefs.flash <- true;
    prefs.brightness <- 15;
    prefs.utc <- false;
    prefs.offset <- 12;
    prefs.timer <- { "on"  : { "hour" : 7,  "min" : 00 }, 
                     "off" : { "hour" : 22, "min" : 30 },
                     "isset" : false };
}

// OFFLINE OPERATION FUNCTIONS
function disHandler(event) {
    // Called if the server connection is broken or re-established
    if ("message" in event) server.log("Disconnection Manager: " + event.message);

    if ("type" in event) {
        if (event.type == "disconnected") {
            isDisconnected = true;
            isConnecting = false;
        }

        if (event.type == "connecting") isConnecting = true;

        if (event.type == "connected") {
            // Check for settings changes
            agent.send("mclock.get.prefs", 1);
            isDisconnected = false;
            isConnecting = false;
        }
    }
}


// START PROGRAM

// Load in generic boot message code
#include "../generic/bootmessage.nut"

// Set up disconnection handler
disconnectionManager.setCallback(disHandler);
disconnectionManager.reconnectDelay = DISCONNECT_TIMEOUT;
disconnectionManager.reconnectTimeout = RECONNECT_TIMEOUT;
disconnectionManager.start();

// Set up I2C hardware
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);

// Set up the clock faces: 0-3 (L-R)
faces = [];
faces.append(HT16K33MatrixCustom(hardware.i2c89, 0x70));
faces.append(HT16K33MatrixCustom(hardware.i2c89, 0x71));
faces.append(HT16K33MatrixCustom(hardware.i2c89, 0x74));
faces.append(HT16K33MatrixCustom(hardware.i2c89, 0x75));

// Set the initial brightness and display angle
foreach (face in faces) face.init(15, INITIAL_ANGLE);

// Load in default prefs
setDefaultPrefs();

// Show the ‘sync’ message then give the text no more than
// 30 seconds to appear. If the prefs data comes from the
// agent before then, the text will automatically be cleared
// (and the timer cancelled)
syncText();
syncTimer = imp.wakeup(30.0, getTime);

// Set up Agent notification response triggers
// First, settings-related actions
agent.on("mclock.set.prefs", setPrefs);
agent.on("mclock.set.bst", setBST);
agent.on("mclock.set.mode", setMode);
agent.on("mclock.set.utc", setUTC);
agent.on("mclock.set.brightness", setBright);
agent.on("mclock.set.flash", setFlash);
agent.on("mclock.set.colon", setColon);
agent.on("mclock.set.light", setLight);
agent.on("mclock.set.debug", setDebug);
agent.on("mclock.set.nightmode", setNight);
agent.on("mclock.set.nighttime", setNightTime);

// Next, other actions
agent.on("mclock.do.reboot", function(dummy) {
    server.restart();
});

// Get preferences from server
// NOTE no longer need this here as it's handled via DisconnectManager
// agent.send("mclock.get.prefs", true);
