# openwrt 中 1Panel 安装包
本仓库修改1panel安装脚本，以匹配openwrt的运行。
使用前，openwrt固件中的docker及docker-compose版本，需要满足1panel运行条件

[1Panel](https://github.com/1Panel-dev/1Panel) 是一个现代化、开源的 Linux 服务器运维管理面板。

该项目为 1Panel 安装包相关内容，包含了 1Panel 的安装脚本及默认配置文件等。

## 执行如下命令在openwrt中一键安装 1Panel:

curl -sSL https://raw.githubusercontent.com/gcsong023/wrt_installer/wrt_1panel/quick_start.sh -o quick_start.sh && bash quick_start.sh

### 问题反馈

如果您在使用过程中遇到什么问题，或有进一步的需求需要反馈，请提交 GitHub Issue 到 [1Panel 项目的主仓库](https://github.com/1Panel-dev/1Panel/issues)
