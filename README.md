# Codex Peek

Codex Peek 是一款轻量的 macOS 菜单栏应用，用来查看 OpenAI Codex 的真实用量和剩余额度。

它不会使用 mock 数据。应用会优先读取本机 Codex CLI 登录凭证，例如 `~/.codex/auth.json`，然后通过 Codex 使用量接口读取 5 小时和每周窗口的用量数据。

## 安装

直接到 GitHub Release 下载最新版本：

[下载最新版 Codex Peek](https://github.com/jiqimaooo/codex-peek/releases/latest)

下载 `Codex Peek.dmg` 后：

1. 打开 DMG 安装包
2. 将 `Codex Peek.app` 拖到 `Applications`
3. 从「应用程序」中启动 Codex Peek

Codex Peek 是菜单栏应用，启动后不会显示在 Dock，只会显示在屏幕顶部菜单栏。

## 功能

- 菜单栏显示 5 小时剩余额度
- 弹层展示 5 小时和每周用量、剩余额度、重置时间、最近更新时间
- 手动刷新
- 使用 Codex 活动触发刷新，避免无意义轮询
- 可配置最短刷新间隔
- 开机启动
- 中文 / English 切换
- 深色 / 浅色模式自适应
- 只常驻菜单栏，不显示 Dock 图标

## 数据来源

Codex Peek 会读取本地 Codex 认证信息，并请求真实 Codex usage 数据。

使用前请先登录 Codex CLI：

```bash
codex login
```

如果本机没有登录，或者接口权限不可用，应用会在界面中显示明确错误状态。

## 构建

普通用户不需要自己构建，直接下载 Release 里的 DMG 即可。

开发者本地构建需要 macOS 14 或更高版本，以及 Xcode Command Line Tools：

```bash
swift build -c release
```

生成发布包：

```bash
./scripts/package_release.sh
```

每次推送到 `main` 时，GitHub Actions 会自动构建 DMG，并更新 Release 的最新版安装包。

## 隐私

- 不硬编码 token
- 不把敏感凭证写入日志
- 不提交本地认证文件
- 所有真实用量读取都依赖用户本机已有的 Codex 登录状态

## 开源协议

本项目使用 `GPL-3.0-or-later` 协议。

如果你分发基于本项目修改后的版本，也需要按 GPL 协议开放对应源代码。
