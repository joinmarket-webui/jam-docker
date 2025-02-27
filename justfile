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
docker-build-ui:
    @echo "Creating 'ui' docker image ..."
    @docker build --label "local" \
        --build-arg JAM_REPO_REF=$JAM_REPO_REF \
        --tag "joinmarket-webui/jam-ui-only" ./ui-only

# create "standalone" docker image
[group("docker")]
docker-build-standalone:
    @echo "Creating 'standalone' docker image ..."
    @docker build --label "local" \
        --build-arg JAM_REPO_REF=$JAM_REPO_REF \
        --build-arg JM_SERVER_REPO_REF=$JM_SERVER_REPO_REF \
        --tag "joinmarket-webui/jam-standalone" ./standalone

# run shell in "standalone" docker container
[group("docker")]
docker-run-shell-standalone:
    @docker run --rm --entrypoint="/bin/bash" -it joinmarket-webui/jam-standalone

# size of the docker images
[group("docker")]
docker-image-size:
    @docker images "joinmarket-webui/jam-*"

[group("development")]
extract-default-config:
    @echo "Starting docker container to extract default configuration..."
    @docker run --rm --detach --entrypoint="/bin/bash" --name "jam-dev-create-config" -t joinmarket-webui/jam-standalone
    @docker exec -it jam-dev-create-config python3 /src/scripts/jmwalletd.py || :
    @echo "Writing config to {{project_dir}}/standalone/default.cfg.."
    @docker exec -it jam-dev-create-config cat /root/.joinmarket/joinmarket.cfg > standalone/default.cfg
    @echo "Stopping docker container..."
    @docker stop jam-dev-create-config
