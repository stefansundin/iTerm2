#import "iTermBadgeRenderer.h"
#import "iTermMetalRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@implementation iTermBadgeRenderer {
    iTermMetalRenderer *_metalRenderer;
    id<MTLTexture> _texture;
    CGSize _size;
}

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _metalRenderer = [[iTermMetalRenderer alloc] initWithDevice:device
                                                 vertexFunctionName:@"iTermBadgeVertexShader"
                                               fragmentFunctionName:@"iTermBadgeFragmentShader"
                                                           blending:YES];
        NSImage *image = [NSImage imageNamed:@"badge"];
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
                   vertexBuffers:@{ @(iTermVertexInputIndexVertices): _metalRenderer.vertexBuffer,
                                    @(iTermVertexInputIndexOffset): self.newOffsetBuffer }
                        textures:@{ @(iTermTextureIndexPrimary): _texture }];
}

- (void)setViewportSize:(vector_uint2)viewportSize {
    [_metalRenderer setViewportSize:viewportSize];
    _metalRenderer.vertexBuffer = [_metalRenderer newQuadOfSize:_size];
}

- (id<MTLBuffer>)newOffsetBuffer {
    CGSize viewport = CGSizeMake(_metalRenderer.viewportSize.x, _metalRenderer.viewportSize.y);
    vector_float2 offset = {
        viewport.width - _size.width - 20,
        viewport.height - _size.height - 20
    };
    return [_metalRenderer.device newBufferWithBytes:&offset
                                              length:sizeof(offset)
                                             options:MTLResourceStorageModeManaged];
}

@end

NS_ASSUME_NONNULL_END
