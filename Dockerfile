FROM ubuntu:16.04
LABEL maintainer="mskalski13@gmail.com"

ENV CROSS_TRIPLET powerpc-pc-freebsd6

ADD freebsd /freebsd
ADD fix-links /freebsd/fix-links

# The header correction etc is because the soft-links are broken in the iso
#https://lists.freebsd.org/pipermail/freebsd-current/2011-August/026487.html
RUN apt-get -y update && \
    apt-get -y install build-essential m4 bison flex git vim file libtool automake autoconf autogen pkg-config && \
    mkdir -p /src && \
    mkdir -p /freebsd/${CROSS_TRIPLET} && \
    mv /freebsd/usr/include /freebsd/${CROSS_TRIPLET} && \
    mv /freebsd/usr/lib /freebsd/${CROSS_TRIPLET} && \
    mv /freebsd/lib/* /freebsd/${CROSS_TRIPLET}/lib && \
    /freebsd/fix-links

ADD binutils-2.25.1.tar.gz /src/
ADD gcc-4.8.5.tar.bz2 /src/
ADD gmp-6.0.0a.tar.xz /src/
ADD mpc-1.0.3.tar.gz /src/
ADD mpfr-3.1.3.tar.xz /src/

RUN \
    export PREFIX=/freebsd && \
    export TARGET=${CROSS_TRIPLET} && \
    export PATH="${PREFIX}/bin:${PATH}" && \
    cd /src/binutils-2.25.1 && \
    ./configure --enable-libssp --enable-ld --prefix=/freebsd \
                --host=x86_64-linux-gnu --target=${CROSS_TRIPLET} \
                --with-sysroot --disable-nls --disable-werror && \
    make -j4 && \
    make install && \
    cd /src/gmp-6.0.0 && \
    ./configure --prefix=/freebsd --enable-shared --enable-static \
      --enable-fft --enable-cxx --host=${CROSS_TRIPLET} && \
    make -j4 && \
    make install && \
    cd /src/mpfr-3.1.3 && \
    ./configure --prefix=/freebsd --with-gnu-ld  --enable-static \
      --enable-shared --with-gmp=/freebsd --host=${CROSS_TRIPLET} && \
    make -j4 && \
    make install && \
    cd /src/mpc-1.0.3/ && \
    ./configure --prefix=/freebsd --with-gnu-ld \
      --enable-static --enable-shared --with-gmp=/freebsd \
      --with-mpfr=/freebsd --host=${CROSS_TRIPLET}  &&\
    make -j4 && \
    make install && \
    mkdir -p /src/gcc-4.8.5/build && \
    cd /src/gcc-4.8.5/build && \
    ../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls \
        --enable-languages=c,c++ --enable-libssp --enable-ld \
        --disable-libitm --disable-libquadmath \
        --build=x86_64-pc-linux-gnu \
        --host=x86_64-pc-linux-gnu \
        --target=${CROSS_TRIPLET} \
        --prefix=/freebsd --with-gmp=/freebsd \
        --with-mpc=/freebsd --with-mpfr=/freebsd --disable-libgomp && \
    LD_LIBRARY_PATH=/freebsd/lib make -j10 && \
    make install && \
    cd / && \
    rm -rf /src

env LD_LIBRARY_PATH /freebsd/lib
env PATH /freebsd/bin/:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
env CC ${CROSS_TRIPLET}-gcc
env CPP ${CROSS_TRIPLET}-cpp
env AS ${CROSS_TRIPLET}-as
env LD ${CROSS_TRIPLET}-ld
env AR ${CROSS_TRIPLET}-ar
env RANLIB ${CROSS_TRIPLET}-ranlib
env HOST ${CROSS_TRIPLET}
