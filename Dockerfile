# Build environment for the assembler, linker and emulator.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        g++ \
        make \
        flex \
        bison \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /ss
