/* FusePreviewProvider.m: Quick Look preview extension for Spectrum files.

   Implements the view-controller-based Quick Look preview for the
   com.apple.quicklook.preview extension point. Configures an NSImageView
   with the Spectrum screen extracted from a libspectrum-supported file.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "FusePreviewProvider.h"

#import <ImageIO/ImageIO.h>

#import "JWSpectrumScreen.h"
#import "LibspectrumSCRExtractor.h"

@interface FusePreviewProvider ()
@property (nonatomic, retain) NSImageView *imageView;
@end

@implementation FusePreviewProvider

@synthesize imageView;

- (void)loadView
{
  NSRect frame = NSMakeRect( 0.0, 0.0, 800.0, 600.0 );
  NSView *container = [[[NSView alloc] initWithFrame:frame] autorelease];
  container.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  imageView = [[NSImageView alloc] initWithFrame:frame];
  imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
  imageView.imageFrameStyle = NSImageFrameNone;
  imageView.imageAlignment = NSImageAlignCenter;
  imageView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [container addSubview:imageView];

  self.view = container;
}

- (void)preparePreviewOfFileAtURL:(NSURL *)url
                completionHandler:(void (^)(NSError * _Nullable))handler
{
  (void)[self view];

  LibspectrumSCRExtractor *speccyFile =
    [[[LibspectrumSCRExtractor alloc] initWithContentsOfURL:url] autorelease];

  NSImage *image = nil;
  switch( [speccyFile image_type] ) {
  case TYPE_SCR:
    {
      JWSpectrumScreen *screen =
        [[[JWSpectrumScreen alloc] initFromData:[speccyFile scrData]
                                        mltHint:[speccyFile type] == LIBSPECTRUM_ID_SCREEN_MLT]
           autorelease];
      NSBitmapImageRep *imageRep = [screen imageRep];
      if( imageRep ) {
        image = [[[NSImage alloc] initWithSize:[screen canvasSize]] autorelease];
        [image addRepresentation:imageRep];
      }
      break;
    }
  case TYPE_IMAGEIO:
    {
      CGImageSourceRef src =
        CGImageSourceCreateWithData( (CFDataRef)[speccyFile scrData],
                                     (CFDictionaryRef)[speccyFile scrOptions] );
      if( src ) {
        CGImageRef cgimg = CGImageSourceCreateImageAtIndex( src, 0, NULL );
        CFRelease( src );
        if( cgimg ) {
          image = [[[NSImage alloc] initWithCGImage:cgimg
                                               size:NSZeroSize] autorelease];
          CGImageRelease( cgimg );
        }
      }
      break;
    }
  default:
    break;
  }

  if( !image ) {
    handler( [NSError errorWithDomain:NSCocoaErrorDomain
                                 code:NSFileReadCorruptFileError
                             userInfo:nil] );
    return;
  }

  self.imageView.image = image;
  handler( nil );
}

- (void)dealloc
{
  [imageView release];
  [super dealloc];
}

@end
