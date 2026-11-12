# mpv-config

个人使用的 mpv 配置，包括超分、插帧、B 站在线播放与弹幕支持。

## 1. 硬件和系统

- Arch Linux
- Wayland
- NVIDIA GPU

配置依赖符号链接，只在 Linux 上使用。

## 2. 文件目录

`third_party/` 下是第三方子模块，其余是本仓库维护的配置。标「链接」的是指向子模块的符号链接。

```text
.
├── fonts/                   链接 · 界面用的 Inter 字体
├── frame-interpolation/
│   └── rife.vpy             RIFE 插帧滤镜
├── input.conf               快捷键和右键菜单
├── mpv.conf                 主配置
├── script-opts/
│   ├── menu_style.conf      链接 · 菜单磨砂玻璃样式
│   ├── modernz-locale.json  链接 · 界面翻译
│   └── modernz.conf         界面选项（只写和默认不同的项）
├── scripts/
│   ├── bili-danmaku.lua     B 站弹幕下载、转换、挂载
│   ├── idle-screen.lua      空闲界面：渐变背景，自动弹出最近播放
│   ├── interpolation.lua    插帧开关，启动时挂上
│   ├── menu/                链接 · 右键菜单脚本
│   ├── modernz.lua          链接 · 界面脚本
│   ├── play-clipboard.lua   播放剪贴板里的链接
│   └── upscale.lua          超分档位和开关，启动时挂上默认档
└── third_party/
    ├── Anime4K/             超分着色器
    ├── ArtCNN/              超分着色器
    ├── menu-plugin/         右键菜单
    ├── modern-glass/        液态玻璃界面
    └── vs-rife/             vsrife，RIFE 插帧的 VapourSynth 封装
```

## 3. 安装

- 安装 mpv。

```bash
sudo pacman -S --needed mpv
```

- 安装插帧依赖：VapourSynth 框架，以及 vsrife 需要的 PyTorch（CUDA 版）等 Python 包。

```bash
sudo pacman -S --needed vapoursynth python-pytorch-cuda python-numpy python-requests python-tqdm
```

- 克隆到 `~/.config/mpv`，同时拉取子模块。第一次播放时会自动下载插帧模型（当前只使用了 `4.22.lite`）。

```bash
git clone --recurse-submodules <仓库地址> ~/.config/mpv
git submodule update --init   # 克隆时没带 --recurse-submodules 的话补这一句
```

- （可选）安装 B 站播放依赖。yt-dlp 解析页面、换回已授权的播放地址，由 mpv 内置的 `ytdl_hook` 自动调用。

```bash
sudo pacman -S --needed yt-dlp
```

- （可选）安装biliass，显示 B 站弹幕。

```bash
paru -S --needed python-biliass
```

## 4. 快捷键

| 按键        | 作用         | 其他说明                                                                     |
| --------- | ---------- | ------------------------------------------------------------------------ |
| Space / p | 暂停/播放      |                                                                          |
| ← / →     | 后退/前进 5 秒  |                                                                          |
| ↓ / ↑     | 后退/前进 1 分钟 |                                                                          |
| Backspace | 恢复默认速度     |                                                                          |
| 9 / 0     | 降低/提高音量    |                                                                          |
| m         | 静音         |                                                                          |
| f         | 全屏切换       |                                                                          |
| i         | 查看视频信息     |                                                                          |
| v         | 显示/隐藏字幕    |                                                                          |
| j         | 切换字幕轨道     |                                                                          |
| #         | 切换音轨       |                                                                          |
| 右键        | 弹出菜单       |                                                                          |
| Ctrl+`    | 开关 RIFE 插帧 | 默认开启，2 倍                                                                 |
| Ctrl+1    | 开关超分       | 默认开启，Anime4K 极致档（去模糊 + Restore CNN L + 放大 CNN x2 L）。其他档位在右键「视频 > 超分模式」里选 |
| Ctrl+V    | 播放剪贴板里的链接  | 读取 Ctrl+C 复制的内容                                                          |
| h         | 打开最近播放列表   | 空闲时自动弹出。↑/↓ 选择，历史记录在`~/.local/state/mpv/watch_history.jsonl`             |
| d         | 开关 B 站弹幕   | 默认开启                                                                     |

完整按键见 `input.conf`。

## 5. 原理

### 5.1. 插帧

- **mpv**：解码视频（硬件加速），调用 VapourSynth 滤镜，输出画面（Vulkan）。
- **VapourSynth**：视频处理框架，接收 mpv 解码后的帧，用 Python 处理后交回 mpv。
- **vsrife**：把 RIFE 封装成 VapourSynth 可调用的函数 `vsrife.rife(...)`。
- **RIFE 模型**：输入两帧，生成中间帧，在 GPU 上运行。

固定 2 倍插帧，模型 `4.22.lite`，半精度推理。RTX 4070 上 1080p 源实测约 88 帧/秒（只算插帧，不含超分），24fps 插到 48fps 有余量。4K 源会自动把光流降到半分辨率，但也只有约 28 帧/秒，会卡。

后续可以优化的方向：

- 自动判断低帧率才插帧
- 降分辨率再插帧（大幅降低负载）

### 5.2. 超分

由 Anime4K / ArtCNN 着色器实现。所有档位的着色器链都定义在 `scripts/upscale.lua`，`input.conf` 的菜单项只按名字切换，当前档位会打勾。

### 5.3. B 站在线播放与弹幕

装好 B 站播放依赖后，直接把 B 站链接丢给 mpv 即可。

```bash
mpv "https://www.bilibili.com/video/BVxxxxxxxx"
```

#### 5.3.1. 画质与登录

B 站对番剧等内容**未登录硬卡 480P**。`mpv.conf` 末尾的 `[bili]` profile 从 Edge 读取 cookie（前提是 Edge 的 Default profile 里已登录 B 站），从而解锁 720P / 1080P。

选流策略（两者同时生效）：

- `ytdl-format` 限定 h264（avc1）。B 站 DASH 的 av1 档只有约 600kbps，h264 档约 2600kbps，低码率源喂给 Anime4K 会把压缩伪影一起放大。
- `format-sort=br`：在 h264 + 1080P 上限的候选里，选码率最高的一条。

自检命令：

```bash
yt-dlp --cookies-from-browser edge -f 'bv*[height<=1080][vcodec^=avc1]' --get-url "视频链接" \
  | grep -oE '_nb[0-9]*-1-[0-9]+\.m4s'
```

输出含 `_30080.m4s` 表示 1080P，登录态生效；输出 `_30032.m4s` 表示 480P，cookie 没读到。

#### 5.3.2. 弹幕

mpv 的 `ytdl_hook` 拿到的弹幕轨只有原始 XML，mpv 不认这个格式。`bili-danmaku.lua` 会在加载后再跑一次 yt-dlp 把 XML 落盘，交给 biliass 转成 ASS，再用 `sub-add` 挂载，并移除那个无法解析的内置轨。

弹幕缓存在 `~/.cache/bili-danmaku/`，只缓存 ASS（几百 KB），默认 1 天过期。

字体、字号、停留时长、屏蔽规则、缓存天数等参数见 `scripts/bili-danmaku.lua` 头部注释，在 `mpv.conf` 里用 script-opts 覆盖：

```ini
script-opts=bili-danmaku-font_face=Source Han Sans CN
script-opts-append=bili-danmaku-duration_marquee=12
```

改完风格参数后把 `style_version` 加 1，可以让旧缓存失效。

#### 5.3.3. 排障

- **画质还是 480P**：Edge 的 `Default` profile 里没登录 B 站，或者 cookie 读取失败。Edge 有多个 profile 时，yt-dlp 默认只读 `Default`。
- **完全播不了，日志出现** `[ytdl_hook] youtube-dl failed`：把 `mpv.conf` 末尾 `[bili]` 段里的 `cookies-from-browser=edge,` 删掉，降级为无登录。
- **没有弹幕**：先按 `d` 确认弹幕是开的。仍然没有的话，加上 `script-opts-append=bili-danmaku-keep_intermediate=yes` 保留中间 XML 排查。想强制重新抓取，在 `input.conf` 里绑一个快捷键调用 `script-message bili-danmaku-reload`。

## 6. 感谢

感谢 DeepSeek、Grok、Claude，大部分配置和代码都是她们写的。

界面美化：

- [akFace/mpv.config](https://github.com/akFace/mpv.config)（LGPL-2.1）
- [Demetter/ModernGlass](https://github.com/Demetter/ModernGlass)（LGPL-2.1）
- [mpvConfig/mpv-menu-plugin-next](https://github.com/mpvConfig/mpv-menu-plugin-next)（LGPL-2.1）

超分着色器：

- [bloc97/Anime4K](https://github.com/bloc97/Anime4K)（MIT）
- [Artoriuz/ArtCNN](https://github.com/Artoriuz/ArtCNN)（MIT）

插帧：

- [HolyWu/vs-rife](https://github.com/HolyWu/vs-rife)（MIT）
