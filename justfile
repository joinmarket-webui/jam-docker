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

# size of the docker images
[group("docker")]
docker-image-size:
    @docker images "joinmarket-webui/jam-*"
