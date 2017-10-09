@import simd;
@import MetalKit;

#import "iTermTextureArray.h"
#import "iTermMetalTestDriver.h"
#import "iTermBackgroundImageRenderer.h"
#import "iTermBackgroundColorRenderer.h"
#import "iTermBadgeRenderer.h"
#import "iTermBroadcastStripesRenderer.h"
#import "iTermCursorGuideRenderer.h"
#import "iTermCursorRenderer.h"
#import "iTermMarkRenderer.h"
#import "iTermTextRenderer.h"
#import "iTermTextureMap.h"

#import "iTermShaderTypes.h"

@implementation iTermMetalTestDriver {
    iTermBackgroundImageRenderer *_backgroundImageRenderer;
    iTermBackgroundColorRenderer *_backgroundColorRenderer;
    iTermTextRenderer *_textRenderer;
    iTermMarkRenderer *_markRenderer;
    iTermBadgeRenderer *_badgeRenderer;
    iTermBroadcastStripesRenderer *_broadcastStripesRenderer;
    iTermCursorGuideRenderer *_cursorGuideRenderer;
    iTermCursorRenderer *_underlineCursorRenderer;
    iTermCursorRenderer *_barCursorRenderer;
    iTermCursorRenderer *_blockCursorRenderer;
    iTermCopyModeCursorRenderer *_copyModeCursorRenderer;

    // The command Queue from which we'll obtain command buffers
    id<MTLCommandQueue> _commandQueue;

    // The current size of our view so we can use this in our render pipeline
    vector_uint2 _viewportSize;
    CGSize _cellSize;
    int _iteration;
    BOOL _busy;
    int _rows;
    int _columns;
    BOOL _sizeChanged;
    CGFloat _scale;
}

- (nullable instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView {
    self = [super init];
    if (self) {
        _backgroundImageRenderer = [[iTermBackgroundImageRenderer alloc] initWithDevice:mtkView.device];
        _textRenderer = [[iTermTextRenderer alloc] initWithDevice:mtkView.device];
        _backgroundColorRenderer = [[iTermBackgroundColorRenderer alloc] initWithDevice:mtkView.device];
        _markRenderer = [[iTermMarkRenderer alloc] initWithDevice:mtkView.device];
        _badgeRenderer = [[iTermBadgeRenderer alloc] initWithDevice:mtkView.device];
        _broadcastStripesRenderer = [[iTermBroadcastStripesRenderer alloc] initWithDevice:mtkView.device];
        _cursorGuideRenderer = [[iTermCursorGuideRenderer alloc] initWithDevice:mtkView.device];
        _underlineCursorRenderer = [iTermCursorRenderer newUnderlineCursorRendererWithDevice:mtkView.device];
        _barCursorRenderer = [iTermCursorRenderer newBarCursorRendererWithDevice:mtkView.device];
        _blockCursorRenderer = [iTermCursorRenderer newBlockCursorRendererWithDevice:mtkView.device];
        _copyModeCursorRenderer = [iTermCursorRenderer newCopyModeCursorRendererWithDevice:mtkView.device];
        [self setCellSize:CGSizeMake(30, 30) gridSize:VT100GridSizeMake(80, 25) scale:1];

        _commandQueue = [mtkView.device newCommandQueue];
    }

    return self;
}

- (NSArray<id<iTermMetalCellRenderer>> *)cellRenderers {
    return @[ _textRenderer,
              _backgroundColorRenderer,
              _markRenderer,
              _cursorGuideRenderer,
              _underlineCursorRenderer,
              _barCursorRenderer,
              _blockCursorRenderer,
              _copyModeCursorRenderer ];
}

- (NSArray<id<iTermMetalRenderer>> *)renderers {
    NSArray *nonCellRenderers = @[ _backgroundImageRenderer,
                                   _badgeRenderer,
                                   _broadcastStripesRenderer ];
    return [self.cellRenderers arrayByAddingObjectsFromArray:nonCellRenderers];
}

- (void)setCellSize:(CGSize)cellSize gridSize:(VT100GridSize)gridSize scale:(CGFloat)scale {
    if (scale == 0) {
        NSLog(@"Warning: scale is 0");
    }
    scale = MAX(1, scale);
    cellSize.width *= scale;
    cellSize.height *= scale;
    NSLog(@"Cell size is now %@x%@, grid size is now %@x%@", @(cellSize.width), @(cellSize.height), @(gridSize.width), @(gridSize.height));
    _sizeChanged = YES;
    _cellSize = cellSize;
    _rows = MAX(1, gridSize.height);
    _columns = MAX(1, gridSize.width);
    _scale = scale;
}

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Save the size of the drawable as we'll pass these
    //   values to our vertex shader when we draw
    _viewportSize.x = size.width;
    _viewportSize.y = size.height;
//
//    CGSize usableSize = CGSizeMake(_viewportSize.x - MARGIN_WIDTH * 2,
//                                   _viewportSize.y - TOP_MARGIN - BOTTOM_MARGIN);
//    [self setSize:CGSizeMake(usableSize.width / _cellSize.width,
//                             usableSize.height / _cellSize.height)];
}

- (iTermTextRendererContext *)rotate {
    _iteration++;

    [_blockCursorRenderer setCoord:(VT100GridCoord){ 1, 1 }];
    [_underlineCursorRenderer setCoord:(VT100GridCoord){ 2, 2 }];
    [_barCursorRenderer setCoord:(VT100GridCoord){ 3, 3 }];
    [_copyModeCursorRenderer setCoord:(VT100GridCoord){4, 4}];
    _copyModeCursorRenderer.selecting = !((_iteration / 30) % 2);

    [_cursorGuideRenderer setRow:(_iteration / 10) % _rows];

    [_markRenderer setMarkStyle:iTermMarkStyleNone
                            row:((_iteration + 0) % _rows)];
    [_markRenderer setMarkStyle:iTermMarkStyleSuccess
                            row:((_iteration + 1) % _rows)];
    [_markRenderer setMarkStyle:iTermMarkStyleFailure
                            row:((_iteration + 2) % _rows)];
    [_markRenderer setMarkStyle:iTermMarkStyleOther
                            row:((_iteration + 3) % _rows)];

    iTermTextRendererContext *context = [[iTermTextRendererContext alloc] init];
    int i = 0;
    for (int y = 0; y < _rows; y++) {
        for (int x = 0; x < _columns; x++) {
//            unichar c = 'A' + ((_iteration + (i % 2)) % 26);
            NSData *c = [_dataSource characterAtScreenCoord:VT100GridCoordMake(x, y)];
            [_textRenderer setCharacter:c
                             attributes:@{}
                                  coord:(VT100GridCoord){x,y}
                                context:context
                               creation:^NSImage * _Nonnull{
                                   return [_dataSource metalImageForCharacterAtCoord:VT100GridCoordMake(x, y)
                                                                                size:_cellSize
                                                                               scale:_scale];
                               }];
            i++;
        }
    }

    i = 0;
    for (int y = 0; y < _rows; y++) {
        for (int x = 0; x < _columns; x++) {
            int j = i + _iteration / 10;
            [_backgroundColorRenderer setColor:(vector_float4){ sin(j), sin(j + M_PI_2), sin(j + M_PI), ((j/60) % 2) ? 1 : 0 }
                                         coord:(VT100GridCoord){x, y}];
            i++;
        }
    }
    return context;
}

/// Called whenever the view needs to render a frame
- (void)drawInMTKView:(nonnull MTKView *)view {
    if (_cellSize.width == 0 || _cellSize.height == 0) {
        NSLog(@"Uninitialized");
        return;
    }
    if (_busy || _textRenderer.preparing) {
        NSLog(@"Drop frame");
        return;
    }
    _busy = YES;

    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

    if (_sizeChanged) {
        [self.renderers enumerateObjectsUsingBlock:^(id<iTermMetalCellRenderer>  _Nonnull renderer, NSUInteger idx, BOOL * _Nonnull stop) {
            [renderer setViewportSize:_viewportSize];
        }];
        [self.cellRenderers enumerateObjectsUsingBlock:^(id<iTermMetalCellRenderer>  _Nonnull renderer, NSUInteger idx, BOOL * _Nonnull stop) {
            [renderer setCellSize:_cellSize];
            [renderer setGridSize:(VT100GridSize){ MAX(1, _columns), MAX(1, _rows) }];
        }];
        _sizeChanged = NO;
    }

    // For some reason this is very slow
    iTermTextRendererContext* context = [self rotate];
    [_textRenderer prepareForDrawWithContext:context
                                  completion:^{
        [self reallyDrawInView:view
                     startTime:start
                       context:context];
    }];
}

- (void)reallyDrawInView:(MTKView *)view
               startTime:(NSTimeInterval)start
                 context:(iTermTextRendererContext *)context {
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Test Driver Draw";

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil) {
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"TerminalRenderEncoder";
        view.currentDrawable.texture.label = @"Drawable";

        // Set the region of the drawable to which we'll draw.
        MTLViewport viewport = {
            -(double)_viewportSize.x,
            0.0,
            _viewportSize.x * 2,
            _viewportSize.y * 2,
            -1.0,
            1.0
        };
        [renderEncoder setViewport:viewport];

//        [_backgroundImageRenderer drawWithRenderEncoder:renderEncoder];
//        [_backgroundColorRenderer drawWithRenderEncoder:renderEncoder];
//        [_broadcastStripesRenderer drawWithRenderEncoder:renderEncoder];
//        [_badgeRenderer drawWithRenderEncoder:renderEncoder];
//        [_cursorGuideRenderer drawWithRenderEncoder:renderEncoder];
//
//        [_blockCursorRenderer drawWithRenderEncoder:renderEncoder];
//        [_underlineCursorRenderer drawWithRenderEncoder:renderEncoder];
//        [_barCursorRenderer drawWithRenderEncoder:renderEncoder];
//        [_copyModeCursorRenderer drawWithRenderEncoder:renderEncoder];

        [_textRenderer drawWithRenderEncoder:renderEncoder];

        [_markRenderer drawWithRenderEncoder:renderEncoder];
        [renderEncoder endEncoding];

        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
            [_textRenderer releaseContext:context];
            NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];
            NSLog(@"%@ fps", @(1.0 / (end - start)));
            _busy = NO;
        }];

        [commandBuffer presentDrawable:view.currentDrawable];
    }
    [commandBuffer commit];
}

@end

