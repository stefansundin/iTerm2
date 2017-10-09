//
//  iTermMetalGlue.m
//  iTerm2SharedARC
//
//  Created by George Nachman on 10/8/17.
//

#import "iTermMetalGlue.h"

#import "iTermColorMap.h"
#import "iTermSelection.h"
#import "iTermTextDrawingHelper.h"
#import "PTYFontInfo.h"
#import "VT100Screen.h"

NS_ASSUME_NONNULL_BEGIN


@implementation iTermMetalGlue {
    BOOL _havePreviousCharacterAttributes;
    screen_char_t _previousCharacterAttributes;
    NSColor *_lastUnprocessedColor;
    NSColor *_previousForegroundColor;
}

#pragma mark - iTermMetalTestDriverDataSource

- (void)metalDriverWillBeginDrawingFrame {
    _havePreviousCharacterAttributes = NO;
}

- (NSData *)metalCharacterAtScreenCoord:(VT100GridCoord)coord
                             attributes:(NSDictionary **)attributes {
    int firstVisibleRow = [self.textDrawingHelper coordRangeForRect:self.textDrawingHelper.delegate.enclosingScrollView.documentVisibleRect].start.y;
    screen_char_t *line = [self.screen getLineAtIndex:firstVisibleRow + coord.y];
    BOOL selected = [[self.textDrawingHelper.selection selectedIndexesOnLine:coord.y] containsIndex:coord.x];

    BOOL findMatch = NO;
    NSData *findMatches = [self.textDrawingHelper.delegate drawingHelperMatchesOnLine:coord.y];
    if (findMatches && !selected) {
        findMatch = CheckFindMatchAtIndex(findMatches, coord.x);
    }

    NSColor *textColor = [self textColorForCharacter:&line[coord.x]
                                                line:coord.y
                                     backgroundColor:nil  // TODO
                                            selected:selected
                                           findMatch:findMatch
                                   inUnderlinedRange:NO  // TODO
                                               index:coord.x];
    *attributes = @{ NSForegroundColorAttributeName: textColor };
    return [NSData dataWithBytesNoCopy:&line[coord.x] length:sizeof(screen_char_t) freeWhenDone:NO];
}

- (NSImage *)metalImageForCharacterAtCoord:(VT100GridCoord)coord
                                      size:(CGSize)size
                                     scale:(CGFloat)scale {
    if (self.textDrawingHelper.delegate == nil) {
        return nil;
    }
    
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

#pragma mark - Letter Drawing

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

#pragma mark - Color

- (NSColor *)textColorForCharacter:(screen_char_t *)c
                              line:(int)line
                   backgroundColor:(nullable NSColor *)backgroundColor
                          selected:(BOOL)selected
                         findMatch:(BOOL)findMatch
                 inUnderlinedRange:(BOOL)inUnderlinedRange
                             index:(int)index {
    NSColor *rawColor = nil;
    BOOL isMatch = NO;
    iTermColorMap *colorMap = self.textDrawingHelper.colorMap;
    const BOOL needsProcessing = backgroundColor && (self.textDrawingHelper.minimumContrast > 0.001 ||
                                                     colorMap.dimmingAmount > 0.001 ||
                                                     colorMap.mutingAmount > 0.001 ||
                                                     c->faint);  // faint implies alpha<1 and is faster than getting the alpha component


    if (isMatch) {
        // Black-on-yellow search result.
        rawColor = [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:1];
        _havePreviousCharacterAttributes = NO;
    } else if (inUnderlinedRange) {
        // Blue link text.
        rawColor = [colorMap colorForKey:kColorMapLink];
        _havePreviousCharacterAttributes = NO;
    } else if (selected) {
        // Selected text.
        rawColor = [colorMap colorForKey:kColorMapSelectedText];
        _havePreviousCharacterAttributes = NO;
    } else if (self.textDrawingHelper.reverseVideo &&
               ((c->foregroundColor == ALTSEM_DEFAULT && c->foregroundColorMode == ColorModeAlternate) ||
                (c->foregroundColor == ALTSEM_CURSOR && c->foregroundColorMode == ColorModeAlternate))) {
           // Reverse video is on. Either is cursor or has default foreground color. Use
           // background color.
           rawColor = [colorMap colorForKey:kColorMapBackground];
           _havePreviousCharacterAttributes = NO;
    } else if (!_havePreviousCharacterAttributes ||
               c->foregroundColor != _previousCharacterAttributes.foregroundColor ||
               c->fgGreen != _previousCharacterAttributes.fgGreen ||
               c->fgBlue != _previousCharacterAttributes.fgBlue ||
               c->foregroundColorMode != _previousCharacterAttributes.foregroundColorMode ||
               c->bold != _previousCharacterAttributes.bold ||
               c->faint != _previousCharacterAttributes.faint ||
               !_previousForegroundColor) {
        // "Normal" case for uncached text color. Recompute the unprocessed color from the character.
        _previousCharacterAttributes = *c;
        _havePreviousCharacterAttributes = YES;
        rawColor = [self.textDrawingHelper.delegate drawingHelperColorForCode:c->foregroundColor
                                                                        green:c->fgGreen
                                                                         blue:c->fgBlue
                                                                    colorMode:c->foregroundColorMode
                                                                         bold:c->bold
                                                                        faint:c->faint
                                                                 isBackground:NO];
    } else {
        // Foreground attributes are just like the last character. There is a cached foreground color.
        if (needsProcessing) {
            // Process the text color for the current background color, which has changed since
            // the last cell.
            rawColor = _lastUnprocessedColor;
        } else {
            // Text color is unchanged. Either it's independent of the background color or the
            // background color has not changed.
            return _previousForegroundColor;
        }
    }

    _lastUnprocessedColor = rawColor;

    NSColor *result = nil;
    if (needsProcessing) {
        result = [colorMap processedTextColorForTextColor:rawColor
                                      overBackgroundColor:backgroundColor];
    } else {
        result = rawColor;
    }
    _previousForegroundColor = result;
    return result;
}

@end

NS_ASSUME_NONNULL_END
