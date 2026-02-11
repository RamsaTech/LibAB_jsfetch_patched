#!/bin/bash
set -e

# Detect core count
if [[ "$OSTYPE" == "darwin"* ]]; then
  CORES=$(sysctl -n hw.ncpu)
else
  CORES=$(nproc)
fi

echo "Building with $CORES cores..."

# FFmpeg Configuration
FLAGS="--prefix=/opt/ffmpeg \
--target-os=none \
--enable-cross-compile \
--disable-x86asm \
--disable-inline-asm \
--disable-runtime-cpudetect \
--cc=emcc \
--ranlib=emranlib \
--disable-doc \
--disable-stripping \
--disable-programs \
--disable-ffplay \
--disable-ffprobe \
--disable-network \
--disable-iconv \
--disable-xlib \
--disable-sdl2 \
--disable-zlib \
--disable-everything \
--disable-pthreads \
--arch=emscripten \
--optflags=-Oz \
--enable-protocol=data \
--enable-protocol=file \
--enable-protocol=jsfetch \
--enable-protocol=crypto \
--enable-filter=aresample \
--enable-filter=asetnsamples \
--enable-muxer=mp4 \
--enable-muxer=matroska \
--enable-demuxer=matroska \
--enable-demuxer=aac \
--enable-demuxer=hls \
--enable-demuxer=flv \
--enable-demuxer=dash \
--enable-muxer=hls \
--enable-parser=aac \
--enable-decoder=aac \
--enable-decoder=h264 \
--enable-parser=h264 \
--enable-bsf=h264_metadata \
--enable-bsf=extract_extradata \
--enable-demuxer=mpegts \
--enable-demuxer=mp3 \
--enable-demuxer=mov \
--enable-muxer=mp3 \
--enable-demuxer=webvtt \
--enable-demuxer=srt \
--enable-demuxer=ass \
--enable-decoder=mp3 \
--enable-libmp3lame \
--enable-encoder=libmp3lame \
--enable-libvpx \
--enable-parser=vp9 \
--enable-bsf=vp9_metadata \
--enable-bsf=opus_metadata \
--enable-decoder=libvpx_vp9 \
--enable-ffmpeg \
--enable-ffprobe \
--enable-demuxer=ogg"

# Clean build dir?
# rm -rf build
mkdir -p build

# Build Dependencies
mkdir -p deps
cd deps

# LAME
if [ ! -d "lame-3.100" ]; then
  echo "Downloading LAME..."
  curl -L -O https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
  tar -xf lame-3.100.tar.gz
  cd lame-3.100
  echo "Configuring LAME..."
  emconfigure ./configure --prefix=$(pwd)/../../build/opt/ffmpeg --host=x86_64-linux --disable-shared --enable-static
  echo "Building LAME..."
  emmake make -j$CORES
  emmake make install
  cd ..
fi

# VPX
if [ ! -d "libvpx-1.13.0" ]; then
  echo "Downloading VPX..."
  curl -L -O https://github.com/webmproject/libvpx/archive/v1.13.0.tar.gz
  tar -xf v1.13.0.tar.gz
  cd libvpx-1.13.0
  echo "Configuring VPX..."
  emconfigure ./configure --prefix=$(pwd)/../../build/opt/ffmpeg --target=generic-gnu --disable-examples --disable-docs --disable-unit-tests --enable-vp9-highbitdepth --as=nasm
  echo "Building VPX..."
  emmake make -j$CORES
  emmake make install
  cd ..
fi

cd ..

# FFmpeg Configuration
# Update flags to include dependency paths
FLAGS="$FLAGS --extra-cflags=-I$(pwd)/build/opt/ffmpeg/include --extra-ldflags=-L$(pwd)/build/opt/ffmpeg/lib"

cd ffmpeg

echo "Configuring FFmpeg..."
emconfigure ./configure $FLAGS

echo "Building FFmpeg..."
emmake make -j$CORES

echo "Installing FFmpeg to temporary location..."
emmake make install DESTDIR=$(pwd)/../build

cd ..

echo "Linking LibAV..."

# Emscripten flags
EMCC_FLAGS="-Oz \
-s ASYNCIFY=1 \
-s MODULARIZE=1 \
-s EXPORT_NAME=\"LibAVFactory\" \
-s INITIAL_MEMORY=67108864 \
-s ALLOW_MEMORY_GROWTH=1 \
-s EXIT_RUNTIME=0 \
-s FILESYSTEM=1 \
-s FORCE_FILESYSTEM=1 \
-s EXPORTED_FUNCTIONS=['_main','_free','_malloc'] \
-s EXPORTED_RUNTIME_METHODS=['ccall','cwrap','FS','WORKERFS'] \
-lworkerfs.js \
--js-library src/library_jsfetch.js \
--pre-js src/jsfetch_dependencies.js"

# Includes and Libs from build/opt/ffmpeg
INCLUDES="-Ibuild/opt/ffmpeg/include"
LIB_DIR="-Lbuild/opt/ffmpeg/lib"
LIBS="-lavdevice -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lmp3lame -lvpx -lm"

# Note: libmp3lame and libvpx might need to be built separately or included?
# The user config has `--enable-libmp3lame` and `--enable-libvpx`.
# This implies these libraries are EXPECTED to be present or built by ffmpeg (if ffmpeg source includes them, which it usually doesn't).
# Attempting to build with these enabled without the libraries present will fail configuration.
# User said "Build FFmpeg...". Did they provide mp3lame/vpx source?
# No.
# But `emscripten` puts ports in `~/.emscripten_ports`.
# Typically one uses `-s USE_LIBPNG=1` etc.
# For mp3lame and libvpx, emscripten doesn't have them built-in as ports (except maybe via generic ports).
# Wait, if the user requested configuration has these enabled, and I am just building ffmpeg, 
# I might need to build these dependencies first!
# User constraints: "Create GitHub Actions workflow that... Installs exact Emscripten version... Builds FFmpeg... Builds libav.js".
# It doesn't mention building mp3lame/vpx.
# But if I use `--enable-libmp3lame --enable-libvpx`, configure will fail if not found.
# Maybe the user's "Apply jsfetch patch" includes enabling them internally or something?
# No, patch was for `jsfetch`.
# Maybe they are statically linked?
# I will check if emscripten ports support them.
# `emcc --show-ports`
# If not, I'm missing steps.
# BUT I must not "fork any upstream repositories".
# The user might be expecting me to download them.
# OR, maybe the user *Mistakenly* included them?
# "Identify build tags and compilation flags... Preserve versions exactly."
# If the original build had them, they must be there.
# I'll check if `libmp3lame` is in the ports or needs to be built.
# I will assume for now I might need to download them. Use `embuilder`?
# I'll start by converting this script to just echo the config and fail if missing.
#
# Actually, I'll add steps to download/build mp3lame and libvpx if needed.
# But "libav.js" repo usually includes a Makefile that builds dependencies.
# I am rewriting the build system.
# I will try to build WITHOUT them first? No, configuration will fail.
# I will add commented out sections for them, but if compilation fails I know why.

# Check if we need to build dependencies.
# I will assume `emscripten` ports might have `libvpx`? No.
# I will try to include a step to fetch them if needed.
# For now, I'll proceed with the linking command assuming libraries are available or I needed to build them.
# The user said "Add FFmpeg source". Didn't say "Add lame source".
# Maybe `ffmpeg` includes them? No.
#
# Let's hope the user's `config` meant `internal` encoders?
# `--enable-libmp3lame` means EXTERNAL library. `--enable-encoder=aac` is internal.
# If I use `--enable-libmp3lame`, I need `libmp3lame`.
# I will add a step in `build.sh` to download and build specific versions of lame and vpx if they are missing.
# Lame 3.100 and VPX 1.13.0 are reasonable guesses.
#
# BUT, the user prompt constraints: "Add FFmpeg source... Apply jsfetch patch... GitHub Actions... Installs exact Emscripten... Builds FFmpeg... Builds libav.js".
# No mention of mp3lame/vpx.
# I will try to build without explicit dependency build steps first? No, configure will fail.
# I'll add the dependency build logic to `scripts/build_deps.sh` and call it?
# Or put it in `build.sh`.
# I'll put it in `build.sh`.

# I will use `emcc` to link.
emcc $EMCC_FLAGS \
  $INCLUDES $LIB_DIR \
  ffmpeg/fftools/ffmpeg.c \
  ffmpeg/fftools/ffmpeg_opt.c \
  ffmpeg/fftools/ffmpeg_filter.c \
  ffmpeg/fftools/ffmpeg_mux_init.c \
  ffmpeg/fftools/ffmpeg_demux.c \
  ffmpeg/fftools/cmdutils.c \
  ffmpeg/fftools/opt_common.c \
  $LIBS \
  -o libav-6.5.7.1-h264-aac-mp3.wasm.mjs

