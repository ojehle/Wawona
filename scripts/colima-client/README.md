# Colima Client Script Modules

This directory contains modular scripts for the colima-client functionality, split into focused, maintainable components.

## Structure

- **common.sh** - Shared variables and constants (colors, container config, paths)
- **waypipe-setup.sh** - Waypipe client setup and management
- **docker-setup.sh** - Docker/Colima installation and verification
- **container-setup.sh** - Container image and container lifecycle management
- **weston-install.sh** - Weston installation logic (for reference, not used in container)
- **socket-detect.sh** - Socket detection and verification (for reference)
- **weston-run.sh** - Weston execution logic (for reference)
- **container-commands.sh** - Container-side command generation helpers

## Main Script

The main `colima-client.sh` script in the parent directory orchestrates these modules:

1. Sources common variables and module functions
2. Initializes waypipe client
3. Checks compositor socket
4. Sets up Docker/Colima
5. Manages container lifecycle
6. Runs waypipe server + Weston in container

## Benefits

- **Reduced complexity**: Each module has a single responsibility
- **Easier maintenance**: Changes are isolated to specific modules
- **Better readability**: Smaller files are easier to understand
- **Reusability**: Modules can be used independently if needed
- **Reduced tool calls**: Smaller files mean fewer tokens per tool call

