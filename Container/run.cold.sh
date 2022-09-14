#!/bin/zsh

set -x
set -e

podman machine start

source ./run.sh

source ./start.sh

source ./service.sh
