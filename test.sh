#!/usr/bin/env bash

# Simple test script to run the tests in docker

# Error on any non-zero command, and print the commands as they're run
set -ex

# Make sure we have the docker utility
if ! command -v docker; then
    echo "🐋 Please install docker first 🐋"
    exit 1
fi

# Set the docker image name to default to repo basename
DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-$(basename -s .git "$(git remote --verbose | awk 'NR==1 { print tolower($2) }')")}

# build the docker image
function build_image() {
    DOCKER_BUILDKIT=1 docker build -t "$DOCKER_IMAGE_NAME" --build-arg "UID=$(id -u)" -f Dockerfile .
}

# by default, run tox
RUN_JOB=${RUN_JOB:-tox}
case $RUN_JOB in
    tox)
        build_image
        # execute tox in the docker container. don't run in parallel; the test
        # script writes files to an in-tree location, so run serially to avoid
        # clobbering during the tests
        docker run --rm -v "$(pwd)":/workspace -t "$DOCKER_IMAGE_NAME" bash -c "tox $TOX_ARGS"

        ./tools/test-nonexistent-file-cmd.sh
    ;;
    quick-test)
        build_image
        # single quick test
        docker run --rm -v "$(pwd)":/workspace -t "$DOCKER_IMAGE_NAME" bash -c "python3 tests/compare.py"
    ;;
    rst2man)
        build_image
        # build man page from README
        docker run --rm -v "$(pwd)":/workspace -t "$DOCKER_IMAGE_NAME" bash tools/gen-manpage.sh archived/README dtrx.1
    ;;
    windows)
        # verify that installing on windows fails
        docker run --rm -v "$(pwd)":/workdir -t tobix/pywine:3.9 bash -c 'wine pip install /workdir' | tee /dev/stderr | \
            grep -q 'ERROR: No matching distribution found for platform==unsupported' || echo "ERROR: pip install should fail!"
    ;;
esac
