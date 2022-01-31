#!/usr/bin/env bash
set -e

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

declare -a contexts=(ui-only standalone)

ORG="joinmarket-webui"
IMAGE_NAME_PREFIX="joinmarket-webui-"
IMAGE_TAG='latest'

for context in "${contexts[@]}"
do
    docker_path="${script_dir}/${context}"
    image_name="${ORG}/${IMAGE_NAME_PREFIX}-${context}:${IMAGE_TAG}"
    echo "Building docker image ${image_name}"
	docker build --label "local" --tag "${image_name}" "${docker_path}"
    echo "Built image! Run with: docker run -it --rm -p \"8080:80\" ${image_name}"
done
