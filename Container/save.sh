#!/bin/bash

set -x
set -e

podman container commit -a lZackx zource zource.image

podman save -o ./zource.image --format "oci-archive" zource.image
