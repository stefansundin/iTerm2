#import "iTermMarkRenderer.h"
#import "iTermTextureArray.h"
#import "iTermMetalCellRenderer.h"

@implementation iTermMarkRenderer {
    iTermMetalCellRenderer *_cellRenderer;
    iTermTextureArray *_marksArrayTexture;
    CGSize _markSize;
    NSMutableDictionary<NSNumber *, NSNumber *> *_marks;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _marks = [NSMutableDictionary dictionary];
        _cellRenderer = [[iTermMetalCellRenderer alloc] initWithDevice:device
                                                    vertexFunctionName:@"iTermMarkVertexShader"
                                                  fragmentFunctionName:@"iTermMarkFragmentShader"
                                                              blending:YES
                                                        piuElementSize:sizeof(iTermMarkPIU)];
    }
    return self;
}

- (void)setCellSize:(CGSize)cellSize {
    [_cellRenderer setCellSize:cellSize];
    _markSize = CGSizeMake(MARGIN_WIDTH - 4, MIN(15, _cellRenderer.cellSize.height - 2));
    _marksArrayTexture = [[iTermTextureArray alloc] initWithTextureWidth:_markSize.width
                                                          textureHeight:_markSize.height
                                                            arrayLength:3
                                                                 device:_cellRenderer.device];

    [_marksArrayTexture addSliceWithImage:[self newImageWithMarkOfColor:[NSColor blueColor] size:_markSize]];
    [_marksArrayTexture addSliceWithImage:[self newImageWithMarkOfColor:[NSColor redColor] size:_markSize]];
    [_marksArrayTexture addSliceWithImage:[self newImageWithMarkOfColor:[NSColor yellowColor] size:_markSize]];

    _cellRenderer.vertexBuffer = [_cellRenderer newQuadOfSize:_markSize];
}

- (void)setGridSize:(VT100GridSize)gridSize {
    [_cellRenderer setGridSize:gridSize];
    if (_marks.count > 0) {
        [self updatePIUs];
    }
}

- (void)setViewportSize:(vector_uint2)viewportSize {
    [_cellRenderer setViewportSize:viewportSize];
}

- (void)setMarkStyle:(iTermMarkStyle)markStyle row:(int)row {
    if (markStyle == iTermMarkStyleNone) {
        [_marks removeObjectForKey:@(row)];
    } else {
        _marks[@(row)] = @(markStyle);
    }
}

- (void)drawWithRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    if (_marks.count == 0) {
        return;
    }

    [self updatePIUs];

    if (_marks.count) {
        [_cellRenderer drawPipeline:_cellRenderer.pipelineState
                      renderEncoder:renderEncoder
                   numberOfVertices:6
                       numberOfPIUs:_marks.count
                      vertexBuffers:@{ @(iTermVertexInputIndexVertices): _cellRenderer.vertexBuffer,
                                       @(iTermVertexInputIndexPerInstanceUniforms): _cellRenderer.pius,
                                       @(iTermVertexInputIndexOffset): _cellRenderer.offsetBuffer }
                           textures:@{ @(iTermTextureIndexPrimary): _marksArrayTexture.texture } ];
    }
}

#pragma mark - Private

- (void)updatePIUs {
    assert (_marks.count > 0);

    NSData *data = [self newMarkPerInstanceUniforms];
    _cellRenderer.pius = [_cellRenderer.device newBufferWithLength:data.length options:MTLResourceStorageModeManaged];
    memcpy(_cellRenderer.pius.contents, data.bytes, data.length);
    [_cellRenderer.pius didModifyRange:NSMakeRange(0, _cellRenderer.pius.length)];
}

- (NSImage *)newImageWithMarkOfColor:(NSColor *)color size:(CGSize)size {
    NSImage *image = [[NSImage alloc] initWithSize:size];
    NSBezierPath *path = [NSBezierPath bezierPath];

    [image lockFocus];
    [path moveToPoint:NSMakePoint(0,0)];
    [path lineToPoint:NSMakePoint(size.width - 1, size.height / 2)];
    [path lineToPoint:NSMakePoint(0, size.height - 1)];
    [path lineToPoint:NSMakePoint(0,0)];

    [color setFill];
    [path fill];
    [image unlockFocus];

    return image;
}

- (nonnull NSData *)newMarkPerInstanceUniforms {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:sizeof(iTermMarkPIU) * _marks.count];
    iTermMarkPIU *pius = (iTermMarkPIU *)data.mutableBytes;
    __block size_t i = 0;
    [_marks enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull rowNumber, NSNumber * _Nonnull styleNumber, BOOL * _Nonnull stop) {
        MTLOrigin origin = [_marksArrayTexture offsetForIndex:styleNumber.integerValue];
        pius[i] = (iTermMarkPIU) {
            .offset = {
                2,
                (_cellRenderer.gridSize.height - rowNumber.intValue - 1) * _cellRenderer.cellSize.height
            },
            .textureOffset = { origin.x, origin.y }
        };
        i++;
    }];
    return data;
}

@end
