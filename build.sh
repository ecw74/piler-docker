#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

PILER_VERSION="1.3.11"
MAILPILER_GIT_TAG="5c2ceb178b4df0ca4a3ac1b41fb380715af4fb7c"
IMAGE_NAME="ecw74/piler"
VCS_REF=$(git rev-parse --short HEAD)


BUILDKIT_PROGRESS=plain DOCKER_BUILDKIT=1 docker build --rm \
    --build-arg VCS_REF=$VCS_REF \
    --build-arg MAILPILER_GIT_TAG=$MAILPILER_GIT_TAG \
    -t $IMAGE_NAME:$PILER_VERSION piler/
