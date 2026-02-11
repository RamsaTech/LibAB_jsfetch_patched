# LibAB_jsfetch_patched

This repository contains a reproducible build system for a custom `libav.js` (FFmpeg) variant with `jsfetch` protocol support, designed for HLS streaming in web extensions.

## Project Structure

```
LibAB_jsfetch_patched/
├── .github/
│   └── workflows/
│       └── build.yml       # GitHub Actions CI workflow
├── ffmpeg/                 # FFmpeg 6.0 source code (patched)
├── patches/
│   └── ffmpeg/
│       └── 07-jsfetch-protocol.diff  # jsfetch protocol patch
├── scripts/
│   └── build.sh            # Main build script (downloads deps, configures, builds)
├── src/
│   ├── jsfetch_dependencies.js  # JS helper functions (pre-js)
│   └── library_jsfetch.js       # Emscripten library for jsfetch (js-library)
└── README.md
```

## Build Instructions

### GitHub Actions (Recommended)
This project is configured to build automatically via GitHub Actions.
1. Push this repository to GitHub.
2. The `Build LibAV` workflow will trigger on push to `main`.
3. Artifacts (`libav-6.5.7.1-h264-aac-mp3.wasm.mjs`, `libav-6.5.7.1-h264-aac-mp3.wasm.wasm`) will be uploaded to the workflow run.

### Local Build
To build locally, you need [Emscripten SDK](https://emscripten.org/docs/getting_started/downloads.html) installed and active (`emcc` in PATH).

1. Install dependencies (Linux):
   ```bash
   sudo apt-get install nasm build-essential pkg-config
   ```
2. Run the build script:
   ```bash
   ./scripts/build.sh
   ```
   This will:
   - Download and build `libmp3lame` and `libvpx` into `deps/`.
   - Configure FFmpeg with the specified flags.
   - Build FFmpeg to WASM.
   - Link the final `libav-*.mjs` and `.wasm` files.

## Modifications
- **FFmpeg**: Version 6.0, patched with `jsfetch` protocol.
- **Emscripten**: Built with version 3.1.71.
- **Flags**: Optimized for size (`-Oz`), with H.264, AAC, MP3, HLS support enabled.
- **Custom JS**: Includes `jsfetch` implementation for handling HTTP requests and HLS segments via proper protocol redirection.

## Artifacts
The build produces:
- `libav-6.5.7.1-h264-aac-mp3.wasm.mjs`: The JavaScript glue code (ES Module format + Emscripten wrapper).
- `libav-6.5.7.1-h264-aac-mp3.wasm.wasm`: The WebAssembly binary.
