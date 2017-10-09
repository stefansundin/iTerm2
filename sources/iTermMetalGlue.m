//
//  iTermMetalGlue.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 10/8/17.
//

#import "iTermMetalGlue.h"

#import "iTermTextDrawingHelper.h"
#import "PTYFontInfo.h"
#import "VT100Screen.h"

NS_ASSUME_NONNULL_BEGIN

@implementation iTermMetalGlue

#pragma mark - iTermMetalTestDriverDataSource

- (void)metalDriverWillBeginDrawingFrame {
}

- (NSData *)characterAtScreenCoord:(VT100GridCoord)coord {
    int firstVisibleRow = [self.textDrawingHelper coordRangeForRect:self.textDrawingHelper.delegate.enclosingScrollView.documentVisibleRect].start.y;
    screen_char_t *line = [self.screen getLineAtIndex:firstVisibleRow + coord.y];
    return [NSData dataWithBytesNoCopy:&line[coord.x] length:sizeof(screen_char_t) freeWhenDone:NO];
}

- (NSImage *)metalImageForCharacterAtCoord:(VT100GridCoord)coord
                                      size:(CGSize)size
                                     scale:(CGFloat)scale {
    if (self.textDrawingHelper.delegate == nil) {
        return nil;
    }
    
    iTermTextDrawingHelper *helper = self.textDrawingHelper;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL,
                                             size.width,
                                             size.height,
                                             8,
                                             size.width * 4,
                                             colorSpace,
                                             kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);

    CGContextSetRGBFillColor(ctx, 0, 0, 0, 0);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));

    screen_char_t *line = [self.screen getLineAtIndex:coord.y];
    screen_char_t *sct = line + coord.x;
    BOOL fakeBold = NO;
    BOOL fakeItalic = NO;
    PTYFontInfo *fontInfo = [self.textDrawingHelper.delegate drawingHelperFontForChar:sct->code
                                                                            isComplex:sct->complexChar
                                                                           renderBold:&fakeBold
                                                                         renderItalic:&fakeItalic];
    NSFont *font = fontInfo.font;
    assert(font);
    [self drawString:ScreenCharToStr(sct)
                font:font
                size:size
      baselineOffset:fontInfo.baselineOffset
               scale:scale
             context:ctx];

    CGImageRef imageRef = CGBitmapContextCreateImage(ctx);

    return [[NSImage alloc] initWithCGImage:imageRef size:size];
}

- (void)drawString:(NSString *)string
              font:(NSFont *)font
              size:(CGSize)size
    baselineOffset:(CGFloat)baselineOffset
             scale:(CGFloat)scale
           context:(CGContextRef)ctx {
    NSLog(@"Draw %@ of size %@", string, NSStringFromSize(size));
    if (string.length == 0) {
        return;
    }
    CGGlyph glyphs[string.length];
    const NSUInteger numCodes = string.length;
    unichar characters[numCodes];
    [string getCharacters:characters];
    BOOL ok = CTFontGetGlyphsForCharacters((CTFontRef)font,
                                           characters,
                                           glyphs,
                                           numCodes);
    if (!ok) {
        // TODO: fall back and use core text
//        assert(NO);
        return;
    }

    // TODO: fake italic, fake bold, optional anti-aliasing, thin strokes, faint
    const BOOL antiAlias = YES;
    CGContextSetShouldAntialias(ctx, antiAlias);

    size_t length = numCodes;

    // TODO: This is slow. Avoid doing it.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CGContextSelectFont(ctx,
                        [[font fontName] UTF8String],
                        [font pointSize],
                        kCGEncodingMacRoman);
#pragma clang diagnostic pop

    // TODO: could use extended srgb on macOS 10.12+
    CGContextSetFillColorSpace(ctx, CGColorSpaceCreateWithName(kCGColorSpaceSRGB));
    const CGFloat components[4] = { 1.0, 1.0, 1.0, 1.0 };
    CGContextSetFillColor(ctx, components);
    double y = -baselineOffset * scale;
    // Flip vertically and translate to (x, y).
    CGContextSetTextMatrix(ctx, CGAffineTransformMake(scale,  0.0,
                                                      0, scale,
                                                      0, y));

    CGPoint points[length];
    for (int i = 0; i < length; i++) {
        points[i].x = 0;
        points[i].y = 0;
    }
    CGContextShowGlyphsAtPositions(ctx, glyphs, points, length);
}

@end

NS_ASSUME_NONNULL_END
