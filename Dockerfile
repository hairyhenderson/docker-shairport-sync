FROM hairyhenderson/gomplate:v3.10.0-slim AS gomplate
FROM alpine:3.16 AS build-base

RUN apk --no-cache add \
    git \
    build-base \
    autoconf \
    automake \
    libtool \
    dbus \
    su-exec \
    alsa-lib-dev \
    libdaemon-dev \
    popt-dev \
    mbedtls-dev \
    soxr-dev \
    avahi-dev \
    libconfig-dev \
    libsndfile-dev \
    mosquitto-dev \
    xmltoman

FROM build-base AS build-alac

# First, install ALAC
WORKDIR /root/alac
RUN git clone https://github.com/mikebrady/alac.git .
RUN autoreconf -i -f
RUN ./configure \
  --prefix=/usr/local
RUN make
RUN make install

FROM build-base AS build

WORKDIR /root/shairport-sync
RUN git clone https://github.com/mikebrady/shairport-sync.git .
RUN autoreconf -i -f

COPY --from=build-alac /usr/local/lib/libalac.* /usr/local/lib/
COPY --from=build-alac /usr/local/lib/pkgconfig/alac.pc /usr/local/lib/pkgconfig/alac.pc
COPY --from=build-alac /usr/local/include /usr/local/include

RUN ./configure \
        --prefix=/usr/local \
        --with-alsa \
        --with-dummy \
        --with-pipe \
        --with-stdout \
        --with-avahi \
        --with-ssl=mbedtls \
        --with-soxr \
        --sysconfdir=/etc \
        --with-dbus-interface \
        --with-mpris-interface \
        --with-mqtt-client \
        --with-apple-alac \
        --with-convolution \
        --with-metadata
RUN make -j $(nproc)
RUN make install

FROM alpine:3.16 AS shairport

RUN apk --no-cache add \
    alsa-lib \
    dbus \
    popt \
    glib \
    mbedtls \
    soxr \
    avahi \
    libconfig \
    libsndfile \
    mosquitto-libs \
    su-exec \
    libgcc \
    libgc++

RUN addgroup shairport-sync
RUN adduser -D shairport-sync -G shairport-sync
RUN addgroup -g 29 docker_audio && addgroup shairport-sync docker_audio

COPY --from=gomplate /gomplate /bin/gomplate

COPY --from=build-alac /usr/local/lib/libalac.* /usr/local/lib/

COPY --from=build /etc/shairport-sync* /etc/
COPY --from=build /etc/dbus-1/system.d/shairport-sync-dbus.conf /etc/dbus-1/system.d/
COPY --from=build /etc/dbus-1/system.d/shairport-sync-mpris.conf /etc/dbus-1/system.d/
COPY --from=build /usr/local/bin/shairport-sync /usr/local/bin/shairport-sync

COPY start.sh /start.sh
COPY shairport-sync.conf.tmpl /shairport-sync.conf.tmpl

ENV AIRPLAY_NAME Docker

ENTRYPOINT [ "/start.sh" ]
