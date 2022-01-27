#!/usr/bin/env bash
set -e

#-----------------------------------------------------------
# STANDALONE

STANDALONE_UI_IMAGE_NAME='joinmarket-webui-standalone'
#STANDALONE_UI_IMAGE_TAG=$(git rev-parse HEAD)
STANDALONE_UI_IMAGE_TAG='latest'

echo "Building docker image ${STANDALONE_UI_IMAGE_NAME}:${STANDALONE_UI_IMAGE_TAG}"

docker build --tag "${STANDALONE_UI_IMAGE_NAME}:${STANDALONE_UI_IMAGE_TAG}" ./standalone
# and run with: docker run -it --rm -p "8080:80" joinmarket-webui-standalone:...
