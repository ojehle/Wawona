#pragma once

#import <Cocoa/Cocoa.h>
#include "wayland_seat.h"

// Input Handler - Converts NSEvent to Wayland events
@interface InputHandler : NSObject

@property (nonatomic, assign) struct wl_seat_impl *seat;
@property (nonatomic, assign) NSWindow *window;
@property (nonatomic, assign) id compositor; // Reference to MacOSCompositor to trigger redraws

// Expose seat for focus checking

- (instancetype)initWithSeat:(struct wl_seat_impl *)seat window:(NSWindow *)window compositor:(id)compositor;
- (void)handleMouseEvent:(NSEvent *)event;
- (void)handleKeyboardEvent:(NSEvent *)event;
- (void)setupInputHandling;

@end

