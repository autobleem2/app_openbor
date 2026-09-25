#!/usr/bin/env bash
# Builds OpenBOR (v7533, its last release for 32-bit machines) in the autobleem-build image
# (ghcr.io/autobleem2/autobleem-build) and packages it as an AutoBleem App:
#
#   ci/build.sh native                    a host build (build_native/)
#   ci/build.sh psc|rpi|rpi64|pcusb|win   a target -> dist/openbor-<key>-<version>.zip
#   ci/build.sh all                       every one of them
#
# upstream/* are pinned submodules, never edited: each build copies them and applies patches/<name>/*.patch
# (CLAUDE.md). The codecs OpenBOR plays its music and videos with - zlib, libpng, libogg, libvorbis, libvpx (VP8
# decoding only) - are built from their submodules as static libraries and linked in, and SDL2_gfx's frame-rate
# limiter is compiled into the program; so the only shared library it needs is SDL2 - the launcher's (the console,
# Windows) or the system's (the Pis, the PC stick).
#
# On the build server: docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src \
#                          ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

VERSION="${AB_VERSION:-$(tr -d '\r' < VERSION)}"
JOBS="${JOBS:-$(nproc)}"
PSC=${AB_PSC_TOOLCHAIN:-/opt/psc}
MINGW_SDL2=${AB_MINGW_SDL2:-/opt/mingw-sdl2}
APP=openbor
PROGRAM=OpenBOR
# what upstream's version.sh would have written for the v7533 tag (it asks git, and the build copy has none)
OPENBOR_BUILD=7533
OPENBOR_COMMIT=5c82614

banner() { printf '\n==== %s ====\n' "$*"; }

# ---------------------------------------------------------------------------------------------------------
# One target. Each target_* sets CC, AR, RANLIB, STRIP, CFLAGS_T (CPU flags), CMAKE_T (a cross build's CMake
# arguments), VPX_TARGET, CROSS, SDL_INCLUDE, SDL_LIBS, PLATFORM (LINUX or WIN), EXE
# ---------------------------------------------------------------------------------------------------------
cross_cmake() { # cross_cmake <system> <processor>
    CMAKE_T=(-DCMAKE_SYSTEM_NAME="$1" -DCMAKE_SYSTEM_PROCESSOR="$2" -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="${CC%gcc}g++"
             -DCMAKE_AR="$(command -v "$AR")" -DCMAKE_RANLIB="$(command -v "$RANLIB")")
}
target_native() {
    CC=gcc; AR=ar; RANLIB=ranlib; STRIP=strip; CROSS=""; CFLAGS_T=""; CMAKE_T=(); VPX_TARGET=generic-gnu
    SDL_INCLUDE=$(pkg-config --variable=includedir sdl2)/SDL2; SDL_LIBS=$(pkg-config --libs sdl2)
    PLATFORM=LINUX; EXE=""
}
target_psc() {
    # the console's gcc-6 against a Debian Stretch sysroot, and the launcher's SDL2 (/opt/psc/sdl2)
    CROSS="$PSC/bin/armv8-sony-linux-gnueabihf-"
    CC="${CROSS}gcc"; AR="${CROSS}ar"; RANLIB="${CROSS}ranlib"; STRIP="${CROSS}strip"
    CFLAGS_T="-mfloat-abi=hard -march=armv8-a -mfpu=neon-vfpv4"; VPX_TARGET=armv7-linux-gcc
    cross_cmake Linux arm
    SDL_INCLUDE="$PSC/sdl2/include/SDL2"; SDL_LIBS="-L$PSC/sdl2/lib -lSDL2"
    PLATFORM=LINUX; EXE=""
}
target_rpi() {
    CROSS=arm-linux-gnueabihf-; CC="${CROSS}gcc"; AR="${CROSS}ar"; RANLIB="${CROSS}ranlib"; STRIP="${CROSS}strip"
    CFLAGS_T="-mfloat-abi=hard -mfpu=neon-vfpv4 -march=armv7-a"; VPX_TARGET=armv7-linux-gcc
    cross_cmake Linux arm
    SDL_INCLUDE=$(arm-linux-gnueabihf-pkg-config --variable=includedir sdl2)/SDL2
    SDL_LIBS=$(arm-linux-gnueabihf-pkg-config --libs sdl2)
    PLATFORM=LINUX; EXE=""
}
target_rpi64() {
    CROSS=aarch64-linux-gnu-; CC="${CROSS}gcc"; AR="${CROSS}ar"; RANLIB="${CROSS}ranlib"; STRIP="${CROSS}strip"
    CFLAGS_T="-march=armv8-a"; VPX_TARGET=arm64-linux-gcc
    cross_cmake Linux aarch64
    SDL_INCLUDE=$(aarch64-linux-gnu-pkg-config --variable=includedir sdl2)/SDL2
    SDL_LIBS=$(aarch64-linux-gnu-pkg-config --libs sdl2)
    PLATFORM=LINUX; EXE=""
}
target_pcusb() {
    CROSS=i686-linux-gnu-; CC="${CROSS}gcc"; AR="${CROSS}ar"; RANLIB="${CROSS}ranlib"; STRIP="${CROSS}strip"
    CFLAGS_T="-march=i686 -mtune=generic -D_FILE_OFFSET_BITS=64"; VPX_TARGET=generic-gnu
    cross_cmake Linux i686
    SDL_INCLUDE=$(i386-linux-gnu-pkg-config --variable=includedir sdl2)/SDL2
    SDL_LIBS=$(i386-linux-gnu-pkg-config --libs sdl2)
    PLATFORM=LINUX; EXE=""
}
target_win() {
    # the official SDL2 mingw development package: the DLL the Windows product ships next to the launcher, which
    # puts its folder on an App's PATH
    CROSS=x86_64-w64-mingw32-; CC="${CROSS}gcc"; AR="${CROSS}ar"; RANLIB="${CROSS}ranlib"; STRIP="${CROSS}strip"
    CFLAGS_T=""; VPX_TARGET=generic-gnu
    cross_cmake Windows AMD64
    CMAKE_T+=(-DCMAKE_RC_COMPILER="${CROSS}windres")
    SDL_INCLUDE="$MINGW_SDL2/include/SDL2"; SDL_LIBS="-L$MINGW_SDL2/lib -lmingw32 -lSDL2main -lSDL2 -mwindows"
    PLATFORM=WIN; EXE=.exe
}

# ---------------------------------------------------------------------------------------------------------
# The static codecs, into build_<key>/deps (include/, lib/). Kept between runs: a target whose deps/.stamp names
# the same submodule commits is not rebuilt (libvpx alone is most of a clean build's time).
# ---------------------------------------------------------------------------------------------------------
deps_stamp() {
    git submodule status upstream/zlib upstream/libpng upstream/ogg upstream/vorbis upstream/libvpx 2>/dev/null \
        | awk '{print $1 $2}' | tr -d '+-'
    echo "$CC $CFLAGS_T $VPX_TARGET"
}

cmake_dep() { # cmake_dep <key> <name> <cmake args...>
    local key="$1" name="$2"; shift 2
    local src="build_$key/deps-src/$name" deps="$ROOT/build_$key/deps"
    rm -rf "$src"
    mkdir -p "$src"
    cp -r "upstream/$name/." "$src/src"
    rm -rf "$src/src/.git"
    PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig" cmake -S "$src/src" -B "$src/build" -G "Unix Makefiles" --no-warn-unused-cli \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$deps" -DCMAKE_PREFIX_PATH="$deps" \
        -DCMAKE_C_FLAGS="$CFLAGS_T" -DCMAKE_POSITION_INDEPENDENT_CODE=OFF -DBUILD_SHARED_LIBS=OFF \
        "${CMAKE_T[@]}" "$@" >/dev/null
    cmake --build "$src/build" -j "$JOBS" >/dev/null
    cmake --install "$src/build" >/dev/null
}

build_deps() { # build_deps <key>
    local key="$1" deps="$ROOT/build_$1/deps"
    local stamp; stamp=$(deps_stamp)
    if [ -f "$deps/.stamp" ] && [ "$(cat "$deps/.stamp")" = "$stamp" ]; then
        echo "    codecs: up to date (build_$key/deps)"
        return
    fi
    rm -rf "$deps" "build_$key/deps-src"
    mkdir -p "$deps"

    echo "    zlib"
    cmake_dep "$key" zlib -DZLIB_BUILD_EXAMPLES=OFF
    # zlib's CMake names its static library libz.a on Unix and libzlibstatic.a elsewhere; only the static one is used
    [ -f "$deps/lib/libz.a" ] || cp "$deps/lib/libzlibstatic.a" "$deps/lib/libz.a"
    rm -f "$deps"/lib/libz.so* "$deps"/lib/libzlib.dll.a "$deps"/bin/*.dll

    echo "    libpng"
    cmake_dep "$key" libpng -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF -DPNG_TOOLS=OFF \
        -DPNG_FRAMEWORK=OFF -DPNG_HARDWARE_OPTIMIZATIONS=OFF \
        -DZLIB_INCLUDE_DIR="$deps/include" -DZLIB_LIBRARY="$deps/lib/libz.a" -DZLIB_ROOT="$deps"
    [ -f "$deps/lib/libpng16.a" ] || cp "$deps"/lib/libpng16_static.a "$deps/lib/libpng16.a"

    echo "    libogg"
    cmake_dep "$key" ogg -DINSTALL_DOCS=OFF -DBUILD_TESTING=OFF
    echo "    libvorbis"
    cmake_dep "$key" vorbis -DBUILD_TESTING=OFF -DOGG_INCLUDE_DIR="$deps/include" -DOGG_LIBRARY="$deps/lib/libogg.a"

    echo "    libvpx ($VPX_TARGET, VP8 decoding)"
    local src="build_$key/deps-src/libvpx"
    mkdir -p "$src"
    cp -r upstream/libvpx/. "$src/src"
    rm -rf "$src/src/.git"
    mkdir -p "$src/build"
    (cd "$src/build" && CROSS="$CROSS" ../src/configure --target="$VPX_TARGET" --prefix="$deps" \
        --enable-static --disable-shared --disable-examples --disable-tools --disable-docs --disable-unit-tests \
        --disable-vp9 --disable-vp8-encoder --disable-install-bins --disable-install-srcs \
        --extra-cflags="$CFLAGS_T" >/dev/null \
        && make -j "$JOBS" >/dev/null && make install >/dev/null)

    rm -rf "build_$key/deps-src"
    echo "$stamp" > "$deps/.stamp"
}

# ---------------------------------------------------------------------------------------------------------
# The engine
# ---------------------------------------------------------------------------------------------------------
write_version_h() { # write_version_h <engine dir>: version.sh's version.h, without git
    cat > "$1/version.h" <<EOF
/* Written by the AutoBleem App's ci/build.sh in place of upstream's version.sh (v$OPENBOR_BUILD) */
#ifndef VERSION_H
#define VERSION_H

#define VERSION_NAME "OpenBOR"
#define VERSION_MAJOR "4"
#define VERSION_MINOR "0"
#define VERSION_BUILD "$OPENBOR_BUILD"
#define VERSION_BUILD_INT $OPENBOR_BUILD
#define VERSION_COMMIT "$OPENBOR_COMMIT"
#define VERSION "v"VERSION_MAJOR"."VERSION_MINOR" Build "VERSION_BUILD" (commit hash: "VERSION_COMMIT")"

#endif
EOF
}

build_engine() { # build_engine <key>
    local key="$1" dir="build_$1/openbor"
    rm -rf "$dir"
    mkdir -p "$dir"
    cp -r upstream/openbor/. "$dir/src"
    rm -rf "$dir/src/.git"
    for p in patches/openbor/*.patch; do
        [ -f "$p" ] || continue
        patch -d "$dir/src" -p1 --no-backup-if-mismatch < "$p" >/dev/null
    done
    local engine="$dir/src/engine"
    write_version_h "$engine"
    python3 tools/make_branding.py "$engine" >/dev/null
    cp resources/build/CMakeLists.txt "$engine/"

    cmake -S "$engine" -B "$dir/build" -G "Unix Makefiles" --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="$CFLAGS_T" "${CMAKE_T[@]}" \
        -DAB_DEPS="$ROOT/build_$key/deps" -DAB_SDL2_INCLUDE="$SDL_INCLUDE" -DAB_SDL2_LIBS="$SDL_LIBS" \
        -DAB_SDL2_GFX="$ROOT/upstream/SDL2_gfx" -DAB_PLATFORM="$PLATFORM" >/dev/null
    cmake --build "$dir/build" -j "$JOBS" 2>&1 | { grep -E "error|Error" || true; }
    [ -f "$dir/build/$PROGRAM$EXE" ] || { echo "    ERROR: $PROGRAM$EXE was not built" >&2; exit 1; }

    local stage="build_$key/Apps/$APP"
    rm -rf "$stage"
    mkdir -p "$stage/bin/$key" "$stage/Paks" "$stage/Saves"
    cp "$dir/build/$PROGRAM$EXE" "$stage/bin/$key/"
    "$STRIP" "$stage/bin/$key/$PROGRAM$EXE"
    cp resources/app/app.ini resources/app/readme.txt resources/app/icon.png resources/app/pad.ini "$stage/"
    cp resources/app/Paks/* "$stage/Paks/" 2>/dev/null || true
    cp "$dir/src/LICENSE" "$stage/LICENSE-openbor.txt"
    # the libraries linked in: their licences ask for their notices to travel with the binary
    mkdir -p "$stage/licences"
    cp upstream/zlib/LICENSE "$stage/licences/zlib.txt"
    cp upstream/libpng/LICENSE "$stage/licences/libpng.txt"
    cp upstream/ogg/COPYING "$stage/licences/libogg.txt"
    cp upstream/vorbis/COPYING "$stage/licences/libvorbis.txt"
    cat upstream/libvpx/LICENSE upstream/libvpx/PATENTS > "$stage/licences/libvpx.txt"
    sed '/\*\//q' upstream/SDL2_gfx/SDL2_framerate.c > "$stage/licences/SDL2_gfx.txt"
    sed -i "s/^Version=.*/Version=$VERSION/" "$stage/app.ini"
}

build_target() { # build_target <key>
    banner "$1 (build_$1)"
    "target_$1"
    build_deps "$1"
    build_engine "$1"
}

package() { # package <key>
    local key="$1" dir="build_$1"
    local zip="dist/$APP-$key-$VERSION.zip"
    mkdir -p dist
    rm -f "$zip"
    (cd "$dir" && python3 "$ROOT/tools/zip_app.py" "$ROOT/$zip" "Apps/$APP")
    ls -l "$zip"
}

check() { # check <key>: the program is the platform's and needs nothing we do not ship
    local key="$1" stage="build_$1/Apps/$APP"
    case "$key" in
        psc)
            file "$stage/bin/psc/$PROGRAM" | grep -q 'ELF 32-bit LSB.*ARM'
            bash tools/check_psc_binary.sh "$stage/bin/psc/$PROGRAM" "$PSC" ;;
        rpi) file "$stage/bin/rpi/$PROGRAM" | grep -q 'ELF 32-bit LSB.*ARM' ;;
        rpi64) file "$stage/bin/rpi64/$PROGRAM" | grep -q 'ELF 64-bit LSB.*aarch64' ;;
        pcusb) file "$stage/bin/pcusb/$PROGRAM" | grep -q 'ELF 32-bit LSB.*Intel 80386' ;;
        win) file "$stage/bin/win/$PROGRAM.exe" | grep -q 'PE32+ executable.*x86-64' ;;
    esac
    bash tools/check_needed.sh "$key" "$stage"
}

build_one() { # build_one <key>
    build_target "$1"
    check "$1"
    package "$1"
}

[ $# -gt 0 ] || { echo "usage: $0 native|psc|rpi|rpi64|pcusb|win|all" >&2; exit 2; }
for target in "$@"; do
    case "$target" in
        native) build_target native; ls -l build_native/Apps/$APP/bin/native/ ;;
        psc | rpi | rpi64 | pcusb | win) build_one "$target" ;;
        all) build_target native; for k in psc rpi rpi64 pcusb win; do build_one "$k"; done ;;
        *) echo "unknown target: $target" >&2; exit 2 ;;
    esac
done
