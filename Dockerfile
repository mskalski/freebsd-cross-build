FROM ubuntu:16.04 AS freebsd-cross-devenv
LABEL maintainer="mskalski13@gmail.com"

RUN apt-get -y update && \
    apt-get -y install build-essential m4 bison flex git vim file \
               libtool automake autoconf autogen pkg-config mc bmake \
               git texinfo \
               libgmp-dev libmpc-dev libmpfr-dev libbabeltrace-dev && \
    apt-get clean

ADD tools    /usr/local/bin/
ADD scripts  /root/
ADD scripts  /etc/skel/

# Create builder image
FROM freebsd-cross-devenv AS freebsd_cross_builder
LABEL maintainer="mskalski13@gmail.com"

ARG PREFIX=/freebsd
ARG TARGET_ARCH=aarch64
ARG TARGET=${TARGET_ARCH}-pc-freebsd12

ADD freebsd ${PREFIX}
RUN mkdir -p {PREFIX}/bin
ADD fix-links ${PREFIX}/bin/freebsd-fix-links

# The header correction etc is because the soft-links are broken in the iso
#https://lists.freebsd.org/pipermail/freebsd-current/2011-August/026487.html
RUN mkdir -p /src && \
    mkdir -p ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/usr/include ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/usr/lib ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/usr/share ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/lib/* ${PREFIX}/${TARGET}/lib && \
    rm -fr ${PREFIX}/usr ${PREFIX}/lib && \
    ${PREFIX}/bin/freebsd-fix-links ${PREFIX} "${TARGET}"

ADD binutils-2.32.tar.gz /src/
RUN \
    export PATH="${PREFIX}/bin:${PATH}" && \
    cd /src/binutils-2.32 && \
    ./configure --enable-libssp --enable-ld --prefix=${PREFIX} \
                --target=${TARGET} \
                --with-sysroot --disable-nls --disable-werror && \
    make -j4 && \
    make install

ADD gcc-7.4.0.tar.xz /src/
RUN \
    export PATH="${PREFIX}/bin:${PATH}" && \
    mkdir -p /src/gcc-7.4.0/build && \
    cd /src/gcc-7.4.0/build && \
    ../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls \
        --enable-languages=c,c++ --enable-libssp --enable-ld \
        --disable-libitm --disable-libquadmath --disable-libgomp \
        --enable-threads=posix --disable-nls \
        --target=${TARGET} --prefix=${PREFIX} --libexecdir=${PREFIX}/lib && \
    LD_LIBRARY_PATH=${PREFIX}/lib make -j10  && \
    make install

ADD gdb-8.2.tar.gz /src/
# Create cross-GDB
RUN ( \
    export PATH="${PREFIX}/bin:${PATH}" && \
    mkdir -p /src/gdb-8.2/build && \
    cd /src/gdb-8.2/build && \
    ../configure --target=${TARGET} --prefix=${PREFIX} \
                 --enable-libssp --disable-libquadmath && \
    LD_LIBRARY_PATH=${PREFIX}/lib make -j10  && \
    make install ) || true

RUN \
    find ${PREFIX} -type f -executable -a '!' -type l | xargs file | grep 'ELF.*executable' | sed 's/:.*$//' | xargs strip || true
    
# Finally compile GDB for remote debugging using crosscompiler just created
RUN ( \
    export PATH="${PREFIX}/bin:${PATH}" && \
    mkdir -p /src/gdb-8.2/build-${TARGET} && \
    cd /src/gdb-8.2/build-${TARGET} && \
    ../configure --host=${TARGET} --prefix=${PREFIX}/${TARGET}/sysroot \
                 --enable-libssp --disable-libquadmath && \
    LD_LIBRARY_PATH=${PREFIX}/lib make -j10  && \
    make install; \
    find ${PREFIX}/${TARGET}/sysroot -type f -executable -a '!' -type l | xargs file | grep 'ELF.*executable' | sed 's/:.*$//' | xargs ${TARGET}-strip || true \
    ) || true


# Build final image
FROM freebsd-cross-devenv
LABEL maintainer="mskalski13@gmail.com"

ARG PREFIX=/freebsd
ARG TARGET_ARCH=aarch64
ARG TARGET=${TARGET_ARCH}-pc-freebsd12

COPY --from=freebsd_cross_builder $PREFIX $PREFIX

ADD compat ${PREFIX}/bin

ENV LD_LIBRARY_PATH ${PREFIX}/lib
ENV PATH ${PREFIX}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV CC ${TARGET}-gcc
ENV CXX ${TARGET}-g++
ENV CPP ${TARGET}-cpp
ENV AS ${TARGET}-as
ENV LD ${TARGET}-ld
ENV AR ${TARGET}-ar
ENV NM ${TARGET}-nm
ENV OBJCOPY ${TARGET}-objcopy
ENV OBJDUMP ${TARGET}-objdump
ENV RANLIB ${TARGET}-ranlib
ENV READELF ${TARGET}-readelf
ENV STRIP ${TARGET}-strip

ENV HOST ${TARGET}
ENV MAKESYSPATH ${PREFIX}/${TARGET}/share/mk
ENV TARGET_ARCH ${TARGET_ARCH}
ENV TARGET_MACHINE ${TARGET_ARCH}
ENV TARGET_OS FreeBSD
ENV OPSYS     FreeBSD

