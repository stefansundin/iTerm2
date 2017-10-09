#import "iTermMetalCellRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@class iTermTextureMap;
@class iTermTextRendererContext;

@interface iTermTextRendererContext : NSObject
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

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)prepareForDrawWithContext:(iTermTextRendererContext *)context
                       completion:(void (^)(void))completion;

- (void)setCharacter:(NSData *)character
          attributes:(NSDictionary *)attributes
               coord:(VT100GridCoord)coord
             context:(iTermTextRendererContext *)context
            creation:(NSImage *(^)(void))creation;

- (void)releaseContext:(iTermTextRendererContext *)context;

@end

NS_ASSUME_NONNULL_END

