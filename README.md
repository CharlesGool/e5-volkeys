# 音量键功能 · Volume keys

音量键改为调亮度或亮屏熄屏

*Volume keys for brightness or screen power*

容悦 E5（OpenWrt）信息屏应用。当前版本 **v1.3**，应用 ID `volkeys`。

## 截图

<img src="screenshots/volkeys.png" alt="音量键功能" width="320">

设备屏幕上的音量键功能页面：选择调节屏幕亮度、亮屏 / 熄屏或调节音量。

## 安装

1. 下载 [`releases/volkeys-v1.3.tar.gz`](releases/volkeys-v1.3.tar.gz)。
2. 在信息屏的「应用管理」中安装（LuCI：服务 → 信息屏应用 → 应用管理）。
3. 安装后文件位于设备上的 `/etc/e5-infoscreen/plugins/volkeys/`。

## 设置

加粗为默认值。

- 音量键（Volume keys）：**调节屏幕亮度**；亮屏 / 熄屏（同电源键）；调节音量（原样）
- 每按一次亮度变化（Brightness per press）：5–25 %，默认 10
- 最低亮度再按音量 − 关闭屏幕（Volume − at lowest cuts the screen off）：默认开  
  <sub>关闭后任何按键、触摸、短信都不亮屏，只有音量 + 恢复</sub>

## 熄屏时屏蔽其他按键（v1.3）

用音量 − 关闭屏幕后，电源键、音量 −、热点键在中断控制器上被屏蔽：既不会传到屏幕，也不会把系统从深度休眠（热点省电）里唤醒；只有音量 + 能唤醒并恢复屏幕，恢复后这些按键随即解除屏蔽。

- 这些按键是 gpio-keys，但设备树里没有 `linux,can-disable`，`disabled_keys` 用不了；即便能用，`disable_irq()` 是惰性的，而电源键、音量 + 在 PMIC 的 EIC 上（嵌套中断，从不在进入时屏蔽），照样会触发 PMIC 中断唤醒系统。
- 所以带了一个小内核模块 `e5_keywake`（源码 [`keywake/`](keywake/)），用 `IRQ_DISABLE_UNLAZY` 关中断，立即在控制器上屏蔽；`keywake.sh` 负责加载、等按键松开后屏蔽、恢复时解除。
- 模块按内核版本放在 `volkeys/keywake/<uname -r>.ko`，目前有 **e5-sleep4**（`6.18.54-e5-sleep4-00072-g020b970e351e-dirty`）、**e5-sleep5**（`6.18.54-e5-sleep5-charles-00072-g020b970e351e-dirty`）和 **e5-sleep8**（`6.18.54-e5-sleep8-charles-00072-g020b970e351e-dirty`）三个内核；其他内核上这项功能不生效（应用页面会显示「本内核不支持」），其余照旧。
- 安全措施：屏幕每次启动都会解除屏蔽；每分钟检查一次，屏幕亮着却仍在屏蔽就解除；卸载补丁（`POST /unpatch`）也会解除；重启后自然解除。
- 实测（2026-10-17）：屏蔽期间按电源键，PMIC 中断计数不变；拔线熄屏休眠 106 秒，期间多次按电源键、热点键、音量 − 都没有唤醒，最后只被音量 + 唤醒（`woken by key (… Volume_Up_Key …)`）。

构建模块（e5-sleep 内核构建树里）：

```sh
make -C k-sleep4 O=obj-sleep4 ARCH=arm64 LLVM=1 LLVM_IAS=1 M=$PWD/keywake modules
llvm-strip --strip-debug -o volkeys/keywake/$(cat obj-sleep4/include/config/kernel.release).ko keywake/e5_keywake.ko
```

## 源码

`volkeys/` 是当前版本安装包解压后的内容：

- [`backend.uc`](volkeys/backend.uc)
- [`index.html`](volkeys/index.html)
- [`manifest.json`](volkeys/manifest.json)
- [`patch.js`](volkeys/patch.js)
- [`keywake.sh`](volkeys/keywake.sh)、`keywake/`（e5_keywake.ko）

## 版本

- [v1.5](releases/volkeys-v1.5.tar.gz)（当前）：增加 e5-sleep8 内核的 e5_keywake 模块
- [v1.4](releases/volkeys-v1.4.tar.gz)：增加 e5-sleep5 内核的 e5_keywake 模块
- [v1.3](releases/volkeys-v1.3.tar.gz)：熄屏时屏蔽其他按键，不唤醒深度休眠；熄屏后音量 + 不再依赖 `/mode`
- [v1.2](releases/volkeys-v1.2.tar.gz)
- [v1.1](releases/volkeys-v1.1.tar.gz)
- [v1.0](releases/volkeys-v1.0.tar.gz)
