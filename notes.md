
1. CSD Wayland Clients aren't minimizing using macOS native minimize api.
2. CSD Wayland clients aren't resizable. 
3. SSD Wayland Clients are still drawing Client-Side Decoration.
4. SSD Wayland Clients anre't resizing to match the native macOS NSWindow size - something we solved awhile ago, is now broken again.
5. CSD Wayland clients are now properly drawing the native macOS Resize on edges and corners - but on resize, the client doesn't follow the frame size changes. Must be fixed.
6. CSD Wayland clients don't properly understand the zoom button. we'll come back to this after resize is fixed.





1. Now CSD wayland clients are drawing macOS windows decorations. BAD!
2. SSD is not properly rendering SSD only - it is also rendering CSD. remember, CSD means Client-Side Decorations, while SSD means Server-Side decorations. SSD for macOS Would be native macOS Windows. CSD would be the wayland client telling our Wawona wayland compositor that it will render its own custom Client-Side Decoration for each window. 
3.Don't forget Wawona Settings has FORCE SSD - for forcing native macOS window styles. when this is on, we ignore wayland clients that request Client-Side decoration and force them to use native Server-Side Decoration of the compositor.
4.the client now resizes, thank you. but, don't forget - we need 2 layers for client-side decorated windows - one passthru shadow layer, and then the window frame layer that needs to be resizable. Fix this!


