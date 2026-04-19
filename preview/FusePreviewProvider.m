/* FusePreviewProvider.m: Quick Look preview extension for Spectrum files.

   Extracts a screen image from a libspectrum-supported file and hands it
   back to the Quick Look host as a bitmap. Ports the TYPE_SCR / TYPE_IMAGEIO
   paths from the legacy CFPlugIn-based GeneratePreviewForURL.m, including
   the intentional tape-file skip.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "FusePreviewProvider.h"

#import <AppKit/AppKit.h>

#import "JWSpectrumScreen.h"
#import "LibspectrumSCRExtractor.h"

@implementation FusePreviewProvider

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply *, NSError *))handler
{
  LibspectrumSCRExtractor *speccyFile =
    [[[LibspectrumSCRExtractor alloc] initWithContentsOfURL:request.fileURL] autorelease];

  /* No preview for tapes: these are going to have inlays etc. which are more
     like album art in mp3s than file previews. Preserves legacy behaviour. */
  if( [speccyFile class] == LIBSPECTRUM_CLASS_TAPE ) {
    handler( nil, nil );
    return;
  }

  switch( [speccyFile image_type] ) {
  case TYPE_SCR:
    {
      JWSpectrumScreen *screen =
        [[[JWSpectrumScreen alloc] initFromData:[speccyFile scrData]
                                        mltHint:[speccyFile type] == LIBSPECTRUM_ID_SCREEN_MLT]
           autorelease];
      NSBitmapImageRep *imageRep = [[screen imageRep] retain];
      NSSize canvasSize = [screen canvasSize];

      QLPreviewReply *reply = [[[QLPreviewReply alloc]
        initWithContextSize:canvasSize
                   isBitmap:YES
               drawingBlock:^BOOL( CGContextRef context,
                                   QLPreviewReply *_Nonnull aReply,
                                   NSError *__autoreleasing *error ) {
          NSGraphicsContext *gc =
            [NSGraphicsContext graphicsContextWithCGContext:context flipped:YES];
          [NSGraphicsContext saveGraphicsState];
          [NSGraphicsContext setCurrentContext:gc];

          NSImage *image =
            [[[NSImage alloc] initWithSize:canvasSize] autorelease];
          [image addRepresentation:imageRep];
          NSRect rect = NSMakeRect( 0.0, 0.0, canvasSize.width,
                                    canvasSize.height );
          [image drawAtPoint:NSZeroPoint
                    fromRect:rect
                   operation:NSCompositingOperationSourceOver
                    fraction:1.0];

          [NSGraphicsContext restoreGraphicsState];
          [imageRep release];
          return YES;
        }] autorelease];

      handler( reply, nil );
      return;
    }
  case TYPE_IMAGEIO:
    {
      NSImage *image =
        [[[NSImage alloc] initWithData:[speccyFile scrData]] autorelease];
      if( !image || NSEqualSizes( image.size, NSZeroSize ) ) {
        handler( nil, nil );
        return;
      }
      NSSize canvasSize = image.size;
      [image retain];

      QLPreviewReply *reply = [[[QLPreviewReply alloc]
        initWithContextSize:canvasSize
                   isBitmap:YES
               drawingBlock:^BOOL( CGContextRef context,
                                   QLPreviewReply *_Nonnull aReply,
                                   NSError *__autoreleasing *error ) {
          NSGraphicsContext *gc =
            [NSGraphicsContext graphicsContextWithCGContext:context flipped:YES];
          [NSGraphicsContext saveGraphicsState];
          [NSGraphicsContext setCurrentContext:gc];

          NSRect rect = NSMakeRect( 0.0, 0.0, canvasSize.width,
                                    canvasSize.height );
          [image drawAtPoint:NSZeroPoint
                    fromRect:rect
                   operation:NSCompositingOperationSourceOver
                    fraction:1.0];

          [NSGraphicsContext restoreGraphicsState];
          [image release];
          return YES;
        }] autorelease];

      handler( reply, nil );
      return;
    }
  default:
    break;
  }

  handler( nil, nil );
}

@end
