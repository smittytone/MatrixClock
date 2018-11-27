// Matrix Clock
// Copyright 2016-18, Tony Smith

// IMPORTS
// NOTE If you're not using Squinter or an equivalent tool, cut and paste the named 
// file's code over the following lines. For Squinter users, you will need to change
// the path to the file in each #import statement 
#import "HT16K33MatrixCustom.class.2.nut"   // Source code for this file here: https://github.com/smittytone/MatrixClock
#import "../generic/utilities.nut"          // Source code for this file here: https://github.com/smittytone/generic
#import "../generic/disconnect.nut"         // Source code for this file here: https://github.com/smittytone/generic


// CONSTANTS
const DISCONNECT_TIMEOUT = 60;
const RECONNECT_TIMEOUT = 15;
const TICK_DURATION = 0.5;
const TICK_TOTAL = 4;
const HALF_TICK_TOTAL = 2;
const LED_ANGLE = 0;
const ALARM_DURATION = 2;
const ALARM_STATE_OFF = 0;
const ALARM_STATE_ON = 1;
const ALARM_STATE_DONE = 2;


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
        if (hours == settings.timer.off.hour && minutes >= settings.timer.off.min) isAdvanceSet = false;
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
        if (!settings.flash || (settings.flash && tickFlag)) drawColon();
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
    // Tell all four LEDs to power up - in reverse order (R to L)
    // NOTE This probably happens too quickly to matter - may need to add a delay
    display[3].powerUp();
    imp.sleep(0.25);
    display[2].powerUp();
    imp.sleep(0.25);
    display[1].powerUp();
    imp.sleep(0.25);
    display[0].powerUp();
}

function powerDown() {
    // Tell all four LEDs to power down - in order (L to R)
    display[0].powerDown();
    imp.sleep(0.25);
    display[1].powerDown();
    imp.sleep(0.25);
    display[2].powerDown();
    imp.sleep(0.25);
    display[3].powerDown();
}

function setBrightness(b) {
    // Set all four LEDs' brightness
    display[0].setBrightness(b);
    display[1].setBrightness(b);
    display[2].setBrightness(b);
    display[3].setBrightness(b);
    // NOTE 'setBrightness()' triggers an LED redraw
}

function clearDisplay() {
    // Clear all four LEDs
    display[0].clearDisplay();
    display[1].clearDisplay();
    display[2].clearDisplay();
    display[3].clearDisplay();
    // NOTE 'clearDisplay()' triggers an LED redraw
}

function setVideo(state) {
    // ADDED IN 2.1.0
    // Set inverse state of all four LEDs
    display[0].setInverseVideo(state);
    display[1].setInverseVideo(state);
    display[2].setInverseVideo(state);
    display[3].setInverseVideo(state);
    // NOTE 'setInverseVideo()' triggers an LED redraw
}

function syncText() {
    // Display 'Sync' after the clock is powered up and until it receives its preferences from the agent
    if (!settings.on) return;
    local letters = [0x53, 0x79, 0x6E, 0x63];
    foreach (index, char in letters) display[index].displayChar(char, 2);
    updateDisplay();
}


// PREFERENCES FUNCTIONS
function setPrefs(prefsData) {
    // Log receipt of prefs data
    if (debug) server.log("Received preferences from agent");
    
    // Cancel the 'Sync' display timer if it has yet to fire
    if (syncTimer) imp.cancelwakeup(syncTimer);
    syncTimer = null;

    // Set the debug state
    if ("debug" in prefsData) setDebug(prefsData.debug);

    // Parse the set-up data table provided by the agent
    settings.mode = prefsData.hrmode;
    settings.bst = prefsData.bst;
    settings.flash = prefsData.flash;
    settings.colon = prefsData.colon;
    settings.utc = prefsData.utc;
    settings.offset = prefsData.utcoffset;
    
    // ADDED IN 2.1.0
    settings.timer.on.hour = prefsData.timer.on.hour;
    settings.timer.on.min = prefsData.timer.on.min;
    settings.timer.off.hour = prefsData.timer.off.hour;
    settings.timer.off.min = prefsData.timer.off.min;
    settings.timer.isset = prefsData.timer.isset;
    isAdvanceSet = prefsData.timer.isadv;

    // ADDED IN 2.1.0: Make use of display disable times
    // NOTE We change settings.on, so the the local state record, settings.on,
    //      is correctly updated in the next stanza
    if (settings.timer.isset) {
        local now = date();
        if (now.hour > settings.timer.on.hour || now.hour < settings.timer.off.hour) prefsData.on = false;
        if (now.hour == settings.timer.off.hour && now.min < settings.timer.off.min) prefsData.on = false;
        if (now.hour == settings.timer.on.hour && now.min >= settings.timer.on.min) prefsData.on = false;
    }

    local updateBright = false;
    local updateState = false;

    // Set the brightness
    if (settings.brightness != prefsData.brightness) {
        settings.brightness = prefsData.brightness;
        updateBright = true;
    }

    // ADDED IN 2.1.0
    // Set the video state: normal (false) or inverse (true)
    if (settings.video != prefsData.video) {
        settings.video = prefsData.video;
        updateState = true;
    }

    // Set the display state
    // NOTE 'setLight()' updates 'settings.on'
    if (settings.on != prefsData.on) setLight(prefsData.on);

    // Only set the brightness and state now if the display is on
    if (settings.on) {
        if (updateState) setVideo(settings.video);
        if (updateBright) setBrightness(settings.brightness);
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

function setBright(value) {
    // This function is called when the app changes the clock's brightness
    // 'value' is passed in from the agent as an integer
    if (value < 0 || value > 15 || value == settings.brightness) return;
    if (debug) server.log("Setting display brightness " + value);
    settings.brightness = value;
    
    // Tell the display(s) to change their brightness
    setBrightness(value);
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
    // 'value' is passed in from the agent as a bool

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

function setInverse(state) {
    // ADDED IN 2.1.0
    // Update the display state (inverse or normal)
    settings.video = state;
    setVideo(state);
    if (debug) server.log("Setting display to " + (state ? "black on green" : "green on black")); 
}

function setDefaultPrefs() {
    // Initialise the clock's local preferences store
    settings = {};
    settings.on <- true;
    settings.mode <- true;
    settings.bst <- true;
    settings.colon <- true;
    settings.flash <- true;
    settings.brightness <- 1;
    settings.utc <- false;
    settings.offset <- 12;
    
    // ADDED IN 2.1.0
    settings.alarms <- [];
    settings.timer <- { "on"  : { "hour" : 7,  "min" : 00 }, 
                        "off" : { "hour" : 22, "min" : 30 },
                        "isset" : false };
    settings.video <- false;
}


// ADDED IN 2.1.0
// ALARM FUNCTONS
function checkAlarms() {
    // Do we need to display an alarm screen flash? **** EXPERIMENTAL ****
    if (settings.alarms.len() > 0) {
        foreach (alarm in settings.alarms) {
            // Check if it's time to turn an alarm on
            if (alarm.hour == hours && alarm.min == minutes) {
                if (!alarm.on && !alarm.done) {
                    // The alarm is not on, but should be, so turn it on now
                    if (debug) server.log("Alarm triggered at " + format("%02i", hours) + ":" + format("%02i", minutes));
                    alarmState = ALARM_STATE_ON;
                    alarm.offmins = alarm.min + ALARM_DURATION;
                    alarm.offhour = alarm.hour
                    if (alarm.offmins > 59) {
                        alarm.offmins = 60 - alarm.offmins;
                        alarm.offhour++;
                        if (alarm.offhour > 23) alarm.offhour = 24 - alarm.offhour;
                    }

                    alarm.on = true;
                }
            }

            // Check if it's time to turn an alarm off
            if (alarm.offhour == hours && alarm.offmins == minutes) {
                alarmState = ALARM_STATE_DONE;
                if (debug) server.log("Alarm stopped at " + format("%02i", hours) + ":" + format("%02i", minutes));
                if (!alarm.repeat) alarm.done = true;
            }
        }

        // Clear all completed alarms which are not on repeat
        local i = 0;
        local flag = false;
        while (i < settings.alarms.len()) {
            local alarm = settings.alarms[i];
            if (alarm.done == true) {
                // Alarm is only done if it's not on repeart
                flag = true;
                settings.alarms.remove(i);
                if (debug) server.log("Alarm deleted");
            } else {
                i++;
            }
        }

        // We have made changes, so inform the agent
        if (flag) agent.send("update.alarms", alarms);
    }
}

// Sort the alarms into incidence order
function sortAlarms() {
    settings.alarms.sort(function(a, b) {
        // Match the hour first
        if (a.hour > b.hour) return 1;
        if (a.hour < b.hour) return -1;

        // Hours match, so try the minutes
        if (a.min > b.min) return 1;
        if (a.min < b.min) return -1;

        // The two alarms are the same
        return 0;
    });
}

function setAlarm(newAlarm) {
    if (settings.alarms.len() > 0) {
        // We have some alarms set, so check that the new one is not
        // already on the list
        foreach (alarm in settings.alarms) {
            if (alarm.hour == newAlarm.hour && alarm.min == newAlarm.min) {
                // Alarm matches an existing one - are we setting the repeat value?
                if (alarm.repeat == newAlarm.repeat) return;
                alarm.repeat = newAlarm.repeat;
                if (debug) server.log("Alarm at " + format("%02i", alarm.hour) + ":" + format("%02i", alarm.min) + " updated: repeat " + (alarm.repeat ? "on" : "off"));
                
                // Made a change so update the agent's master list
                agent.send("update.alarms", alarms);
                return;
            }
        }
    }

    // Add the new alarm to the list
    newAlarm.on <- false;
    newAlarm.done <- false;
    newAlarm.offmins <- -1;
    newAlarm.offhour <- -1;
    settings.alarms.append(newAlarm);
    sortAlarms();
    if (debug) server.log("Alarm " + alarms.len() + " added. Time: " + format("%02i", alarm.hour) + ":" + format("%02i", alarm.min));
    agent.send("update.alarms", alarms);
}

function clearAlarm(index) {
    if (!(index > alarms.len() - 1)) {
        local alarm = settings.alarm[index];
        settings.alarms.remove(index);
        if (debug) server.log("Alarm at " + format("%02i", alarm.hour) + ":" + format("%02i", alarm.min) + " removed");
        agent.send("update.alarms", alarms);
    }
}

function stopAlarm(ignored) {
    // Run through each alarm that's on and mark it done
    if (settings.alarms.len() > 0) {
        foreach (alarm in settings.alarms) {
            if ("on" in alarm) {
                alarm.done = true;
                alarmState = ALARM_STATE_DONE;
            }
        }
    }
}


// OFFLINE OPERATION FUNCTIONS
function discHandler(event) {
    // Called if the server connection is broken or re-established
    if ("message" in event) server.log("Connection Manager: " + event.message);

    if ("type" in event) {
        if (event.type == "disconnected") {
            isDisconnected = true;
            isConnecting = false;
            if (disTime == 0) disTime = event.ts;
        }

        if (event.type == "connecting") isConnecting = true;

        if (event.type == "connected") {
            // Check for settings changes
            agent.send("clock.get.prefs", 1);
            isDisconnected = false;
            isConnecting = false;
            
            if (disTime != 0) {
                local delta = event.ts - disTime;
                if (debug) server.log("Connection Manager: disconnection duration " + delta + " seconds");
                disTime = 0;
            }
        }
    }
}


// START PROGRAM

// Load in generic boot message code
// NOTE If you're not using Squinter or an equivalent tool, cut and paste the named 
// file's code over the following line. For Squinter users, you will need to change
// the path to the file in each #import statement 
// Source code for this file here: https://github.com/smittytone/generic
#import "../generic/bootmessage.nut"

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
foreach (led in display) {
    led.setupCharset();
    led.init(settings.brightness, LED_ANGLE);
}

// Show the ‘sync’ message then give the text no more than
// 30 seconds to appear. If the prefs data comes from the
// agent before then, the text will automatically be cleared
// (and the timer cancelled)
syncText();
syncTimer = imp.wakeup(30.0, function() {
    syncTimer = null;
    clockTick();
});

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
agent.on("clock.set.video", setInverse);

// Next, other actions
agent.on("clock.do.reboot", function(dummy) {
    imp.reset();
});

// Get preferences from server
// NOTE no longer need this here as it's handled via DisconnectManager
// agent.send("clock.get.prefs", true);
// if (debug) server.log("Requesting preferences from agent");