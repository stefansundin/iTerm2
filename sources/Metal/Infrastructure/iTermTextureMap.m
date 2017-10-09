#import "iTermTextureMap.h"

#import "iTermTextureArray.h"

#define DLog(format, ...)

@interface iTermTextureMapEntry : NSObject
@property (nonatomic) NSInteger index;
@property (nonatomic, strong) NSDictionary *key;
@end

@implementation iTermTextureMapEntry
@end

@implementation iTermTextureMap {
    id<MTLDevice> _device;

    // Maps a character description dictionary to its index in _array
    NSMutableDictionary<NSDictionary *, NSNumber *> *_map;

    // LRU list of indexes
    NSMutableArray<iTermTextureMapEntry *> *_lru;

    // Set of indexes that need to be blitted from stage to array.
    NSMutableIndexSet *_indexesToBlit;

    // Set of indexes that aren't ready yet.
    NSMutableIndexSet *_stagedIndexes;

    // Which indexes should not be modified
    NSCountedSet<NSNumber *> *_lockedIndexes;

    id<MTLCommandQueue> _commandQueue;

    dispatch_queue_t _queue;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                      cellSize:(CGSize)cellSize
                      capacity:(NSInteger)capacity {
    self = [super init];
    if (self) {
        _device = device;
        _capacity = capacity;
        _array = [[iTermTextureArray alloc] initWithTextureWidth:cellSize.width
                                                   textureHeight:cellSize.height
                                                     arrayLength:_capacity
                                                          device:_device];
        _stage = [[iTermTextureArray alloc] initWithTextureWidth:cellSize.width
                                                   textureHeight:cellSize.height
                                                     arrayLength:_capacity
                                                          device:_device];
        _commandQueue = [_device newCommandQueue];
        _map = [NSMutableDictionary dictionaryWithCapacity:_capacity];
        _lru = [NSMutableArray arrayWithCapacity:_capacity];
        _indexesToBlit = [NSMutableIndexSet indexSet];
        _stagedIndexes = [NSMutableIndexSet indexSet];
        _lockedIndexes = [[NSCountedSet alloc] init];
        _queue = dispatch_queue_create("com.iterm2.textureMap", NULL);
    }
    return self;
}

- (void)findOrAllocateIndexOfLockedTextureWithKey:(id)key
                                         creation:(NSImage *(^)(void))creation
                                       completion:(void (^)(NSInteger))completion {
    dispatch_async(_queue, ^{
        NSNumber *number = _map[key];
        NSInteger index;
        if (number) {
            index = number.integerValue;
            [_lockedIndexes addObject:@(index)];
            DLog(@"%@: lock existing texture %@", self.label, @(index));
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(index);
            });
        } else {
            index = [self newStagingIndexForKey:key];

//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
#warning TODO: Do this in a bg queue so it can be parallelized. this requires serious changes to the text drawing helper.
            dispatch_async(dispatch_get_main_queue(), ^{
                NSImage *image = creation();
                dispatch_async(_queue, ^{
                    DLog(@"%@: create and stage new texture %@", self.label, @(index));
                    [_stage setSlice:index withImage:image];
                    [_stagedIndexes addIndex:index];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(index);
                    });
                });
            });
        }
    });
}

- (void)unlockTextureWithIndex:(NSInteger)index {
    dispatch_async(_queue, ^{
        DLog(@"%@: unlock %@", self.label, @(index));
        [_lockedIndexes removeObject:@(index)];
    });
}

- (void)blitNewTexturesFromStagingAreaWithCompletion:(void (^)(void))completion {
    dispatch_async(_queue, ^{
        DLog(@"%@: blit from staging to completion: %@", self.label, _indexesToBlit);
        if (_indexesToBlit.count == 0) {
            completion();
            return;
        }
        id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = [NSString stringWithFormat:@"blit from %@ to %@", _stage.texture.label, _array.texture.label];
        id <MTLBlitCommandEncoder> blitter = [commandBuffer blitCommandEncoder];
        [_indexesToBlit enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
            [_stage copyTextureAtIndex:idx
                               toArray:_array
                                 index:idx
                               blitter:blitter];
        }];

        // Swap out indexes to blit. They don't need to be blitted again and we need to unlock them
        // when the blit is done.
        NSIndexSet *blittedIndexes = _indexesToBlit;
        _indexesToBlit = [NSMutableIndexSet indexSet];

        // Unlock the indexes we just blitted and remove them.
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
            dispatch_async(_queue, ^{
                DLog(@"%@: finished blit from staging to completion", self.label);
                [blittedIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL * _Nonnull stop) {
                    DLog(@"%@: unlock and mark as ready %@", self.label, @(index));
                    [_lockedIndexes removeObject:@(index)];
                    [_stagedIndexes removeIndex:index];
                }];
            });
            dispatch_async(dispatch_get_main_queue(), completion);
        }];

        [blitter endEncoding];
        [commandBuffer commit];
    });
}

- (void)blitIndexes:(NSDictionary<NSNumber *, NSNumber *> *)indexes
       toStageOfMap:(iTermTextureMap *)destination
         completion:(void (^)(void))completion {
    if (indexes.count == 0) {
        completion();
        return;
    }
    DLog(@"%@: will blit indexes %@ to stage of %@. First commit my stage.", self.label, indexes, destination.label);

    // Make sure everything in the stage is available in the main map.
    [self blitNewTexturesFromStagingAreaWithCompletion:^{
        DLog(@"%@: will blit indexes %@ to stage of %@. Begin blit from my texture to their stage.", self.label, indexes, destination.label);
        // Create a command buffer and blit command encoder to do the work.
        id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = [NSString stringWithFormat:@"blit from %@ to %@", _array.texture.label, destination.stage.texture.label];
        id <MTLBlitCommandEncoder> blitter = [commandBuffer blitCommandEncoder];

        // Copy from this texture array to the destination.
        [indexes enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull sourceIndex, NSNumber * _Nonnull destinationIndex, BOOL * _Nonnull stop) {
            [_array copyTextureAtIndex:sourceIndex.integerValue
                               toArray:destination->_stage
                                 index:destinationIndex.integerValue
                               blitter:blitter];
        }];

        // When the copying is all down, unlock the source indexes and invoke the completion
        // block.
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
            DLog(@"%@: will blit indexes %@ to stage of %@. Finished. Unlock indexes.", self.label, indexes, destination.label);
            [indexes enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull sourceIndex, NSNumber * _Nonnull destinationIndex, BOOL * _Nonnull stop) {
                [_lockedIndexes removeObject:sourceIndex];
            }];
            completion();
        }];
        [blitter endEncoding];
        [commandBuffer commit];
    }];
}

#pragma mark - Private

// Private queue only
// Allocates an index and marks it as needing blitting.
- (NSInteger)newStagingIndexForKey:(NSDictionary *)key {
    iTermTextureMapEntry *entry;
    if (_lru.count == _capacity) {
        iTermTextureMapEntry *entry = nil;
        for (iTermTextureMapEntry *candidate in _lru.reverseObjectEnumerator) {
            if ([_lockedIndexes countForObject:@(candidate.index)] == 0) {
                entry = candidate;
                break;
            }
        }
        assert(entry != nil);
        [_map removeObjectForKey:entry.key];
        entry.key = key;
        [_lru removeLastObject];
        DLog(@"%@: LRU cache is full. Reuse %@", self.label, @(entry.index));
    } else {
        entry = [[iTermTextureMapEntry alloc] init];
        entry.key = key;
        // Index 0 is reserved for "clear".
        entry.index = _lru.count + 1;
        DLog(@"%@: allocate new index %@", self.label, @(entry.index));
    }
    _map[key] = @(entry.index);
    [_lru insertObject:entry atIndex:0];
    [_indexesToBlit addIndex:entry.index];
    [_lockedIndexes addObject:@(entry.index)];
    DLog(@"%@ lock and mark as needing blit from stage %@", self.label, @(entry.index));

    return entry.index;
}

@end
