// IMPORTS
// NOTE If you are not using Squinter or an equivalent tool, cut and paste the named
// file's code over the following line. For Squinter users, you will need to change
// the path to the file in the #import statement
#import "../HT16K33Matrix-Squirrel/HT16K33Matrix.class.nut"     // Source: https://github.com/smittytone/HT16K33Matrix-Squirrel

class HT16K33MatrixCustom extends HT16K33Matrix {

    // Squirrel class for the MatrixClock
    // It extends this class: https://github.com/smittytone/HT16K33Matrix
    // to modify certain functions to meet the needs of this device

    static VERSION = "3.0.0";

    function setupCharset() {
        // Modify certain characters ('0') in the default character set
        // NOTE This is not present in the base class
        _pcharset[17] = "\x22\x42\xfe\x02\x02";
    }

    function displayChar(asciiValue = 32, offset = 0) {
        // This is an overridden version of this function (cf https://github.com/smittytone/HT16K33Matrix)
        // which does not update the display at the end
        local inputMatrix;

        if (asciiValue < 32) {
            // A user-definable character has been chosen
            try {
                inputMatrix = _defchars[asciiValue];
            } catch (err) {
                // Undefined user-def char selected, so just display a ?
                inputMatrix = _pcharset[63];
            }
        } else {
            // A standard character has been chosen - if out of range, select ?
            asciiValue -= 32;
            if (asciiValue < 0 || asciiValue > _alphaCount) asciiValue = 63;
            inputMatrix = _pcharset[asciiValue];
        }

        // Clear the LED buffer
        _buffer = blob(8);

        // But if we're in inverse video mode, set all the pixels on
        if (_inverseVideoFlag) _fill();

        // Set the buffer to the input matrix values
        for (local i = 0 ; i < inputMatrix.len() ; i++) {
            local a = i + offset;
            if (a < 8) {
                _buffer[a] = _inverseVideoFlag ? ~inputMatrix[i] : inputMatrix[i];
            } else {
                break;
            }
        }
    }
}
