# check=skip=InvalidDefaultArgInFrom
# Builds the OpenCV .deb in a clean container - use ./docker_build.sh instead of calling this directly.

# no default on purpose: docker_build.sh always passes it
ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS deps

ARG NVIDIA_REPO
ARG WITH_CUDA=on
ARG CUDA_VERSION

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# libmkl-dev is in multiverse (enabled in Ubuntu images) / non-free (not enabled in Debian images)
RUN if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
        sed -i 's/^Components: main$/Components: main contrib non-free/' /etc/apt/sources.list.d/debian.sources; \
    fi \
    && apt-get update \
    && apt-get install -y --no-install-recommends build-essential ca-certificates curl devscripts equivs fakeroot

# compiler and libraries only - the full cuda-toolkit meta package pulls in the Nsight GUIs
RUN if [ "$WITH_CUDA" = "on" ]; then \
        curl -fsSL -o /tmp/cuda-keyring.deb "https://developer.download.nvidia.com/compute/cuda/repos/${NVIDIA_REPO}/x86_64/cuda-keyring_1.1-1_all.deb" \
        && dpkg -i /tmp/cuda-keyring.deb \
        && rm /tmp/cuda-keyring.deb \
        && apt-get update \
        && apt-get install -y --no-install-recommends \
            "cuda-nvcc-${CUDA_VERSION/./-}" \
            "cuda-libraries-dev-${CUDA_VERSION/./-}" \
            libcudnn9-dev-cuda-13; \
    fi
ENV PATH=/usr/local/cuda-${CUDA_VERSION}/bin:${PATH}

COPY debian/control /tmp/deps/debian/control
RUN cd /tmp/deps \
    && apt-get update \
    && mk-build-deps --install --remove --tool "apt-get -y --no-install-recommends" debian/control \
    && rm -rf /tmp/deps


FROM deps AS build

ARG WITH_CUDA=on
ARG CUDA_VERSION
ARG OPENCV_VERSION=5.0.0
ARG USE_MKL=on
ARG WITH_JAVA=off
ARG WITH_PYTHON=on
ARG WITH_EXAMPLES=off
ARG WITH_DOCS=off

WORKDIR /src
COPY build_package.sh ./
COPY debian ./debian
COPY patches ./patches
# BuildKit clips a step's output after 2 MiB, so only progress goes to the console; the full
# log is exported next to the .deb. If the build fails, the first errors (with -j the actual
# error is usually far from the end of the log) and the end of the log are shown instead.
RUN bash ./build_package.sh --opencv-version "$OPENCV_VERSION" --with-cuda "$WITH_CUDA" ${CUDA_VERSION:+--cuda-version "$CUDA_VERSION"} \
        --use-mkl "$USE_MKL" --with-java "$WITH_JAVA" --with-python "$WITH_PYTHON" \
        --with-examples "$WITH_EXAMPLES" --with-docs "$WITH_DOCS" 2>&1 \
        | tee /src/build.log | (grep --line-buffered -E '^\[ *[0-9]+%\]|^Downloading|^Building package|dpkg-deb: building' || true) \
    || { echo "Build failed - first errors:"; grep -n -B 3 -A 12 -m 10 -E ' error:|: fatal error|\*\*\* \[|^CMake Error|undefined reference' /src/build.log; \
         echo "Build failed - last 100 lines of the log:"; tail -n 100 /src/build.log; exit 1; }


FROM scratch AS export
COPY --from=build /src/build/*.deb /src/build.log /
