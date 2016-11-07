//
//  AttributeBlockTimexHiRes.h
//  Mac2Spec
//
//  Created by James on 4/9/2006.
//  Copyright 2006 James Weatherley. All rights reserved.
//

#import "AttributeBlock.h"
#import "JWSpectrumScreenConstants.h"

@interface AttributeBlockTimexHiRes : AttributeBlock {
	
	TimexHiResMode hiResMode;
}

-(id)initWithBitmap:(NSBitmapImageRep*)bitmap attributeHeight:(int)height attributeWidth:(int)width index:(int)index mode:(TimexHiResMode)mode;

// Called by writeScreenOne: and writeScreenTwo:
// This method is not meant to be called externally.
-(void)writeScreenInternal:(unsigned char*)screenBase;

@end
