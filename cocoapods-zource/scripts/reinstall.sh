#! /bin/bash

set -x
set -e

PATH_FOR_DIRECTORY_CURRENT=$(
    cd "$(dirname "$0")"
    pwd
)

cd $PATH_FOR_DIRECTORY_CURRENT/..

gem uninstall cocoapods-zource

gem install ./*.gem
