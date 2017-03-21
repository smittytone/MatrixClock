// Matrix Clock
// Copyright 2016-17, Tony Smith

#require "utilities.nut:1.0.0"

#import "HT16K33MatrixCustom.class.nut"

// Set up connectivity policy
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);

// CONSTANTS

const DISCONNECT_TIMEOUT = 60;
const TICK_DURATION = 0.5;
const INITIAL_ANGLE = 0;

// GLOBALS

local faces = null;
local tickTimer = null;
local syncTimer = null;
local prefs = null;
local disMessage = null;
local disTime = -1;
local disFlag = false;
local tickCount = 0;
local tickFlag = true;
local tickTotal = (1.0 / TICK_DURATION).tointeger() * 2;
local halfTickTotal = tickTotal / 2;
local pmFlag = false;
local debug = true;

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

    // Adjust the hour for BST and midnight rollover
    if (prefs.bst && utilities.bstCheck()) hour++;
    if (hour > 23) hour = 0;

    // AM or PM?
    pmFlag = (hour > 11) ? true : false;

    // Update the tick counter
    tickCount++;
    if (tickCount >= tickTotal) tickCount = 0;
    tickFlag = (tickCount < halfTickTotal) ? true : false;

    // Present the current time
    displayTime();
}

function displayTime() {
    if (!prefs.on) {
        clearDisplay();
        return;
    }

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
    if (disFlag) faces[0].plot(0, 7, 1).plot(0, 6, 1).plot(1, 7, 1).plot(1, 6, 1);

    // AM or PM?
    if (!prefs.mode && pmFlag) faces[3].plot(7, 7, 1).plot(7, 6, 1).plot(6, 7, 1).plot(6, 6, 1);

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
    foreach (index, character in letters) {
        faces[index].displayChar(character, 2);
    }

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
    prefs.offset = settings.utcoffset - 12;

    // Clear the display
    if (settings.on != prefs.on) setLight(settings.on ? 1 : 0);

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
    if (debug) server.log("Setting BST monitoring " + ((value == 1) ? "on" : "off"));
    prefs.bst = (value == 1);
}

function setMode(value) {
    // This function is called when 12/24 modes are switched by app
    if (debug) server.log("Setting 24-hour mode " + ((value == 24) ? "on" : "off"));
    prefs.mode = (value == 24 && prefs.mode == false);
}

function setUTC(string) {
    // This function is called when the app sets or unsets UTC
    if (debug) server.log("Setting UTC " + ((string == "N") ? "on" : "off"));
    if (string == "N") {
        prefs.utc = false;
    } else {
        prefs.utc = true;
        prefs.offset = string.tointeger() - 12;
    }
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
    if (debug) server.log("Setting colon flash " + ((value == 1) ? "on" : "off"));
    prefs.flash = (value == 1);
}

function setColon(value) {
    // This function is called when the app sets or unsets the colon flash
    if (debug) server.log("Setting colon state " + ((value == 1) ? "on" : "off"));
    prefs.colon = (value == 1);
}

function setLight(value) {
    if (debug) server.log("Setting light " + ((value == 1) ? "on" : "off"));
    if (value == 1) {
        prefs.on = true;
        powerUp();
    } else {
        prefs.on = false;
        powerDown();
    }
}

function setDebug(state) {
    debug = (state == 1);
}

// OFFLINE OPERATION FUNCTIONS

function disconnectHandler(reason) {
    // Called if the server connection is broken or re-established
    // Sets 'disFlag' true if there is no connection

    // Clear face 0, pixel 0,0 to show we're attempting to connect
    faces[0].plot(0,0,0).draw();

    if (reason != SERVER_CONNECTED) {
        // Server is not connected
        if (!disFlag) {
            disFlag = true;
            disTime = time();
            local now = date();
            disMessage = "Went offline at " + now.hour + ":" + now.min + ":" + now.sec + ". Reason: " + reason;
        }

        imp.wakeup(DISCONNECT_TIMEOUT, reconnect);
    } else {
        // Server is connected
        if (debug) {
            server.log(disMessage);
            server.log("Back online after " + (time() - disTime) + " seconds");
        }

        disTime = -1;
        disFlag = false;
        disMessage = null;
        agent.send("mclock.get.prefs", 1);
    }
}

function reconnect() {
    if (server.isconnected()) {
        disconnectHandler(SERVER_CONNECTED);
    } else {
        faces[0].plot(0,0,1).draw();
        server.connect(disconnectHandler, 30);
    }
}

// START PROGRAM

// Set up disconnection handler
server.onunexpecteddisconnect(disconnectHandler);

// Set up I2C hardware
hardware.i2c89.configure(CLOCK_SPEED_400_KHZ);
utilities.debugI2C(hardware.i2c89);

// Set up the clock faces: 0-3 (L-R)
faces = [];
local matrix = HT16K33MatrixCustom(hardware.i2c89, 0x70, debug);
faces.append(matrix);
matrix = HT16K33MatrixCustom(hardware.i2c89, 0x71, debug);
faces.append(matrix);
matrix = HT16K33MatrixCustom(hardware.i2c89, 0x74, debug);
faces.append(matrix);
matrix = HT16K33MatrixCustom(hardware.i2c89, 0x75, debug);
faces.append(matrix);

// Set the initial brightness and display angle
foreach (face in faces) {
    face.init(15, INITIAL_ANGLE);
}

// Load in default prefs
prefs = {};
prefs.on <- true;
prefs.mode <- true;
prefs.bst <- true;
prefs.colon <- true;
prefs.flash <- true;
prefs.brightness <- 15;
prefs.utc <- false;
prefs.offset <- 12;

// Show the ‘sync’ message then give the text no more than
// 30 seconds to appear. If the prefs data comes from the
// agent before then, the text will automatically be cleared
// (and the timer cancelled)
syncText();
syncTimer = imp.wakeup(30.0, getTime);

// Set up Agent notification response triggers
agent.on("mclock.set.prefs", setPrefs);
agent.on("mclock.set.bst", setBST);
agent.on("mclock.set.mode", setMode);
agent.on("mclock.set.utc", setUTC);
agent.on("mclock.set.brightness", setBright);
agent.on("mclock.set.flash", setFlash);
agent.on("mclock.set.colon", setColon);
agent.on("mclock.set.light", setLight);
agent.on("mclock.set.debug", setDebug);

// Get preferences from server
agent.send("mclock.get.prefs", true);
