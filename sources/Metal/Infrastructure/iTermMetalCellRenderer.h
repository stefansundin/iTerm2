#import "iTermMetalRenderer.h"
#import "VT100GridTypes.h"

NS_ASSUME_NONNULL_BEGIN

extern const CGFloat MARGIN_WIDTH;
extern const CGFloat TOP_MARGIN;
extern const CGFloat BOTTOM_MARGIN;

@protocol iTermMetalCellRenderer<iTermMetalRenderer>

- (void)setCellSize:(CGSize)cellSize;
- (void)setGridSize:(VT100GridSize)gridSize;

@end

@interface iTermMetalCellRenderer : iTermMetalRenderer

@property (nonatomic) CGSize cellSize;
@property (nonatomic) VT100GridSize gridSize;
@property (nonatomic, readonly) id<MTLBuffer> offsetBuffer;
@property (nonatomic, strong) id<MTLBuffer> pius;

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device NS_UNAVAILABLE;

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device
                     vertexFunctionName:(NSString *)vertexFunctionName
                   fragmentFunctionName:(NSString *)fragmentFunctionName
                               blending:(BOOL)blending NS_UNAVAILABLE;

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device
                     vertexFunctionName:(NSString *)vertexFunctionName
                   fragmentFunctionName:(NSString *)fragmentFunctionName
                               blending:(BOOL)blending
                         piuElementSize:(size_t)piuElementSize NS_DESIGNATED_INITIALIZER;

- (void)setValue:(void *)c coord:(VT100GridCoord)coord;
- (const void *)piuForCoord:(VT100GridCoord)coord;

@end

NS_ASSUME_NONNULL_END
