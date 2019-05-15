# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder

name = "Arpack"
version = v"3.5.0-3"

# Collection of sources required to build ArpackMKLBuilder
sources = [
    "https://github.com/opencollab/arpack-ng.git" =>
    "b095052372aa95d4281a645ee1e367c28255c947",

]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir
cd arpack*
mkdir build
cd build
# cmake -DINTERFACE64=1 -DBUILD_SHARED_LIBS=ON -DLAPACK_FOUND=true -DLAPACK_INCLUDE_DIRS=${MKLROOT}/include -DLAPACK_LIBRARIES=mkl_rt -DBLAS_FOUND=true -DBLAS_INCLUDE_DIRS=${MKLROOT}/include -DBLAS_LIBRARIES=mkl_rt ..
CMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS} -Wl,-rpath -Wl,$MKLROOT/lib"
# Symbols that have float32, float64, complexf32, and complexf64 support
SDCZ_SYMBOLS="axpy copy gemv geqr2 lacpy lahqr lanhs larnv lartg \
              lascl laset scal trevc trmm trsen gbmv gbtrf gbtrs \
              gttrf gttrs pttrf pttrs"
# All symbols that have float32/float64 support (including the SDCZ_SYMBOLS above)
SD_SYMBOLS="${SDCZ_SYMBOLS} dot ger labad laev2 lamch lanst lanv2 \
            lapy2 larf larfg lasr nrm2 orm2r rot steqr swap"
# All symbols that have complexf32/complexf64 support (including the SDCZ_SYMBOLS above)
CZ_SYMBOLS="${SDCZ_SYMBOLS} dotc geru unm2r"
# Add in (s|d)*_64 symbol remappings:
for sym in ${SD_SYMBOLS}; do     SYMBOL_DEFS="${SYMBOL_DEFS} -Ds${sym}=s${sym}_64 -Dd${sym}=d${sym}_64"; done
# Add in (c|z)*_64 symbol remappings:
for sym in ${CZ_SYMBOLS}; do     SYMBOL_DEFS="${SYMBOL_DEFS} -Dc${sym}=c${sym}_64 -Dz${sym}=z${sym}_64"; done
# Add one-off symbol mappings; things that don't fit into any other bucket:
for sym in scnrm2 dznrm2 csscal zdscal dgetrf dgetrs; do     SYMBOL_DEFS="${SYMBOL_DEFS} -D${sym}=${sym}_64"; done
# Set up not only lowercase symbol remappings, but uppercase as well:
SYMBOL_DEFS="${SYMBOL_DEFS} ${SYMBOL_DEFS^^}"
FFLAGS="${FFLAGS} -fdefault-integer-8 ${SYMBOL_DEFS} -ff2c"
cmake ..  -DINTERFACE64=1 -DBUILD_SHARED_LIBS=ON -DBLAS_LIBRARIES="-L$MKLROOT/lib -lmkl_rt" -DLAPACK_LIBRARIES="-L$MKLROOT/lib -lmkl_rt" -DCMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS}" -DCMAKE_Fortran_FLAGS="${FFLAGS}"
make clean all
make install
cp lib/libarpack.so.2.0.0 $prefix
exit

"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Linux(:x86_64, libc=:glibc),
    Linux(:i686, libc=:glibc)
]
platforms = expand_gcc_versions(platforms)

# The products that we will ensure are always built
products(prefix) = [
    LibraryProduct(prefix, "libarpack", :libarpack)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    "https://raw.githubusercontent.com/JuliaComputing/MKL.jl/76ab0ac2b671eb4e199c1b4a31872ccb22898e4f/deps/build_MKL.jl"
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)

