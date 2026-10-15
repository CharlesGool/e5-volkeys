# 音量键功能 · Volume keys

音量键改为调亮度或亮屏熄屏

*Volume keys for brightness or screen power*

容悦 E5（OpenWrt）信息屏应用。当前版本 **v1.2**，应用 ID `volkeys`。

## 截图

<img src="screenshots/volkeys.png" alt="音量键功能" width="320">

设备屏幕上的音量键功能页面：选择调节屏幕亮度、亮屏 / 熄屏或调节音量。

## 安装

1. 下载 [`releases/volkeys-v1.2.tar.gz`](releases/volkeys-v1.2.tar.gz)。
2. 在信息屏的「应用管理」中安装（LuCI：服务 → 信息屏应用 → 应用管理）。
3. 安装后文件位于设备上的 `/etc/e5-infoscreen/plugins/volkeys/`。

## 设置

加粗为默认值。

- 音量键（Volume keys）：**调节屏幕亮度**；亮屏 / 熄屏（同电源键）；调节音量（原样）
- 每按一次亮度变化（Brightness per press）：5–25 %，默认 10
- 最低亮度再按音量 − 关闭屏幕（Volume − at lowest cuts the screen off）：默认开  
  <sub>关闭后任何按键、触摸、短信都不亮屏，只有音量 + 恢复</sub>

## 源码

`volkeys/` 是当前版本安装包解压后的内容：

- [`backend.uc`](volkeys/backend.uc)
- [`index.html`](volkeys/index.html)
- [`manifest.json`](volkeys/manifest.json)
- [`patch.js`](volkeys/patch.js)

## 版本

- [v1.2](releases/volkeys-v1.2.tar.gz)（当前）
- [v1.1](releases/volkeys-v1.1.tar.gz)
- [v1.0](releases/volkeys-v1.0.tar.gz)
