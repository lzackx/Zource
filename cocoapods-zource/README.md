# cocoapods-zource

cocoapods-zource is a helper aim to binarize iOS dependencies.

## Installation

``` Ruby
gem install cocoapods-zource
```

## Usage


### 1. init

To init the helper, use command as follow:

``` Ruby
pod zource init
```

It will create a .zourcerc file in the working directory for configuration.

``` JSON
{
    "environment": "development",
    "repo_privacy": "",
    "repo_binary": "",
    "binary_url": "http://localhost:10080/frameworks/%s/%s/zip",
    "binary_file_type": "zip",
}
```

### 2. install & update

Load `zource.podfile` file, whose behavior is as same as Podfile but with higher priority.

To do so, use command as follow:

``` Ruby
pod zource install
# or
pod zource update
```

It will load `zource.podfile`, which should be located at the same path of Podfile, merge dependencies, and install/update the dependencies.