// IMPORTS
// NOTE If you're not using Squinter or an equivalent tool, cut and paste the named 
// file's code over the following line. For Squinter users, you will need to change
// the path to the file in the #import statement
#import "../HT16K33Matrix/HT16K33Matrix.class.nut"     // Source code for this file here: https://github.com/smittytone/HT16K33Matrix

class HT16K33MatrixCustom extends HT16K33Matrix {
    
    // Squirrel class for the MatrixClock
    // It extends this class: https://github.com/smittytone/HT16K33Matrix
    // to modify certain functions to meet the needs of this device

    static VERSION = "1.4.0";
    
    function setupCharset() {
        // Modify certain characters in the default character set
        // NOTE This is not present in the base class
        _pcharset[17] = "\x22\x42\xfe\x02\x02";
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
            try {
                inputMatrix = _defchars[asciiValue];
            } catch (err) {
                inputMatrix = _pcharset[63];
            }
        } else {
            // A standard character has been chosen
            asciiValue = asciiValue - 32;
            if (asciiValue < 0 || asciiValue > _alphaCount) asciiValue = 63;
            inputMatrix = _pcharset[asciiValue];
        }

        _buffer = blob(8);

        if (_inverseVideoFlag) {
            for (local i = 0 ; i < 8 ; i++) {
                _buffer[i] = 0xFF;
            }
        }

        for (local i = 0 ; i < inputMatrix.len() ; i++) {
            local a = i + offset;
            
            if (a < 8) {
                _buffer[a] = _inverseVideoFlag ? _flip(~inputMatrix[i]) : _flip(inputMatrix[i]);
            } else {
                break;
            }
        }
    }
}
