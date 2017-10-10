#import "iTermMetalCellRenderer.h"
#import "iTermMetalGlyphKey.h"

NS_ASSUME_NONNULL_BEGIN

@class iTermTextureMap;
@class iTermTextRendererContext;

@interface iTermTextRendererContext : NSObject
- (instancetype)initWithQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

// Usage:
// iTermTextRendererContext *context = [[iTermTextRendererContext alloc] init];
// [textRenderer setCharacter:c attributes:dict coord:coord context:context];
// ...more character setting...
// [textRenderer prepareForDrawWithContext:context
//                              completion:^{ [textRenderer drawWithRenderEncoder:renderEncoder] }];

@interface iTermTextRenderer : NSObject<iTermMetalCellRenderer>

@property (nonatomic, strong) iTermTextureMap *globalTextureMap;
@property (nonatomic, readonly) BOOL preparing;

- (instancetype)initWithDevice:(id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)prepareForDrawWithContext:(iTermTextRendererContext *)context
                       completion:(void (^)(void))completion;

- (void)setCharacter:(iTermMetalGlyphKey *)character
          attributes:(iTermMetalGlyphAttributes *)attributes
               coord:(VT100GridCoord)coord
             context:(iTermTextRendererContext *)context
            creation:(NSImage *(NS_NOESCAPE ^)(void))creation;

- (void)releaseContext:(iTermTextRendererContext *)context;

@end

NS_ASSUME_NONNULL_END

