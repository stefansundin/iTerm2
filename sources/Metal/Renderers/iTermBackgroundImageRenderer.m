#import "iTermBackgroundImageRenderer.h"

#import "iTermShaderTypes.h"

NS_ASSUME_NONNULL_BEGIN

@implementation iTermBackgroundImageRenderer {
    iTermMetalRenderer *_metalRenderer;
    id<MTLTexture> _texture;
}

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _metalRenderer = [[iTermMetalRenderer alloc] initWithDevice:device
                                                 vertexFunctionName:@"iTermBackgroundImageVertexShader"
                                               fragmentFunctionName:@"iTermBackgroundImageFragmentShader"
                                                           blending:NO];
        NSImage *image = [NSImage imageNamed:@"background"];
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
    _metalRenderer.vertexBuffer = [_metalRenderer newQuadOfSize:CGSizeMake(viewportSize.x,
                                                                           viewportSize.y)];
}

@end

NS_ASSUME_NONNULL_END
