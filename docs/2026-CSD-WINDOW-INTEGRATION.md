Skip to content
Chat history


You said:
I need to know how macOS Resizes windows with window edges, corners. I need to know about api for Fullscreen. I need to know about api for maximize (not fullscreen). I need to know how macOS does minimize. give me all the api here.
ChatGPT said:
Below is a complete, practical map of how macOS window management works, split by resize, fullscreen, maximize (zoom), and minimize, with all relevant APIs and how Apple actually wires them together internally.
This is written assuming you’re doing WindowServer-level / compositor / private-framework adjacent work (which you are), not just normal AppKit usage.

1. Window Resizing (Edges & Corners)
User interaction path (what really happens)
Mouse hits resize region
WindowServer decides:
Is resize allowed?
Which edges are active?
WindowServer sends resize tracking events
AppKit updates window frame
Backing store + CALayer tree are resized
Public APIs involved
NSWindow (AppKit)
Enable / disable resizing
window.styleMask |= NSWindowStyleMaskResizable;
Resize constraints
window.minSize = NSMakeSize(w, h);
window.maxSize = NSMakeSize(w, h);
window.contentAspectRatio = NSMakeSize(w, h); 
Programmatic resize
[window setFrame:newFrame display:YES animate:YES];
Live resize callbacks
- (void)windowWillStartLiveResize:(NSNotification *)
- (void)windowDidEndLiveResize:(NSNotification *)
Hit-testing resize regions
- (NSRect)contentRectForFrameRect:(NSRect)
- (NSRect)frameRectForContentRect:(NSRect)
Edges & corners are derived from the frame rect, not content.
Private / lower-level (what you care about)
CoreGraphics / WindowServer
API	Purpose
CGSResizeWindow	Resize request
CGSGetWindowBounds	Frame rect
CGSSetWindowBounds	Force size
CGSGetWindowTransform	Transform during resize
CGSWindowIsResizable	Resize permission
These live in SkyLight.framework
Resize tracking (critical)
During live resize:
WindowServer temporarily owns the mouse
Client receives:
frame-changed notifications
-[NSView viewDidEndLiveResize]
Resize regions (edges/corners)
These are not views.
They are:

Implicit hit regions computed by WindowServer
Size ~6px (configurable internally)
Corners are combinations of edges
If you’re implementing your own compositor:
You must exclude shadow regions from hit-testing
You must implement edge classification yourself
2. Fullscreen (Green Button / Spaces Fullscreen)
Fullscreen is NOT maximize.
Fullscreen:

Creates a new Space
Reparents the window
Window becomes borderless
WindowServer animates transition
Public APIs
Toggle fullscreen
[window toggleFullScreen:nil];
Enable fullscreen support
window.collectionBehavior |= NSWindowCollectionBehaviorFullScreenPrimary;
Opt out
NSWindowCollectionBehaviorFullScreenNone
Fullscreen lifecycle callbacks
windowWillEnterFullScreen:
windowDidEnterFullScreen:
windowWillExitFullScreen:
windowDidExitFullScreen:
Fullscreen behavior flags
NSWindowCollectionBehaviorFullScreenAuxiliary
NSWindowCollectionBehaviorFullScreenAllowsTiling
NSWindowCollectionBehaviorCanJoinAllSpaces
Private internals
Component	Role
WindowServer	Space creation
Dock	Fullscreen animation
SkyLight	Window reparenting
CoreAnimation	Layer transition
Private calls:
CGSEnableWindowFullscreen
CGSSetWindowWorkspace
Key fullscreen facts
Window frame is meaningless in fullscreen
Shadow is removed
Window gets its own Space
Client still renders normally
3. Maximize (Zoom Button, NOT Fullscreen)
This is the green button when NOT in fullscreen mode (or double-click title bar).
macOS calls this Zoom, not maximize.

Public APIs
Zoom (toggle maximize)
[window zoom:nil];
Query zoom state
window.isZoomed
Customize zoom behavior
- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
                        defaultFrame:(NSRect)newFrame;
This is how apps define their maximize size.
Safari uses this to:

Avoid overlapping sidebar
Respect tab bar height
What zoom actually does
Calculates a “standard frame”
Usually:
Same Space
Same window decorations
Same shadow
Does NOT create a new Space
Private APIs involved
API	Purpose
CGSGetBestRectForWindow	Compute maximize frame
CGSSetWindowBounds	Apply
Differences vs Fullscreen
Feature	Zoom	Fullscreen
New Space	❌	✅
Borderless	❌	✅
Shadow	✅	❌
Animation	Minimal	Dock-driven
Titlebar	Visible	Hidden
4. Minimize (Yellow Button / Dock)
Minimize sends the window to the Dock, not just hides it.
Public APIs
Minimize
[window miniaturize:nil];
Restore
[window deminiaturize:nil];
State
window.isMiniaturized
Notifications
windowWillMiniaturize:
windowDidMiniaturize:
windowDidDeminiaturize:
What really happens
WindowServer snapshots window
Dock animates shrink
Window is removed from active space
Backing store may be retained or discarded
Private internals
Component	Role
Dock.app	Animation
WindowServer	Window state
SkyLight	Visibility control
Private calls:
CGSOrderWindow(kCGSOrderOut)
CGSSetWindowMiniaturized
5. Window Shadows (Important for You)
Shadows are not part of the window frame.
They are:

Separate compositor elements
Added by WindowServer
Based on window level & style
Relevant APIs:
window.hasShadow = YES;
Private:
CGSWindowSetShadowParameters
CGSDisableShadow
Why your CSD shadow is clickable
Because:
WindowServer thinks shadow == window bounds
You must:
Subtract shadow extents
Or mark shadow as non-hit-testable
Apple does this internally.
6. Summary Table (Cheat Sheet)
Action	API
Resize window	setFrame:display:
Live resize	windowWillStartLiveResize
Fullscreen	toggleFullScreen:
Enable fullscreen	collectionBehavior
Maximize (zoom)	zoom:
Customize maximize	windowWillUseStandardFrame
Minimize	miniaturize:
Restore	deminiaturize:
Remove shadow	hasShadow = NO
7. What You Should Mirror in Your Compositor
If you want macOS-accurate behavior:
Implement separately:
Resize regions (edges vs corners)
Shadow as non-interactive
Zoom ≠ fullscreen
Fullscreen = new workspace
Minimize = external manager (Dock equivalent)
If you want, next I can:
Map Wayland → macOS window state translations
Show exact hit-test math for resize edges
Explain how Dock animations are triggered
Or give you SkyLight symbol names for reverse engineering
You said:
How could I map this to a wayland window client connected to a macOS Wayland compositor, which allows rendering clients with Client-Side Decoration? to connect non-native macOS window drawing vs SSD (Server-Side Decoration, already implemented). 
ChatGPT said:
This is the right question, and you’re already thinking in the same architectural split Apple uses internally.
Below is a clean, concrete mapping from Wayland semantics → macOS window management, specifically for a macOS-hosted Wayland compositor that supports both SSD and CSD, without breaking hit-testing, shadows, or resize behavior.

I’ll go step-by-step and keep it mechanical, not hand-wavy.

0. The Core Rule (Anchor This)
macOS owns the real window. Wayland owns the visual content.
Your compositor must translate Wayland surface intent into macOS window state, but never let:
CSD pixels become macOS chrome
macOS chrome overlap CSD pixels
shadows participate in input
This means: the macOS window frame must change depending on CSD vs SSD.
1. Two Operating Modes (Hard Split)
You already have SSD. Add an explicit per-toplevel mode:
enum decoration_mode {
    DECORATION_SSD,
    DECORATION_CSD
};
This mode must affect:
macOS window styleMask
Content inset math
Resize hit testing
Shadow extents
Wayland configure sizes
2. Wayland Side: How Clients Express Decoration Intent
Protocols you must support
Protocol	Purpose
xdg-shell	toplevel semantics
xdg-decoration	SSD vs CSD negotiation
Specifically:
zxdg_decoration_manager_v1
zxdg_toplevel_decoration_v1
Client requests:
set_mode(CLIENT_SIDE)
set_mode(SERVER_SIDE)
You must treat this as authoritative unless force-SSD is enabled.
3. macOS Window Mapping (Critical Part)
3.1 Server-Side Decoration (SSD)
This is your existing path.
macOS window configuration
styleMask = NSWindowStyleMaskTitled
          | NSWindowStyleMaskClosable
          | NSWindowStyleMaskMiniaturizable
          | NSWindowStyleMaskResizable;
Wayland mapping
Wayland surface size == macOS contentView size
Titlebar is not visible to Wayland
Resize edges handled by macOS
Shadow handled by macOS
Input
All hit testing delegated to macOS
Wayland only sees content-area events
This is the easy path.
3.2 Client-Side Decoration (CSD)
This is where things break if done wrong.
macOS window MUST change shape
styleMask = NSWindowStyleMaskBorderless;
window.titleVisibility = NSWindowTitleHidden;
window.titlebarAppearsTransparent = YES;
window.hasShadow = YES; // but shadow must be non-hit-testable
⚠️ No titlebar, no system resize affordances
4. Resize Handling in CSD Mode (You Must Own This)
Wayland truth
In CSD mode:
Client draws resize borders
Compositor decides hit regions
Client only gets resize intent, not mouse movement
Required Wayland behavior
You must implement:
xdg_toplevel.resize(seat, serial, edges)
Where edges ∈:
TOP, BOTTOM, LEFT, RIGHT, TOP_LEFT, etc.
5. macOS Side: Implementing Resize Tracking Yourself
Step 1: Hit-test manually
On mouse down:
Convert mouse to window-local coordinates
Compare against CSD-defined resize margin
Typically 6–10 px
Determine Wayland edge enum
⚠️ Exclude shadow extents entirely
if (point ∈ shadow_rect) return NO_HIT;
Step 2: Start resize loop
Once resize begins:
Capture mouse (equivalent to live resize)
On mouse move:
Compute new frame rect
Call:
[window setFrame:newFrame display:YES];
Send Wayland configure:
xdg_toplevel.configure(width, height, states)
Wait for client ack_configure
Present new buffer
This exactly mirrors Wayland compositors on Linux.
6. Shadows: The Click-Through Rule
macOS shadows:
Are compositor-level
Extend beyond frame
Are hit-testable by default in SkyLight
What Apple does internally
Shadow is rendered in a separate layer tree
Shadow region is excluded from input routing
What you must do
When CSD:
Track shadowInsets
Subtract from hit-test region
Never forward shadow hits to Wayland
If you don’t:
➡️ Your shadow becomes a draggable resize border (your current bug)
7. Titlebar & Buttons in CSD Mode
Wayland client responsibility
Draw titlebar
Draw close/min/max buttons
Handle hover, press, drag
Your responsibility
Translate clicks into actions:
CSD Button	macOS Action
Close	-[NSWindow performClose:]
Minimize	miniaturize:
Maximize	zoom:
Fullscreen	toggleFullScreen:
⚠️ Only if the client requests it (via protocol or conventions)
8. Fullscreen Mapping (Wayland ↔ macOS)
Wayland request
xdg_toplevel.set_fullscreen
Your macOS action
[window toggleFullScreen:nil];
Important rules
Ignore macOS resize during fullscreen
Wayland surface always matches display bounds
Shadow disabled
StyleMask irrelevant
On exit:
Restore previous decoration mode
Restore frame
Reconfigure client
9. Maximize (Wayland Has No True Equivalent)
Wayland:
xdg_toplevel.set_maximized
macOS:
[window zoom:nil];
Mapping caveat
macOS “zoom” is heuristic
Wayland expects full available area
Best practice:
Compute usable screen rect yourself
Set frame manually
Mark state as maximized
Do not rely on zoom: if you want correctness.
10. Minimize Mapping
Wayland:
xdg_toplevel.set_minimized
macOS:
[window miniaturize:nil];
Restore:
deminiaturize:
Wayland client stays mapped but not visible.
11. Frame Math (This Is Where Most Compositors Fail)
SSD
macOS frame
 ├─ titlebar
 └─ contentView  ← Wayland surface
CSD
macOS frame
 └─ contentView  ← Wayland surface + decorations
Configure sizes accordingly
If you get this wrong:
Resize feedback loops
One-frame-only rendering
Broken pointer coordinates
12. Hot Reload: Switching SSD ↔ CSD Live
When user toggles “Force SSD”:
Freeze Wayland surface
Recreate macOS window with new styleMask
Reparent CALayer
Send configure
Resume rendering
⚠️ Do NOT change styleMask mid-live-resize
13. Mental Model (Keep This)
Wayland controls intent. macOS controls reality.
Your compositor translates intent into reality.
CSD means:
You are the window manager
macOS is just a pixel container
SSD means:
macOS is the window manager
Wayland just paints
14. If You Want, Next Steps
I can:
Give you exact hit-test equations
Show a state machine diagram
Map wl_surface damage → CoreAnimation
Explain why you’re seeing first-frame-only rendering
Describe how SkyLight excludes shadow regions
Just tell me which one to drill into next.


ChatGPT can make mistakes. Check important info.
ChatGPT says: This is the **right question**, and you’re already thinking in the same architectural split Apple uses internally. Below is a **clean, concrete mapping** from **Wayland semantics → macOS window management**, specifically for a **macOS-hosted Wayland compositor** that supports **both SSD and CSD**, without breaking hit-testing, shadows, or resize behavior. I’ll go step-by-step and keep it **mechanical**, not hand-wavy. --- # 0. The Core Rule (Anchor This) > **macOS owns the real window. Wayland owns the visual content.** Your compositor must **translate Wayland surface intent into macOS window state**, but never let: - CSD pixels become macOS chrome - macOS chrome overlap CSD pixels - shadows participate in input This means: **the macOS window frame must change depending on CSD vs SSD**. --- # 1. Two Operating Modes (Hard Split) You already have SSD. Add an explicit **per-toplevel mode**: ```c enum decoration_mode { DECORATION_SSD, DECORATION_CSD }; ``` This mode must affect: - macOS window styleMask - Content inset math - Resize hit testing - Shadow extents - Wayland configure sizes --- # 2. Wayland Side: How Clients Express Decoration Intent ### Protocols you must support | Protocol | Purpose | |---|---| | `xdg-shell` | toplevel semantics | | `xdg-decoration` | SSD vs CSD negotiation | Specifically: ```text zxdg_decoration_manager_v1 zxdg_toplevel_decoration_v1 ``` Client requests: ```text set_mode(CLIENT_SIDE) set_mode(SERVER_SIDE) ``` You **must treat this as authoritative** unless force-SSD is enabled. --- # 3. macOS Window Mapping (Critical Part) ## 3.1 Server-Side Decoration (SSD) This is your existing path. ### macOS window configuration ```objc styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable; ``` ### Wayland mapping - Wayland surface size == macOS contentView size - Titlebar is **not visible to Wayland** - Resize edges handled by macOS - Shadow handled by macOS ### Input - All hit testing delegated to macOS - Wayland only sees content-area events This is the **easy path**. --- ## 3.2 Client-Side Decoration (CSD) This is where things break if done wrong. ### macOS window MUST change shape ```objc styleMask = NSWindowStyleMaskBorderless; window.titleVisibility = NSWindowTitleHidden; window.titlebarAppearsTransparent = YES; window.hasShadow = YES; // but shadow must be non-hit-testable ``` ⚠️ **No titlebar, no system resize affordances** --- ## 4. Resize Handling in CSD Mode (You Must Own This) ### Wayland truth In CSD mode: - **Client draws resize borders** - **Compositor decides hit regions** - Client only gets resize *intent*, not mouse movement ### Required Wayland behavior You must implement: ```text xdg_toplevel.resize(seat, serial, edges) ``` Where edges ∈: ``` TOP, BOTTOM, LEFT, RIGHT, TOP_LEFT, etc. ``` --- ## 5. macOS Side: Implementing Resize Tracking Yourself ### Step 1: Hit-test manually On mouse down: 1. Convert mouse to window-local coordinates 2. Compare against **CSD-defined resize margin** - Typically 6–10 px 3. Determine Wayland edge enum ⚠️ **Exclude shadow extents entirely** ```c if (point ∈ shadow_rect) return NO_HIT; ``` --- ### Step 2: Start resize loop Once resize begins: 1. Capture mouse (equivalent to live resize) 2. On mouse move: - Compute new frame rect - Call: ```objc [window setFrame:newFrame display:YES]; ``` 3. Send Wayland configure: ```text xdg_toplevel.configure(width, height, states) ``` 4. Wait for client `ack_configure` 5. Present new buffer This **exactly mirrors Wayland compositors on Linux**. --- ## 6. Shadows: The Click-Through Rule macOS shadows: - Are compositor-level - Extend beyond frame - Are hit-testable **by default** in SkyLight ### What Apple does internally - Shadow is rendered in a separate layer tree - Shadow region is excluded from input routing ### What you must do When CSD: - Track `shadowInsets` - Subtract from hit-test region - Never forward shadow hits to Wayland If you don’t: ➡️ Your shadow becomes a draggable resize border (your current bug) --- ## 7. Titlebar & Buttons in CSD Mode ### Wayland client responsibility - Draw titlebar - Draw close/min/max buttons - Handle hover, press, drag ### Your responsibility Translate clicks into actions: | CSD Button | macOS Action | |---|---| | Close | `-[NSWindow performClose:]` | | Minimize | `miniaturize:` | | Maximize | `zoom:` | | Fullscreen | `toggleFullScreen:` | ⚠️ Only if the client requests it (via protocol or conventions) --- ## 8. Fullscreen Mapping (Wayland ↔ macOS) ### Wayland request ```text xdg_toplevel.set_fullscreen ``` ### Your macOS action ```objc [window toggleFullScreen:nil]; ``` ### Important rules - Ignore macOS resize during fullscreen - Wayland surface always matches display bounds - Shadow disabled - StyleMask irrelevant On exit: - Restore previous decoration mode - Restore frame - Reconfigure client --- ## 9. Maximize (Wayland Has No True Equivalent) Wayland: ```text xdg_toplevel.set_maximized ``` macOS: ```objc [window zoom:nil]; ``` ### Mapping caveat - macOS “zoom” is heuristic - Wayland expects **full available area** Best practice: - Compute usable screen rect yourself - Set frame manually - Mark state as maximized Do **not rely on `zoom:`** if you want correctness. --- ## 10. Minimize Mapping Wayland: ```text xdg_toplevel.set_minimized ``` macOS: ```objc [window miniaturize:nil]; ``` Restore: ```objc deminiaturize: ``` Wayland client stays mapped but not visible. --- ## 11. Frame Math (This Is Where Most Compositors Fail) ### SSD ``` macOS frame ├─ titlebar └─ contentView ← Wayland surface ``` ### CSD ``` macOS frame └─ contentView ← Wayland surface + decorations ``` ### Configure sizes accordingly If you get this wrong: - Resize feedback loops - One-frame-only rendering - Broken pointer coordinates --- ## 12. Hot Reload: Switching SSD ↔ CSD Live When user toggles “Force SSD”: 1. Freeze Wayland surface 2. Recreate macOS window with new styleMask 3. Reparent CALayer 4. Send `configure` 5. Resume rendering ⚠️ Do NOT change styleMask mid-live-resize --- ## 13. Mental Model (Keep This) > **Wayland controls intent. macOS controls reality. > Your compositor translates intent into reality.** CSD means: - You are the window manager - macOS is just a pixel container SSD means: - macOS is the window manager - Wayland just paints --- ## 14. If You Want, Next Steps I can: - Give you **exact hit-test equations** - Show a **state machine diagram** - Map **wl_surface damage → CoreAnimation** - Explain why you’re seeing **first-frame-only rendering** - Describe how **SkyLight excludes shadow regions** Just tell me which one to drill into next.