# openwrt 中 1Panel 安装包

[1Panel](https://github.com/1Panel-dev/1Panel) 是一个现代化、开源的 Linux 服务器运维管理面板。

该项目为 1Panel 在openwrt环境下安装包相关内容，包含了 1Panel 的安装脚本及默认配置文件等。

本仓库修改1panel安装脚本，以匹配openwrt的运行，安装脚本默认下载1panel 官方安装包后，替换1pctl、install.sh文件，并在openwrt /etc/init.d/目录下生成1panel 自启动文件。

另外基于1panel-V1.10.1-lts源码，以修改tar命令适配busybox运行环境，打包生成在openwrt中运行的1panel二进制文件，可到仓库[wrt1panel](https://github.com/gcsong023/wrt1panel)选择、查看；

## 2024-5-25 更新说明

1、更新quick_start.sh、install.sh及1pctl脚本，**适配通用linux系统及busybox环境的安装及使用**；
2、修改install.sh脚本，**支持ImmortalWrt固件在线安装docker与docker-compose**，其他固件未测试；

## 使用前须知

WRT固件版本繁多，官方原版[openwrt](https://openwrt.org)及[Imortalwrt](https://downloads.immortalwrt.org/)版本或其他支持在线升级安装软件包的固件，请先安装docker，docker-compose；不具备docker且不支持在线安装docker的固件，在未更换固件的情况夏，可直接放弃安装尝试；

## 执行如下命令一键安装 1Panel:
```sh
curl -sSL https://raw.githubusercontent.com/gcsong023/wrt_installer/wrt_1panel/quick_start.sh -o quick_start.sh && bash quick_start.sh
```
### x86_amd64平台openwrt可尝试使用以下命令安装基于官方V1.10.1-lts源码的修改版本：
```sh
wget https://github.com/gcsong023/wrt1panel/releases/download/v1.10.9-lts/1panel-v1.10.9-lts-linux-amd64.tar.gz  && tar zxvf 1panel-v1.10.9-lts-linux-amd64.tar.gz && cd 1panel-v1.10.9-lts-linux-amd64 && bash install.sh  
```
### 或尝试替换1panel二进制文件方式
```sh
cp $pwd/1panel /usr/local/bin/1panel # 手动替换1panel二进制文件方式 $pwd 为压缩文件解压后目录。
```
### 可能存在的问题：
*1、-ash: curl: not found  bash: not found 出现这类问题的原因是，所使用的openwrt版本，未安装curl  bash 命令 ；*

#### 解决办法：
运行opkg update ，更新包列表，然后 运行opkg install {package};
```sh
opkg update
opkg install curl
opkg install bash
```
如果使用的固件为openwrt官方原版、immortalWrt版本，请尝试以下命令安装docker；
```sh
opkg update
```
*以下命令会自动安装相关依赖包*
```sh
opkg install luci-i18n-dockerman-zh-cn
```
```sh
opkg update
opkg install docker-compose
```
*需要安装的包比较大（约100M)，如不能安装成功，在非磁盘空间不足的情况下，多运行几次安装命令试试，排除掉网络原因*
*安装成功后，运行以下命令，查看版本号*
```sh
docker --version  # 查看docker 的安装版本；
```
```sh
docker-compose --version # 查看docker-compose版本；
```
*2、/etc/localtime 不存在，导致应用商店安装的应用报错无法启动的问题*
#### 解决办法
```sh
opkg update
opkg install zoneinfo-asia  #安装zoneinfo
service system restart  # 重启system 等同于 /etc/init.d/system restart
```
*3、安装OpenResty 提示 80,443端口被占用的问题*

openwrt 管理界面，默认会使用80，443端口，要么更改OpenResty 使用的端口号，要么更改openwrt web管理界面所使用的端口号。


#### 不能使用的1panel功能

*1、快照功能、备份功能: 在openwrt 中执行tar命令和systemctl 命令相关的功能，均不能正常执行，会报错;20240418补充: 以修改源代码的方式已修复快照功能和备份功能。详见：[releases](https://github.com/gcsong023/wrt1panel/releases)*

*2、supervisor fail2ban firewall ssh管理 相关功能暂不能正常使用；*

*3、可能还有其他暂不能正常使用的功能；*

### 问题反馈

如果您在使用过程中遇到什么问题，或有进一步的需求需要反馈，请提交 GitHub Issue 到 [1Panel 项目的主仓库](https://github.com/1Panel-dev/1Panel/issues),欢迎到[wrt1panel仓库](https://github.com/gcsong023/wrt1panel/issues)交流反馈在openwrt中使用1panel的相关问题。
