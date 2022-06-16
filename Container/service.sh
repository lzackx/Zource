#!/bin/bash

set -x
set -e

podman container exec -it zource /bin/bash -ilex /root/work/zource.start.sh
