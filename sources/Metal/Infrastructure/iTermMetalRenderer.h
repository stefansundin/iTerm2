#import <Foundation/Foundation.h>

#import "iTermShaderTypes.h"
@import MetalKit;
@import simd;

NS_ASSUME_NONNULL_BEGIN

@protocol iTermMetalRenderer<NSObject>

- (void)setViewportSize:(vector_uint2)viewportSize;

- (void)drawWithRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder;

@end

@interface iTermMetalRenderer : NSObject

@property (nonatomic) vector_uint2 viewportSize;
@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device;

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device
                     vertexFunctionName:(NSString *)vertexFunctionName
                   fragmentFunctionName:(NSString *)fragmentFunctionName
                               blending:(BOOL)blending;

- (instancetype)init NS_UNAVAILABLE;

- (void)drawWithRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder;

#pragma mark - For subclasses

- (id<MTLBuffer>)newQuadOfSize:(CGSize)size;

- (void)drawPipeline:(id<MTLRenderPipelineState>)pipeline
       renderEncoder:(id <MTLRenderCommandEncoder>)renderEncoder
    numberOfVertices:(NSInteger)numberOfVertices
        numberOfPIUs:(NSInteger)numberOfPIUs
       vertexBuffers:(NSDictionary<NSNumber *, id <MTLBuffer>> *)vertexBuffers
            textures:(NSDictionary<NSNumber *, id<MTLTexture>> *)textures;

- (id<MTLTexture>)textureFromImage:(NSImage *)image;

- (id<MTLRenderPipelineState>)newPipelineWithBlending:(BOOL)blending
                                       vertexFunction:(id<MTLFunction>)vertexFunction
                                     fragmentFunction:(id<MTLFunction>)fragmentFunction;
@end

NS_ASSUME_NONNULL_END
