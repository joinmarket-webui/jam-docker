#!/usr/bin/env bash

#-----------------------------------------------------------
# UMBREL

UMBREL_UI_IMAGE_NAME='joinmarket-webui-umbrel'
#UMBREL_UI_IMAGE_TAG=$(git rev-parse HEAD)
UMBREL_UI_IMAGE_TAG='dev'

echo "Building docker image ${UMBREL_UI_IMAGE_NAME}:${UMBREL_UI_IMAGE_TAG}"

docker build --tag "${UMBREL_UI_IMAGE_NAME}:${UMBREL_UI_IMAGE_TAG}" --file Dockerfile.umbrel .
# and run with: docker run -it --rm -p "8080:80" joinmarket-webui-umbrel:...

#-----------------------------------------------------------
# DEV

DEV_UI_IMAGE_NAME='joinmarket-webui-dev'
#UMBREL_UI_IMAGE_TAG=$(git rev-parse HEAD)
DEV_UI_IMAGE_TAG='dev'

echo "Building docker image ${DEV_UI_IMAGE_NAME}:${DEV_UI_IMAGE_TAG}"

docker build --tag "${DEV_UI_IMAGE_NAME}:${DEV_UI_IMAGE_TAG}" --file Dockerfile.dev .
# and run with: docker run -it --rm -p "3000:3000" joinmarket-webui-dev:...
