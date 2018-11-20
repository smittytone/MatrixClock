// Matrix Clock
// Copyright 2016-18, Tony Smith

// IMPORTS
#require "Rocky.class.nut:2.0.1"

// If you are NOT using Squinter or a similar tool, comment out the following line...
#import "~/Dropbox/Programming/Imp/Codes/matrixclock.nut"
// ...and uncomment and fill in this line:
// const APP_CODE = "YOUR_APP_UUID";

// CONSTANTS
// If you are NOT using Squinter or a similar tool, replace the following #import statement
// with the contents of the named file (matrixclock_ui.html)
const HTML_STRING = @"
#import "matrixclock_ui.html"
";

// MAIN VARIABLES
local prefs = null;
local savedResponse = null;
local api = null;
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
                   // ADDED IN 2.1.0: times to disbale clock (eg. over night)
                   "timer"       : { "on"  : { "hour" : prefs.timer.on.hour,  "min"  : prefs.timer.on.min },
                                     "off" : { "hour" : prefs.timer.off.hour, "min" : prefs.timer.off.min },
                                     "isset" : prefs.timer.isset }
                   "isconnected" : device.isconnected() };
    
    return http.jsonencode(data, { "compact" : true });
}

function encodePrefsForWatch() {
    // Responds to Controller's request for the clock's settings
    // with a subset of the current device settings
    local data = { "mode"        : prefs.hrmode,
                   "bright"      : prefs.brightness,
                   "world"       : { "utc" : prefs.utc },
                   "on"          : prefs.on,
                   "isconnected" : device.isconnected() };
    return http.jsonencode(data, { "compact" : true });
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

    // ADDED IN 2.1.0: times to disbale clock (eg. over night)
    prefs.timer <- { "on"  : { "hour" : 7,  "min" : 00 }, 
                     "off" : { "hour" : 22, "min" : 30 },
                     "isset" : false,
                     "isadv" : false };
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
    if (server.save(prefs) > 0) server.error("Could not save settings");
});

// Set up the control and data API
api = Rocky();

api.authorize(function(context) {
    // Mandate HTTPS connections
    if (context.getHeader("x-forwarded-proto") != "https") return false;
    return true;
});

api.onUnauthorized(function(context) {
    // Incorrect level of access security
    context.send(401, "Insecure access forbidden");
});

// Serve the web UI for a GET at the agent root
api.get("/", function(context) {
    context.send(200, format(HTML_STRING, http.agenturl()));
});

// Serve the clock status for a GET to /status
api.get("/status", function(context) {
    local r = { "isconnected" : device.isconnected() };
    if (stateChange) r.force <- true;
    stateChange = false;
    context.send(200, http.jsonencode(r, { "compact" : true }));
});

// Serve up the settings JSON for a GET to /settingss
api.get("/settings", function(context) {
    context.send(200, encodePrefsForUI());
});

// Deal with incoming settings changes made by sending
// a POST to /settings with JSON as the payload
api.post("/settings", function(context) {
    try {
        local data = http.jsondecode(context.req.rawbody);

        // Check for a mode-set message (value arrives as a bool)
        if ("setmode" in data) {
            if (data.setmode) {
                prefs.hrmode = true;
            } else if (!data.setmode) {
                prefs.hrmode = false;
            } else {
                local e = reportAPIError("setmode");
                if (debug) server.error(e);
                context.send(400, e);
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save mode setting");
            if (debug) server.log("UI says change mode to " + (prefs.hrmode ? "24 hour" : "12 hour"));
            device.send("clock.set.mode", prefs.hrmode);
        }

        // Check for a BST set/unset message (value arrives as a bool)
        if ("setbst" in data) {
            if (data.setbst) {
                prefs.bst = true;
            } else if (!data.setbst) {
                prefs.bst = false;
            }  else {
                local e = reportAPIError("setbst");
                if (debug) server.error(e);
                context.send(400, e);
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save BST/GMT setting");
            if (debug) server.log("UI says turn BST observance " + (prefs.bst ? "on" : "off"));
            device.send("clock.set.bst", prefs.bst);
        }

        // Check for a set colon show message (value arrives as a bool)
        if ("setcolon" in data) {
            if (data.setcolon) {
                prefs.colon = true;
            } else if (!data.setcolon) {
                prefs.colon = false;
            } else {
                local e = reportAPIError("setcolon");
                if (debug) server.error(e);
                context.send(400, e);
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save colon visibility setting");
            if (debug) server.log("UI says turn colon " + (prefs.colon ? "on" : "off"));
            device.send("clock.set.colon", prefs.colon);
        }

        // Check for a set flash message (value arrives as a bool)
        if ("setflash" in data) {
            if (data.setflash) {
                prefs.flash = true;
            } else if (!data.setflash) {
                prefs.flash = false;
            } else {
                local e = reportAPIError("setflash");
                if (debug) server.error(e);
                context.send(400, e);
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save colon flash setting");
            if (debug) server.log("UI says turn colon flashing " + (prefs.flash ? "on" : "off"));
            device.send("clock.set.flash", prefs.flash);
        }

        // Check for a set brightness message (value arrives as a string)
        if ("setbright" in data) {
            // Check that the conversion to integer works
            try {
                prefs.brightness = data.setbright.tointeger();
                if (server.save(prefs) != 0) server.error("Could not save brightness setting");
                if (debug) server.log(format("UI says set display brightness to %i", prefs.brightness));
                device.send("clock.set.brightness", prefs.brightness);
            } catch (err) {
                local e = reportAPIError("setbright");
                if (debug) server.error(e);
                contex.send(400, e);
                return;
            }
        }
 
        // Check for set light message (value arrives as a bool)
        if ("setlight" in data) {
            if (data.setlight) {
                prefs.on = true;
            } else if (!data.setlight) {
                prefs.on = false;
            } else {
                local e = reportAPIError("setlight");
                if (debug) server.error(e);
                contex.send(400, e);
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save display light setting");
            if (debug) server.log("UI says turn display " + (prefs.on ? "on" : "off"));
            device.send("clock.set.light", prefs.on);
        }

        // Check for set world time message (value arrives as a bool with subsidiary string value)
        if ("setutc" in data) {
            // Is there an offset value?
            if ("utcval" in data) {
                // Check that it can be converted to an integer
                try {
                    prefs.utcoffset = data.utcval.tointeger();
                } catch (err) {
                    // 'utcval' not an integer-compatible string.
                    // Just ignore the error as we won't set anything
                    if (debug) server.error(reportAPIError("setutc:utcval"));
                }
            }
            
            // Is world time switch on or off
            if (!data.setutc) {
                prefs.utc = false;
                device.send("clock.set.utc", { "state" : prefs.utc });
            } else if (data.setutc) {
                prefs.utc = true;
                device.send("clock.set.utc", { "state" : prefs.utc, "offset" : prefs.utcoffset });
            } else {
                local e = reportAPIError("setutc");
                if (debug) server.error(e);
                contex.send(400, e);
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save world time setting");
            if (debug) server.log("UI says turn world time mode " + (prefs.utc ? "on" : "off") + ", offset: " + prefs.utcoffset);
        }

        // ADDED IN 2.1.0
        if ("setnight" in data) {
            if (data.setnight) {
                prefs.timer.isset = true;
            } else if (!data.setnight) {
                prefs.timer.isset = false;
            } else {
                local e = reportAPIError("setnight");
                if (debug) server.error(e);
                context.send(400, e);
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save night mode setting");
            if (debug) server.log("UI says " + (prefs.timer.isset ? "enable" : "disable") + " night mode");
            device.send("clock.set.nightmode", prefs.timer.isset);
        }

        if ("setdimmer" in data) {
            local set = false;
            if ("dimmeron" in data) {
                prefs.timer.on = { "hour" : data.dimmeron.hour.tointeger(),  "min" : data.dimmeron.min.tointeger() };
                set = true;
            }

            if ("dimmeroff" in data) {
                prefs.timer.off = { "hour" : data.dimmeroff.hour.tointeger(),  "min" : data.dimmeroff.min.tointeger() };
                set = true;
            }

            if (!set) {
                local e = reportAPIError("setdimmer");
                if (debug) server.error(e);
                context.send(400, e);
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save night mode times");
            if (debug) server.log("UI says set night time to start at " + format("%02i", prefs.timer.on.hour) + ":" + format("%02i", prefs.timer.on.min) + " and end at " + format("%02i", prefs.timer.off.hour) + ":" + format("%02i", prefs.timer.off.min));
            device.send("clock.set.nighttime", prefs.timer);
        }

        context.send(200, "OK");
    } catch (err) {
        server.error(err);
        context.send(400, "Bad data posted");
        return;
    }

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
