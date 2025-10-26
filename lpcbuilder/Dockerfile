FROM ubuntu:22.04

# Set environment variables
ENV WORKDIR_PATH=/workdir
ENV DEBIAN_FRONTEND=noninteractive
ENV TOOLCHAIN_URL=https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-x86_64-arm-none-eabi.tar.xz
ENV TOOLCHAIN_DIR=/opt/arm-toolchain

WORKDIR $WORKDIR_PATH

SHELL ["/bin/bash", "-c"]

# Install dependencies
RUN apt-get update && apt-get install -y \
    vim \
    git \
    wget \
    tar \
    xz-utils \
    build-essential \
    libstdc++6 \
    dfu-util \
    libusb-1.0-0-dev \
    libncursesw5 \
    usbutils \
    python3-tk \
    tio \
    && apt clean && rm -rf /var/lib/apt/lists/*

ENV PATH=$PATH:/root/.local/bin

# Download and extract Arm GNU Toolchain
RUN mkdir -p $TOOLCHAIN_DIR && \
    wget -q $TOOLCHAIN_URL -O /tmp/toolchain.tar.xz && \
    tar -xf /tmp/toolchain.tar.xz -C $TOOLCHAIN_DIR --strip-components=1 && \
    rm /tmp/toolchain.tar.xz

# Add toolchain to PATH
ENV PATH="$TOOLCHAIN_DIR/bin:$PATH"

# Verify toolchain installation
RUN arm-none-eabi-gcc --version

# Install LinkServer
# COPY files/MCU-Link_3.153.deb $WORKDIR_PATH/LinkServer/
# COPY files/LPCScrypt_2.1.3.deb $WORKDIR_PATH/LinkServer/
# COPY files/LinkServer_24.12.21.x86_64.deb $WORKDIR_PATH/LinkServer/

RUN dpkg -i $WORKDIR_PATH/LinkServer/LPCScrypt_Patched_2.1.3.deb && \
    dpkg -i $WORKDIR_PATH/LinkServer/MCU-Link_Patched_3.153.deb && \
    dpkg -i $WORKDIR_PATH/LinkServer/LinkServer_Patched_24.12.21.x86_64.deb

ENV PATH=$PATH:/usr/local/LinkServer/
ENV PATH=$PATH:/usr/local/LinkServer/lpcscrypt/bin

CMD ["/bin/bash"]
