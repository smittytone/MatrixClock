# MatrixClock 1.1

An [Electric Imp](https://electricimp.com/) imp001-based digital clock using four [Adafruit 8x8 LED matrix displays](http://www.adafruit.com/products/1854) based on the Holtek HT16K33 controller, embedded in a custom laser-cut acrylic case.

## Hardware

![Matrix Clock](matrixclock.jpg)

### Ingredients

- 1 x [Electric Imp Developer Kit](https://electricimp.com/docs/gettingstarted/devkits/)
- 4 x [Adafruit 1.2-inch 8x8 Square LED Matrix plus Backpack](http://www.adafruit.com/products/1854)
- 1x or 2x barrel jack
- 2x mini solder-less breadboards

### Circuit

*Circuit to follow*

### Setup

You’ll need to visit [Electric Imp](https://ide.electricimp.com/login/) to sign up for a free developer account. You will be asked to confirm your email address.

Visit Electric Imp’s [Getting Started Guide](https://electricimp.com/docs/gettingstarted/blinkup/) to learn how to configure your imp001 to access your local WiFi network, and how to enter code into the IDE and run it on your device.

## Software

The Matrix Clock is controlled by the same API as the [Big Clock](https://github.com/smittytone/BigClock) design.

### UK/US Usage

The Matrix Clock device code is currently hardwired for UK usage: it adjusts to British Summer Time (BST) and back to Greenwich Mean Time (GMT) as appropriate. To do so, it makes use of Electric Imp’s [Utilities library](https://electricimp.com/docs/libraries/utilities/utilities/) and its *bstCheck()* function. This call can be replaced with the *dstCheck()* function if you wish to use a Matrix Clock in the US. This change will cause the clock to adjust to US Daylight Savings Time.

## Casing

You can use the file `clock.svg` to produce a simple laser-cut case/mounting frame for the Matrix Clock.

[![Matrix Clock](laser.jpg)](clock.svg)

## Licence

The design and software for Matrix Clock are made available under the [MIT Licence](./LICENSE).

Copyright 2016-2017, Tony Smith