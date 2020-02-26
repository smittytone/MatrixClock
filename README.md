# MatrixClock 2.2.8 #

An [Electric Imp](https://electricimp.com/) imp001-based digital clock using four [Adafruit 8x8 LED matrix displays](http://www.adafruit.com/products/1854) based on the Holtek HT16K33 controller, embedded in a custom laser-cut acrylic case.

## Hardware ##

<p><img src="images/matrixclock.jpg" width="760" alt="The Matrix Clock in use" /></p>

### Ingredients ##

- 1 x [Electric Imp Developer Kit](https://developer.electricimp.com/gettingstarted/devkits)
- 4 x [Adafruit 1.2-inch 8x8 Square LED Matrix plus Backpack](http://www.adafruit.com/products/1854)
- 1x or 2x barrel jack
- 2x mini solder-less breadboards

### Circuit ###

<p><img src="images/circuit.png" width="760" alt="The Matrix Clock circuit design" /></p>

The circuit shown is idealised. Power comes from the imp breakout board’s USB port (VIN). In practice, you will want to re-position the imp relative to the LED matrices, and I added to barrel jack power ports in parallel and positioned so that you can run a cable into the top of the clock or up to its base, depending on where you plan to site the clock. The jacks were wired directly to the GND and power rails, and from there to the imp board’s P+ and P- panels. The jumper on the board was adjusted accordingly.

### Assembly ###

If you use the laser-cut [casing](#casing), make sure you first place the faceplate face down, fit the LED matrices into the cut-out correctly, and then use a glue gun to fill the gaps between the faceplate and the matrices’ circuitboards, which overhang the LEDs by approximately 5mm. This will hold them in place while you assemble the circuit &mdash; you can then slot LEDs into the board, add the side plates and finally glue on the backplate.

### Setup ###

You’ll need to visit [Electric Imp](https://impcentral.electricimp.com/login) to sign up for a free developer account. You will be asked to confirm your email address.

Visit Electric Imp’s [Getting Started Guide](https://developer.electricimp.com/gettingstarted/blinkup) to learn how to configure your imp001 to access your local WiFi network, and how to enter code into impCentral and run it on your device.

The application code makes use of a number of components not all of which are included in the device and agent code listings. You can spot these external components by looking for the `#import` statements by which they are referenced. You can use a tool like [Squinter](https://smittytone.github.io/squinter/index.html) or [impt](https://developer.electricimp.com/tools/impworks/impt/) to ‘compile’ these parts into complete device and agent code, and upload it to the Electric Imp impCloud™. Alternatively, you can simply copy and paste the contents of the files names in the `#import` statements into the main code blocks, then copy and paste this code into [impCentral™](https://developer.electricimp.com/tools/impcentral/impcentralintroduction), Electric Imp’s online IDE.

Not all of the required components are included in this repository: they are not specific to this application. Only the files `matrixclock_ui.html` and `HT16K33MatrixCustom.class.nut` are included here. The other components can be found in these repositories:

- [utilities.nut](https://github.com/smittytone/generic)
- [disconnect.nut](https://github.com/smittytone/generic)
- [bootmessage.nut](https://github.com/smittytone/generic)
- [HT16K33Matrix.class.nut](https://github.com/smittytone/HT16K33Matrix)

## Usage ##

### UK/US Usage ###

The Matrix Clock device code is currently hardwired for UK usage: it adjusts to British Summer Time (BST) and back to Greenwich Mean Time (GMT) as appropriate. To do so, it makes use of my [Utilities library](https://github.com/smittytone/generic) and its *bstCheck()* function. This call can be replaced with the *dstCheck()* function if you wish to use a Matrix Clock in the US. This change will cause the clock to adjust to US Daylight Savings Time. The code can readily be adapted to match other territories’ daylight savings periods.

### Control UI ###

The Matrix Clock can be controlled by accessing its agent URL:

<p><img src="images/grab01.png" width="400" alt="The Matrix Clock web-based UI" /></p>

### Night Mode ###

Version 2.1.0 introduces a new option: night mode. Using night mode, which is enabled or disabled through the web UI, the clock will power down its display overnight. This can be useful if you don't like the clock filling the room with light at night. Even with the LED brightness set to minimum, it will generate a lot of illumination in a darkened room. You may find this unappealing, especially if the clock is placed in a bedroom, and night mode allows you to deal with this without having to manually turn off the display at nighttime.

When you enable night mode in the UI, the clock turns off the display automatically at a time you specify. It then turns on the display at a subsequent time. You set these times &mdash; respectively, night start and end &mdash; in the UI using 24-hour clock values. The default values are: start 22:30, end 07:00.

You can still turn the clock display on (or off) during unlit (or lit) periods using the UIs ‘Turn Display On/Off’ button.

## Casing ##

You can use the file `clock.svg` to produce a simple laser-cut case/mounting frame for the Matrix Clock.

[![Matrix Clock](images/laser.jpg)](files/clock.svg)

## Release Notes ##

- 2.2.8 *26 February 2020*
    - Support HT16K33Matrix 3.0.0, Bootstrap 4.4.1.
    - Discover displays on the I2C bus and use the detected addresses.
        - Deals with alternatively wired hardware, provided the display’s LED are addressed in left-to-right ascending order.
        - Include fallback configuration in case there is an error.
- 2.2.7 *18 December 2019*
    - Support Rocky 3.0.0.
- 2.2.6 *22 October 2019*
    - Fix incorrectly named variables in *clearAlarm()* and *stopAlarm()*.
    - Alarm table CSS fixes and minor changes.
- 2.2.5 *5 September 2019*
    - Support polite deployments
    - Update Jquery to 3.4.1, Boostrap to 4.3.1, Simpleslack to 1.0.1, Bootmessage to 2.2.2
- 2.2.4 *18 April 2019*
    - Update JQuery to 3.4.0
- 2.2.3 *6 March 2019*
    - Add low, mid and high brightness icons to the web UI
    - Update dependencies: HT16K33MatrixCustom/HT16K33Matrix 2.0.0
- 2.2.2 *18 February 2019*
    - Sync device and agent code with [Clock](https://github.com/smittytone/Clock)
    - Add API debugging
    - Remove redundant agent-side **server.save()** result checks
- 2.2.1 *30 January 2019*
    - Refresh web UI logo
- 2.2.0 *19 December 2018*
    - Add visual alarms
- 2.1.0 *3 December 2018*
    - Add an option to automatically [turn off the clock display overnight](#night-mode)
    - Add an option to switch display between black on green and green on black
    - Improve UI layout
    - Update matrix LED class
- 2.0.0 *1 November 2018*
    - Update dependencies
    - Restructure API to use JSON
    - Improved [Apple Watch Controller](https://github.com/smittytone/Controller) support
    - Improved error handling
    - Improved settings handling
    - Improved web UI code
- 1.6.0 *11 September 2018*
    - Add **Advanced Settings** area to UI; move Reset button into it; add Debug checkbox
- 1.5.0 *7 June 2018*
    - Update Web UI based on Bootstrap
    - Separate out Web UI code into own file for clarity
    - Use [DisconnectionManager](https://github.com/smittytone/generic/blob/master/disconnect.nut)
    - Update to [JQuery 3.3.1](https://jquery.com)
    - Prevent Ajax XHR caching
- 1.4.0
    - Bring dependencies up to date
- 1.3.0
    - Add support for world time display, including web UI controls
    - Add favicon and iOS home page icon
- 1.2.0
    - Add web UI controls
- 1.1.0
    - Initial public release

## Licence ##

The design and software for Matrix Clock are made available under the [MIT Licence](./LICENSE).

Copyright &copy; 2016-2020, Tony Smith