//
//  AttributeBlockIterator.m
//  Mac2Spec
//
//  Created by James on 20/8/2006.
//  Copyright 2006 JamesWeatherley. All rights reserved.
//
#import "AttributeManager.h"
#import "AttributeBlockIterator.h"
#import "AttributeBlock.h"
#import "AttributeBlockTimex.h"
#import "AttributeBlockTimexHiRes.h"


@implementation AttributeBlockIterator

-(id)initWithBitmap:(NSBitmapImageRep*)image mode:(int)theMode
{
	if((self = [super init])) {
		bitmap = image;
		[bitmap retain];
		
		mode = theMode;
		if(mode == ATTRIBUTE_ZX) {
			attributeHeight = ATTRIBUTE_HEIGHT_SINCLAIR;
			attributeWidth = ATTRIBUTE_WIDTH;
		} else if(mode == ATTRIBUTE_TIMEX_HI_COL) {
			attributeHeight = ATTRIBUTE_HEIGHT_TIMEX_HI_COL;
			attributeWidth = ATTRIBUTE_WIDTH;
		} else if(mode == ATTRIBUTE_TIMEX_HI_RES) {
			attributeHeight = ATTRIBUTE_HEIGHT_TIMEX_HI_RES;
			attributeWidth = ATTRIBUTE_WIDTH_TIMEX_HI_RES;
		} else {
			assert(0);
		}
		
		[self reset];
	}
	return self;
}

-(void)dealloc
{
	[bitmap release];
	[super dealloc];
}

-(void)reset
{
	index = 0;
}

-(void)setHiResMode:(TimexHiResMode)hiMode
{
	hiResMode = hiMode;
}

-(AttributeBlock*)nextBlock
{
	AttributeBlock* block = nil;
	
	if(mode == ATTRIBUTE_ZX) {
		block = [[AttributeBlock alloc] initWithBitmap:bitmap 
										attributeHeight:attributeHeight
										attributeWidth:attributeWidth
										index:index];
	} else if(mode == ATTRIBUTE_TIMEX_HI_COL) {
		block = [[AttributeBlockTimex alloc] initWithBitmap:bitmap 
												attributeHeight:attributeHeight
												attributeWidth:attributeWidth
												index:index];
	} else if(mode == ATTRIBUTE_TIMEX_HI_RES) {
		block = [[AttributeBlockTimexHiRes alloc] initWithBitmap:bitmap 
												  attributeHeight:attributeHeight
												  attributeWidth:attributeWidth
												  index:index
												  mode:hiResMode];
	}

	if(!block) {
		index = 0;
	} else {
		++index;
	}
	
	[block autorelease];
	return block;
}


@end
