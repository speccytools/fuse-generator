/* FuseThumbnailProvider.m: Quick Look thumbnail extension for Spectrum files.

   Extracts a screen image from a libspectrum-supported file and hands it
   back to the Quick Look host. Ports the TYPE_SCR / TYPE_IMAGEIO paths from
   the legacy CFPlugIn-based GenerateThumbnailForURL.m.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
*/

#import "FuseThumbnailProvider.h"

#import <AppKit/AppKit.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "JWSpectrumScreen.h"
#import "LibspectrumSCRExtractor.h"

static NSSize
fit_into( NSSize content, NSSize maximum )
{
  if( content.width <= 0.0 || content.height <= 0.0 ) return content;
  if( maximum.width  <= 0.0 || maximum.height <= 0.0 ) return content;

  double w_ratio = maximum.width  / content.width;
  double h_ratio = maximum.height / content.height;
  double scale   = w_ratio < h_ratio ? w_ratio : h_ratio;
  if( scale >= 1.0 ) return content;

  return NSMakeSize( content.width  * scale,
                     content.height * scale );
}

@implementation FuseThumbnailProvider

- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request
                     completionHandler:(void (^)(QLThumbnailReply *, NSError *))handler
{
  @autoreleasepool {
    LibspectrumSCRExtractor *speccyFile =
      [[[LibspectrumSCRExtractor alloc] initWithContentsOfURL:request.fileURL] autorelease];

    NSSize maxSize = request.maximumSize;

    switch( [speccyFile image_type] ) {
    case TYPE_SCR:
      {
        JWSpectrumScreen *screen =
          [[[JWSpectrumScreen alloc] initFromData:[speccyFile scrData]
                                          mltHint:[speccyFile type] == LIBSPECTRUM_ID_SCREEN_MLT]
             autorelease];
        NSBitmapImageRep *imageRep = [screen imageRep];
        NSSize canvasSize = [screen canvasSize];
        NSSize contextSize = fit_into( canvasSize, maxSize );

        QLThumbnailReply *reply = [QLThumbnailReply
          replyWithContextSize:contextSize
            currentContextDrawingBlock:^BOOL {
              NSImage *image =
                [[[NSImage alloc] initWithSize:canvasSize] autorelease];
              [image addRepresentation:imageRep];
              NSRect rect = NSMakeRect( 0.0, 0.0, contextSize.width,
                                        contextSize.height );
              [image drawInRect:rect
                       fromRect:NSZeroRect
                      operation:NSCompositingOperationSourceOver
                       fraction:1.0];
              return YES;
            }];

        handler( reply, nil );
        return;
      }
    case TYPE_IMAGEIO:
      {
        NSData *data = [speccyFile scrData];
        NSDictionary *options = [speccyFile scrOptions];

        CGImageSourceRef src =
          CGImageSourceCreateWithData( (CFDataRef)data, (CFDictionaryRef)options );
        if( !src ) { handler( nil, nil ); return; }
        CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex( src, 0, NULL );
        CFRelease( src );
        if( !props ) { handler( nil, nil ); return; }
        NSNumber *width  = (NSNumber *)CFDictionaryGetValue( props, kCGImagePropertyPixelWidth );
        NSNumber *height = (NSNumber *)CFDictionaryGetValue( props, kCGImagePropertyPixelHeight );
        CGSize imageSize = CGSizeMake( [width  doubleValue],
                                       [height doubleValue] );
        CFRelease( props );
        if( CGSizeEqualToSize( imageSize, CGSizeZero ) ) { handler( nil, nil ); return; }

        NSString *utiString = options[(NSString *)kCGImageSourceTypeIdentifierHint];
        UTType *contentType = utiString ? [UTType typeWithIdentifier:utiString]
                                        : UTTypeImage;

        QLThumbnailReply *reply = [QLThumbnailReply
          replyWithDataOfContentType:contentType
                         contentSize:imageSize
                   dataCreationBlock:^NSData *( QLThumbnailReply *r, NSError **err ) {
                     return data;
                   }];

        handler( reply, nil );
        return;
      }
    default:
      break;
    }

    handler( nil, nil );
  }
}

@end
