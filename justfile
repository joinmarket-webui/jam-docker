# This justfile requires https://github.com/casey/just

# Load environment variables from `.env` file.
set dotenv-load
# Fail the script if the env file is not found.
set dotenv-required

project_dir := justfile_directory()

# print available targets
[group("project-agnostic")]
default:
    @just --list --justfile {{justfile()}}

# evaluate and print all just variables
[group("project-agnostic")]
evaluate:
    @just --evaluate

# print system information such as OS and architecture
[group("project-agnostic")]
system-info:
    @echo "architecture: {{arch()}}"
    @echo "os: {{os()}}"
    @echo "os family: {{os_family()}}"

# create "ui" docker image
[group("docker")]
docker-build-ui jam_repo_ref=env('JAM_REPO_REF') *args='':
    @echo "Creating 'ui' docker image ..."
    @docker build {{args}} \
        --label "local" \
        --build-arg JAM_REPO_REF={{jam_repo_ref}} \
        --tag "joinmarket-webui/jam-ui-only" ./ui-only

# create "ui" docker image from master
[group("docker")]
docker-build-ui-master *args='':
    @just docker-build-ui master \
        --build-arg SKIP_RELEASE_VERIFICATION=true \
        {{args}}

# create "standalone-ng" docker image (joinmarket-ng backend)
[group("docker")]
docker-build-standalone-ng jam_repo_ref=env('JAM_REPO_REF') jm_ng_repo_ref=env('JM_NG_REPO_REF') *args='':
    @echo "Creating 'standalone-ng' docker image ..."
    @docker buildx build {{args}} \
        --label "local" \
        --build-arg JAM_REPO_REF={{jam_repo_ref}} \
        --build-arg JM_NG_REPO_REF={{jm_ng_repo_ref}} \
        --tag "joinmarket-webui/jam-standalone-ng" ./standalone-ng

# create "standalone-ng" docker image from main (skip release verification)
[group("docker")]
docker-build-standalone-ng-main *args='':
    @just docker-build-standalone-ng master main \
        --build-arg SKIP_RELEASE_VERIFICATION=true \
        {{args}}

# run shell in "standalone-ng" docker container
[group("docker")]
docker-run-shell-standalone-ng:
    @docker run --rm --entrypoint="/bin/bash" -it joinmarket-webui/jam-standalone-ng

[group("docker")]
docker-lint-standalone-ng:
    @docker run --rm -i hadolint/hadolint:latest-alpine hadolint "$@" - < "./standalone-ng/Dockerfile"

# create "contrib/dinit" docker image
[group("docker")]
docker-build-contrib-dinit *args='':
    @echo "Creating 'dinit' docker image ..."
    @docker buildx build {{args}} \
        --label "local" \
        --tag "joinmarket-webui/jam-contrib-dinit" ./contrib/dinit

# size of the docker images
[group("docker")]
docker-image-size:
    @docker images "joinmarket-webui/jam-*"

[group("docker")]
docker-lint-ui-only:
    @docker run --rm -i hadolint/hadolint:latest-alpine hadolint "$@" - < "./ui-only/Dockerfile"

# push docker image manually
[group("docker")]
docker-push username image_name tag:
    # this exists in case ci actoin fails (e.g. because if resource exhaustion)
    @docker login --username {{username}} --password-stdin ghcr.io
    @docker push ghcr.io/{{image_name}}:{{tag}}

[group("development")]
probe-directory-node onion_url port='5222':
    @curl --verbose --proxy socks5h://localhost:9050 {{onion_url}}:{{port}}
