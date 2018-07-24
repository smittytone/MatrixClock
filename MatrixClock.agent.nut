// Matrix Clock
// Copyright 2016-18, Tony Smith

// IMPORTS
#require "Rocky.class.nut:2.0.1"

// If you are NOT using Squinter or a similar tool, comment out the following line...
#import "~/Dropbox/Programming/Imp/Codes/matrixclock.nut"
// ...and uncomment and fill in this line:
// const APP_CODE = "YOUR_APP_UUID";

// CONSTANTS
// If you are NOT using Squinter or a similar tool, replace the #import statement
// with the contents of the named file (matrixclock_ui.html)
const HTML_STRING = @"
#import "matrixclock_ui.html"
";

// MAIN VARIABLES
local prefs = null;
local saveResponse = null;
local api = null;
local debug = true;

// USE 'true' TO ZAP THE STORED DEFAULTS
local firstRun = false;

// CLOCK FUNCTIONS
function sendPrefsToDevice(value) {
    // Matrix Clock has requested the current set-up data
    if (debug) server.log("Sending stored preferences to the Matrix Clock");
    device.send("mclock.set.prefs", prefs);
    device.send("mclock.set.debug", (debug ? 1 : 0));
}

function appResponse() {
    // Responds to the app's request for the clock's set-up data
    // Generates a string in the form:
    //
    //   1.1.1.1.01.1.01.1.d
    //
    // for the values
    //   0. mode
    //   1. bst state
    //   2. colon flash
    //   3. colon state
    //   4. brightness
    //   5. utc state
    //   6. utc offset
    //   7. display state
    //   8. connection status
    //
    // UTC offset is the value for the app's UI slider, ie. 0 to 24
    // (mapping in device code to offset values of +12 to -12)

    // Add Mode as a 1-digit value
    local rs = "0.";
    if (prefs.hrmode == true) rs = "1.";

    // Add BST status as a 1-digit value
    rs = rs + ((prefs.bst) ? "1." : "0.");

    // Add colon flash status as a 1-digit value
    rs = rs + ((prefs.flash) ? "1." : "0.");

    // Add colon state as a 1-digit value
    rs = rs + ((prefs.colon) ? "1." : "0.");

    // Add brightness as a two-digit value
    rs = rs + prefs.brightness.tostring() + ".";

    // Add UTC status as a 1-digit value
    rs = rs + ((prefs.utc) ? "1." : "0.");

    // Add UTC offset
    rs = rs + prefs.utcoffset.tostring() + ".";

	// Add clock state as 1-digit value
	rs = rs + ((prefs.on) ? "1." : "0.");

    // Add d indicate disconnected, or c
    rs = rs + (device.isconnected() ? "c" : "d");

    return rs;
}

function resetToDefaults() {
    // Reset clock prefs to the defaults
    prefs.hrmode = true;
    prefs.bst = true;
    prefs.utc = false;
    prefs.flash = true;
    prefs.colon = true;
    prefs.on = true;
    prefs.utcoffset = 12;
    prefs.brightness = 15;
}

// PROGRAM START

// IMPORTANT Set firstRun at the top of the listing to reset settings
if (firstRun) server.save({});

// Set the clock preferences
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
prefs.utcoffset <- 12;
prefs.brightness <- 15;

local loadedPrefs = server.load();

if (loadedPrefs.len() != 0) {
    // Table is NOT empty so set the prefs to the loaded table
    prefs = loadedPrefs;
    if (debug) server.log("Clock settings loaded: " + appResponse());
} else {
    // Table is empty, so this must be a first run
    if (debug) server.log("First Matrix Clock run");
}

// Register device event triggers
device.on("mclock.get.prefs", sendPrefsToDevice);

// Set up the API
api = Rocky();

api.get("/", function(context) {
    context.send(200, format(HTML_STRING, http.agenturl()));
});

api.get("/state", function(context) {
    local a = (device.isconnected() ? "c" : "d");
    context.send(200, a);
});

api.get("/settings", function(context) {
    context.send(200, appResponse());
});

api.post("/settings", function(context) {
    try {
        local data = http.jsondecode(context.req.rawbody);

        // Check for a mode-set message
        if ("setmode" in data) {
            if (data.setmode == "1") {
                prefs.hrmode = true;
            } else if (data.setmode == "0") {
                prefs.hrmode = false;
            } else {
                if (debug) server.error("Mis-formed parameter to setmode");
                context.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save mode setting");
            if (debug) server.log("Clock mode turned to " + (prefs.hrmode ? "24 hour" : "12 hour"));
            device.send("mclock.set.mode", (prefs.hrmode ? 24 : 12));
        }

        // Check for a BST set/unset message
        if ("setbst" in data) {
            if (data.setbst == "1") {
                prefs.bst = true;
            } else if (data.setbst == "0") {
                prefs.bst = false;
            }  else {
                if (debug) server.error("Mis-formed parameter to setbst");
                context.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save BST/GMT setting");
            if (debug) server.log("Clock BST observance turned " + (prefs.bst ? "on" : "off"));
            device.send("mclock.set.bst", (prefs.bst ? 1 : 0));
        }

        // Check for a set brightness message
        if ("setbright" in data) {
            prefs.brightness = data.setbright.tointeger();
            if (server.save(prefs) != 0) server.error("Could not save brightness setting");
            if (debug) server.log(format("Brightness set to %i", prefs.brightness));
            device.send("mclock.set.brightness", prefs.brightness);
        }

        // Check for a set flash message
        if ("setflash" in data) {
            if (data.setflash == "1") {
                prefs.flash = true;
            } else if (data.setflash == "0") {
                prefs.flash = false;
            } else {
                if (debug) server.error("Mis-formed parameter to setflash");
                context.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save colon flash setting");
            if (debug) server.log("Clock colon flash turned " + (prefs.flash ? "on" : "off"));
            device.send("mclock.set.flash", (prefs.flash ? 1 : 0));
        }

        // Check for a set colon show message
        if ("setcolon" in data) {
            if (data.setcolon == "1") {
                prefs.colon = true;
            } else if (data.setcolon == "0") {
                prefs.colon = false;
            } else {
                if (debug) server.error("Attempt to pass an mis-formed parameter to setcolon");
                context.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save colon visibility setting");
            if (debug) server.log("Clock colon turned " + (prefs.colon ? "on" : "off"));
            device.send("mclock.set.colon", (prefs.colon ? 1 : 0));
        }

        // Check for set light message
        if ("setlight" in data) {
            if (data.setlight == "1") {
                prefs.on = true;
            } else if (data.setlight == "0") {
                prefs.on = false;
            } else {
                if (debug) server.error("Attempt to pass an mis-formed parameter to setlight");
                contex.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save display light setting");
            if (debug) server.log("Clock display turned " + (prefs.on ? "on" : "off"));
            device.send("mclock.set.light", (prefs.on ? 1 : 0));
        }

        if ("setutc" in data) {
            if (data.setutc == "0") {
                prefs.utc = false;
                device.send("mclock.set.utc", "N");
            } else if (data.setutc == "1") {
                prefs.utc = true;
                if ("utcval" in data) {
                    prefs.utcoffset = data.utcval.tointeger();
                    device.send("mclock.set.utc", prefs.utcoffset);
                } else {
                    device.send("mclock.set.utc", prefs.utcoffset);
                }
            } else {
                if (debug) server.error("Attempt to pass an mis-formed parameter to setutc");
                contex.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save world time setting");
            if (debug) server.log("World time turned " + (prefs.utc ? "on" : "off") + ", offset: " + prefs.utcoffset);
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
                resetToDefaults();
                device.send("mclock.set.prefs", prefs);
                if (debug) server.log("Clock settings reset");
                if (server.save(prefs) != 0) server.error("Could not save clock settings after reset");
            }

            if (data.action == "debug") {
                if (data.action.debug == "1") {
                    debug = true;
                } else if (data.action.debug == "0") {
                    debug = false;
                }

                device.send("mclock.set.debug", (debug ? 1 : 0));
                server.log("Debug mode " + (debug ? "on" : "off"));
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
    local data = device.isconnected() ? "1" : "0"
    context.send(200, data);
});
