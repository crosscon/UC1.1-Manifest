FROM ubuntu:24.04

ENV WORKDIR_PATH=/work
ENV DEBIAN_FRONTEND=nointeractive

WORKDIR $WORKDIR_PATH

SHELL ["/bin/bash", "-c"]

ENV PATH=$PATH:/root/.local/bin

COPY MCUXPRESSO-SECURE-PROVISIONING-V25.03-AMD64-UBUNTU24.deb $WORKDIR_PATH

RUN apt update && \
    apt install -y --no-install-recommends \
    libhidapi-dev \
    libusb-1.0-0 \
    openssl \
    libsdl2-2.0-0 \
    libpcre2-32-0 \
    libpcsclite1 \
    pcscd \
    pcsc-tools \
    libgtk-3-0 \
    libx11-6 \
    libxext6 \
    libsm6 \
    libxrender1 \
    libglib2.0-0 \
    libgdk-pixbuf2.0-0 \
    libpango-1.0-0 \
    libatk1.0-0 \
    libxcb1 \
    libdbus-1-3 \
    libxtst6 \
    media-types \
    mailcap \
    shared-mime-info \
    && apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt install $WORKDIR_PATH/MCUXPRESSO-SECURE-PROVISIONING-V25.03-AMD64-UBUNTU24.deb

ENV PATH=$PATH:/opt/nxp/MCUX_Provi_25.03/bin/
