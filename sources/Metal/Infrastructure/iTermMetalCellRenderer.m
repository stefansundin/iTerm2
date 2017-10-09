#import "iTermMetalCellRenderer.h"

const CGFloat MARGIN_WIDTH = 10;
const CGFloat TOP_MARGIN = 2;
const CGFloat BOTTOM_MARGIN = 2;

NS_ASSUME_NONNULL_BEGIN

@implementation iTermMetalCellRenderer {
    size_t _piuElementSize;
}

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device
                     vertexFunctionName:(NSString *)vertexFunctionName
                   fragmentFunctionName:(NSString *)fragmentFunctionName
                               blending:(BOOL)blending
                         piuElementSize:(size_t)piuElementSize {
    self = [super initWithDevice:device
              vertexFunctionName:vertexFunctionName
            fragmentFunctionName:fragmentFunctionName
                        blending:blending];
    if (self) {
        _piuElementSize = piuElementSize;
    }
    return self;
}

- (void)setGridSize:(VT100GridSize)gridSize {
    _gridSize = gridSize;

    CGSize usableSize = CGSizeMake(self.viewportSize.x - MARGIN_WIDTH * 2,
                                   self.viewportSize.y - TOP_MARGIN - BOTTOM_MARGIN);

    vector_float2 offset = {
        MARGIN_WIDTH,
        fmod(usableSize.height, _cellSize.height) + BOTTOM_MARGIN
    };
    _offsetBuffer = [self.device newBufferWithBytes:&offset
                                             length:sizeof(offset)
                                            options:MTLResourceStorageModeManaged];
}

- (void)setValue:(void *)valuePointer coord:(VT100GridCoord)coord {
    const size_t index = coord.x + coord.y * self.gridSize.width;
    memcpy(self.pius.contents + index * _piuElementSize, valuePointer, _piuElementSize);
    [self.pius didModifyRange:NSMakeRange(index * _piuElementSize, _piuElementSize)];
}

- (const void *)piuForCoord:(VT100GridCoord)coord {
    const size_t index = coord.x + coord.y * self.gridSize.width;
    return self.pius.contents + index * _piuElementSize;
}

@end

NS_ASSUME_NONNULL_END

