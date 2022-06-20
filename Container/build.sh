#!/bin/bash

set -x
set -e

podman build -t zource.image -f ./zource.image.containerfile
