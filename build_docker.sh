#!/usr/bin/env bash
set -e

#-----------------------------------------------------------
# UMBREL

UMBREL_UI_IMAGE_NAME='joinmarket-webui-standalone'
#UMBREL_UI_IMAGE_TAG=$(git rev-parse HEAD)
UMBREL_UI_IMAGE_TAG='latest'

echo "Building docker image ${UMBREL_UI_IMAGE_NAME}:${UMBREL_UI_IMAGE_TAG}"

docker build --tag "${UMBREL_UI_IMAGE_NAME}:${UMBREL_UI_IMAGE_TAG}" ./standalone
# and run with: docker run -it --rm -p "8080:80" joinmarket-webui-standalone:...
