//
//  JWSpectrumScreen.m
//  Mac2SpecQLPlugin
//
//  Created by James Weatherley on 09/11/2007.
//  Copyright 2007 James Weatherley. All rights reserved.
//

#import "JWSpectrumScreen.h"
#import "ColourMacros.h"
#import "AttributeBlockIterator.h"
#import "AttributeBlock.h"


typedef struct BitmapOffsets {
	int bitmapOffset;
	int attrOffset;
} BitmapOffsets;

// Internal method to get the offsets for the bitmap and attribute
// for a byte in the Spectrum screen file.
BitmapOffsets bitmapOffsets(int x, int y, ScreenMode mode);


@implementation JWSpectrumScreen

- (BOOL)initialise
{
	if(zxScreen) {
		if([zxScreen length] == SCREEN_STANDARD_BYTES) {
			canvasSize.width = SCREEN_STANDARD_WIDTH;
			canvasSize.height = SCREEN_STANDARD_HEIGHT;
			mode = ScreenModeSinclair;
		} else if([zxScreen length] == SCREEN_TIMEX_HI_COL_BYTES) {
			canvasSize.width = SCREEN_STANDARD_WIDTH;
			canvasSize.height = SCREEN_STANDARD_HEIGHT;
			mode = ScreenModeTimexHiCol;
		} else if([zxScreen length] == SCREEN_TIMEX_HI_RES_BYTES) {
			canvasSize.width = SCREEN_TIMEX_HIRES_WIDTH;
			canvasSize.height = SCREEN_STANDARD_HEIGHT * 2;
			mode = ScreenModeTimexHiRes;
		} else {
			// Invalid length.
			return NO;
		}

		return YES;
	}

	return NO;
}

- (id)initFromData:(NSData*)scrData
{
	self = [super init];
	if(self) {
		zxScreen = [[NSMutableData alloc] init];
		[zxScreen setData:scrData];
		
		if( [self initialise] == NO ) {
		NSLog( @"JWSpectrumScreen: initFromData : Some problem with the source scrData.\n" );
			// Some problem with the source scrData.
			[self release];
			self = nil;
		}
	}
	return self;
}

- (id)initWithContentsOfURL:(NSURL*)url
{
	self = [super init];
	if(self) {
		NSError* error = nil;
		zxScreen = [[NSMutableData alloc] initWithContentsOfURL:url options:0 error:&error];
		
		if( [self initialise] == NO ) {
			// Some error reading data from the URL.
			[self release];
			self = nil;
		}
	}
	return self;
}

- (id)initWithRepresentation:(NSBitmapImageRep*)rep mode:(ScreenMode)screenMode hiResMode:(TimexHiResMode)hiResMode
{
	self = [super init];
	if(self) {
	
		// Check that the imagerep is the correct size.
		bool valid = true;
		NSSize size = [rep size];
		NSUInteger screenSize = 0;
		
		if(screenMode == ScreenModeSinclair || screenMode == ScreenModeTimexHiCol) {
			if(size.width != SCREEN_STANDARD_WIDTH && size.height != SCREEN_STANDARD_HEIGHT) {
				valid = false;
			} else {
				canvasSize.width = SCREEN_STANDARD_WIDTH;
				canvasSize.height = SCREEN_STANDARD_HEIGHT;
				if(screenMode == ScreenModeSinclair) {
					screenSize = SCREEN_STANDARD_BYTES;
				} else {
					screenSize = SCREEN_TIMEX_HI_COL_BYTES;
				}
			}
		} else if(screenMode == ScreenModeTimexHiRes) {
			if(size.width != SCREEN_TIMEX_HIRES_WIDTH && 
				(size.height != SCREEN_STANDARD_HEIGHT || size.height != SCREEN_STANDARD_HEIGHT * 2)) {
				valid = false;
			} else {
				canvasSize.width = SCREEN_TIMEX_HIRES_WIDTH;
				canvasSize.height = SCREEN_STANDARD_HEIGHT * 2;
				screenSize = SCREEN_TIMEX_HI_RES_BYTES;
				
				// A double height imagerep must be resized to standard height.
				// We do it in quite a hacky way :P.
				if(size.height == SCREEN_STANDARD_HEIGHT * 2) {

					NSBitmapImageRep* rep2 = [[rep copy] autorelease];					
					unsigned char* bitmapData = [rep2 bitmapData];
					NSInteger bytesPerRow = [rep2 bytesPerRow];
					NSInteger bytesPerPlane = [rep2 bytesPerPlane];
					NSInteger rows = bytesPerPlane / bytesPerRow;
					assert(rows == SCREEN_STANDARD_HEIGHT * 2);				
										
					// Here's the promised hack. We just copy the even scan lines into the top half
					// of the image rep. The block iterating code operates on the first 512x192 bytes
					// and ignores what is left further down.
					for(NSInteger i = 2; i < rows; i += 2) {
						memcpy(bitmapData + bytesPerRow * i / 2, bitmapData + bytesPerRow * i, bytesPerRow);
					}
					// Use the hacked up imagerep from now on.
					rep = rep2;
				}
			}
		} else {
			// WTF?
			valid = false;
			assert(0);
		}
		
		if(valid) {
			mode = screenMode;
			AttributeBlockIterator* blockIt = [[[AttributeBlockIterator alloc] initWithBitmap:rep mode:screenMode] autorelease];
			zxScreen = [[NSMutableData alloc] initWithLength:screenSize];
			unsigned char* zxScreenBytes = [zxScreen mutableBytes];
			
			if(screenMode == ScreenModeTimexHiRes) {
				[blockIt setHiResMode:hiResMode];
				zxScreenBytes[screenSize - 1] = hiResMode;
			}
			
			AttributeBlock* block = nil;
			while((block = [blockIt nextBlock])) {
				[block writeScreenOne:zxScreenBytes];
				[block writeScreenTwo:zxScreenBytes + SCREEN_BITMAP_SIZE];
			}
		} else {
			[self release];
			self = 0;
		}
	}
	return self;
}

- (NSBitmapImageRep*)imageRep
{
	NSBitmapImageRep* imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:0
										pixelsWide:canvasSize.width 
										pixelsHigh:canvasSize.height
										bitsPerSample:8
										samplesPerPixel:3
										hasAlpha:NO
										isPlanar:NO
										colorSpaceName:NSDeviceRGBColorSpace
										bytesPerRow:canvasSize.width * 3
										bitsPerPixel:24];
	
	if(imageRep) {
		unsigned char* imageBytes = [imageRep bitmapData];
		BitmapByteData bitmapByteData;
		
		for(int y = 0; y < canvasSize.height; ++y) {
			for(int x = 0; x < canvasSize.width; x += 8) {
				bitmapByteData = [self bitmapByteDataAtX:x y:y];
				
				for(int bit = 0; bit < 8; ++bit) {
					unsigned char mask = 1 << (7 - bit);
					int colour;
					if(bitmapByteData.bitmapByte & mask) {
						colour = spectrumColourFromIndex(bitmapByteData.ink);
					} else {
						colour = spectrumColourFromIndex(bitmapByteData.paper);
					}
					*imageBytes++ = RED(colour);
					*imageBytes++ = GREEN(colour);
					*imageBytes++ = BLUE(colour);
				}
			}
		}
	}
	
	return [imageRep autorelease];
}


- (BitmapByteData)bitmapByteDataAtX:(int)x y:(int)y
{
	// x must be byte aligned.
	// x and y must be within the canvas.
	assert(x % 8 == 0);
	assert(x < canvasSize.width);
	assert(y < canvasSize.height);

	const char* bitmapBytes = [zxScreen bytes];	
	BitmapByteData data;
	BitmapOffsets offsets = bitmapOffsets(x, y, mode);
	data.bitmapByte = bitmapBytes[offsets.bitmapOffset];
	
	if(mode == ScreenModeSinclair || mode == ScreenModeTimexHiCol) {		

		char attribute = bitmapBytes[offsets.attrOffset];
		bool bright = attribute & (1 << 6);
		int ink = attribute & 0x7;
		int paper = (attribute & (0x7 << 3)) >> 3;
		if(bright) {
			if(ink) {
				ink += 7;
			}
			if(paper) {
				paper += 7;
			}
		}
		data.ink = ink;
		data.paper = paper;
	} else if(mode == ScreenModeTimexHiRes) {
	
		int outValue = bitmapBytes[SCREEN_TIMEX_HI_RES_BYTES - 1];		
                // Mask out the non-colour related bits
		outValue &= 0x38;

		switch(outValue) {
			case TimexHiResBlackWhite:
			data.ink = spectrumIndexFromRGB(SPEC_BLACK);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_WHITE);
			break;
			case TimexHiResBlueYellow:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_BLUE);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_YELLOW);
			break;
			case TimexHiResRedCyan:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_RED);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_CYAN);
			break;
			case TimexHiResMagentaGreen:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_MAGENTA);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_GREEN);
			break;
			case TimexHiResGreenMagenta:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_GREEN);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_MAGENTA);
			break;
			case TimexHiResCyanRed:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_CYAN);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_RED);
			break;
			case TimexHiResYellowBlue:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_YELLOW);
			data.paper = spectrumIndexFromRGB(SPEC_BRIGHT_BLUE);
			break;
			case TimexHiResWhiteBlack:
			data.ink = spectrumIndexFromRGB(SPEC_BRIGHT_WHITE);
			data.paper = spectrumIndexFromRGB(SPEC_BLACK);
			break;
			default:
                                NSLog(@"JWSpectrumScreen: unknown attribute:%d\n", outValue);
				assert(0);
		}
	} else {
		// WTF?
		assert(0);
	}
	return data;
}

- (void)setBitmapByteData:(const BitmapByteData)data atX:(int)x y:(int)y
{
	// x must be byte aligned.
	// x and y must be within the canvas.
	assert(x % 8 == 0);
	assert(x < canvasSize.width);
	assert(y < canvasSize.height);
	assert(data.ink >= 0 && data.ink < 14);
	assert(data.paper >= 0 && data.paper < 14);
	
	BitmapOffsets offsets = bitmapOffsets(x, y, mode);
	char* bitmapBytes = [zxScreen mutableBytes];
	bitmapBytes[offsets.bitmapOffset] = data.bitmapByte;
	
	if(mode == ScreenModeSinclair || mode == ScreenModeTimexHiCol) {
						
		char attribute = 0;
		int ink = data.ink;
		int paper = data.paper;
		
		// Handle bright colours.
		if(ink > 7 || paper > 7) {
			if(ink > 7) {
				ink -= 7;
			}
			if(paper > 7) {
				paper -= 7;
			}
			attribute |= 1 << 6;
		}
		
		attribute |= ink;
		attribute |= paper << 3;
		bitmapBytes[offsets.attrOffset] = attribute;
	}
}

- (BOOL)saveScrFile:(NSURL*)url
{
	BOOL success = NO;
	if([zxScreen length]) {
		success = [zxScreen writeToURL:url atomically:NO];
	}
	return success;
}

- (NSDictionary*)screenSections
{
	NSMutableDictionary* dictionary = [[[NSMutableDictionary alloc] initWithCapacity:4] autorelease];
	NSData* screen0 = nil;
	NSData* screen1 = nil;
	NSData* attributes = nil;
	NSData* out255 = nil;
	
	NSUInteger length = [zxScreen length];
	if(length) {
		screen0 = [[[NSData alloc] initWithBytes:[zxScreen bytes] length:SCREEN_BITMAP_SIZE] autorelease];
		[dictionary setObject:screen0 forKey:@"Screen0"];
		
		if(mode == ScreenModeSinclair || mode == ScreenModeTimexHiCol) {
			assert((mode == ScreenModeSinclair && length == SCREEN_STANDARD_BYTES) ||
					(mode == ScreenModeTimexHiCol && length == SCREEN_TIMEX_HI_COL_BYTES));
			attributes = [[[NSData alloc] initWithBytes:[zxScreen bytes] + SCREEN_BITMAP_SIZE length:length - SCREEN_BITMAP_SIZE] autorelease];
			[dictionary setObject:attributes forKey:@"Attributes"];
		} else if( mode == ScreenModeTimexHiRes) {
			assert(length == SCREEN_TIMEX_HI_RES_BYTES);
			screen1 = [[[NSData alloc] initWithBytes:[zxScreen bytes] + SCREEN_BITMAP_SIZE length:SCREEN_BITMAP_SIZE] autorelease];
			out255 = [[[NSData alloc] initWithBytes:[zxScreen bytes] + 2 * SCREEN_BITMAP_SIZE length:1] autorelease];
			[dictionary setObject:screen1 forKey:@"Screen1"];
			[dictionary setObject:out255 forKey:@"Out255"];
		} else {
			// Wtf?
			assert(0);
		}
	}

	return dictionary;
}

- (NSSize)canvasSize
{
	return canvasSize;
}

- (ScreenMode)mode
{
	return mode;
}

- (void)dealloc
{
	[zxScreen release];
	[super dealloc];
}

@end



BitmapOffsets bitmapOffsets(int x, int y, ScreenMode mode)
{
	BitmapOffsets offsets = {0, 0};
	
	int attrX = x / 8;
	int attrY = 0;
	int attrRows = 0;
	
	int screenThird = 0;
	int attrRowInThird = 0;
	int rowInAttr = 0;
	
	if(mode == ScreenModeSinclair || mode == ScreenModeTimexHiCol) {		
		if(mode == ScreenModeSinclair) {
			attrY = y / 8;
			attrRows = SCREEN_STANDARD_HEIGHT / 8;
			screenThird = 3 * attrY / attrRows;
			attrRowInThird = attrY % 8;
		} else {
			attrY = y;
			attrRows = SCREEN_STANDARD_HEIGHT;
			screenThird = 3 * y / attrRows;
			attrRowInThird = y / 8 % 8;
		}

		rowInAttr = y % 8;
		offsets.bitmapOffset = 0x800 * screenThird;
		offsets.bitmapOffset += 0x20 * attrRowInThird;
		offsets.bitmapOffset += 0x100 * rowInAttr;
		offsets.bitmapOffset += attrX;
		
		if(mode == ScreenModeSinclair) {
			offsets.attrOffset = SCREEN_BITMAP_SIZE + attrX + attrY * SCREEN_STANDARD_WIDTH / 8;
		} else {
			offsets.attrOffset = SCREEN_BITMAP_SIZE + offsets.bitmapOffset;
		}
	} else if(mode == ScreenModeTimexHiRes) {
		y /= 2;
		attrRows = SCREEN_STANDARD_HEIGHT;
		screenThird = 3 * y / attrRows;
		attrRowInThird = y / 8 % 8;
		rowInAttr = y % 8;
		
		offsets.bitmapOffset = 0x800 * screenThird;
		offsets.bitmapOffset += 0x20 * attrRowInThird;
		offsets.bitmapOffset += 0x100 * rowInAttr;
				
		if(attrX & 1) {
			offsets.bitmapOffset += SCREEN_BITMAP_SIZE;
			offsets.bitmapOffset += (attrX - 1) / 2;
		} else {
			offsets.bitmapOffset += attrX / 2;
		}
	} else {
		// WTF?
		assert(0);
	}
	
	return offsets;
}
