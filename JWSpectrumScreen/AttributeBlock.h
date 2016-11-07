//
//  AttributeBlock.h
//  Mac2Spec
//
//  Created by James on 20/8/2006.
//  Copyright 2006 James Weatherley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PixelData.h"

@interface AttributeBlock : NSObject {
	
	int ink;
	int paper;
	int inkCount;
	int paperCount;
	
	int index;
	int height;
	int width;
	
	int bitmapOffset;
	int attributeOffset;
	
	int attributeCount;
	int attributeRow;
	int attributeCol;
	const unsigned char* attributeBase;
	
	unsigned char attributeByte;
	unsigned char* rowBitmaps;
	
	PixelData pixelData;
	
	NSBitmapImageRep* macBitmap;
}

-(id)initWithBitmap:(NSBitmapImageRep*)bitmap attributeHeight:(int)height attributeWidth:(int)width index:(int)index;
-(BOOL)setAttributeData;
-(void)setAttributeRowAndColumn;
-(void)setOffsets;
-(void)normalizePaperAndInk;
-(void)determineBitmap;
-(void)pixelData;

-(int)index;

-(void)writeScreenOne:(unsigned char*)screenBase;
-(void)writeScreenTwo:(unsigned char*)attrBase;

@end
