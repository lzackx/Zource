# Zource

该项目由2个部分组成.
1. 存储二进制化库的容器化的存储服务, 于`Container`内.
2. 基于CocoaPods插件机制开发的, 于`cocoapods-zource`内.

----

## 1. Container

`zource.image.containerfile`是容器镜像构建文件, 内部可查看构建环境的相关过程.

容器内的默认服务端口: 9687

服务请求示例:

获取组件信息：
```
curl http://localhost:8080/frameworks/PodA
> {"PodA":["0.2.4"]}

curl http://localhost:8080/frameworks
> {"TDFCoreProtocol":["1.2.4","1.2.5"],"PodA":["0.2.4-binary","0.2.4"]}
```

推送组件 zip 包：
```
curl http://localhost:8080/frameworks -F "name=PodA" -F "version=0.2.4" -F
  "annotate=Mergebranch'release/0.2.3'into'master'" -F
  "file=@/Users/songruiwang/Work/TDF/cocoapods-tdfire-binary/example/PodA/PodA.framework.zip"
  -F "sha=7bf2c8f3ce1184580abfea7129d1648e499d080e"
> 保存成功 PodA (0.2.4)
```

获取组件 zip 包：
```
curl http://localhost:8080/frameworks/PodA/0.2.4/zip > PodA.framework.zip
```

删除组件：
```
curl -X 'DELETE' http://localhost:8080/frameworks/PodA/0.2.4 -O -J
```

zip 包存储在 server 根目录的 `.zource` 目录下

----

## 2. cocoapods-zource

cocoapods-zource is a helper aim to binarize iOS dependencies.

### Installation

``` Ruby
gem install cocoapods-zource
```

### Usage

#### 1. init

To init the helper, use command as follow:

``` Ruby
pod zource init
```

It will create a `zource.yaml` file in the working directory for configuration.

``` YAML
---
repo_privacy_urls:
- ssh://xxx/xxx.git
- ssh://xxx/xxx.git
repo_binary_name: xxx.static
repo_binary_url: ssh://xxx/xxx.static.git
binary_url: http://xxx:9687
```

#### 2. install & update

Load `zource.podfile` file, whose behavior is as same as Podfile but with higher priority.

To do so, use command as follow:

``` Shell
pod zource install --clean-install
# or
pod zource update --clean-install
```

It will load `zource.podfile`, which should be located at the same path of Podfile, merge dependencies, and install/update the dependencies.

#### 3. make & push
 
 To make or push binary xcframework files for the project, use command as follow:

 ```Shell
 # make
pod zource make
 # or
pod zource make \
    --aggregation \
    --update-dependency \
    --configuration=Release \
    --remake \
    --not-arm64-simulator \
    --verbose

# push
pod zource push
 ```

 If you want to take advantage of more features, read the output of `--help` parameter.

 Enjoy the efficiency!