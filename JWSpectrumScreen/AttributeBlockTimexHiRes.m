//
//  AttributeBlockTimexHiRes.m
//  Mac2Spec
//
//  Created by James on 4/9/2006.
//  Copyright 2006 James Weatherley. All rights reserved.
//

#import "AttributeBlockTimexHiRes.h"
#import "AttributeManager.h"

// How many 256x8 blocks in the entire 512x192 bitmap?
const int TIMEX_HI_RES_BITMAP_BLOCKS = 48;

// How many 8x8 pixel blocks in a row? 512 / 8 = 64.
const int BLOCKS_8x8_PER_ROW = 64;



@implementation AttributeBlockTimexHiRes

-(id)initWithBitmap:(NSBitmapImageRep*)bitmap attributeHeight:(int)h attributeWidth:(int)w index:(int)i mode:(TimexHiResMode)m
{
	hiResMode = m;
	return [super initWithBitmap:bitmap attributeHeight:h attributeWidth:w index:i];
}

-(void)pixelData
{
	[super pixelData];
	
	// pixelData refers to the block of pixels that we grab from the bitmap from which
	// we construct the spectrum bitmap block. Our block size is 256x8 but the region that
	// provides the block data is 512x8 - so multiply these variables by two.
	pixelData.attrCount *= 2;
	pixelData.attrWidth *= 2;
}

-(void)setAttributeRowAndColumn
{
	// There are 48 256x8 blocks in the 512x192 screen.
	// The row is divided by two to as there are two blocks per row.
	// Column in zero as the blocks are intertwined rather than consecutive.
	attributeCount = TIMEX_HI_RES_BITMAP_BLOCKS;
	attributeRow = index / 2;
	attributeCol = 0;
}

-(void)setOffsets
{
	int attributeRows = 24;
	int blockRow = attributeRow;
	int screenThird = 3 * blockRow / attributeRows;
	
	bitmapOffset = 0x800 * screenThird;
	bitmapOffset += 0x20 * (blockRow % 8);
	
	attributeOffset = bitmapOffset;
}

-(void)determineBitmap
{
	int i = 0;
	int x, y;
	int block;
	int blockOffset;
	inkCount = 0;
	paperCount = 0;
	
	// Allocate a 256 bit buffer for our bitmap.
	size_t size = width / 8 * sizeof(unsigned char);
	unsigned char* rowBitmap = malloc(size);
	
	// Odd or even block?
	int offset = index & 1;
	
	paper = pixelRGBFromBlock(attributeBase, &pixelData, 0, 0);
	
	// Scan the attribute block - create a bitmap for the row and determine paper and ink.
	// It is assumed that the attribute block only contains two colours.
	//
	// attributeBase is pointing to a 512x8 bitmap with RGB colours. rowBitmap is a 256x8 buffer
	// that contains alternate 8 bit sections of attributeBase. If index is even we take the
	// 8 bit sections 0, 2, 4, ... and if index is odd we take the 8 bit sections 1, 3, 5,...
	for(y = 0; y < height; ++y) {
		memset(rowBitmap, 0, size);
		for(block = offset; block < BLOCKS_8x8_PER_ROW; block += 2) {
			blockOffset = block * 8 * pixelData.samplesPerPixel;
			i = 0;
			for(x = 0; x < 8; ++x) {
				// Calc block offset based on bits per sample etc.
				int colour = pixelRGBFromBlock(attributeBase + blockOffset, &pixelData, x, y);
				if(colour != paper) {
					ink = colour;
					++inkCount;
					// Set ink bit in data
					rowBitmap[block / 2] |= 1 << (7 - i);
				} else {
					++paperCount;
				}
				++i;
			}     
		}
		// Store the attribute block row bitmap.
		memcpy(rowBitmaps + y * size, rowBitmap, size);
	}
	assert(inkCount + paperCount == width * height);
	free(rowBitmap);
}

-(void)writeScreenOne:(unsigned char*)screenBase
{
	// Only write even blocks to screen one.
	if(!(index & 1)) {
		[self writeScreenInternal:screenBase];
	}
}

-(void)writeScreenTwo:(unsigned char*)screenBase
{
	// Only write odd blocks to screen two.
	if(index & 1) {
		[self writeScreenInternal:screenBase];
	}
}

-(void)writeScreenInternal:(unsigned char*)screenBase
{
	//NSLog(@"Writing block %d", index);
	int i;
	size_t size = width / 8;
	for(i = 0; i < height; ++i) {
		memcpy((screenBase + bitmapOffset + (i * 0x100)), rowBitmaps + i * size, size);
	}
}

-(void)normalizePaperAndInk
{
	int actualInk;
	int actualPaper;
	
	switch(hiResMode) {
		case TimexHiResBlackWhite:
			actualInk = 0;
			actualPaper = 7;
			break;
		case TimexHiResBlueYellow:
			actualInk = 1;
			actualPaper = 6;
			break;
		case TimexHiResRedCyan:
			actualInk = 2;
			actualPaper = 5;
			break;
		case TimexHiResMagentaGreen:
			actualInk = 3;
			actualPaper = 4;
			break;
		case TimexHiResGreenMagenta:
			actualInk = 4;
			actualPaper = 3;
			break;
		case TimexHiResCyanRed:
			actualInk = 5;
			actualPaper = 2;
			break;
		case TimexHiResYellowBlue:
			actualInk = 6;
			actualPaper = 1;
			break;
		case TimexHiResWhiteBlack:
			actualInk = 7;
			actualPaper = 0;
			break;
		default:
			assert(0);
	}

	assert(paper == actualPaper || paper == actualInk);
	assert(ink == actualPaper || ink == actualInk);
	
	if(paper != actualPaper) {
		int i;
		for(i = 0; i < height * width / 8; ++i) {
			rowBitmaps[i] = ~rowBitmaps[i];
		}
	}
}

-(NSString*)description
{
	NSString* numbers = [NSString stringWithFormat:@"ink:%d  paper:%d\n", ink, paper];
	return numbers;
}

@end
