#import "iTermCursorGuideRenderer.h"

@implementation iTermCursorGuideRenderer {
    iTermMetalCellRenderer *_cellRenderer;
    id<MTLTexture> _texture;
    NSColor *_color;
    int _row;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _color = [[NSColor blueColor] colorWithAlphaComponent:0.7];
        _cellRenderer = [[iTermMetalCellRenderer alloc] initWithDevice:device
                                                    vertexFunctionName:@"iTermCursorGuideVertexShader"
                                                  fragmentFunctionName:@"iTermCursorGuideFragmentShader"
                                                              blending:YES
                                                        piuElementSize:sizeof(iTermCursorGuidePIU)];
    }
    return self;
}

- (void)setCellSize:(CGSize)cellSize {
    [_cellRenderer setCellSize:cellSize];
    _texture = [self newCursorGuideTextureWithColor];

    _cellRenderer.vertexBuffer = [_cellRenderer newQuadOfSize:cellSize];
}

- (void)setGridSize:(VT100GridSize)gridSize {
    [_cellRenderer setGridSize:gridSize];
    [self updatePIUs];
}

- (void)setViewportSize:(vector_uint2)viewportSize {
    [_cellRenderer setViewportSize:viewportSize];
}

- (void)setColor:(NSColor *)color {
    _color = color;
    _texture = [self newCursorGuideTextureWithColor];
}

- (void)setRow:(int)row {
    _row = row;
}

- (void)drawWithRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    [self updatePIUs];

    [_cellRenderer drawPipeline:_cellRenderer.pipelineState
                  renderEncoder:renderEncoder
               numberOfVertices:6
                   numberOfPIUs:_cellRenderer.gridSize.width
                  vertexBuffers:@{ @(iTermVertexInputIndexVertices): _cellRenderer.vertexBuffer,
                                   @(iTermVertexInputIndexPerInstanceUniforms): _cellRenderer.pius,
                                   @(iTermVertexInputIndexOffset): _cellRenderer.offsetBuffer }
                       textures:@{ @(iTermTextureIndexPrimary): _texture } ];
}

#pragma mark - Private

- (void)updatePIUs {
    NSData *data = [self newCursorGuidePerInstanceUniforms];
    _cellRenderer.pius = [_cellRenderer.device newBufferWithLength:data.length options:MTLResourceStorageModeManaged];
    memcpy(_cellRenderer.pius.contents, data.bytes, data.length);
    [_cellRenderer.pius didModifyRange:NSMakeRange(0, _cellRenderer.pius.length)];
}

- (nonnull NSData *)newCursorGuidePerInstanceUniforms {
    NSMutableData *data = [[NSMutableData alloc] initWithLength:sizeof(iTermCursorGuidePIU) * _cellRenderer.gridSize.width];
    iTermCursorGuidePIU *pius = (iTermCursorGuidePIU *)data.mutableBytes;
    for (size_t i = 0; i < _cellRenderer.gridSize.width; i++) {
        pius[i] = (iTermCursorGuidePIU) {
            .offset = {
                i * _cellRenderer.cellSize.width,
                (_cellRenderer.gridSize.height - _row - 1) * _cellRenderer.cellSize.height
            },
        };
    }
    return data;
}

- (id<MTLTexture>)newCursorGuideTextureWithColor {
    NSImage *image = [[NSImage alloc] initWithSize:_cellRenderer.cellSize];

    [image lockFocus];
    {
        [_color set];
        NSRect rect = NSMakeRect(0,
                                 0,
                                 _cellRenderer.cellSize.width,
                                 _cellRenderer.cellSize.height);
        NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);

        rect.size.height = 1;
        NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);

        rect.origin.y += _cellRenderer.cellSize.height - 1;
        NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
    }
    [image unlockFocus];

    return [_cellRenderer textureFromImage:image];
}

@end
