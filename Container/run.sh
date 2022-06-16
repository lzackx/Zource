#!/bin/bash

set -x
set -e

podman run --name zource -itd -p 10022:22 -p 9687:9687 ubuntu:20.04 /bin/bash
