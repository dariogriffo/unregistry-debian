#!/bin/bash
unregistry_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$unregistry_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <unregistry_version> <build_version> [architecture]"
    echo "Example: $0 0.4.3 1 arm64"
    echo "Example: $0 0.4.3 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, all"
    exit 1
fi

# unregistry is written in Go and is not published as a release binary, so it
# is cross-compiled from the tag being packaged. GOARCH is the only difference
# between architectures.
get_goarch() {
    case "$1" in
        "amd64") echo "amd64" ;;
        "arm64") echo "arm64" ;;
        *)       echo "" ;;
    esac
}

declare -a DISTS=("jammy" "noble" "questing" "resolute")

build_architecture() {
    local build_arch=$1
    local goarch

    goarch=$(get_goarch "$build_arch")
    if [ -z "$goarch" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64"
        return 1
    fi

    echo "Building unregistry for architecture: $build_arch (GOARCH=$goarch)"

    for dist in "${DISTS[@]}"; do
        FULL_VERSION="$unregistry_VERSION-${BUILD_VERSION}~${dist}_${build_arch}_ubu"
        echo "  Building $FULL_VERSION"

        if ! docker build . -f uDockerfile.ubu -t "unregistry-ubuntu-$dist-$build_arch" \
            --build-arg UBUNTU_DIST="$dist" \
            --build-arg unregistry_VERSION="$unregistry_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg GOARCH="$goarch"; then
            echo "❌ Failed to build unregistry image for $dist on $build_arch"
            return 1
        fi

        id="$(docker create "unregistry-ubuntu-$dist-$build_arch")"
        if ! docker cp "$id:/unregistry_$FULL_VERSION.deb" - > "./unregistry_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract unregistry .deb for $dist on $build_arch"
            return 1
        fi
        if ! tar -xf "./unregistry_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract unregistry .deb contents for $dist on $build_arch"
            return 1
        fi
    done

    echo "✅ Successfully built unregistry for $build_arch"
    return 0
}

# docker-pussh is a bash script, so one Architecture: all package per suite
# covers every architecture.
build_docker_pussh() {
    for dist in "${DISTS[@]}"; do
        FULL_VERSION="$unregistry_VERSION-${BUILD_VERSION}~${dist}_all_ubu"
        echo "  Building docker-pussh $FULL_VERSION"

        if ! docker build . -f pDockerfile.ubu -t "docker-pussh-ubuntu-$dist" \
            --build-arg UBUNTU_DIST="$dist" \
            --build-arg unregistry_VERSION="$unregistry_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION"; then
            echo "❌ Failed to build docker-pussh image for $dist"
            return 1
        fi

        id="$(docker create "docker-pussh-ubuntu-$dist")"
        if ! docker cp "$id:/docker-pussh_$FULL_VERSION.deb" - > "./docker-pussh_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract docker-pussh .deb for $dist"
            return 1
        fi
        if ! tar -xf "./docker-pussh_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract docker-pussh .deb contents for $dist"
            return 1
        fi
    done
    echo "✅ Successfully built docker-pussh"
}

if [ "$ARCH" = "all" ]; then
    echo "🚀 Building unregistry $unregistry_VERSION-$BUILD_VERSION for all supported architectures..."
    echo ""

    ARCHITECTURES=("amd64" "arm64")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done
else
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi

if ! build_docker_pussh; then
    exit 1
fi

echo "🎉 Done. Generated packages:"
ls -la unregistry_*.deb docker-pussh_*.deb
