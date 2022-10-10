FROM amazon/aws-lambda-python:3.9 as builder

ENV PREFIX=/usr/local/vips

ENV PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig \
  LD_LIBRARY_PATH=$PREFIX/lib \
  PATH=$PATH:$PREFIX/bin \
  WORKDIR=/usr/local/src

# poppler is for pdfs, can probably get rid of it
# openslide is in epel -- extra packages for enterprise linux
# RUN yum install -y \
#   https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
# RUN yum install -y \
#  openslide-devel

ARG MOZJPEG_VERSION=4.1.1
ARG MOZJPEG_URL=https://github.com/mozilla/mozjpeg/archive/refs/tags

ARG WEBP_VERSION=1.2.4
ARG WEBP_URL=https://storage.googleapis.com/downloads.webmproject.org/releases/webp

ARG VIPS_VERSION=8.13.2
ARG VIPS_URL=https://github.com/libvips/libvips/releases/download

RUN yum update -y \
  # "Development Tools" contains WAY more crud than we need
  # But I don't want to go through each build dep and resolve manually
  && yum groupinstall -y "Development Tools" \
  && yum install -y \
     wget \
     # mozjpeg deps
     nasm cmake3 \
     # libwebp deps
     libpng-devel libtiff-devel libgif-devel \
     # stuff we need to build our own libvips ... this is a pretty basic selection
     # of dependencies, you'll want to adjust these
     # dzsave needs libgsf
     libpng-devel poppler-glib-devel glib2-devel expat-devel zlib-devel orc-devel lcms2-devel libexif-devel libgsf-devel \
  # Make cmake3 our default by linking it
  && ln -s /usr/bin/cmake3 /usr/bin/cmake \
  # Build our own copy of libjpeg [Mozjpeg]
  # need -march=haswell
  && cd /usr/local/src \
     && wget -N ${MOZJPEG_URL}/v${MOZJPEG_VERSION}.tar.gz -O mozjpeg-${MOZJPEG_VERSION}.tar.gz \
     && tar xzf mozjpeg-${MOZJPEG_VERSION}.tar.gz \
     && cd mozjpeg-${MOZJPEG_VERSION} \
     && CFLAGS="${CFLAGS} -fPIC -march=haswell" \
        cmake -G"Unix Makefiles" \
          -DCMAKE_INSTALL_PREFIX=${PREFIX} \
          -DCMAKE_INSTALL_LIBDIR=${PREFIX}/lib \
          -DENABLE_STATIC=TRUE \
          -DENABLE_SHARED=FALSE \
          -DWITH_JPEG8=1 \
          -DWITH_TURBOJPEG=FALSE \
          -DPNG_SUPPORTED=FALSE \
     && make install/strip \
  # clean up mozjpeg source
  && cd /usr/local/src && rm -rfv mozjpeg-${MOZJPEG_VERSION} \
  # Build and install webp
    && wget ${WEBP_URL}/libwebp-${WEBP_VERSION}.tar.gz \
    && tar xzf libwebp-${WEBP_VERSION}.tar.gz \
    && cd libwebp-${WEBP_VERSION} \
    && CFLAGS="${CFLAGS} -fPIC -march=haswell" \
       ./configure --prefix=${PREFIX} \
         --enable-static --disable-shared \
         --enable-libwebpmux \
         --enable-libwebpdemux \
    && make install-strip \
  # clean up webp source
  && cd /usr/local/src && rm -rfv libwebp-${WEBP_VERSION} \
  # Build and install vips
     && wget ${VIPS_URL}/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.gz \
     && tar xzf vips-${VIPS_VERSION}.tar.gz \
     && cd vips-${VIPS_VERSION} \
     && CFLAGS="${CFLAGS} -fPIC -march=haswell" \
        ./configure --prefix ${PREFIX} --enable-shared --disable-static \
     && make install \
   # clean up vips source
   && cd /usr/local/src && rm -rfv vips-${VIPS_VERSION} \
   # clean up yum
   && yum clean all \
   && rm -rf /var/cache/yum

RUN pip install tiny-thumbnail-engine[server] --upgrade

COPY server.py ${LAMBDA_TASK_ROOT}/server.py

CMD ["server.lambda_handler"]
