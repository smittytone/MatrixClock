// Matrix Clock
// Copyright 2016-19, Tony Smith

// IMPORTS
#require "Rocky.class.nut:2.0.2"

// If you are NOT using Squinter or a similar tool, comment out the following line...
#import "~/Dropbox/Programming/Imp/Codes/matrixclock.nut"
// ...and uncomment and fill in this line:
// const APP_CODE = "YOUR_APP_UUID";
// NOTE You can ignore the section above if you are NOT including Apple Watch support
//      (see https://github.com/smittytone/Controller)

// CONSTANTS
const MAX_ALARMS = 8;
// If you are NOT using Squinter or a similar tool, replace the following #import statements
// with the contents of the named files (matrixclock_ui.html, silence_img.nut and delete_img.nut)
// Source code for these files here: https://github.com/smittytone/MatrixClock
#import "img_delete.nut"
#import "img_silence.nut"
#import "img_low.nut"
#import "img_high.nut"
const HTML_STRING = @"
#import "matrixclock_ui.html"       
";


// MAIN VARIABLES
local prefs = null;
local savedResponse = null;
local api = null;
local savedContext = null;
local debug = false;
local stateChange = false;


// CLOCK FUNCTIONS
// NOTE These primarily centre around device settings:
//      sending them to the newly booted device, sending them to
//      controllers, eg. Apple Watch and the web UI

function sendPrefsToDevice(value) {
    // The Matrix Clock unit has requested the current set-up data
    if (debug) server.log("Sending stored preferences to the Matrix Clock");
    device.send("clock.set.prefs", prefs);
}

function encodePrefsForUI() {
    // Responds to the UI's request for the clock's settings
    // by sendung all the clock's settings plus its connected state
    local data = { "mode"        : prefs.hrmode,
                   "bst"         : prefs.bst,
                   "flash"       : prefs.flash,
                   "colon"       : prefs.colon,
                   "bright"      : prefs.brightness,
                   "world"       : { "utc"    : prefs.utc,
                                     "offset" : prefs.utcoffset },
                   "on"          : prefs.on,
                   "debug"       : prefs.debug,
                   "isconnected" : device.isconnected(),
                   // ADDED IN 2.1.0: 
                   // Times to disable clock (eg. over night)
                   "timer"       : { "on"  : { "hour" : prefs.timer.on.hour,  "min"  : prefs.timer.on.min },
                                     "off" : { "hour" : prefs.timer.off.hour, "min" : prefs.timer.off.min },
                                     "isset" : prefs.timer.isset },
                   "video"       : prefs.video,
                   // Alarm list (functionality coming in 2.2.0)
                   "alarms"      : prefs.alarms };
    
    return http.jsonencode(data, {"compact" : true});
}

function encodePrefsForWatch() {
    // Responds to Controller's request for the clock's settings
    // with a subset of the current device settings
    local data = { "mode"        : prefs.hrmode,
                   "bright"      : prefs.brightness,
                   "world"       : { "utc" : prefs.utc },
                   "on"          : prefs.on,
                   "isconnected" : device.isconnected() };
    return http.jsonencode(data, {"compact" : true});
}

function resetPrefs() {
    // Clear the settings and re-save to the agent storage
    // NOTE This is handy if we change the number of keys in prefs table
	server.save({});

	// Reset 'prefs' values to the defaults
	initialisePrefs();

    // Resave the prefs
    server.save(prefs);
}

function initialisePrefs() {
    // Set the clock settings
    // The table is formatted thus:
    //    ON: true/false for display on
    //    HRMODE: true/false for 24/12-hour view
    //    BST: true/false for adapt for daylight savings/stick to GMT
    //    COLON: true/false for colon shown if NOT flashing
    //    FLASH: true/false for colon flash
    //    UTC: true/false for UTC set/unset
    //    UTCOFFSET: 0-24 for GMT offset (subtract 12 for actual value)
    //    BRIGHTNESS: 1 to 15 for boot-set LED brightness
    prefs = {};
    prefs.on <- true;
    prefs.hrmode <- true;
    prefs.bst <- true;
    prefs.colon <- true;
    prefs.flash <- true;
    prefs.utc <- false;
    prefs.debug <- false;
    prefs.utcoffset <- 12;  // ie. no offset
    prefs.brightness <- 15;

    // ADDED IN 2.1.0
    // Times to disbale clock (eg. over night)
    prefs.timer <- { "on"  : { "hour" : 7,  "min" : 00 }, 
                     "off" : { "hour" : 22, "min" : 30 },
                     "isset" : false,
                     "isadv" : false };
    // Alarm list (functionality coming in 2.2.0)
    prefs.alarms <- [];
    // Inverse video
    prefs.video <- false;
}

function reportAPIError(func) {
    // Assemble an API response error message
    return ("Mis-formed parameter sent (" + func +")");
}


// PROGRAM START

// Initialize the clock's preferences - we will read in saved values, if any, next
initialisePrefs();

local loadedPrefs = server.load();

if (loadedPrefs.len() != 0) {
    // Table is NOT empty so set the prefs to the loaded table
    prefs = loadedPrefs;
    
    // Handle prefs added post-release
    if (!("debug" in prefs)) {
        prefs.debug <- debug;
        server.save(prefs);
    } else {
        debug = prefs.debug;
    }

    // ADDED IN 2.1.0: times to disbale clock (eg. over night)
    if (!("timer" in prefs)) {
        prefs.timer <- { "on"  : { "hour" : 7,  "min" : 00 }, 
                         "off" : { "hour" : 22, "min" : 30 },
                         "isset" : false,
                         "isadv" : false };
        server.save(prefs);
    } else {
        local doSave = false;
        
        if (!("isset" in prefs.timer)) {
            prefs.timer.isset <- false;
            doSave = true;
        }

        if (!("isadv" in prefs.timer)) {
            prefs.timer.isadv <- false;
            doSave = true;
        }

        if (doSave) server.save(prefs);
    }

    // ADDED IN 2.1.0: support new alarms setting
    if (!("alarms" in prefs)) {
        prefs.alarms <- [];
    }

    // ADDED IN 2.1.0: support new inverse video setting
    if (!("video" in prefs)) {
        prefs.video <- false;
    }

    // This has to go LAST
    if (debug) {
        server.log("Clock settings loaded:");
        server.log(encodePrefsForUI());
    }
} else {
    // Table is empty, so this must be a first run
    if (debug) server.log("First Matrix Clock run");
}

// Register device event triggers
device.on("clock.get.prefs", sendPrefsToDevice);

device.on("display.state", function(state) {
    stateChange = true;
    prefs.on = state.on;
    prefs.timer.isadv = state.advance;
    if (server.save(prefs) > 0) server.error("Could not save settings (display.state)");
});

// ADDED IN 2.2.0
device.on("update.alarms", function(alarms) {
    prefs.alarms = alarms;
    stateChange = true;
    if (server.save(prefs) > 0) server.error("Could not save settings (update.alarms)");
});

// Set up the control and data API
api = Rocky();

// Set up UI access security
api.authorize(function(context) {
    // Mandate HTTPS connections
    if (context.getHeader("x-forwarded-proto") != "https") return false;
    return true;
});

api.onUnauthorized(function(context) {
    // Incorrect level of access security
    context.send(401, "Insecure access forbidden");
});


/*
    CLOCK ENDPOINTS

    Settings
        GET  /settings -> JSON, settings + connection state
        POST /settings <- JSON, one or more settings to change.

    Actions
        POST /actions <- JSON, action type, eg. reset, plus binary switches

    Status
        GET /status -> JSON, connection state + should UI force an update

    Controller Support
        GET /controller/info -> JSON, app ID, watch support
        GET controller/state -> JSON, subset of settings + connection state
*/


// Serve the web UI for a GET at the agent root
api.get("/", function(context) {
    context.send(200, format(HTML_STRING, http.agenturl()));
});

// Serve up the settings JSON for a GET to /settings
api.get("/settings", function(context) {
    context.send(200, encodePrefsForUI());
});

// Deal with incoming settings changes made by sending
// a POST to /settings with JSON as the payload
api.post("/settings", function(context) {
    try {
        local data = http.jsondecode(context.req.rawbody);
        local error = null;
        
        foreach (setting, value in data) {
            // Check for a mode-set message (value arrives as a bool)
            // eg. { "setmode" : true }
            if (setting == "setmode") {
                if (typeof value != "bool") {
                    error = reportAPIError("setmode");
                    break;
                }

                prefs.hrmode = value;
                if (debug) server.log("UI says change mode to " + (prefs.hrmode ? "24 hour" : "12 hour"));
                device.send("clock.set.mode", prefs.hrmode);
            }

            // Check for a set colon show message (value arrives as a bool)
            // eg. { "setcolon" : true }
            if (setting == "setcolon") {
                if (typeof value != "bool") {
                    error = reportAPIError("setcolon");
                    break;
                }

                prefs.colon = value;
                if (debug) server.log("UI says turn colon " + (prefs.colon ? "on" : "off"));
                device.send("clock.set.colon", prefs.colon);
            }

            // Check for a set flash message (value arrives as a bool)
            // eg. { "setflash" : true }
            if (setting == "setflash") {
                if (typeof value != "bool") {
                    error = reportAPIError("setflash");
                    break;
                }

                prefs.flash = value;
                if (debug) server.log("UI says turn colon flashing " + (prefs.flash ? "on" : "off"));
                device.send("clock.set.flash", prefs.flash);
            }

            // Check for set light message (value arrives as a bool)
            // eg. { "setlight" : true }
            if (setting == "setlight") {
                if (typeof value != "bool") {
                    error = reportAPIError("setlight");
                    break;
                }

                prefs.on = value;
                if (debug) server.log("UI says turn display " + (prefs.on ? "on" : "off"));
                device.send("clock.set.light", prefs.on);
            }

            // Check for a BST set/unset message (value arrives as a bool)
            // eg. { "setbst" : true }
            if (setting == "setbst") {
                if (typeof value != "bool") {
                    error = reportAPIError("setbst");
                    break;
                }

                prefs.bst = value;
                if (debug) server.log("UI says turn BST observance " + (prefs.bst ? "on" : "off"));
                device.send("clock.set.bst", prefs.bst);
            }

            // Check for a set brightness message (value arrives as a string)
            // eg. { "setbright" : 10 }
            if (setting == "setbright") {
                // Check that the conversion to integer works
                try {
                    value = value.tointeger();
                } catch (err) {
                    error = reportAPIError("setbright");
                    break;
                }

                prefs.brightness = value;
                if (debug) server.log(format("UI says set display brightness to %i", prefs.brightness));
                device.send("clock.set.brightness", prefs.brightness);
            }
    
            // Check for set world time message (value arrives as a table)
            // eg. { "setutc" : { "state" : true, "utcval" : -12 } }
            if (setting == "setutc") {
                if (typeof value != "table") {
                    error = reportAPIError("setutc");
                    break;
                }

                if ("state" in value) {
                    if (typeof value.state != "bool") {
                        error = reportAPIError("setutc.state");
                        break;
                    }

                    prefs.utc = value.state;
                }

                if ("offset" in value) {
                    // Check that it can be converted to an integer
                    try {
                        value.offset = value.offset.tointeger();
                    } catch (err) {
                        error = reportAPIError("setutc.offset");
                        break;
                    }

                    prefs.utcoffset = value.offset;
                }

                if (debug) server.log("UI says turn world time mode " + (prefs.utc ? "on" : "off") + ", offset: " + prefs.utcoffset);
                device.send("clock.set.utc", { "state" : prefs.utc, "offset" : prefs.utcoffset });
            }

            // ADDED IN 2.1.0
            // Check for use dimmer time message (value arrives as a bool)
            // eg. { "setnight" : true }
            if (setting == "setnight") {
                if (typeof value != "bool") {
                    error = reportAPIError("setnight");
                    break;
                }

                prefs.timer.isset = value;
                if (debug) server.log("UI says " + (prefs.timer.isset ? "enable" : "disable") + " night mode");
                device.send("clock.set.nightmode", prefs.timer.isset);
            }

            // ADDED IN 2.1.0
            // Check for set dimmer time message (value arrives as a table)
            // eg. { "setdimmer" : { "dimmeron" : { "hour" : 23, "min" : 0 },
            //                       "dimmeroff" : { "hour" : 7, "min" : 0 } }
            if (setting == "setdimmer") {
                if (typeof value != "table") {
                    error = reportAPIError("setdimmer");
                    break;
                }

                local set = 0;
                if ("dimmeron" in value) {
                    if ("hour" in value.dimmeron) {
                        // Check that hour value can be converted to an integer
                        try {
                            value.dimmeron.hour = value.dimmeron.hour.tointeger();
                            set++;
                        } catch (err) {
                            error = reportAPIError("setdimmer.dimmeron.hour");
                            break;
                        }
                    }

                    if ("min" in value.dimmeron) {
                        // Check that minute value can be converted to an integer
                        try {
                            value.dimmeron.min = value.dimmeron.min.tointeger();
                            set++;
                        } catch (err) {
                            error = reportAPIError("setdimmer.dimmeron.min");
                            break;
                        }
                    }
                }

                if ("dimmeroff" in value) {
                    if ("hour" in value.dimmeroff) {
                        // Check that hour value can be converted to an integer
                        try {
                            value.dimmeroff.hour = value.dimmeroff.hour.tointeger();
                            set++;
                        } catch (err) {
                            error = reportAPIError("setdimmer.dimmeroff.hour");
                            break;
                        }
                    }

                    if ("min" in value.dimmeroff) {
                        // Check that minute value can be converted to an integer
                        try {
                            value.dimmeroff.min = value.dimmeroff.min.tointeger();
                            set++;
                        } catch (err) {
                            error = reportAPIError("setdimmer.dimmeroff.min");
                            break;
                        }
                    }
                }

                if (set < 4) {
                    // Not all of the required values were set
                    error = reportAPIError("setdimmer");
                    break;
                }

                prefs.timer.on.hour = value.dimmeron.hour;
                prefs.timer.on.min = value.dimmeron.min;
                prefs.timer.off.hour = value.dimmeroff.hour;
                prefs.timer.off.min = value.dimmeroff.min;

                if (debug) server.log("UI says set night time to start at " + format("%02i", prefs.timer.on.hour) + ":" + format("%02i", prefs.timer.on.min) + " and end at " + format("%02i", prefs.timer.off.hour) + ":" + format("%02i", prefs.timer.off.min));
                device.send("clock.set.nighttime", prefs.timer);
            }

            // ADDED IN 2.1.0
            // Check for inverse video on/off message (value arrives as a bool)
            // eg. { "setvideo" : true }
            if (setting == "setvideo") {
                if (typeof value != "bool") {
                    error = reportAPIError("setvideo");
                    break;
                }

                prefs.video = value;
                if (debug) server.log("UI says turn display " + (prefs.video ? "black on green" : "green on black"));
                device.send("clock.set.video", prefs.video);
            }

            // ADDED IN 2.1.0, UI FUNCTIONAL IN 2.2.0
            // Check for alarm update message (value arrives as a table)
            // eg. { "setalarm" : { "action" : "<type>",
            //                      "hour" : 7, "min" : 0, "repeat" : true } }
            if (setting == "alarm") {
                if (typeof value != "table") {
                    error = reportAPIError("setalarm");
                    break;
                }

                if ("action" in value) {
                    if (value.action == "add") {
                        if (prefs.alarms.len() == MAX_ALARMS) {
                            error = reportAPIError("setalarm") + ": Maximum number of alarms exceeded";
                            break;
                        }

                        local alarm = {};
                        
                        if ("hour" in value) {
                            try {
                                // Check that hour value can be converted to an integer
                                alarm.hour <- value.hour.tointeger();
                            } catch (err) {
                                error = reportAPIError("setalarm.add.hour");
                                break;
                            }
                        }
                        
                        if ("min" in value) {
                            try {
                                // Check that minute value can be converted to an integer
                                alarm.min <- value.min.tointeger();
                            } catch (err) {
                                error = reportAPIError("setalarm.add.min");
                                break;
                            }
                        }

                        if ("repeat" in value) {
                            if (typeof value.repeat != "bool") {
                                error = reportAPIError("setalarm.add.repeat");
                                break;
                            }

                            alarm.repeat <- value.repeat;
                        }

                        if (debug) server.log("UI says set alarm for " + format("%02i", alarm.hour) + ":" + format("%02i", alarm.min) + " (repeat: " + (alarm.repeat ? "yes" : "no") + ")");
                        device.send("clock.set.alarm", alarm);
                        prefs.alarms.append(alarm);
                    } else if (value.action == "delete") {
                        if ("index" in value) {
                            try {
                                // Check that index value can be converted to an integer
                                value.index = value.index.tointeger();
                            } catch (err) {
                                error = reportAPIError("setalarm.delete.index");
                                break;
                            }
                            
                            if (debug) server.log("UI says delete alarm at index " + value.index);
                            device.send("clock.clear.alarm", value.index);
                            prefs.alarms.remove(value.index);
                        } else {
                            error = reportAPIError("setalarm.delete");
                            break;
                        }
                    } else if (value.action == "silence") {
                        if ("index" in value) {
                            try {
                                // Check that index value can be converted to an integer
                                value.index = value.index.tointeger();
                            } catch (err) {
                                error = reportAPIError("setalarm.silence.index");
                                break;
                            }
                            
                            if (debug) server.log("UI says silence alarm at index " + value.index);
                            device.send("clock.stop.alarm", value.index);
                        } else {
                            error = reportAPIError("setalarm.delete");
                            break;
                        }
                    } else {
                        error = reportAPIError("setalarm.action");
                        break;
                    }
                } else {
                    error = reportAPIError("setalarm");
                    break;
                }
            }
        }
        
        if (error != null) {
            context.send(400, error);
            if (debug) server.error(error);
        } else {
            // Send the updated prefs back to the UI (may not be used)
            local ua = context.getHeader("user-agent");
            local r = ua == "Controller/MatrixClockInterfaceController" ? encodePrefsForWatch() : encodePrefsForUI();
            context.send(200, r);

            // Save the settings changes
            if (server.save(prefs) > 0) server.error("Could not save settings");
        }
    } catch (err) {
        server.error(err);
        context.send(400, "Bad data posted: " + context.req.rawbody);
        return;
    }

    // Just in case, but we should never hit this
    context.send(200, "OK");
});

api.post("/action", function(context) {
    try {
        local data = http.jsondecode(context.req.rawbody);

        if ("action" in data) {
            if (data.action == "reset") {
                // A RESET message sent to restore factory settings
                resetPrefs();
                device.send("clock.set.prefs", prefs);
                if (debug) server.log("Clock settings reset");
                if (server.save(prefs) != 0) server.error("Could not save Matrix Clock settings after reset");
            }

            if (data.action == "debug") {
                // A DEBUG message sent
                if (data.state == true) {
                    debug = true;
                    prefs.debug = true;
                } else {
                    debug = false;
                    prefs.debug = false;
                }

                device.send("clock.set.debug", debug);
                server.log("Setting agent debugging " + (debug ? "on" : "off"));
                if (server.save(prefs) != 0) server.error("Could not save Matrix Clock settings after debug switch");
            }

            if (data.action == "reboot") {
                // A REBOOT message sent
                device.send("clock.do.reboot", true);
                if (debug) server.log("Matrix Clock told to reboot");
            }
        }

        context.send(200, "OK");
    } catch (err) {
        context.send(400, "Bad data posted");
        server.error(err);
        return;
    }
});


// ADDED IN 2.1.0
// Serve the clock status for a GET to /status
api.get("/status", function(context) {
    local r = {"isconnected" : device.isconnected()};
    if (stateChange) r.force <- true;
    stateChange = false;
    context.send(200, http.jsonencode(r, {"compact" : true}));
});


// ADDED IN 2.2.0
// Any call to the endpoint /images is sent the correct PNG data
api.get("/images/([^/]*)", function(context) {
    // Determine which image has been requested and send the appropriate
    // stored data back to the requesting web browser
    local path = context.path;
    local name = path[path.len() - 1];
    local image = DELETE_PNG;
    if (name == "low.png") image = LOW_PNG;
    if (name == "high.png") image = HIGH_PNG;
    if (name == "silence.png") image = SILENCE_PNG;
    context.setHeader("Content-Type", "image/png");
    context.send(200, image);
});


// GET at /controller/info returns Controller app UUID
api.get("/controller/info", function(context) {
    local info = { "appcode": APP_CODE,
                   "watchsupported": "true" };
    context.send(200, http.jsonencode(info));
});

// GET at /controller/state returns device state
api.get("/controller/state", function(context) {
    // GET call to /controller/state returns device status
    // Send a relevant subset of the settings as JSON
    context.send(200, encodePrefsForWatch());
});
