//
//  AttributeBlock.m
//  Mac2Spec
//
//  Created by James on 20/8/2006.
//  Copyright 2006 James Weatherley. All rights reserved.
//

#import "AttributeBlock.h"
#import "AttributeManager.h"

@implementation AttributeBlock

-(id)initWithBitmap:(NSBitmapImageRep*)bitmap attributeHeight:(int)h attributeWidth:(int)w index:(int)idx
{
	if((self = [super init])) {
		macBitmap = bitmap;
		[macBitmap retain];
		
		index = idx;
		height = h;
		width = w;
		
		// Allocate width * height bytes of strorage - divide width by eight as width is in bits.
		rowBitmaps = malloc((width / 8) * height * sizeof(unsigned char));
		if(![self setAttributeData]) {
			[self release];
			self = 0;
		}
	}
	return self;
}

-(void)dealloc
{
	[macBitmap release];
	free(rowBitmaps);
	[super dealloc];
}

-(BOOL)setAttributeData
{
	assert(index >=0);
	
	BOOL success = FALSE;
	[self setAttributeRowAndColumn];
	
	if(index < attributeCount) {
		
		[self pixelData];
		
		attributeBase = attribute([macBitmap bitmapData], &pixelData, attributeCol * width, attributeRow * height);		
		[self determineBitmap];
		
		// Use the commonest colour to determine if bright should be used.
		int bright = 0;
		if(paperCount > inkCount) {
			bright = !!(paper & 0x00808080);
		} else {
			bright = !!(ink & 0x00808080);
		}
	
		// Convert paper and ink to three bit values. 
		paper = ((paper & 0x00400000) >> 21) | 
				  ((paper & 0x00004000) >> 12) | 
				  ((paper & 0x00000040) >> 6);
		
		ink = ((ink & 0x00400000) >> 21) | 
				((ink & 0x00004000) >> 12) | 
				((ink & 0x00000040) >> 6);
		
		assert(ink < 8);
		assert(paper < 8);
		
		[self normalizePaperAndInk];
		
		// Build and write the attribute byte.
        attributeByte = 0;
        attributeByte |= paper << 3;
        attributeByte |= ink;
        attributeByte |= bright << 6;

		[self setOffsets];
		success = TRUE;
	}
	
	return success;
}

-(void)pixelData
{
	pixelData.bytesPerRow = [macBitmap bytesPerRow];
	pixelData.samplesPerPixel = [macBitmap samplesPerPixel];
	pixelData.attrCount = attributeCount;
	pixelData.attrWidth = width;
}

-(void)setAttributeRowAndColumn
{
	unsigned int rows = [macBitmap bytesPerPlane] / [macBitmap bytesPerRow] / height;
	unsigned int cols = [macBitmap bytesPerRow] / [macBitmap bitsPerPixel];
	attributeCount = rows * cols;
	attributeRow = index / cols;
	attributeCol = index % cols;
}

-(void)determineBitmap
{
	paper = pixelRGBFromBlock(attributeBase, &pixelData, 0, 0);
	
	// Scan the attribute block - create a bitmap for the row and determine paper and ink.
	// It is assumed that the attribute block only contains two colours.
	int x, y;
	inkCount = 0;
	paperCount = 0;
	unsigned char* rowBitmap = malloc(width / 8 * sizeof(unsigned char));
	
	for(y = 0; y < height; ++y) {
		memset(rowBitmap, 0, sizeof(rowBitmap));
		for(x = 0; x < width; ++x) {
			int colour = pixelRGBFromBlock(attributeBase, &pixelData, x, y);
			if(colour != paper) {
				ink = colour;
				++inkCount;
				// Set ink bit in data
				*rowBitmap |= 1 << (width - 1 - x);
			} else {
				++paperCount;
			}
		}          
		// Store the attribute block row bitmap.
		rowBitmaps[y] = *rowBitmap;
	}
	assert(inkCount + paperCount == width * height);
	free(rowBitmap);
}

-(void)normalizePaperAndInk
{
	if(paper < ink) {
		int temp = paper;
		paper = ink;
		ink = temp;
		
		int i;
		for(i = 0; i < height * width / 8; ++i) {
			rowBitmaps[i] = ~rowBitmaps[i];
		}
	}
}

-(void)setOffsets
{
	int attributeRows = attributeCount / 0x20;
	int screenThird = 3 * attributeRow / attributeRows;
	int blockRow = attributeRow * height / 8 % 8;
	int blockLine = attributeRow * height % 8; 
	
	bitmapOffset = 0x800 * screenThird;
	bitmapOffset += 0x20 * blockRow;
	bitmapOffset += 0x100 * blockLine;
	bitmapOffset += attributeCol;
	
	attributeOffset = index;
}

-(void)writeScreenOne:(unsigned char*)screenBase
{
	int i;
	for(i = 0; i < height; ++i) {
		*(screenBase + bitmapOffset + (i * 0x100)) = rowBitmaps[i];
	}
}

-(void)writeScreenTwo:(unsigned char*)attrBase
{
	*(attrBase + attributeOffset) = attributeByte;
}

-(int)index
{
	return index;
}

-(NSString*)description
{
	NSString* string = @"----------------\n";
	NSString* numbers = [NSString stringWithFormat:@"ink:%d  paper:%d  attr:%x\n", ink, paper, attributeByte];
	string = [string stringByAppendingString:numbers];
	
	int i, j;
	for(i = 0; i < height; ++i) {
		NSString* line = @"";
		unsigned char mask = 0x80;
		for(j = 0; j < width; ++j) {
			if(rowBitmaps[i] & mask) {
				line = [line stringByAppendingString:@"*"];
			} else {
				line = [line stringByAppendingString:@"."];
			}
			mask >>= 1;
		}
		line = [NSString stringWithFormat:@"%@ : %x\n", line, rowBitmaps[i]];
		string = [string stringByAppendingString:line];
	}
	return string;
}

@end
