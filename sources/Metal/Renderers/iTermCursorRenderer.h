#import <Foundation/Foundation.h>

#import "iTermMetalCellRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@class iTermCopyModeCursorRenderer;

@interface iTermCursorRenderer : NSObject<iTermMetalCellRenderer>

+ (instancetype)newUnderlineCursorRendererWithDevice:(id<MTLDevice>)device;
+ (instancetype)newBarCursorRendererWithDevice:(id<MTLDevice>)device;
+ (instancetype)newBlockCursorRendererWithDevice:(id<MTLDevice>)device;
+ (iTermCopyModeCursorRenderer *)newCopyModeCursorRendererWithDevice:(id<MTLDevice>)device;

- (instancetype)init NS_UNAVAILABLE;

- (void)setColor:(NSColor *)color;
- (void)setCoord:(VT100GridCoord)coord;

@end

@interface iTermCopyModeCursorRenderer : iTermCursorRenderer
@property (nonatomic) BOOL selecting;
@end

NS_ASSUME_NONNULL_END
