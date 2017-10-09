#import "VT100GridTypes.h"

@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

@protocol iTermMetalTestDriverDataSource<NSObject>
- (NSData *)characterAtScreenCoord:(VT100GridCoord)coord;
- (NSImage *)metalImageForCharacterAtCoord:(VT100GridCoord)coord;
@end

// Our platform independent render class
NS_CLASS_AVAILABLE(10_11, NA)
@interface iTermMetalTestDriver : NSObject<MTKViewDelegate>

@property (nullable, nonatomic, weak) id<iTermMetalTestDriverDataSource> dataSource;

- (nullable instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;
- (void)setCellSize:(CGSize)cellSize gridSize:(VT100GridSize)gridSize scale:(CGFloat)scale;
@end

NS_ASSUME_NONNULL_END

