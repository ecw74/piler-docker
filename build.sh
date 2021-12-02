#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

PILER_VERSION="1.3.10"
MAILPILER_GIT_TAG="piler-1.3.10"
IMAGE_NAME="ecw74/piler"
VCS_REF=$(git rev-parse --short HEAD)


BUILDKIT_PROGRESS=plain DOCKER_BUILDKIT=1 docker build --rm \
    --build-arg VCS_REF=$VCS_REF \
    --build-arg MAILPILER_GIT_TAG=$MAILPILER_GIT_TAG \
    -t $IMAGE_NAME:$PILER_VERSION piler/
