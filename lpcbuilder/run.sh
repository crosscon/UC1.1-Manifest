#!/bin/bash
set -e

# Get absolute path to current directory
HOST_PWD=$(pwd)

# Dynamically find repo root (assumes you're inside a Git repo)
REPO_ROOT=$(git rev-parse --show-toplevel)

# Get relative path from repo root to current directory
RELATIVE_PATH=${HOST_PWD#"$REPO_ROOT"}

# Image name
IMAGE=lpcbuilderimage

# Docker volume mount — mount repo root
DOCKER_FLAGS=(
    --rm
    --privileged
    -v "$REPO_ROOT:$REPO_ROOT"
    -v /dev:/dev 
    -w "$REPO_ROOT/$RELATIVE_PATH"
)

# Optional: debugging info
echo "[DEBUG] CMD inside container: $@"
echo "[DEBUG] Mounting $REPO_ROOT -> $REPO_ROOT"
echo "[DEBUG] Working dir inside container: $REPO_ROOT/$RELATIVE_PATH"

# Run interactive shell if no arguments passed
if [ $# -eq 0 ]; then
    docker run -it "${DOCKER_FLAGS[@]}" "$IMAGE" /bin/bash
else
    docker run -it "${DOCKER_FLAGS[@]}" "$IMAGE" "$@"
fi
