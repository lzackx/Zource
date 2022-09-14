#!/bin/zsh

set -x
set -e

podman machine start

source ./rerun.sh

source ./service.sh
