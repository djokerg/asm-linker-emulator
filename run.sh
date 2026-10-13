#!/usr/bin/env sh
# Build the toolchain and run example programs inside Docker.
#
#   ./run.sh                 assemble, link and run the hello example
#   ./run.sh level-a         run another example (hello, level-a, level-b)
#   ./run.sh test            run all examples headless and report PASS/FAIL
#   ./run.sh shell           open a shell in the build container
set -e

IMAGE=system-software-toolchain
cd "$(dirname "$0")"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Building toolchain image (one time)..."
    docker build -t "$IMAGE" .
fi

TTY=""
[ -t 0 ] && TTY="-it"

case "${1:-hello}" in
    test)  exec docker run --rm -v "$PWD":/ss "$IMAGE" scripts/run-tests.sh ;;
    shell) exec docker run --rm $TTY -v "$PWD":/ss "$IMAGE" bash ;;
    *)     exec docker run --rm $TTY -v "$PWD":/ss "$IMAGE" scripts/run-example.sh "${1:-hello}" ;;
esac
