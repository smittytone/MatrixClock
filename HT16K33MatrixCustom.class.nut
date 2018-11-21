// CLASS CONSTANTS
// HT16K33 registers and HT16K33-specific variables
const HT16K33_MAT_CUSTOM_CLASS_REGISTER_DISPLAY_ON  = "\x81"
const HT16K33_MAT_CUSTOM_CLASS_REGISTER_DISPLAY_OFF = "\x80"
const HT16K33_MAT_CUSTOM_CLASS_REGISTER_SYSTEM_ON   = "\x21"
const HT16K33_MAT_CUSTOM_CLASS_REGISTER_SYSTEM_OFF  = "\x20"
const HT16K33_MAT_CUSTOM_CLASS_DISPLAY_ADDRESS      = "\x00"
const HT16K33_MAT_CUSTOM_CLASS_I2C_ADDRESS          = 0x70

class HT16K33MatrixCustom {
    // Squirrel class for 1.2-inch 8x8 LED matrix displays driven by the HT16K33 controller
    // For example: http://www.adafruit.com/products/1854
    // Bus: I2C
    // Availibility: Device
    // Written by Tony Smith (@smittytone)
    // Copyright 2014-18
    // Issued under the MIT license (MIT)

    static VERSION = "1.3.0";

    // Proportionally space character set
    static _pcharset = [
        "\x00\x00",              // space - Ascii 32
        "\xfa",                  // !
        "\xc0\x00\xc0",          // "
        "\x24\x7e\x24\x7e\x24",  // #
        "\x24\xd4\x56\x48",      // $
        "\xc6\xc8\x10\x26\xc6",  // %
        "\x6c\x92\x6a\x04\x0a",  // &
        "\xc0",                  // '
        "\x7c\x82",              // (
        "\x82\x7c",              // )
        "\x10\x7c\x38\x7c\x10",  // *
        "\x10\x10\x7c\x10\x10",  // +
        "\x06\x07",              // ,
        "\x10\x10\x10\x10\x10",  // -
        "\x06\x06",              // .
        "\x04\x08\x10\x20\x40",  // /
        "\x7c\x8a\x92\xa2\x7c",  // 0 - Ascii 48
        "\x22\x42\xfe\x02\x02",  // 1 - NOTE This is a custom version of this char (cf https://github.com/smittytone/HT16K33Matrix)
        "\x46\x8a\x92\x92\x62",  // 2
        "\x44\x92\x92\x92\x6c",  // 3
        "\x18\x28\x48\xfe\x08",  // 4
        "\xf4\x92\x92\x92\x8c",  // 5
        "\x3c\x52\x92\x92\x8c",  // 6
        "\x80\x8e\x90\xa0\xc0",  // 7
        "\x6c\x92\x92\x92\x6c",  // 8
        "\x60\x92\x92\x94\x78",  // 9
        "\x36\x36",              // : - Ascii 58
        "\x36\x37",              // ;
        "\x10\x28\x44\x82",      // <
        "\x24\x24\x24\x24\x24",  // =
        "\x82\x44\x28\x10",      // >
        "\x60\x80\x9a\x90\x60",  // ?
        "\x7c\x82\xba\xaa\x78",  // @
        "\x7e\x90\x90\x90\x7e",  // A - Ascii 65
        "\xfe\x92\x92\x92\x6c",  // B
        "\x7c\x82\x82\x82\x44",  // C
        "\xfe\x82\x82\x82\x7c",  // D
        "\xfe\x92\x92\x92\x82",  // E
        "\xfe\x90\x90\x90\x80",  // F
        "\x7c\x82\x92\x92\x5c",  // G
        "\xfe\x10\x10\x10\xfe",  // H
        "\x82\xfe\x82",          // I
        "\x0c\x02\x02\x02\xfc",  // J
        "\xfe\x10\x28\x44\x82",  // K
        "\xfe\x02\x02\x02\x02",  // L
        "\xfe\x40\x20\x40\xfe",  // M
        "\xfe\x40\x20\x10\xfe",  // N
        "\x7c\x82\x82\x82\x7c",  // O
        "\xfe\x90\x90\x90\x60",  // P
        "\x7c\x82\x92\x8c\x7a",  // Q
        "\xfe\x90\x90\x98\x66",  // R
        "\x64\x92\x92\x92\x4c",  // S
        "\x80\x80\xfe\x80\x80",  // T
        "\xfc\x02\x02\x02\xfc",  // U
        "\xf8\x04\x02\x04\xf8",  // V
        "\xfc\x02\x3c\x02\xfc",  // W
        "\xc6\x28\x10\x28\xc6",  // X
        "\xe0\x10\x0e\x10\xe0",  // Y
        "\x86\x8a\x92\xa2\xc2",  // Z - Ascii 90
        "\xfe\x82\x82",          // [
        "\x40\x20\x10\x08\x04",  // \
        "\x82\x82\xfe",          // ]
        "\x20\x40\x80\x40\x20",  // ^
        "\x02\x02\x02\x02\x02",  // _
        "\xc0\xe0",              // '
        "\x04\x2a\x2a\x1e",      // a - Ascii 97
        "\xfe\x22\x22\x1c",      // b
        "\x1c\x22\x22\x22",      // c
        "\x1c\x22\x22\xfc",      // d
        "\x1c\x2a\x2a\x10",      // e
        "\x10\x7e\x90\x80",      // f
        "\x18\x25\x25\x3e",      // g
        "\xfe\x20\x20\x1e",      // h
        "\xbc\x02",              // i
        "\x02\x01\x21\xbe",      // j
        "\xfe\x08\x14\x22",      // k
        "\xfc\x02",              // l
        "\x3e\x20\x18\x20\x1e",  // m
        "\x3e\x20\x20 \x1e",     // n
        "\x1c\x22\x22\x1c",      // o
        "\x3f\x22\x22\x1c",      // p
        "\x1c\x22\x22\x3f",      // q
        "\x22\x1e\x20\x10",      // r
        "\x12\x2a\x2a\x04",      // s
        "\x20\x7c\x22\x04",      // t
        "\x3c\x02\x02\x3e",      // u
        "\x38\x04\x02\x04\x38",  // v
        "\x3c\x06\x0c\x06\x3c",  // w
        "\x22\x14\x08\x14\x22",  // x
        "\x39\x05\x06\x3c",      // y
        "\x26\x2a\x2a\x32",      // z - Ascii 122
        "\x10\x7c\x82\x82",      // {
        "\xee",                  // |
        "\x82\x82\x7c\x10",      // }
        "\x40\x80\x40\x80",      // ~
        "\x60\x90\x90\x60"       // Degrees sign - Ascii 127
    ];

    // Class private properties
    _buffer = null;
    _led = null;
    _defchars = null;

    _ledAddress = 0;
    _alphaCount = 96;
    _rotationAngle = 0;
    _rotateFlag = false;
    _inverseVideoFlag = false;
    _debug = false;

    constructor(impI2Cbus = null, i2cAddress = 0x70, debug = false) {
        // Parameters:
        //   1. Whichever configured imp I2C bus is to be used for the HT16K33
        //   2. The HT16K33's I2C address (default: 0x70)
        //   3. Boolean - set/unset to log/silence error messages
        //
        // Returns:
        //   HT16K33MatrixCustom instance; throws on error
        if (impI2Cbus == null) throw "HT16K33MatrixCustom requires a non-null imp I2C object";
        _led = impI2Cbus;
        _ledAddress = i2cAddress << 1;
        
        if (typeof debug != "bool") debug = false;
        _debug = debug;

        _buffer = blob(8);
        _defchars = {};
    }

    function init(brightness = 15, angle = 0) {
        // Parameters:
        //   1. Display brightness, 1-15 (default: 15)
        //   2. Display auto-rotation angle, 0 to -360 degrees (default: 0)
        // Returns: 
        //   Nothing

        // Angle range can be -360 to + 360 - ignore values beyond this
        if (angle < -360 || angle > 360) angle = 0;

        // Convert angle in degrees to internal value:
        // 0 = none, 1 = 90 clockwise, 2 = 180, 3 = 90 anti-clockwise
        if (angle < 0) angle = 360 + angle;

        if (angle > 3) {
            if (angle < 45 || angle > 360) angle = 0;
            if (angle >= 45 && angle < 135) angle = 1;
            if (angle >= 135 && angle < 225) angle = 2;
            if (angle >= 225) angle = 3
        }

        _rotationAngle = angle;
        if (_rotationAngle != 0) _rotateFlag = true;

        // Power up and set the brightness
        powerUp();
        setBrightness(brightness);
        clearDisplay();
    }

    function setBrightness(brightness = 15) {
        // Parameters:
        //   1. Display brightness, 1-15 (default: 15)
        // Returns: 
        //   Nothing
        
        if (typeof brightness != "integer" && typeof brightness != "float") brightness = 15;
        brightness = brightness.tointeger();

        if (brightness > 15) {
            brightness = 15;
            if (_debug) server.error("HT16K33MatrixCustom.setBrightness() brightness out of range (0-15)");
        }

        if (brightness < 0) {
            brightness = 0;
            if (_debug) server.error("HT16K33MatrixCustom.setBrightness() brightness out of range (0-15)");
        }

        if (_debug) server.log("Brightness set to " + brightness);
        brightness = brightness + 224;

        // Write the new brightness value to the HT16K33
        _led.write(_ledAddress, brightness.tochar() + "\x00");
    }

    function clearDisplay() {
        // Parameters: 
        //   None
        // Returns: 
        //   Nothing

        _buffer = blob(8);
        if (_inverseVideoFlag) {
            for (local i = 0 ; i < 8 ; i++) {
                _buffer[i] = 0xFF;
            }
        }
        _writeDisplay();
    }

    function setInverseVideo(state = true) {
        // Parameters:
        //   1. Boolean: whether inverse video is set (true) or unset (false)
        // Returns: 
        //   Nothing

        if (typeof state != "bool") state = true;
        _inverseVideoFlag = state;
        if (_debug) server.log(format("Switching the HT16K33 Matrix to %s", (state ? "inverse video" : "normal video")));
        _writeDisplay();
    }

    function displayIcon(glyphMatrix, center = false) {
        // Displays a custom character
        // Parameters:
        //   1. Array of 1-8 8-bit values defining a pixel image
        //      The data is passed as columns
        //   2. Boolean indicating whether the icon should be displayed
        //      centred on the screen
        // Returns: nothing

        local type = typeof glyphMatrix;
        if (glyphMatrix == null || (type != "array" && type != "string" && type != "blob")) {
            if (_debug) server.error("HT16K33MatrixCustom.displayIcon() passed undefined icon array");
            return;
        }

        if (glyphMatrix.len() < 1 || glyphMatrix.len() > 8) {
            if (_debug) server.error("HT16K33MatrixCustom.displayIcon() passed incorrectly sized icon array");
            return;
        }

        _buffer = blob(8);

        if (_inverseVideoFlag) {
            for (local i = 0 ; i < 8 ; i++) {
                _buffer[i] = 0xFF;
            }
        }

        for (local i = 0 ; i < glyphMatrix.len() ; i++) {
            local a = i;
            if (center) a = i + ((8 - glyphMatrix.len()) / 2).tointeger();
            _buffer[a] = _inverseVideoFlag ? ~glyphMatrix[i] : glyphMatrix[i];
        }
    }

    function displayChar(asciiValue = 32, offset = 0) {
        // Display a single character specified by its Ascii value
        // NOTE This is a custom version of this function (cf https://github.com/smittytone/HT16K33Matrix)
        // Parameters:
        //   1. Character Ascii code (default: 32 [space])
        //   2. Character display offset from left
        // Returns: 
        //   Nothing

        local inputMatrix;

        if (asciiValue < 32) {
            // A user-definable character has been chosen
            inputMatrix = _defchars[asciiValue];
        } else {
            // A standard character has been chosen
            asciiValue = asciiValue - 32;
            if (asciiValue < 0 || asciiValue > _alphaCount) asciiValue = 0;
            inputMatrix = _pcharset[asciiValue];
        }

        _buffer = blob(8);

        if (_inverseVideoFlag) {
            for (local i = 0 ; i < 8 ; i++) {
                _buffer[i] = 0xFF;
            }
        }

        for (local i = 0 ; i < inputMatrix.len() ; i++) {
            local a;
            if (typeof offset != "string") {
                a = i + offset;
            } else {
                if (offset == "C") a = i + ((8 - inputMatrix.len()) / 2).tointeger();
                if (offset == "R") a = i + (8 - inputMatrix.len()).tointeger();
                if (offset == "L") a = i;
            }

            if (a < 8) {
                _buffer[a] = _inverseVideoFlag ? _flip(~inputMatrix[i]) : _flip(inputMatrix[i]);
            } else {
                break;
            }
        }
    }

    function displayLine(line) {
        // Bit-scroll through the characters in the variable ‘line’
        // Parameters:
        //   1. String of text
        // Returns: 
        //   Nothing

        if (line == null || line == "") {
            if (_debug) server.error("HT16K33MatrixCustom.displayLine() sent a null or zero-length string");
            return;
        }

        foreach (index, character in line) {
            local glyph;
            if (character < 32) {
                if (!(character in _defchars) || (typeof _defchars[character] != "string")) {
                    if (_debug) server.log("Use of undefined character (" + character + ") in HT16K33MatrixCustom.displayLine()");
                    glyph = _pcharset[0];
                } else {
                    glyph = _defchars[character];
                }
            } else {
                glyph = _pcharset[character - 32];
                
                // Add a blank column spacer
                glyph = glyph + (_inverseVideoFlag ? "\xFF" : "\x00");
            }

            foreach (column, columnValue in glyph) {
                local cursor = column;
                local glyphToDraw = glyph;
                local increment = 1;
                local outputFrame = blob(8);

                if (_inverseVideoFlag) {
                    for (local i = 0 ; i < 8 ; i++) {
                        _buffer[i] = 0xFF;
                    }
                }
       
                for (local k = 0 ; k < 8 ; ++k) {
                    if (cursor < glyphToDraw.len()) {
                        outputFrame[k] = _flip(glyphToDraw[cursor]);
                        cursor++;
                    } else {
                        if (index + increment < line.len()) {
                            if (line[index + increment] < 32) {
                                if (!(line[index + increment] in _defchars) || (typeof _defchars[line[index + increment]] != "string")) {
                                    if (_debug) server.log("Use of undefined character (" + line[index + increment] + ") in HT16K33MatrixCustom.displayLine()");
                                    glyphToDraw = _pcharset[0];
                                } else {
                                    glyphToDraw = _defchars[line[index + increment]];
                                }
                            } else {
                                glyphToDraw = _pcharset[line[index + increment] - 32];
                                glyphToDraw = glyphToDraw + (_inverseVideoFlag ? "\xFF" : "\x00");
                            }
                            increment++;
                            cursor = 1;
                            outputFrame[k] = _flip(glyphToDraw[0]);
                        }
                    }
                }

                for (local k = 0 ; k < 8 ; k++) {
                    _buffer[k] = _inverseVideoFlag ? ~outputFrame[k] : outputFrame[k];
                }

                // Pause between frames according to level of rotation
                imp.sleep(_rotationAngle == 0 ? 0.060 : 0.045);

                _writeDisplay();
            }
        }
    }

    function defineChar(asciiCode = 0, glyphMatrix = null) {
        // Set a user-definable char for later use
        // Parameters:
        //   1. Character Ascii code 0-31 (default: 0)
        //   2. Array of 1-8 8-bit values defining a pixel image
        //      The data is passed as columns
        // Returns: 
        //   Nothing

        local type = typeof glyphMatrix;
        if (glyphMatrix == null || (type != "array" && type != "string" && type != "blob")) {
            if (_debug) server.error("HT16K33MatrixCustom.defineChar() passed undefined icon array");
            return;
        }

        if (glyphMatrix.len() < 1 || glyphMatrix.len() > 8) {
            if (_debug) server.error("HT16K33MatrixCustom.defineChar() passed incorrectly sized icon array");
            return;
        }

        if (asciiCode < 0 || asciiCode > 31) {
            if (_debug) server.error("HT16K33MatrixCustom.defineChar() passed an incorrect character code");
            return;
        }

        if (_debug) {
            if (asciiCode in _defchars) {
                _logger.log("Character " + asciiCode + " already defined so redefining it");
            } else {
                _logger.log("Setting user-defined character " + asciiCode);
            }
        }

        local matrix = "";
        for (local i = 0 ; i < glyphMatrix.len() ; i++) {
            matrix = matrix + _flip(glyphMatrix[i]).tochar();
        }

        // Save the string in the defchars table with the supplied Ascii code as its key
        if (asciiCode in _defchars) {
            _defchars[asciiCode] = matrix;
        } else {
            _defchars[asciiCode] <- matrix;
        }
    }

    function plot(x, y, ink = 1, xor = false) {
        // Plot a point on the matrix. (0,0) is bottom left as viewed
        // Parameters:
        //   1. Integer X co-ordinate (0 - 7)
        //   2. Integer Y co-ordinate (0 - 7)
        //   3. Integer Ink color: 1 = white, 0 = black (NOTE inverse video mode reverses this)
        //   4. Boolean indicating whether a pixel already color ink should be inverted
        // Returns:
        //   this

        if (x < 0 || x > 7) {
            server.error("HT16K33MatrixCustom.plot() X co-ordinate out of range (0-7)");
            return;
        }

        if (y < 0 || y > 7) {
            server.error("HT16K33MatrixCustom.plot() Y co-ordinate out of range (0-7)");
            return;
        }

        if (ink != 1 && ink != 0) ink = 1;
        if (_inverseVideoFlag) ink = ((ink == 1) ? 0 : 1);

        local row = _buffer[x];
        if (ink == 1) {
            // We want to set the pixel
            local bit = row & (1 << (7 - y));
            if (bit > 0 && xor) {
                // Pixel is already set, but 'xor' is true so clear the pixel
                row = row & (0xFF - (1 << (7 - y)));
            } else {
                // Pixel is clear so set it
                row = row | (1 << (7 - y));
            }
        } else {
            // We want to clear the pixel
            local bit = row & (1 << (7 - y));
            if (bit == 0 && xor) {
                // Pixel is already clear, but 'xor' is true so invert the pixel
                row = row | (1 << (7 - y));
            } else {
                // Pixel is set so clear it
                row = row & (0xFF - (1 << (7 - y)));
            }
        }

        _buffer[x] = row;
        return this;
    }

    function draw() {
        // Write out the buffer to the display
        _writeDisplay();
    }

    function powerDown() {
        if (_debug) server.log("Turning the HT16K33 Matrix off");
        _led.write(_ledAddress, HT16K33_MAT_CUSTOM_CLASS_REGISTER_DISPLAY_OFF);
        _led.write(_ledAddress, HT16K33_MAT_CUSTOM_CLASS_REGISTER_SYSTEM_OFF);
    }

    function powerUp() {
        if (_debug) server.log("Turning the HT16K33 Matrix on");
        _led.write(_ledAddress, HT16K33_MAT_CUSTOM_CLASS_REGISTER_SYSTEM_ON);
        _led.write(_ledAddress, HT16K33_MAT_CUSTOM_CLASS_REGISTER_DISPLAY_ON);
    }

    // ****** PRIVATE FUNCTIONS - DO NOT CALL ******

    function _writeDisplay() {
        // Takes the contents of _buffer and writes it to the LED matrix
        // Uses function processByte() to manipulate regular values to
        // Adafruit 8x8 matrix's format
        local dataString = HT16K33_MAT_CUSTOM_CLASS_DISPLAY_ADDRESS;
        local writedata = clone(_buffer);
        if (_rotationAngle != 0) writedata = _rotateMatrix(writedata, _rotationAngle);

        for (local i = 0 ; i < 8 ; ++i) {
            dataString = dataString + (_processByte(writedata[i])).tochar() + "\x00";
        }

        _led.write(_ledAddress, dataString);
    }

    function _flip(value) {
        // Function used to manipulate pre-defined character matrices
        // ahead of rotation by changing their byte order
        local a = 0;
        local b = 0;

        for (local i = 0 ; i < 8 ; i++) {
            a = value & (1 << i);
            if (a > 0) b = b + (1 << (7 - i));
        }

        return b;
    }

    function _rotateMatrix(inputMatrix, angle = 0) {
        // Value of angle determines the rotation:
        // 0 = none, 1 = 90 clockwise, 2 = 180, 3 = 90 anti-clockwise
        if (angle == 0) return inputMatrix;

        local a = 0;
        local lineValue = 0;
        local outputMatrix = blob(8);

        // NOTE It's quicker to have three case-specific
        //      code blocks than a single, generic block
        switch(angle) {
            case 1:
                for (local y = 0 ; y < 8 ; y++) {
                    lineValue = inputMatrix[y];
                    for (local x = 7 ; x > -1 ; --x) {
                        a = lineValue & (1 << x);
                        if (a != 0) outputMatrix[7 - x] = outputMatrix[7 - x] + (1 << y);
                    }
                }
                break;

            case 2:
                for (local y = 0 ; y < 8 ; y++) {
                    lineValue = inputMatrix[y];
                    for (local x = 7 ; x > -1 ; --x) {
                        a = lineValue & (1 << x);
                        if (a != 0) outputMatrix[7 - y] = outputMatrix[7 - y] + (1 << (7 - x));
                    }
                }
                break;

            case 3:
                for (local y = 0 ; y < 8 ; y++) {
                    lineValue = inputMatrix[y];
                    for (local x = 7 ; x > -1 ; --x) {
                        a = lineValue & (1 << x);
                        if (a != 0) outputMatrix[x] = outputMatrix[x] + (1 << (7 - y));
                    }
                }
                break;
        }

        return outputMatrix.tostring();
    }

    function _processByte(byteValue) {
        // Adafruit 8x8 matrix requires some data manipulation:
        // Bits 7-0 of each line need to be sent 0 through 7,
        // and bit 0 rotate to bit 7

        local result = 0;
        local a = 0;
        for (local i = 0 ; i < 8 ; ++i) {
            // Run through each bit in byteValue and set the
            // opposite bit in result accordingly, ie. bit 0 -> bit 7,
            // bit 1 -> bit 6, etc.
            a = byteValue & (1 << i);
            if (a > 0) result = result + (1 << (7 - i));
        }

        // Get bit 0 of result
        result & 0x01;

        // Shift result bits one bit to right
        result = result >> 1;

        // if old bit 0 is set, set new bit 7
        if (a > 0) result = result + 0x80;
        return result;
    }
}
