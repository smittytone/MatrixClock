// Matrix Clock
// Copyright 2016-17, Tony Smith

#require "Rocky.class.nut:2.0.0"

// CONSTANTS

const APP_NAME = "Clock";
const APP_VERSION = "1.2";
const HTML_STRING = @"<!DOCTYPE html><html lang='en-US'><meta charset='UTF-8'>
<html>
    <head>
        <title>Matrix Clock</title>
        <link rel='stylesheet' href='https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css'>
        <link href='//fonts.googleapis.com/css?family=Rubik' rel='stylesheet'>
        <link href='//fonts.googleapis.com/css?family=Monofett' rel='stylesheet'>
        <link href='//fonts.googleapis.com/css?family=Questrial' rel='stylesheet'>
        <meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
            .center { margin-left: auto; margin-right: auto; margin-bottom: auto; margin-top: auto; }
            body {background-color: #222222;}
            p {color: white; font-family: Questrial}
            h2 {color: #33cc00; font-family: Monofett; font-size: 4em}
            h4 {color: white; font-family: Questrial}
            td {color: white; font-family: Questrial}
            hr {border-color: #33cc00}
            .error-message {color: white}
        </style>
    </head>
    <body>
        <div class='container' style='padding: 20px;'>
            <div style='border: 2px solid #33cc00' align='center'>
                <h2 align='center'>Matrix Clock</h2>
                <p align='center'>&nbsp;</p>
                <table width='100%%'>
                    <tr>
                        <td width='20%%'>&nbsp;</td>
                        <td width='60%%'>
                            <h4>General Settings</h4>
                            <div class='mode-checkbox' style='color:white;font-family:Questrial'>
                                <input type='checkbox' name='mode' id='mode' value='mode'> 24-Hour Mode (Switch off for AM/PM)
                            </div>
                            <div class='mode-checkbox' style='color:white;font-family:Questrial'>
                                <input type='checkbox' name='bst' id='bst' value='bst'> Apply Daylight Savings Time Automatically
                            </div>
                            <div class='seconds-checkbox' style='color:white;font-family:Questrial'>
                                <input type='checkbox' name='seconds' id='seconds' value='seconds'> Show Seconds Indicator
                            </div>
                            <div class='flash-checkbox' style='color:white;font-family:Questrial'>
                                <input type='checkbox' name='flash' id='flash' value='seconds'> Flash Seconds Indicator
                            </div>
                            <div class='slider'>
                                <p>&nbsp;<br>Clock Brightness</p>
                                <input type='range' name='brightness' id='brightness' value='15' min='1' max='15'>
                                <p class='brightness-status' align='right'>Brightness: <span></span></p>
                            </div>
                            <div class='onoff-button' style='color:dimGrey;font-family:Rubik;weight:bold' align='center'>
                                <button type='submit' id='onoff' style='height:32px;width:200px'>Turn off Display</button>
                            </div>
                            <hr>
                            <div class='utc-controls'>
                                <h4>World Time</h4>
                                <div class='utc-checkbox' style='color:white;font-family:Questrial'>
                                    <small><input type='checkbox' name='utc' id='utc' value='utc'> Show World Time</small>
                                </div>
                                <div class='utc-slider'>
                                    <input type='range' name='utcs' id='utcs' value='0' min='0' max='24'>
                                    <table width='100%%'><tr><td width='30%%' align='left'>-12</td><td width='40%%' align='center'>0</td><td width='30%%' align='right'>+12</td></tr></table>
                                    <p class='utc-status' align='right'>&nbsp;<br>Offset from local time: <span></span> hours</p>
                                </div>
                            </div>
                            <hr>
                            <h4 align='center' class='clock-status'><i><span>This Matrix Clock is online</span></i></h4>
                            <hr>
                            <div class='reset-button' style='color:dimGrey;font-family:Rubik;weight:bold' align='center'>
                                <button type='submit' id='reset' style='height:28px;width:200px'>Reset Matrix Clock</button>
                            </div>
                        </td>
                        <td width='20%%'>&nbsp;</td>
                    </tr>
                </table>
                <p class='text-center'>&nbsp;<br><small>Matrix Clock copyright &copy; 2014-17 Tony Smith</small><br>&nbsp;<br><img src='https://smittytone.github.io/rassilon.png' width='32' height='32'></p>
            </div>
        </div>

        <script src='https://ajax.googleapis.com/ajax/libs/jquery/3.1.1/jquery.min.js'></script>
        <script>
          // Variables
          var agenturl = '%s';
          var displayon = true;
          var stateflag = false;

          // Get initial readings
          getState(updateReadout);

          // Set UI click actions: Checkboxes
          $('#mode').click(setmode);
          $('#bst').click(setbst);
          $('#seconds').click(setcolon);
          $('#flash').click(setflash);
          $('#utc').click(setutc);
          // $('#debug').click(setdebug);

          // Buttons
          $('.reset-button button').click(reset);
          $('.onoff-button button').click(setlight);

          // Slider
          var slider = document.getElementById('brightness');
          slider.addEventListener('mouseup', updateSlider);
          slider.addEventListener('touchend', updateSlider);
          $('.brightness-status span').text(slider.value);
          $('#brightness').css('background', '#222222');

          // World Time Slider
          slider = document.getElementById('utcs');
          slider.addEventListener('mouseup', updateutc);
          slider.addEventListener('touchend', updateutc);
          $('.utc-status span').text(slider.value);
          $('#utcs').css('background', '#222222');

          // Functions
          function updateSlider() {
            $('.brightness-status span').text($('#brightness').val());
            setbright();
          }

          function updateutc() {
            var u = $('#utcs').val();
            $('.utc-status span').text(u - 12);
            if (document.getElementById('utc').checked == true) {
              setutc();
            }
          }

          function updateReadout(data) {
            var s = data.split('.');
            document.getElementById('mode').checked = (s[0] == '1') ? true : false;
            document.getElementById('bst').checked = (s[1] == '1') ? true : false;
            document.getElementById('seconds').checked = (s[3] == '1') ? true : false;
            document.getElementById('flash').checked = (s[2] == '1') ? true : false;
            document.getElementById('utc').checked = (s[5] == '1') ? true : false;

            var b = parseInt(s[6]);
            $('.utc-status span').text(b - 12);
            $('#utcs').val(b);

            $('.onoff-button button').text((s[7] == '1') ? 'Turn off Display' : 'Turn on Display');
            displayon = (s[7] == '1');

            b = parseInt(s[4]);
            $('.brightness-status span').text(b);
            $('#brightness').val(b);

            updateState(s[8]);

            // Auto-reload data in 120 seconds
            if (!stateflag) {
              checkState();
              stateflag = true;
            }
          }

          function updateState(s) {
             if (s == 'd') {
               $('.clock-status span').text('This Matrix Clock is offline');
             } else {
               $('.clock-status span').text('This Matrix Clock is online');
             }
          }

          function getState(callback) {
             // Request the current data
             $.ajax({
               url : agenturl + '/settings',
               type: 'GET',
               success : function(response) {
                 if (callback) {
                   callback(response);
                 }
               },
               error : function(xhr, textStatus, error) {
                 if (error) {
                   $('.clock-status span').text(error);
                 }
               }
             });
          }

          function checkState() {
            $.ajax({
               url : agenturl + '/state',
               type: 'GET',
               success : function(response) {
                 updateState(response)
                 setTimeout(checkState, 120000);
               },
               error : function(xhr, textStatus, error) {
                 if (error) {
                   $('.clock-status span').text(error);
                 }
               }
             });
          }

          function setmode() {
            var d = { 'setmode' : ((document.getElementById('mode').checked == true) ? '1' : '0') };
            sendstate(d);
          }

          function setbst() {
            var d = { 'setbst' : ((document.getElementById('bst').checked == true) ? '1' : '0') };
            sendstate(d);
          }

          function setcolon() {
            var d = { 'setcolon' : ((document.getElementById('seconds').checked == true) ? '1' : '0') };
            sendstate(d);
          }

          function setflash() {
            var d = { 'setflash' : ((document.getElementById('flash').checked == true) ? '1' : '0') };
            sendstate(d);
          }

          function setbright() {
            var d = { 'setbright' : ($('#brightness').val()) };
            sendstate(d);
          }

          function setlight() {
            displayon = !displayon;
            $('.onoff-button button').text(displayon ? 'Turn off Display' : 'Turn on Display');
            var s = (displayon ? '1' : '0');
            var d = { 'setlight' :  s };
            sendstate(d);
          }

          function setutc() {
            var d = { 'setutc' : ((document.getElementById('utc').checked == true) ? '1' : '0'), 'utcval' : $('#utcs').val() };
            sendstate(d);
          }

          function sendstate(data) {
            $.ajax({
              url : agenturl + '/settings',
              type: 'POST',
              data: JSON.stringify(data),
              success: function() {
                getState(updateReadout);
              },
              error : function(xhr, textStatus, error) {
                if (error) {
                  $('.clock-status span').text(error);
                }
              }
            });
          }

          function reset() {
            // Trigger a settings reset
            $.ajax({
              url : agenturl + '/action',
              type: 'POST',
              data: JSON.stringify({ 'action' : 'reset' }),
              success : function(response) {
                getState(updateReadout);
              }
            });
          }

          function setdebug() {
            // Tell the device to enter or leave debug mode
            $.ajax({
              url : agenturl + '/action',
              type: 'POST',
              data: JSON.stringify({ 'action' : 'debug', 'debug' : document.getElementById('debug').checked }),
              error : function(xhr, textStatus, error) {
                if (error) {
                  $('.clock-status span').text(error);
                }
              }
            });
          }

          function reboot() {
            // Trigger a device restart
            $.ajax({
              url : agenturl + '/action',
              type: 'POST',
              data: JSON.stringify({ 'action' : 'reboot' }),
              success : function(response) {
                getState(updateReadout);
              },
              error : function(xhr, textStatus, error) {
                if (error) {
                  $('.clock-status span').text(error);
                }
              }
            });
          }
        </script>
    </body>
</html>";

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

    if (debug) {
    	// Also switch the device to debug mode
    	device.send("mclock.set.debug", 1);
    	server.log("Clock told to enter debug mode");
    } else {
    	device.send("mclock.set.debug", 0);
    }
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
            if (debug) server.log("Clock bst observance turned " + (prefs.bst ? "on" : "off"));
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
                device.send("clock.set.utc", "N");
            } else if (data.setutc == "1") {
                prefs.utc = true;
                if ("utcval" in data) {
                    prefs.utcoffset = data.utcval.tointeger();
                    device.send("clock.set.utc", data.utcval);
                }
            } else {
                if (debug) server.error("Attempt to pass an mis-formed parameter to setutc");
                contex.send(400, "Mis-formed parameter sent");
                return;
            }

            if (server.save(prefs) > 0) server.error("Could not save world time setting");
            if (debug) server.log("World time turned " + (prefs.utc ? "on" : "off") + ", offset: " + prefs.offset);
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
