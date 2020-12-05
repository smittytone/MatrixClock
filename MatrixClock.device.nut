/*
 * Matrix Clock
 * Copyright 2020, Tony Smith
 */


/*
 * EARLY RUN CODE
 */
server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 10);


/*
 * IMPORTS
 */
// If you are NOT using Squinter or a similar tool, replace the following #import statement(s)
// with the contents of the named file(s):
#import "HT16K33MatrixCustom.class.nut"             // Source code: https://github.com/smittytone/MatrixClock
#import "../generic-squirrel/utilities.nut"         // Source code: https://github.com/smittytone/generic-squirrel
#import "../generic-squirrel/disconnect.nut"        // Source code: https://github.com/smittytone/generic-squirrel
#import "../generic-squirrel/crashReporter.nut"     // Source code: https://github.com/smittytone/generic-squirrel


/*
 * CONSTANTS
 */
const DISCONNECT_TIMEOUT = 60;
const RECONNECT_TIMEOUT  = 15;
const TICK_DURATION      = 0.5;
const TICK_TOTAL         = 4;
const HALF_TICK_TOTAL    = 2;
const ALARM_DURATION     = 2;
const ALARM_STATE_OFF    = 0;               // Alarm silent, ie. off
const ALARM_STATE_ON     = 1;               // Alarm triggered, ie. on
const ALARM_STATE_DONE   = 2;               // Alarm completed, can be deleted
const LED_ANGLE          = 0;


/*
 * GLOBAL VARIABLES
 */
// Objects
local display = null;
local tickTimer = null;
local syncTimer = null;
local settings = null;

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

// Alarms
local alarmFlashState = ALARM_STATE_OFF;
local alarmFlashFlag = false;

// Disconnected/connected animation
local ca = [0,7,1,7,1,6,0,6];
local cc = 0;


/*
 * TIME AND DISPLAY CONTROL FUNCTIONS
 */
function clockTick() {
    // This is the main clock loop
    // Queue the function to run again in TICK_DURATION seconds
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
        // If UTC is set, add the international time offset (0 - 24, converted here to -12 to + 12)
        hours += (settings.utcoffset - 12);
        if (hours > 24) {
            hours -= 24;
        } else if (hours < 0) {
            hours += 24;
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
    alarmFlashFlag = !alarmFlashFlag;

    // ADDED IN 2.2.0
    // Check for Alarms
    checkAlarms();

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
    // NOTE 'isAdvanceSet' should ONLY be set if 'settings.timer.isset' is TRUE
    if (isAdvanceSet) {
        // 'isAdvanceSet' is unset when the next event time (display goes on or off) is reached
        if (hours == settings.timer.on.hour && minutes >= settings.timer.on.min) isAdvanceSet = false;
        if (hours == settings.timer.off.hour && minutes >= settings.timer.off.min) isAdvanceSet = false;
        if (!settings.timer.isset) isAdvancedSet = false;
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
    local a = bcd(hours);

    // Set the hours
    if (settings.mode) {
        // 24-hour clock
        display[0].displayChar(48 + ((a & 0xF0) >> 4), 3);
        display[1].displayChar(48 + (a & 0x0F), 1);
    } else {
        // 12-hour clock
        a = hours;
        if (isPM) a -= 12;
        if (a == 0) a = 12;
        a = bcd(a);
        if (a < 10) {
            display[0].displayGlyph(32, 3);
        } else {
            display[0].displayChar(49, 3);
        }

        display[1].displayChar(48 + (a & 0x0F), 1);
    }

    // Set the minutes
    a = bcd(minutes);
    display[2].displayChar(48 + ((a & 0xF0) >> 4), 2);
    display[3].displayChar(48 + (a & 0x0F), 0);

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
    // Plot a 2x2 square in the bottom right corner of the display for AM,
    // or a 2x2 square in the top right corner of the display for PM
    if (!settings.mode) {
        if (isPM) {
            display[3].plot(7, 7, 1).plot(7, 6, 1).plot(6, 7, 1).plot(6, 6, 1);
        } else {
            display[3].plot(7, 1, 1).plot(7, 2, 1).plot(6, 1, 1).plot(6, 2, 1);
        }
    }

    // UTC
    // Plot a 2x2 square in the bottom left corner of the display
    if (settings.utc) display[0].plot(0, 1, 1).plot(0, 0, 1).plot(1, 1, 1).plot(1, 0, 1);

    // Check whether the colon should appear
    if (settings.colon) {
        // Colon is set to be displayed. Will it flash?
        if (!settings.flash || (settings.flash && tickFlag)) drawColon();
    }

    // ADDED IN 2.2.0
    // Check for alarms
    if (alarmFlashState == ALARM_STATE_ON) {
        // The display should flash, so set it according to the current 'alarmFlashFlag' state
        setVideo(alarmFlashFlag);
    } else if (alarmFlashState == ALARM_STATE_DONE) {
        // The flash has been turned off, so reset the display and update the state
        // variable so that this operation doesn't happen over and over again
        setVideo(settings.video);
        alarmFlashState = ALARM_STATE_OFF;
    }

    // Draw the display
    updateDisplay();
}

function bcd(binValue) {
    for (local i = 0 ; i < 8 ; i++) {
        binValue = binValue << 1
        if (i == 7) break;
        if ((binValue & 0xF00) > 0x4FF) binValue += 0x300
        if ((binValue & 0xF000) > 0x4FFF) binValue += 0x3000
    }

    return (binValue >> 8) & 0xFF;
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

function displayFlash(f) {
    display[0].setDisplayFlash(f);
    display[1].setDisplayFlash(f);
    display[2].setDisplayFlash(f);
    display[3].setDisplayFlash(f);
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


/*
 * PREFERENCES FUNCTIONS
 */
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
    settings.utcoffset = prefsData.utcoffset;

    // ADDED IN 2.1.0
    settings.timer.on.hour = prefsData.timer.on.hour;
    settings.timer.on.min = prefsData.timer.on.min;
    settings.timer.off.hour = prefsData.timer.off.hour;
    settings.timer.off.min = prefsData.timer.off.min;
    settings.timer.isset = prefsData.timer.isset;
    //isAdvanceSet = prefsData.timer.isadv;

    // ADDED IN 2.2.0
    // Clear and reset the local list of alarms
    if (settings.alarms != null) settings.alarms = [];
    if (prefsData.alarms.len() > 0) {
        foreach (alarm in prefsData.alarms) setAlarm(alarm);
    }

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
    if ("offset" in value) settings.utcoffset = value.offset;
    if ("state" in value) {
        settings.utc = value.state;
        if (debug) server.log("Setting UTC " + (value.state ? "on" : "off"));
    }
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
        // NOTE This will cause 'settings.on' to be set elsewhere (see 'clockTick()')
        isAdvanceSet = !isAdvanceSet;
    } else {
        // We're not in night mode, so just turn the light off
        settings.on = value;
        setDisplay(value);
    }
}

function setDebug(state) {
    // Enable or disable debugging messaging in response to a message from the UI via the agent
    if (debug != state) {
        foreach (led in display) led.setDebug(state, true);
        debug = state;
    }

    server.log("Setting device-side debug messages " + (state ? "on" : "off"));
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
    settings.utcoffset <- 12;

    // ADDED IN 2.1.0
    settings.alarms <- [];
    settings.timer <- { "on"  : { "hour" : 7,  "min" : 00 },
                        "off" : { "hour" : 22, "min" : 30 },
                        "isset" : false };
    settings.video <- false;
}

/*
 * ALARM FUNCTONS
 */
function checkAlarms() {
    // ADDED IN 2.1.0
    // Do we need to display an alarm screen flash?
    if (settings.alarms.len() > 0) {
        foreach (alarm in settings.alarms) {
            // Check if it's time to turn an alarm on
            if (alarm.hour == hours && alarm.min == minutes) {
                if (alarm.state == ALARM_STATE_OFF) {
                    // The alarm is not on, but should be, so turn it on now
                    alarm.state = ALARM_STATE_ON;

                    // Set the 'show alarm flash' flag
                    alarmFlashState = ALARM_STATE_ON;

                    // Set the time at which the alarm should be silenced automatically
                    alarm.offmins = alarm.min + ALARM_DURATION;
                    alarm.offhour = alarm.hour;
                    if (alarm.offmins > 59) {
                        alarm.offmins = 60 - alarm.offmins;
                        alarm.offhour++;
                        if (alarm.offhour > 23) alarm.offhour = 24 - alarm.offhour;
                    }

                    if (debug) server.log("Alarm triggered at " + format("%02i", hours) + ":" + format("%02i", minutes));
                }
            }

            // Check if it's time to turn an alarm off
            if (alarm.offhour == hours && alarm.offmins == minutes) {
                // Zap the offtimes to prevent repeated triggers of this stanza
                alarm.offhour = 99;
                alarm.offmins = 99;

                // Set the 'show alarm flash' flag to end flashing
                if (alarmFlashState != ALARM_STATE_OFF) alarmFlashState = ALARM_STATE_DONE;

                // If the alarm is not a repeater, mark it for deletion
                alarm.state = alarm.repeat ? ALARM_STATE_OFF : ALARM_STATE_DONE;

                if (debug) server.log("Alarm stopped at " + format("%02i", hours) + ":" + format("%02i", minutes));
            }
        }

        // Clear all completed alarms which are not on repeat
        local i = 0;
        local flag = false;
        while (i < settings.alarms.len()) {
            local alarm = settings.alarms[i];
            if (alarm.state == ALARM_STATE_DONE) {
                // Alarm is only done if it's not on repeat, so remove
                // it and flag that we have made one or more deletions
                flag = true;
                settings.alarms.remove(i);
                if (debug) server.log("Alarm at " + format("%02i", alarm.hour) + ":" + format("%02i", alarm.min) + " removed");
            } else {
                i++;
            }
        }

        // If we have made changes, inform the agent
        if (flag) agent.send("update.alarms", settings.alarms);

        // Make sure the alarm isn't flashing when it doesn't need to
        if (settings.alarms.len() > 0) {
            flag = false;

            foreach (alarm in settings.alarms) {
                // Flag if at least one alarm is on
                if (alarm.state == ALARM_STATE_ON) {
                    flag = true;
                    break;
                }
            }

            // If no alarms are on, if necessary, mark the display flashing to be disabled
            if (!flag && alarmFlashState != ALARM_STATE_OFF) alarmFlashState = ALARM_STATE_DONE;
        } else {
            // All existing alarms were deleted above, so if necessary, mark
            // the display flashing to be disabled ( see displayTime() )
            if (alarmFlashState != ALARM_STATE_OFF) alarmFlashState = ALARM_STATE_DONE;
        }
    } else {
        // No alarms, so make sure no flash occurs
        if (alarmFlashState != ALARM_STATE_OFF) alarmFlashState = ALARM_STATE_DONE;
    }
}


function sortAlarms() {
    // ADDED IN 2.1.0
    // Sort the alarms into incidence order
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
    // ADDED IN 2.1.0
    // Add a new alarm to the list
    if (settings.alarms.len() > 0) {
        // We have some alarms set, so check that the new one is not
        // already on the list
        foreach (alarm in settings.alarms) {
            if (alarm.hour == newAlarm.hour && alarm.min == newAlarm.min) {
                // Alarm matches an existing one - are we setting the repeat value? If so, bail
                if (alarm.repeat == newAlarm.repeat) return;

                // Otherwise, make the change and update the agent
                alarm.repeat = newAlarm.repeat;

                // Update the agent's list
                agent.send("update.alarms", settings.alarms);

                if (debug) server.log("Alarm at " + format("%02i", alarm.hour) + ":" + format("%02i", alarm.min) + " updated: repeat " + (alarm.repeat ? "on" : "off"));
                return;
            }
        }
    }

    // Add the new alarm to the list
    newAlarm.state <- ALARM_STATE_OFF;
    newAlarm.offmins <- 99;
    newAlarm.offhour <- 99;
    settings.alarms.append(newAlarm);
    sortAlarms();
    if (debug) server.log("Alarm " + settings.alarms.len() + " added. Time: " + format("%02i", newAlarm.hour) + ":" + format("%02i", newAlarm.min));

    // Update the agent's list
    agent.send("update.alarms", settings.alarms);
}

function clearAlarm(index) {
    // ADDED IN 2.1.0
    // Remove the alarm from the array; it's at index 'index'
    if (settings.alarms.len() > 0) {
        // First, check that the value of 'index' is valid
        if (index < 0 || index > settings.alarms.len() - 1) {
            if (debug) server.error("clearAlarm() bad alarm index: " + index);
            return;
        }

        // Set the alarm's state to DONE so that it removed by the alarm handler, checkAlarms()
        local alarm = settings.alarms[index];
        if (alarm.state == ALARM_STATE_ON) stopAlarm(index);
        alarm.state = ALARM_STATE_DONE;
    }
}

function stopAlarm(index) {
    // ADDED IN 2.1.0
    // Silence the alarm from the array; it's at index 'index'
    if (settings.alarms.len() > 0) {
        // First, check that the value of 'index' is valid
        if (index < 0 || index > settings.alarms.len() - 1) {
            if (debug) server.error("stopAlarm() bad alarm index: " + index);
            return;
        }

    // Set the alarm's state so that it is either removed by the alarm handler,
    // checkAlarms(), or causes checkAlarms() to stop the flash
    local alarm = settings.alarms[index];
    alarm.state = alarm.repeat ? ALARM_STATE_OFF : ALARM_STATE_DONE;
    if (debug) server.log("Alarm at " + format("%02i", alarm.hour) + ":" + format("%02i", alarm.min) + " silenced at " + format("%02i", hours) + ":" + format("%02i", minutes));
    }
}


/*
 * NIGHT MODE FUNCTIONS
 */
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

    if (debug) server.log("Night mode to start at " + format("%02i", settings.timer.on.hour) + ":" + format("%02i", settings.timer.on.min) + " and end at " + format("%02i", settings.timer.off.hour) + ":" + format("%02i", settings.timer.off.min));
}


/*
 * OFFLINE OPERATION FUNCTIONS
 */
function discHandler(event) {
    // Called if the server connection is broken or re-established
    if ("message" in event && debug) server.log("Connection Manager: " + event.message);

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
                if (debug) server.log("Connection Manager: Disconnection duration " + delta + " seconds");
                disTime = 0;
            }
        }
    }
}


/*
 * START OF PROGRAM
 */

// Load in generic boot message code
// If you are NOT using Squinter or a similar tool, replace the following #import statement(s)
// with the contents of the named file(s):
#import "../generic-squirrel/bootmessage.nut"        // Source code: https://github.com/smittytone/generic-squirrel

// Set up the crash reporter
crashReporter.init();

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

// FROM 2.2.8
// Get the I2C devices (only displays on the bus)
local i2cs = [];
for (local i = 2 ; i < 256 ; i += 2) {
    if (hardware.i2c89.read(i, "", 1) != null) i2cs.append(i >> 1);
}

if (i2cs.len() < 4) {
    // Backup if something goes wrong
    display.append(HT16K33MatrixCustom(hardware.i2c89, 0x70));
    display.append(HT16K33MatrixCustom(hardware.i2c89, 0x71));
    display.append(HT16K33MatrixCustom(hardware.i2c89, 0x74));
    display.append(HT16K33MatrixCustom(hardware.i2c89, 0x75));
} else {
    display.append(HT16K33MatrixCustom(hardware.i2c89, i2cs[0]));
    display.append(HT16K33MatrixCustom(hardware.i2c89, i2cs[1]));
    display.append(HT16K33MatrixCustom(hardware.i2c89, i2cs[2]));
    display.append(HT16K33MatrixCustom(hardware.i2c89, i2cs[3]));
}

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
agent.on("clock.set.alarm", setAlarm);
agent.on("clock.clear.alarm", clearAlarm);
agent.on("clock.stop.alarm", stopAlarm);
agent.on("clock.set.nightmode", setNight);
agent.on("clock.set.nighttime", setNightTime);
agent.on("clock.set.video", setInverse);

// Next, other actions
agent.on("clock.do.reboot", function(dummy) {
    imp.reset();
});

// impOS Polite Deployment
server.onshutdown(function(reason) {
    // Trigger the crash reporter
    local reasons = ["new Squirrel", "impOS Update", "other"];
    agent.send("crash.reporter.relay.debug.error", "Polite Deployment triggered -- reason " + reasons[reason]);
    server.flush(10);

    // Trigger the update itself
    imp.wakeup(10, function() {
        server.restart();
    });
});

// Get preferences from server
// NOTE no longer need this here as it's handled via DisconnectManager
// agent.send("clock.get.prefs", true);
// if (debug) server.log("Requesting preferences from agent");