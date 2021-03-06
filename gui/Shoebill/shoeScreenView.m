/*
 * Copyright (c) 2014, Peter Rutenbar <pruten@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "shoeScreenView.h"
#import "shoeScreenWindow.h"
#import "shoeAppDelegate.h"
#import "shoeApplication.h"
#import <Foundation/Foundation.h>

@implementation shoeScreenView


- (void)initCommon
{
    shoeApp = (shoeApplication*) NSApp;
    control = &shoeApp->control;
}


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
        [self initCommon];
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
        [self initCommon];
    return self;
}

- (void) awakeFromNib
{
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFADoubleBuffer,
        0
    };
    
    NSOpenGLPixelFormat *pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    assert(pf);
    
    NSOpenGLContext* context = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
    [self setPixelFormat:pf];
    [self setOpenGLContext:context];
    
    colorspace = CGColorSpaceCreateDeviceRGB();
    
    timer = [NSTimer
             scheduledTimerWithTimeInterval:0.001
             target:self
             selector:@selector(timerFireMethod:)
             userInfo:nil
             repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer
                                forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer:timer
                                forMode:NSEventTrackingRunLoopMode];
    
    
    
    shoebill_card_video_t *video = &control->slots[10].card.video;
    NSSize size = {
        .height=video->height,
        .width=video->width
    };

    [[self window] setContentSize:size];
    [[self window] setTitle:[NSString stringWithFormat:@"Shoebill - Screen 1"]];
    [[self window] makeKeyAndOrderFront:nil];
}

- (void)timerFireMethod:(NSTimer *)timer
{
    [self setNeedsDisplay:YES];
}

- (void)prepareOpenGL
{
    NSRect      frame = [self frame];
    NSRect      bounds = [self bounds];
    GLfloat     minX, minY, maxX, maxY;
    
    minX = NSMinX(bounds);
    minY = NSMinY(bounds);
    maxX = NSMaxX(bounds);
    maxY = NSMaxY(bounds);
    
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
    
    if(NSIsEmptyRect([self visibleRect]))
    {
        glViewport(0, 0, 1, 1);
    } else {
        glViewport(0, 0,  frame.size.width ,frame.size.height);
    }
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(minX, maxX, minY, maxY, -1.0, 1.0);
}

static void _do_clut_translation(shoebill_card_video_t *ctx)
{
    uint32_t i;

    switch (ctx->depth) {
        case 1: {
            for (i=0; i < ctx->pixels/8; i++) {
                const uint8_t byte = ctx->indexed_buf[i];
                ctx->direct_buf[i * 8 + 0] = ctx->clut[(byte >> 7) & 1];
                ctx->direct_buf[i * 8 + 1] = ctx->clut[(byte >> 6) & 1];
                ctx->direct_buf[i * 8 + 2] = ctx->clut[(byte >> 5) & 1];
                ctx->direct_buf[i * 8 + 3] = ctx->clut[(byte >> 4) & 1];
                ctx->direct_buf[i * 8 + 4] = ctx->clut[(byte >> 3) & 1];
                ctx->direct_buf[i * 8 + 5] = ctx->clut[(byte >> 2) & 1];
                ctx->direct_buf[i * 8 + 6] = ctx->clut[(byte >> 1) & 1];
                ctx->direct_buf[i * 8 + 7] = ctx->clut[(byte >> 0) & 1];
            }
            break;
        }
        case 2: {
            for (i=0; i < ctx->pixels/4; i++) {
                const uint8_t byte = ctx->indexed_buf[i];
                ctx->direct_buf[i * 4 + 0] = ctx->clut[(byte >> 6) & 3];
                ctx->direct_buf[i * 4 + 1] = ctx->clut[(byte >> 4) & 3];
                ctx->direct_buf[i * 4 + 2] = ctx->clut[(byte >> 2) & 3];
                ctx->direct_buf[i * 4 + 3] = ctx->clut[(byte >> 0) & 3];
            }
            break;
        }
        case 4: {
            for (i=0; i < ctx->pixels/2; i++) {
                const uint8_t byte = ctx->indexed_buf[i];
                ctx->direct_buf[i * 2 + 0] = ctx->clut[(byte >> 4) & 0xf];
                ctx->direct_buf[i * 2 + 1] = ctx->clut[(byte >> 0) & 0xf];
            }
            break;
        }
        case 8:
            for (i=0; i < ctx->pixels; i++)
                ctx->direct_buf[i] = ctx->clut[ctx->indexed_buf[i]];
            break;
            
        default:
            assert(!"unknown depth");
    }
}


- (void)drawRect:(NSRect)rect
{
    [[self openGLContext] makeCurrentContext];
    
    
    glDrawBuffer(GL_BACK);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glClearColor(0.0, 0.0, 0.0, 0.0);

    if (shoeApp->isRunning) {
        uint8_t slotnum = ((shoeScreenWindow*)[self window])->slotnum;
        shoebill_card_video_t *video = &control->slots[slotnum].card.video;
        
        /*NSSize size = {
            .height=video->height,
            .width=video->width
        };
        [self setFrameSize:size];
        [[self window] setContentSize:size];*/
        
        _do_clut_translation(video);
        glViewport(0, 0, video->width, video->height);
        glRasterPos2i(0, video->height);
        glPixelStorei(GL_UNPACK_LSB_FIRST, GL_TRUE);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        
        glPixelZoom(1.0, -1.0);
        
        glDrawPixels(video->width,
                     video->height,
                     GL_RGBA,
                     GL_UNSIGNED_BYTE,
                     video->direct_buf);
    }
    
    [[self openGLContext] flushBuffer];
}

- (void)viewDidMoveToWindow
{
    [[self window] setAcceptsMouseMovedEvents:YES];
    [[self window] makeFirstResponder:self];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    [[self window] setAcceptsMouseMovedEvents:YES];
    [[self window] makeFirstResponder:self];
}


- (void)mouseMoved:(NSEvent *)theEvent
{
    if (shoeApp->doCaptureMouse) {
        shoeScreenWindow *win = (shoeScreenWindow*)[self window];
        
        assert(shoeApp->isRunning);
        
        int32_t delta_x, delta_y;
        CGGetLastMouseDelta(&delta_x, &delta_y);
        shoebill_mouse_move_delta(delta_x, delta_y);
        [win warpToCenter];
    }
}

-(void)mouseDragged:(NSEvent *)theEvent
{
    [self mouseMoved:theEvent];
}

/*- (void) say:(NSString*)str
{
    NSAlert *theAlert = [NSAlert
                         alertWithMessageText:nil
                         defaultButton:nil
                         alternateButton:nil
                         otherButton:nil
                         informativeTextWithFormat:@"%@", str
                         ];
    [theAlert runModal];
}*/

- (void)mouseDown:(NSEvent *)theEvent
{
    
    if (shoeApp->doCaptureMouse) {
        assert(shoeApp->isRunning);
        
        // ctrl - left click doesn't get reported as rightMouseDown
        // on Mavericks (and maybe other OS X versions?)
        if ([theEvent modifierFlags] & NSControlKeyMask) {
            shoeScreenWindow *win = (shoeScreenWindow*)[self window];
            [win uncaptureMouse];
        }
        else
            shoebill_mouse_click(1);
        
    }
    else {
        shoeScreenWindow *win = (shoeScreenWindow*)[self window];
        if ([win isKeyWindow]) {
            shoeApp->doCaptureKeys = YES;
            [win captureMouse];
        }
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (shoeApp->doCaptureMouse) {
        assert(shoeApp->isRunning);
        shoebill_mouse_click(0);
    }
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
    if (shoeApp->doCaptureMouse) {
        shoeScreenWindow *win = (shoeScreenWindow*)[self window];
        [win uncaptureMouse];
    }
}

/*
 * Ignore keyDown/Up events here.
 * shoeApplication captures and sends them down to the emulator. 
 * We need to implement these methods though, because if they make it all
 * the way down to NSOpenGLView, they'll generate a beep, which is annoying.
 */
- (void) keyDown:(NSEvent *)theEvent
{
}
- (void) keyUp:(NSEvent *)theEvent
{
}

@end
