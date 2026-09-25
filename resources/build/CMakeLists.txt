# OpenBOR v7533's engine for the AutoBleem App - ci/build.sh copies this file into the build's copy of engine/.
#
# Upstream's own build for this release is engine/Makefile, a tree of per-platform branches driven by pkg-config
# (and its CMake of today, on master, is 64-bit only - the console, the 32-bit Pi and the PC stick are 32-bit).
# This is the Makefile's SDL build as a plain list: its sources for BUILD_SDL + BUILD_SDL_IO + BUILD_GFX +
# BUILD_VORBIS + BUILD_WEBM + BUILD_PTHREAD, no OpenGL. Every library comes in as a path (AB_DEPS: the static
# zlib, libpng, libogg, libvorbis and libvpx ci/build.sh built; SDL2_*: the target's SDL2), so nothing is searched.
cmake_minimum_required(VERSION 3.13)
project(OpenBOR C)

set(AB_DEPS "" CACHE PATH "the static libraries' prefix (include/, lib/)")
set(AB_SDL2_INCLUDE "" CACHE PATH "SDL2's include/SDL2")
set(AB_SDL2_LIBS "" CACHE STRING "how to link SDL2")
set(AB_SDL2_GFX "" CACHE PATH "SDL2_gfx's source (only SDL2_framerate is used)")
set(AB_PLATFORM "LINUX" CACHE STRING "LINUX or WIN - the engine's TARGET_PLATFORM")

file(GLOB SRC_SCRIPTLIB source/scriptlib/*.c)
list(FILTER SRC_SCRIPTLIB EXCLUDE REGEX "_unittest\\.c$")
file(GLOB SRC_OPENBORSCRIPT source/openborscript/*.c)
list(FILTER SRC_OPENBORSCRIPT EXCLUDE REGEX "collision_coordinates\\.c$")  # not in the Makefile either
file(GLOB SRC_GAMELIB source/gamelib/*.c)
file(GLOB SRC_PREPROCESSOR source/preprocessorlib/*.c)

add_executable(OpenBOR
    openbor.c openborscript.c
    sdl/joysticks.c sdl/control.c sdl/sblaster.c sdl/timer.c sdl/sdlport.c sdl/video.c sdl/videocommon.c
    sdl/threads.c sdl/menu.c
    source/adpcmlib/adpcm.c
    source/gfxlib/2xSaI.c source/gfxlib/bilinear.c source/gfxlib/dotmatrix.c source/gfxlib/gfx.c
    source/gfxlib/hq2x.c source/gfxlib/scale2x.c source/gfxlib/scanline.c source/gfxlib/simple2x.c
    source/gfxlib/tv2x.c
    ${SRC_GAMELIB} ${SRC_SCRIPTLIB} ${SRC_OPENBORSCRIPT} ${SRC_PREPROCESSOR}
    source/stringptr.c source/utils.c source/stristr.c source/omath.c
    source/ramlib/ram.c source/randlib/rand32.c source/pnglib/pngdec.c source/pnglib/savepng.c
    source/webmlib/vidplay.c source/webmlib/vorbis.c source/webmlib/samplecvt.c source/webmlib/yuv.c
    source/webmlib/halloc/halloc.c source/webmlib/nestegg/nestegg.c
    ${AB_SDL2_GFX}/SDL2_framerate.c)

target_compile_definitions(OpenBOR PRIVATE ${AB_PLATFORM} SDL=1 OV_EXCLUDE_STATIC_CALLBACKS WEBM NO_RAM_DEBUGGER)
target_compile_options(OpenBOR PRIVATE -std=gnu99 -fsigned-char -O2 -fomit-frame-pointer -Wno-unused-result)
target_include_directories(OpenBOR PRIVATE
    . sdl source source/adpcmlib source/gamelib source/preprocessorlib source/ramlib source/randlib
    source/scriptlib source/openborscript source/pnglib source/gfxlib source/webmlib resources
    ${AB_SDL2_GFX} ${AB_DEPS}/include ${AB_DEPS}/include/libpng16 ${AB_SDL2_INCLUDE})

separate_arguments(AB_SDL2_LINK UNIX_COMMAND "${AB_SDL2_LIBS}")
target_link_libraries(OpenBOR PRIVATE
    ${AB_DEPS}/lib/libvpx.a ${AB_DEPS}/lib/libvorbisfile.a ${AB_DEPS}/lib/libvorbis.a ${AB_DEPS}/lib/libogg.a
    ${AB_DEPS}/lib/libpng16.a ${AB_DEPS}/lib/libz.a
    ${AB_SDL2_LINK})
if(AB_PLATFORM STREQUAL "WIN")
    # the icon and version block (resources/OpenBOR.rc, which reads version.h)
    enable_language(RC)
    target_sources(OpenBOR PRIVATE resources/OpenBOR.rc)
    target_link_libraries(OpenBOR PRIVATE psapi winmm -static-libgcc -Wl,-Bstatic,--whole-archive -lwinpthread
                          -Wl,--no-whole-archive,-Bdynamic)
else()
    target_link_libraries(OpenBOR PRIVATE pthread m)
endif()
