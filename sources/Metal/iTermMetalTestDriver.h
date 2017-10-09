#import "VT100GridTypes.h"

@import MetalKit;

@protocol iTermMetalTestDriverDataSource<NSObject>
- (NSData *)characterAtScreenCoord:(VT100GridCoord)coord;
- (NSImage *)metalImageForCharacterAtCoord:(VT100GridCoord)coord;
@end

// Our platform independent render class
@interface iTermMetalTestDriver : NSObject<MTKViewDelegate>

@property (nullable, nonatomic, weak) id<iTermMetalTestDriverDataSource> dataSource;

- (nullable instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;
- (void)setCellSize:(CGSize)cellSize gridSize:(VT100GridSize)gridSize scale:(CGFloat)scale;
@end
