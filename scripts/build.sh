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
-Wno-pointer-sign \
--js-library src/library_jsfetch.js \
--pre-js src/jsfetch_dependencies.js"

# Includes and Libs from build/opt/ffmpeg
INCLUDES="-Ibuild/opt/ffmpeg/include -Iffmpeg"
LIB_DIR="-Lbuild/opt/ffmpeg/lib"
LIBS="-lavdevice -lavfilter -lavformat -lavcodec -lswresample -lswscale -lavutil -lmp3lame -lvpx -lm"



# I will use `emcc` to link.
emcc $EMCC_FLAGS \
  $INCLUDES $LIB_DIR \
  ffmpeg/fftools/ffmpeg.c \
  ffmpeg/fftools/ffmpeg_opt.c \
  ffmpeg/fftools/ffmpeg_filter.c \
  ffmpeg/fftools/ffmpeg_mux_init.c \
  ffmpeg/fftools/ffmpeg_demux.c \
  ffmpeg/fftools/ffmpeg_sched.c \
  ffmpeg/fftools/ffmpeg_hw.c \
  ffmpeg/fftools/ffmpeg_dec.c \
  ffmpeg/fftools/ffmpeg_enc.c \
  ffmpeg/fftools/ffmpeg_mux.c \
  ffmpeg/fftools/sync_queue.c \
  ffmpeg/fftools/thread_queue.c \
  ffmpeg/fftools/objpool.c \
  ffmpeg/fftools/cmdutils.c \
  ffmpeg/fftools/opt_common.c \
  $LIBS \
  -o libav-6.5.7.1-h264-aac-mp3.wasm.mjs

