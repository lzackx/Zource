#!/bin/bash

set -x
set -e

podman run --restart unless-stopped --name zource -itd -p 10022:22 -p 9687:9687 zource.image /bin/bash
