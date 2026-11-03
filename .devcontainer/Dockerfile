FROM mcr.microsoft.com/devcontainers/base:ubuntu

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y \
        ghdl \
        gtkwave \
        make \
        git \
        curl \
        wget \
        build-essential \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

