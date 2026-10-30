FROM docker.io/library/ubuntu:24.04

# Same base libraries as aptos-debugger (the extractor links no database code)
RUN apt-get update && apt-get install -y \
libjemalloc2 \
libssl3 \
libstdc++6 \
zlib1g \
ca-certificates \
patchelf \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /app

ARG BINARY_PATH=target/release
COPY --chmod=0755 ${BINARY_PATH}/aptos-waypoint-extractor /usr/local/bin/aptos-waypoint-extractor
RUN patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 /usr/local/bin/aptos-waypoint-extractor

# Add build info
ARG BUILD_DATE
ENV BUILD_DATE=${BUILD_DATE}
ARG GIT_TAG
ENV GIT_TAG=${GIT_TAG}
ARG GIT_BRANCH
ENV GIT_BRANCH=${GIT_BRANCH}
ARG GIT_SHA
ENV GIT_SHA=${GIT_SHA}

# Verify the binary can be executed
RUN LD_LIBRARY_PATH=/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu /usr/local/bin/aptos-waypoint-extractor --help

ENTRYPOINT ["/usr/local/bin/aptos-waypoint-extractor"]
CMD ["--help"]
