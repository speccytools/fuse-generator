	//
//  JWSpectrumScreen.h
//  Mac2SpecQLPlugin
//
//  Created by James Weatherley on 09/11/2007.
//  Copyright 2007 James Weatherley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "JWSpectrumScreenConstants.h"


// Structure representing a byte of screen.
typedef struct BitmapByteData {
	unsigned char bitmapByte;	// Bits 1 - ink, 0 - paper
	int paper;					// Paper colour in RGB
	int ink;					// Ink colour in RGB
} BitmapByteData;


@interface JWSpectrumScreen : NSObject {

	// The Spectrum screen. Bitmaps + attributes.
	NSMutableData* zxScreen;
	
	// What display mode are we using?
	ScreenMode mode;

	// Size of the canvas.
	// This is the size that OS X will draw, standard and
	// high colour screens will be 256x192, but high res
	// screens will be 512x384 to preserve the aspect ratio.
	NSSize canvasSize;
}

// Internal utility method.
- (BOOL)initialise;

// Create an instance from the passed data object.
// Returns 'nil' if:
//   The data pointed to is not the right size - see constants above.
- (id)initFromData:(NSData*)scrData;

// Create an instance from whatever the URL is pointing to.
// Returns 'nil' if:
//   The URL is invalid
//   The data pointed to is not the right size - see constants above.
- (id)initWithContentsOfURL:(NSURL*)url;

// Create an instance based on the image representation and screen mode passed in.
// Returns 'nil' if the representation is the wrong size. Only 256x192 for standard
// and high colour screens, and either 512x192 or 512x384 for high res, are allowed.
// If a 512x384 image rep is used, only the even scan lines are considered.
//
// The representaion should also be dithered and consist of legal colours as defined in
// ColourMacros.h. This is not enforced (yet), but the results of using a non-conforming
// imagerep are undefined.
//
// The final argument is ignored except for Timex high resolution images. 
// It determines the colour scheme to be used. I think it's needed because
// even if a bitmap contains the correct pair of colours, we can't tell which
// is meant to be paper, and which is meant to be ink.
- (id)initWithRepresentation:(NSBitmapImageRep*)rep mode:(ScreenMode)screenMode hiResMode:(TimexHiResMode)hiMode;

// Returns an NSBitmapImageRep* so you can draw the screen on a Mac.
- (NSBitmapImageRep*)imageRep;

// Returns a bitmap byte, paper and ink.
// Preconditions:
//   x must be byte aligned - ie divisible by eight.
//   x and y must lie within 'canvasSize'.
//
// The ink and paper colours returned in BitmapByteData are
// Spectrum colours. They will be in the range 0 <= col < 14
// which represents BLACK to WHITE followed by the bright versions.
// of the non-black colours. Obtain an RGB value defined in ColourMacros.h
// as follows:
//   int macRGB = spectrumColourFromIndex(spectrumColour);
//
// Paper and ink are undefined for Timex high res screens.
- (BitmapByteData)bitmapByteDataAtX:(int)x y:(int)y;

// As above, except it sets a bitmap byte.
// Preconditions:
//   As above and ink and paper must be in the range 0 <= col < 14.
//   ie the Sepctrum colours BLACK to WHITE + BRIGHT BLUE to BRIGHT WHITE
//   if you have an RGB colour defined in ColourMacros.h you can convert it:
//		int spectrumColour = spectrumIndexFromRGB(macRGB);
- (void)setBitmapByteData:(const BitmapByteData)data atX:(int)x y:(int)y;

// Save the Spectrum screen data as a SCR file at the given path.
// Returns 'YES' is the file was saved successfully.
- (BOOL)saveScrFile:(NSURL*)url;

// Return a dictionary. 
// Valid keys are NSStrings 'Screen0', 'Screen1', 'Attributes', 'Out255'.
// Values are NSData objects refering to the names screen sections.
// Standard and Timex High Colour have non-nil 'Screen0' and 'Attributes' values.
// Timex High Res has non-nil 'Screen0', 'Screen1' and 'Out255' values.
- (NSDictionary*)screenSections;

// Return 'canvasSize'.
- (NSSize)canvasSize;

// Return the screen mode used to display the image.
- (ScreenMode)mode;

@end
