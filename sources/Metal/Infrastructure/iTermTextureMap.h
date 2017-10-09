#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

@class iTermTextureArray;

@interface iTermTextureMap : NSObject

// Given in number of cells
@property (nonatomic, readonly) NSInteger capacity;
@property (nonatomic, readonly) iTermTextureArray *array;
@property (nonatomic, readonly) iTermTextureArray *stage;
@property (nonatomic, copy) NSString *label;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                      cellSize:(CGSize)cellSize
                      capacity:(NSInteger)capacity NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)findOrAllocateIndexOfLockedTextureWithKey:(id)key
                                         creation:(NSImage *(^)(void))creation
                                       completion:(void (^)(NSInteger index))completion;

- (void)unlockTextureWithIndex:(NSInteger)index;

// The completion block is called on a private queue.
- (void)blitNewTexturesFromStagingAreaWithCompletion:(void (^)(void))completion;

// Source indexes should be locked. This WILL unlock them.
// Destination indexes should be locked. This will NOT unlock them.
// The completion block could be called on any queue. If it returns nil then nothing is staged.
- (void)blitIndexes:(NSDictionary<NSNumber *, NSNumber *> *)indexes
       toStageOfMap:(iTermTextureMap *)destination
         completion:(void (^)(void))completion;

@end
