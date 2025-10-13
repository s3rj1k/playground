# Build k0s without embedded binaries
#
# Build for ARM64:
#   docker buildx build --platform linux/arm64 -f k0s-no-embedded-binaries.Dockerfile -t k0s --load .
#
# Build for AMD64:
#   docker buildx build --platform linux/amd64 -f k0s-no-embedded-binaries.Dockerfile -t k0s --load .
#
# Extract the binary:
#   docker create --name k0s-tmp k0s
#   docker cp k0s-tmp:/usr/local/bin/k0s ./k0s
#   docker rm k0s-tmp

FROM docker.io/library/golang:alpine AS builder

RUN apk add --no-cache make git gcc musl-dev binutils-gold

ARG K0S_REPO=https://github.com/k0sproject/k0s.git
ARG K0S_VERSION=release-1.34

WORKDIR /workspace

RUN git clone --depth 1 --branch ${K0S_VERSION} ${K0S_REPO} . || \
    (git clone ${K0S_REPO} . && git checkout ${K0S_VERSION})

RUN go mod download

RUN EMBEDDED_BINS_BUILDMODE=none make --touch codegen

RUN echo "VERSION=$(git describe --tags 2>/dev/null || echo 'v0.0.0-dev')" > /.env
RUN echo "BUILD_TAGS=osusergo,noembedbins" >> /.env
RUN echo 'LD_FLAGS="-w -s -extldflags=-static"' >> /.env
RUN sh -c '. /.env && echo "LD_FLAGS=\"$LD_FLAGS -X github.com/k0sproject/k0s/pkg/build.Version=$VERSION\""' >> /.env
RUN echo "CGO_ENABLED=1" >> /.env

RUN set -ex; . /.env; \
    go build -trimpath -tags="$BUILD_TAGS" -buildvcs=false -ldflags="$LD_FLAGS" -o k0s main.go;

# Ensure binary is statically linked
FROM busybox:latest AS verify
COPY --from=builder /workspace/k0s /tmp/k0s
RUN /tmp/k0s version

FROM alpine:latest AS runtime
RUN apk add --no-cache ca-certificates
WORKDIR /
COPY --from=verify /tmp/k0s /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/k0s"]
