FROM ubuntu:16.04
LABEL maintainer="mskalski13@gmail.com"

ARG PREFIX=/freebsd
ARG TARGET=powerpc-pc-freebsd6

ADD freebsd ${PREFIX}
ADD fix-links ${PREFIX}/fix-links

# The header correction etc is because the soft-links are broken in the iso
#https://lists.freebsd.org/pipermail/freebsd-current/2011-August/026487.html
RUN apt-get -y update && \
    apt-get -y install build-essential m4 bison flex git vim file libtool automake autoconf autogen pkg-config mc bmake && \
    mkdir -p /src && \
    mkdir -p ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/usr/include ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/usr/lib ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/usr/share ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/lib/* ${PREFIX}/${TARGET}/lib && \
    ${PREFIX}/fix-links ${PREFIX} "${TARGET}"

ADD binutils-2.25.1.tar.gz /src/
ADD gcc-4.8.5.tar.bz2 /src/
ADD gmp-6.0.0a.tar.xz /src/
ADD mpc-1.0.3.tar.gz /src/
ADD mpfr-3.1.3.tar.xz /src/

RUN \
    export PATH="${PREFIX}/bin:${PATH}" && \
    cd /src/binutils-2.25.1 && \
    ./configure --enable-libssp --enable-ld --prefix=${PREFIX} \
                --host=x86_64-linux-gnu --target=${TARGET} \
                --with-sysroot --disable-nls --disable-werror && \
    make -j4 && \
    make install && \
    \
    cd /src/gmp-6.0.0 && \
    ./configure --prefix=${PREFIX} --enable-shared --enable-static \
      --enable-fft --enable-cxx && \
    make -j4 && \
    make install && \
    cd /src/mpfr-3.1.3 && \
    ./configure --prefix=${PREFIX} --with-gnu-ld  --enable-static \
      --enable-shared --with-gmp=${PREFIX} && \
    make -j4 && \
    make install && \
    cd /src/mpc-1.0.3/ && \
    ./configure --prefix=${PREFIX} --with-gnu-ld \
      --enable-static --enable-shared --with-gmp=${PREFIX} \
      --with-mpfr=${PREFIX} &&\
    make -j4 && \
    make install && \
    \
    mkdir -p /src/gcc-4.8.5/build && \
    cd /src/gcc-4.8.5/build && \
    ../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls \
        --enable-languages=c,c++ --enable-libssp --enable-ld \
        --disable-libitm --disable-libquadmath --disable-libgomp \
        --target=${TARGET} \
        --prefix=${PREFIX} --with-gmp=${PREFIX} \
        --with-mpc=${PREFIX} --with-mpfr=${PREFIX} && \
    LD_LIBRARY_PATH=${PREFIX}/lib make -j10  && \
    make install && \
    cd / && \
    rm -rf /src

env LD_LIBRARY_PATH ${PREFIX}/lib
env PATH ${PREFIX}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
env CC ${TARGET}-gcc
env CPP ${TARGET}-cpp
env AS ${TARGET}-as
env LD ${TARGET}-ld
env AR ${TARGET}-ar
env RANLIB ${TARGET}-ranlib
env HOST ${TARGET}
env MAKESYSPATH ${PREFIX}/${TARGET}/share/mk
