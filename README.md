# Installation playbook

## How to use ?

    $> docker run \
    --rm \
    -ti \
    -v /path/to/.ssh/id_rsa:/root/.ssh/id_rsa:ro \
    -v $(pwd):/app \
    -w=/app \
    -e DOCKER_USERNAME=docker.io_registry_username \
    -e DOCKER_PASSWORD=docker.io_registry_password \
    -e CANONICAL_KEY=canonical_livepatch_key \
    -e PARSEC_PEER_ID=parsec_peer_id \
    -e PIHOLE_PASSWORD=some_password \
    shokohsc/ansible -i inventory -K install.yml
