// Matrix Clock
// Copyright 2016-17, Tony Smith
// Version 1.1

// GLOBALS

local prefs = {};
local saveResponse = null;
local debug = true;

// USE 'true' TO ZAP THE STORED DEFAULTS
local firstRun = false;

// CLOCK FUNCTIONS

function sendPrefsToDevice(value) {
    // Matrix Clock has requested the current set-up data
    if (debug) server.log("Sending stored preferences to the Matrix Clock");
    device.send("mclock.set.prefs", prefs);
}

function appResponse() {
    // Responds to the app's request for the clock's set-up data
    // Generates a string in the form:
    //
    //   1.1.1.1.01.1.01.1.d
    //
    // for the values
    //   mode
    //   bst state
    //   colon flash
    //   colon state
    //   brightness
    //   utc state
    //   utc offset
    //   display state
    //
    // UTC offset is the value for the app's UIPicker, ie. 0 to 24
    // (mapping in device code to offset values of +12 to -12)
    //
    // .d is ONLY added if the agent detects the device is not
    // connected when this method is called

    // Add Mode as a 1-digit value
    local rs = "0.";
    if (prefs.hrmode == true) rs = "1.";

    // Add BST status as a 1-digit value
    if (prefs.bst) {
        rs = rs + "1.";
    } else {
        rs = rs + "0.";
    }

    // Add colon flash status as a 1-digit value
    if (prefs.flash) {
        rs = rs + "1.";
    } else {
        rs = rs + "0.";
    }

    // Add colon state as a 1-digit value
    if (prefs.colon) {
        rs = rs + "1.";
    } else {
        rs = rs + "0.";
    }

    // Add brightness as a two-digit value
    rs = rs + format("%02d", prefs.brightness) + ".";

    // Add UTC status as a 1-digit value
    if (prefs.utc) {
        rs = rs + "1.";
    } else {
        rs = rs + "0.";
    }

    // Add UTC offset
    rs = rs + format("%02d", prefs.utcoffset) + ".";

    // Add clock state as 1-digit value
    if (prefs.on) {
        rs = rs + "1";
    } else {
        rs = rs + "0";
    }

    if (!device.isconnected()) rs = rs + ".d";

    // Return data string to app via cached HTTP response
    saveResponse.send(200, rs);
}

function requestHandler(request, response) {
    try {
        // Check for app test
        if ("getappcode" in request.query) {
            response.send(200, appID);
            return;
        }

        // Check for a mode-read message
        if ("getmode" in request.query) {
            saveResponse = response;
            appResponse();
            return;
        }

        // Check for a reset message
        if ("reset" in request.query) {
            reset();
            sendPrefsToDevice(true);

            if (server.save(prefs) == 0) {
                response.send(200, "Settings reset");
            } else {
                response.send(200, "Settings not reset");
            }

            return;
        }

        // Check for a mode-set message
        // ?setmode=24 or ?setmode=12 for 24/12-hour clock
        if ("setmode" in request.query) {
            if (request.query.setmode == "1" || request.query.setmode == "24") {
                device.send("mclock.set.mode", 24);
                prefs.hrmode = true;
            } else {
                device.send("mclock.set.mode", 12);
                prefs.hrmode = false;
            }

            response.send(200, "Clock mode switched");

            if (server.save(prefs) == 0) {
                if (debug) server.log("Mode setting saved");
            } else {
                if (debug) server.log("Mode setting not saved");
            }

            return;
        }

        // Check for a BST set/unset message
        // ?setbst=1 or ?setbst=0 for BST/GMT
        if ("setbst" in request.query) {
            if (request.query.setbst == "1") {
                device.send("mclock.set.bst", 1);
                prefs.bst = true;
            } else {
                device.send("mclock.set.bst", 0);
                prefs.bst = false;
            }

            response.send(200, "BST setting switched");

            if (server.save(prefs) == 0) {
                if (debug) server.log("BST setting saved");
            } else {
                if (debug) server.log("BST setting not saved");
            }

            return;
        }

        // Check for a UTC set/unset and offset message
        // ?setutc=0.xx or ?setutc=1.xx for set/unset world time
        // xx = two-digit offset (-12 for the actual value)
        if ("setutc" in request.query) {
            local us = "";

            // Slice up incoming data string to obtain parameters
            if (request.query.setutc.slice(0,1) == "1") {
                // UTC is set
                prefs.utc = true;
                us = request.query.setutc;
                us = us.slice(2);
                prefs.utcoffset = us.tointeger();
            } else {
                // Set the string to be passed to the imp to zero if
                // world time is being disabled
                prefs.utc = false;
                us = "N";
            }

            device.send("mclock.set.utc", us);
            response.send(200, "UTC set");

            if (server.save(prefs) == 0) {
                if (debug) server.log("UTC setting saved");
            } else {
                if (debug) server.log("UTC setting not saved");
            }

            return;
        }

        // Check for a set brightness message
        if ("setbright" in request.query) {
            // Note this only sets prefs, to be applied next time the device
            // boots up. ?setbright=xx xx = 0-15
            prefs.brightness = request.query.setbright.tointeger();
            device.send("mclock.set.brightness", prefs.brightness);

            response.send(200, "Brightness set");

            if (server.save(prefs) == 0) {
                if (debug) server.log("Brightness setting saved");
            } else {
                if (debug) server.log("Brightness setting not saved");
            }

            return;
        }

        // Check for a set flash message
        if ("setflash" in request.query) {
            if (request.query.setflash == "1") {
                device.send("mclock.set.flash", 1);
                prefs.flash = true;
            } else {
                device.send("mclock.set.flash", 0);
                prefs.flash = false;
            }

            response.send(200, "Colon flash set");

            if (server.save(prefs) == 0) {
                if (debug) server.log("Colon flash setting saved");
            } else {
                if (debug) server.log("Colon flash setting not saved");
            }

            return;
        }

        // Check for a set colon show message
        if ("setcolon" in request.query) {
            if (request.query.setcolon == "1") {
                device.send("mclock.set.colon", 1);
                prefs.colon = true;
            } else {
                device.send("mclock.set.colon", 0);
                prefs.colon = false;
            }

            response.send(200, "Colon state set");

            if (server.save(prefs) == 0) {
                if (debug) server.log("Colon state setting saved");
            } else {
                if (debug) server.log("Colon state setting not saved");
            }

            return;
        }

        if ("setlight" in request.query) {
            if (request.query.setlight == "1") {
                device.send("mclock.set.light", 1);
                prefs.on = true;
            } else {
                device.send("mclock.set.light", 0);
                prefs.on = false;
            }

            response.send(200, "Light switched");

            if (server.save(prefs) == 0) {
                if (debug) server.log("Display light setting saved");
            } else {
                if (debug) server.log("Display light setting not saved");
            }

            return;
        }

        // If the command has not been recognised, inform the app
        response.send(200, "Command not recognised");
    } catch(error) {
        response.send(500, ("Agent error: " + error));
    }
}

function reset() {
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

// Register an agent event trigger for HTTP requests from app
http.onrequest(requestHandler);

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
} else {
    // Table is empty, so this must be a first run
    if (debug) server.log("First Matrix Clock run");
}

// Register device event triggers
device.on("mclock.get.prefs", sendPrefsToDevice);
