# Compiler Configuration

Wawona uses **strict compiler settings** similar to Rust's compiler, treating all warnings as errors and enabling maximum type safety.

## C Standard

- **C17** (ISO/IEC 9899:2018) - Latest stable C standard
- **GNU Extensions**: Disabled (`-std=c17` not `-std=gnu17`)
- **Standard Required**: Yes (`CMAKE_C_STANDARD_REQUIRED ON`)

## Warning Flags (All Enabled, Treated as Errors)

### Basic Warnings
- `-Wall` - Enable all common warnings
- `-Wextra` - Enable extra warnings
- `-Wpedantic` - Strict ISO C compliance
- `-Werror` - **Treat all warnings as errors** (like Rust)

### Type Safety
- `-Wstrict-prototypes` - Require function prototypes
- `-Wmissing-prototypes` - Warn about missing prototypes
- `-Wold-style-definition` - Warn about old-style function definitions
- `-Wmissing-declarations` - Warn about missing declarations

### Initialization
- `-Wuninitialized` - Warn about uninitialized variables
- `-Winit-self` - Warn about self-initialization

### Pointer Safety
- `-Wpointer-arith` - Warn about pointer arithmetic
- `-Wcast-qual` - Warn about casts that discard qualifiers
- `-Wcast-align` - Warn about casts that increase alignment

### String Safety
- `-Wwrite-strings` - Treat string literals as const
- `-Wformat=2` - Enhanced format string checking
- `-Wformat-security` - Warn about format string vulnerabilities

### Conversion Safety
- `-Wconversion` - Warn about implicit conversions
- `-Wsign-conversion` - Warn about sign conversions

### Undefined Behavior
- `-Wundef` - Warn about undefined identifiers
- `-Wshadow` - Warn about shadowed variables
- `-Wstrict-overflow=5` - Maximum strictness for overflow warnings

### Control Flow
- `-Wswitch-default` - Warn about missing default in switch
- `-Wswitch-enum` - Warn about missing enum cases
- `-Wunreachable-code` - Warn about unreachable code
- `-Wfloat-equal` - Warn about floating-point equality

### Security
- `-Wstack-protector` - Enable stack protection
- `-fstack-protector-strong` - Strong stack protection
- `-fPIC -fPIE -pie` - Position-independent code

## Optimization

### Release Builds
- `-O3` - Maximum optimization
- `-flto` - Link-time optimization
- `-DNDEBUG` - Disable assertions

### Debug Builds
- `-O0` - No optimization
- `-g3` - Maximum debug information
- `-DDEBUG` - Enable debug macros

## Sanitizers (Debug Builds)

- `-fsanitize=address` - Address sanitizer (detects memory errors)
- `-fsanitize=undefined` - Undefined behavior sanitizer
- `-fsanitize=leak` - Leak sanitizer
- `-fno-omit-frame-pointer` - Keep frame pointers for better stack traces

## Code Formatting

### clang-format
- **Style**: LLVM
- **Indent**: 4 spaces
- **Column Limit**: 100 characters
- **Configuration**: `.clang-format`

### Usage
```bash
# Format all code
make format

# Check formatting (for CI)
make check-format
```

## Code Linting

### clang-tidy
- **Checks**: bugprone, cert, clang-analyzer, concurrency, cppcoreguidelines, google, misc, modernize, performance, portability, readability, security
- **Warnings as Errors**: Yes
- **Configuration**: `.clang-tidy`

### Usage
```bash
# Lint all code
make lint
```

## Comparison with Rust

| Feature | Rust | Wawona (C) |
|---------|------|------------|
| Warnings as Errors | ✅ Default | ✅ `-Werror` |
| Type Safety | ✅ Strong | ✅ Maximum warnings |
| Memory Safety | ✅ Built-in | ✅ Sanitizers |
| Formatting | ✅ `cargo fmt` | ✅ `make format` |
| Linting | ✅ `cargo clippy` | ✅ `make lint` |
| Standard | Latest stable | C17 (latest) |

## Benefits

1. **Catch bugs early** - Warnings become errors
2. **Type safety** - Maximum type checking enabled
3. **Memory safety** - Sanitizers catch memory errors
4. **Code quality** - Consistent formatting and linting
5. **Security** - Stack protection and format string checking

