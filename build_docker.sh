#!/usr/bin/env bash
set -e

#-----------------------------------------------------------
# UI_ONLY
UI_ONLY_IMAGE_NAME='joinmarket-webui-ui-only'
#STANDALONE_UI_IMAGE_TAG=$(git rev-parse HEAD)
UI_ONLY_IMAGE_TAG='latest'

echo "Building docker image ${UI_ONLY_IMAGE_NAME}:${UI_ONLY_IMAGE_TAG}"

docker build --tag "${UI_ONLY_IMAGE_NAME}:${UI_ONLY_IMAGE_TAG}" ./ui-only
# and run with: docker run -it --rm -p "8080:80" joinmarket-webui-ui-only:...

# STANDALONE
STANDALONE_UI_IMAGE_NAME='joinmarket-webui-standalone'
#STANDALONE_UI_IMAGE_TAG=$(git rev-parse HEAD)
STANDALONE_UI_IMAGE_TAG='latest'

echo "Building docker image ${STANDALONE_UI_IMAGE_NAME}:${STANDALONE_UI_IMAGE_TAG}"

docker build --tag "${STANDALONE_UI_IMAGE_NAME}:${STANDALONE_UI_IMAGE_TAG}" ./standalone
# and run with: docker run -it --rm -p "8080:80" joinmarket-webui-standalone:...

