# This justfile requires https://github.com/casey/just

# Load environment variables from `.env` file.
set dotenv-load
# Fail the script if the env file is not found.
set dotenv-required

project_dir := justfile_directory()

regtest_bitcoin_container_name := 'jam_docker_bitcoind'
regtest_bitcoin_container_rpcport := '43782'

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
        --tag "joinmarket-webui/jam-local-ui-only" ./ui-only

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
        --tag "joinmarket-webui/jam-local-standalone-ng" ./standalone-ng

# create "standalone-ng" docker image from main (skip release verification)
[group("docker")]
docker-build-standalone-ng-main *args='':
    @just docker-build-standalone-ng master main \
        --build-arg SKIP_RELEASE_VERIFICATION=true \
        {{args}}

# run shell in "standalone-ng" docker container
[group("docker")]
docker-run-shell-standalone-ng:
    @docker run --rm --entrypoint="/bin/bash" -it joinmarket-webui/jam-local-standalone-ng

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


[group("regtest")]
regtest-build *args='':
    @docker compose build --pull {{args}}

[group("regtest")]
regtest-up *args='':
    @docker compose up {{args}}

[group("regtest")]
regtest-down *args='':
    @docker compose down {{args}}

[group("regtest")]
regtest-clear *args='':
    @just regtest-down --volumes --remove-orphans {{args}}

[group("regtest")]
regtest-logs *args='':
    @docker compose logs --follow

[group("regtest")]
regtest-ps *args='':
    @docker compose ps {{args}}

# Execute a bitcoin-cli command
[group("regtest")]
regtest-bitcoind-exec +command:
  @docker exec -t {{regtest_bitcoin_container_name}} bitcoin-cli -datadir=/home/bitcoin/data -regtest -rpcport={{regtest_bitcoin_container_rpcport}} {{command}}

# Mine to a specified address and return the block hashes.
[group("regtest")]
regtest-mine blocks='1' address='bcrt1q6rz28mcfaxtmd6v789l9rrlrusdprr9pz3cppk':
  @echo "{{address}}"
  @just regtest-bitcoind-exec generatetoaddress "{{blocks}}" "{{address}}"
  @echo "Note: Coinbase outputs need 100 confirmations before they show up in the user interface."

[group("mainnet")]
mainnet-up *args='':
    @docker compose --file docker-compose.mainnet.yml up {{args}}

[group("mainnet")]
mainnet-down *args='':
    @docker compose --file docker-compose.mainnet.yml down {{args}}

[group("mainnet")]
mainnet-clear *args='':
    @just mainnet-down --volumes --remove-orphans {{args}}
