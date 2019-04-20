#!/bin/bash

cd "$(dirname "$(readlink -f "$0" || realpath "$0")")"

jplatform="${jplatform:=linux}"
j64="${j64:=j64}"

# gcc 5 vs 4 - killing off linux asm routines (overflow detection)
# new fast code uses builtins not available in gcc 4
# use -DC_NOMULTINTRINSIC to continue to use more standard c in version 4
# too early to move main linux release package to gcc 5

macmin="-mmacosx-version-min=10.6"

if [ "x$CC" = x'' ] ; then
if [ -f "/usr/bin/cc" ]; then
CC=cc
else
if [ -f "/usr/bin/clang" ]; then
CC=clang
else
CC=gcc
fi
fi
export CC
fi
# compiler=`$CC --version | head -n 1`
compiler=`readlink -f $(command -v $CC)`
echo "CC=$CC"
echo "compiler=$compiler"

if [ -z "${compiler##*gcc*}" ]; then
# gcc
common="-fPIC -O1 -fwrapv -fno-strict-aliasing -Wextra -Wno-maybe-uninitialized -Wno-unused-parameter -Wno-sign-compare -Wno-clobbered -Wno-empty-body -Wno-unused-value -Wno-pointer-sign -Wno-parentheses"
OVER_GCC_VER6=$(echo `$CC -dumpversion | cut -f1 -d.` \>= 6 | bc)
if [ $OVER_GCC_VER6 -eq 1 ] ; then
common="$common -Wno-shift-negative-value"
else
common="$common -Wno-type-limits"
fi
# alternatively, add comment /* fall through */
OVER_GCC_VER7=$(echo `$CC -dumpversion | cut -f1 -d.` \>= 7 | bc)
if [ $OVER_GCC_VER7 -eq 1 ] ; then
common="$common -Wno-implicit-fallthrough"
fi
OVER_GCC_VER8=$(echo `$CC -dumpversion | cut -f1 -d.` \>= 8 | bc)
if [ $OVER_GCC_VER8 -eq 1 ] ; then
common="$common -Wno-cast-function-type"
fi
else
# clang 3.5 .. 5.0
common="-Werror -fPIC -O1 -fwrapv -fno-strict-aliasing -Wextra -Wno-consumed -Wno-uninitialized -Wno-unused-parameter -Wno-sign-compare -Wno-empty-body -Wno-unused-value -Wno-pointer-sign -Wno-parentheses -Wno-unsequenced -Wno-string-plus-int"
fi
darwin="-fPIC -O1 -fwrapv -fno-strict-aliasing -Wno-string-plus-int -Wno-empty-body -Wno-unsequenced -Wno-unused-value -Wno-pointer-sign -Wno-parentheses -Wno-return-type -Wno-constant-logical-operand -Wno-comment -Wno-unsequenced"

case $jplatform\_$j64 in

linux_j32) # linux x86
TARGET=libtsdll.so
# faster, but sse2 not available for 32-bit amd cpu
# sse does not support mfpmath=sse in 32-bit gcc
CFLAGS="$common -m32 -msse2 -mfpmath=sse -DC_NOMULTINTRINSIC "
# slower, use 387 fpu and truncate extra precision
# CFLAGS="$common -m32 -ffloat-store "
LDFLAGS=" -shared -Wl,-soname,libtsdll.so -m32 -lm -ldl"
;;

linux_j64nonavx) # linux intel 64bit nonavx
TARGET=libtsdll.so
CFLAGS="$common "
LDFLAGS=" -shared -Wl,-soname,libtsdll.so -lm -ldl"
;;

linux_j64) # linux intel 64bit avx
TARGET=libtsdll.so
CFLAGS="$common "
LDFLAGS=" -shared -Wl,-soname,libtsdll.so -lm -ldl"
;;

raspberry_j32) # linux raspbian arm
TARGET=libtsdll.so
CFLAGS="$common -marm -march=armv6 -mfloat-abi=hard -mfpu=vfp -DRASPI -DC_NOMULTINTRINSIC "
LDFLAGS=" -shared -Wl,-soname,libtsdll.so -lm -ldl"
;;

raspberry_j64) # linux arm64
TARGET=libtsdll.so
CFLAGS="$common -march=armv8-a+crc -DRASPI "
LDFLAGS=" -shared -Wl,-soname,libtsdll.so -lm -ldl"
;;

darwin_j32) # darwin x86
TARGET=libtsdll.dylib
CFLAGS="$darwin -m32 $macmin"
LDFLAGS=" -dynamiclib -lm -ldl -m32 $macmin"
;;

darwin_j64nonavx) # darwin intel 64bit nonavx
TARGET=libtsdll.dylib
CFLAGS="$darwin $macmin"
LDFLAGS=" -dynamiclib -lm -ldl $macmin"
;;

darwin_j64) # darwin intel 64bit
TARGET=libtsdll.dylib
CFLAGS="$darwin $macmin "
LDFLAGS=" -dynamiclib -lm -ldl $macmin"
;;

*)
echo no case for those parameters
exit
esac

echo "CFLAGS=$CFLAGS"

mkdir -p ../bin/$jplatform/$j64
export CFLAGS LDFLAGS TARGET jplatform j64
cd tsdll
make -f makefile clean
make -f makefile
cd ..