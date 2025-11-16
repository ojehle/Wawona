# Building Wawona Compositor

## Quick Start

The easiest way to build the compositor is using the automated build script:

```bash
./build.sh
```

This will:
1. ✅ Check all dependencies are installed
2. ✅ Configure CMake
3. ✅ Build the compositor
4. ✅ Show you where the binary is located

## Build Options

### Basic Build
```bash
./build.sh
```

### Clean Build (removes old build files)
```bash
./build.sh --clean
```

### Build and Run
```bash
./build.sh --run
```

### Clean, Build, and Run
```bash
./build.sh --clean --run
```

### Install to System
```bash
./build.sh --install
```
Installs the compositor to `/usr/local/bin/Wawona`

### Verbose Output
```bash
./build.sh --verbose
```

## Manual Build (Alternative)

If you prefer to build manually:

```bash
# 1. Check dependencies
./check-deps.sh

# 2. Create build directory
mkdir -p build
cd build

# 3. Configure with CMake
cmake ..

# 4. Build
make -j8
# or if you have ninja:
ninja

# 5. Run
./Wawona
```

## What Gets Built

The build process creates:
- **Binary**: `build/Wawona`
- **Build artifacts**: `build/CMakeFiles/`, `build/CMakeCache.txt`, etc.

## Troubleshooting

### "wayland-server not found"
Run `./install-wayland.sh` to install Wayland from source.

### "pixman-1 not found"
Install with: `brew install pixman`

### "cmake not found"
Install with: `brew install cmake`

### Build fails with linking errors
Make sure Wayland is properly installed:
```bash
./check-deps.sh
```

If tests fail, check that `PKG_CONFIG_PATH` includes Wayland:
```bash
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
```

## Next Steps After Building

1. **Run the compositor**:
   ```bash
   ./build.sh --run
   ```

2. **Test with a Wayland client**:
   ```bash
   # In another terminal, set WAYLAND_DISPLAY
   export WAYLAND_DISPLAY=wayland-0  # (or whatever socket name was created)
   
   # Run a Wayland client (if you have one)
   # For example, with QtWayland:
   # qtwayland5-example
   ```

3. **View the compositor window**:
   - A window titled "Wawona" should appear
   - This is where Wayland surfaces will be rendered

## Development Workflow

1. **Make changes** to source files in `src/`
2. **Rebuild**: `./build.sh --clean` (or just `./build.sh` if CMake detects changes)
3. **Test**: `./build.sh --run`
4. **Iterate**

## Build System Details

- **CMake**: Version 3.20+ required
- **Compiler**: Clang (comes with Xcode)
- **Build System**: Make or Ninja (auto-detected)
- **Parallel Builds**: Automatically uses all CPU cores

## Integration with IDE

The build script generates `build/compile_commands.json` which can be used by:
- **CLion**: Auto-detects CMake projects
- **VS Code**: Use CMake Tools extension
- **Xcode**: Can import CMake projects

## See Also

- `check-deps.sh` - Verify all dependencies
- `install-wayland.sh` - Install Wayland from source
- `README.md` - Project overview
- `docs/IMPLEMENTATION_STRATEGY.md` - Implementation details

