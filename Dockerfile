FROM freebsd-cross-devenv:latest
LABEL maintainer="mskalski13@gmail.com"

ARG PREFIX=/freebsd
ARG TARGET_ARCH=powerpc
ARG TARGET=${TARGET_ARCH}-pc-freebsd6

ADD freebsd ${PREFIX}
ADD fix-links ${PREFIX}/fix-links

# The header correction etc is because the soft-links are broken in the iso
#https://lists.freebsd.org/pipermail/freebsd-current/2011-August/026487.html
RUN mkdir -p /src && \
    mkdir -p ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/usr/include ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/usr/lib ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/usr/share ${PREFIX}/${TARGET} && \
    mv ${PREFIX}/lib/* ${PREFIX}/${TARGET}/lib && \
    ${PREFIX}/fix-links ${PREFIX} "${TARGET}"

ADD binutils-2.25.1.tar.gz /src/
ADD gcc-4.8.5.tar.bz2 /src/

RUN \
    export PATH="${PREFIX}/bin:${PATH}" && \
    cd /src/binutils-2.25.1 && \
    ./configure --enable-libssp --enable-ld --prefix=${PREFIX} \
                --host=x86_64-linux-gnu --target=${TARGET} \
                --with-sysroot --disable-nls --disable-werror && \
    make -j4 && \
    make install && \
    \
    mkdir -p /src/gcc-4.8.5/build && \
    cd /src/gcc-4.8.5/build && \
    ../configure --without-headers --with-gnu-as --with-gnu-ld --disable-nls \
        --enable-languages=c,c++ --enable-libssp --enable-ld \
        --disable-libitm --disable-libquadmath --disable-libgomp \
        --target=${TARGET} --prefix=${PREFIX} && \
    LD_LIBRARY_PATH=${PREFIX}/lib make -j10  && \
    make install && \
    cd / && \
    rm -rf /src

# Add required BSD users and groups
RUN groupadd --non-unique --force --gid 0 wheel    && \
    for group in staff operator guest man news mail games; do \
      groupadd --force --system $group; \
    done && \
    useradd --non-unique --uid 0 --gid 0 --no-create-home -c 'Bourne-again Superuser' -d /root -s /bin/bash toor && \
    grep -q '^kmem' /etc/passwd || useradd --gid kmem --no-create-home -c 'KMem Sandbox' -d / -s /usr/sbin/nologin kmem 
    
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
