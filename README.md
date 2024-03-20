# openwrt 中 1Panel 安装包

[1Panel](https://github.com/1Panel-dev/1Panel) 是一个现代化、开源的 Linux 服务器运维管理面板。

该项目为 1Panel 在openwrt环境下安装包相关内容，包含了 1Panel 的安装脚本及默认配置文件等。

本仓库修改1panel安装脚本，以匹配openwrt的运行，安装脚本默认下载1panel 官方安装包后，替换1pctl、install.sh文件，并在openwrt /etc/init.d/目录下生成1panel 自启动文件。

## 使用前须知

openwrt固件版本繁多，openwrt官方原版及Imortalwrt版本等支持在线升级安装软件包的固件，请先安装docker，docker-compose；不具备docker且不支持在线安装docker的固件，在未更换固件的情况夏，可直接放弃安装尝试；

## 执行如下命令在openwrt中一键安装 1Panel:
```sh
curl -sSL https://raw.githubusercontent.com/gcsong023/wrt_installer/wrt_1panel/quick_start.sh -o quick_start.sh && bash quick_start.sh
```
### 可能存在的问题：
1、-ash: curl: not found  bash: not found 出现这类问题的原因是，所使用的openwrt版本，未安装curl  bash 命令 ；

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
#### 不能使用的1panel功能

*1、快照功能、备份功能: 在openwrt 中执行tar命令相关的功能，均不能正常执行，会报错;*

*2、supervisor fail2ban firewall 相关功能暂不能正常使用；*

*3、可能还有其他暂不能正常使用的功能；*

### 问题反馈

如果您在使用过程中遇到什么问题，或有进一步的需求需要反馈，请提交 GitHub Issue 到 [1Panel 项目的主仓库](https://github.com/1Panel-dev/1Panel/issues)
