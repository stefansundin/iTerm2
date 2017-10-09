#import "iTermBroadcastStripesRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@implementation iTermBroadcastStripesRenderer {
    iTermMetalRenderer *_metalRenderer;
    id<MTLTexture> _texture;
    CGSize _size;
}

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _metalRenderer = [[iTermMetalRenderer alloc] initWithDevice:device
                                                 vertexFunctionName:@"iTermBroadcastStripesVertexShader"
                                               fragmentFunctionName:@"iTermBroadcastStripesFragmentShader"
                                                           blending:YES];
        NSImage *image = [NSImage imageNamed:@"BackgroundStripes"];
        _size = image.size;
        _texture = [_metalRenderer textureFromImage:image];
    }
    return self;
}

- (void)drawWithRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    [_metalRenderer drawPipeline:_metalRenderer.pipelineState
                   renderEncoder:renderEncoder
                numberOfVertices:6
                    numberOfPIUs:0
                   vertexBuffers:@{ @(iTermVertexInputIndexVertices): _metalRenderer.vertexBuffer }
                        textures:@{ @(iTermTextureIndexPrimary): _texture }];
}

- (void)setViewportSize:(vector_uint2)viewportSize {
    [_metalRenderer setViewportSize:viewportSize];

    const float maxX = viewportSize.x / _size.width;
    const float maxY = viewportSize.y / _size.height;
    const iTermVertex vertices[] = {
        // Pixel Positions, Texture Coordinates
        { { viewportSize.x, 0 },              { maxX, 0 } },
        { { 0,              0 },              { 0,    0 } },
        { { 0, viewportSize.y },              { 0,    maxY } },

        { { viewportSize.x, 0 },              { maxX, 0 } },
        { { 0,              viewportSize.y }, { 0,    maxY } },
        { { viewportSize.x, viewportSize.y }, { maxX, maxY } },
    };
    _metalRenderer.vertexBuffer = [_metalRenderer.device newBufferWithBytes:vertices
                                                                     length:sizeof(vertices)
                                                                    options:MTLResourceStorageModeShared];
}

@end

NS_ASSUME_NONNULL_END

