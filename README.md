# 简介

个人使用的MPV配置，包括超分，插帧。同时做了简单的快捷键处理。

# 系统

- Arch Linux
- Wayland
- Nvidia GPU

# 文件目录

input.conf -- 键盘绑定配置文件\
mpv.conf   -- 主配置文件\
rife.vpy   -- 插帧脚本文件，用于调用 RIFE 模型（GPU）进行插帧处理\
scripts/   -- 脚本文件目录\
　　clipboard.lua　　-- 从系统剪切板获取链接并播放\
　　bili-danmaku.lua -- B站弹幕自动下载/转换/挂载\
shaders/   -- 超分所需文件

# 使用方式

- 安装mpv（播放器）
  > 2026-07-26更新：paru -S mpv安装的版本，不支持vf=vapoursynth=路径的语法，插帧失败，改为pacman -S mpv-git后成功
- 安装vapourSynth（视频处理依赖）
  > paru -S vapoursynth
- 安装vsrife（插帧依赖）

  由于Arch没有维护AUR包，所以只能暂且使用pip安装管理。当然这并非Arch推荐的处理方式，故如果不加break-system-packages参数无法安装。如果有兴趣可以自行去AUR维护......
  > pip install vsrife --break-system-packages
  如果没有插帧模型则播放视频的时候自动下载(rife.vpy中设置了auto\_download=True，默认4.22.lite)。当然也可以python -m vsrife下载相应的模型

  配置结束后，可清理下载过程中的whl缓存文件
  > pip cache purge
- 将本项目所有文件放在\~/.config/mpv下，mpv启动会自行读取配置

# 快捷键

## 插帧

\| Ctrl + \` | 开启/关闭 RIFE 插帧（默认开启，插帧到120fps，可自行修改rife.vpy中的target\_fps）

## Anime4K 超分

越往下效果越好

\| Ctrl + 0 | 关闭 Anime4K\
\| Ctrl + 1 | Upscale CNN x2 S\
\| Ctrl + 2 | Restore CNN M + Upscale CNN x2 M\
\| Ctrl + 3 | Deblur DoG + Restore CNN L + Upscale CNN x2 L（默认）

## 从剪切板播放

\| Ctrl + V | 	从系统剪切板获取链接并播放

> 需要安装 wl-paste：sudo pacman -S wl-paste


## 常用 mpv 默认快捷键

\| i |          查看视频信息（帧率/分辨率/编码等）\
\| f|           全屏切换\
\| Space / p |  暂停/播放\
\| ← / → |      快退/快进 5 秒\
\| ↑ / ↓ |      快退/快进 1 分钟\
\| Backspace |  恢复默认速度\
\| 9 / 0 |      降低/提高音量\
\| m |          静音\
\| V |          显示/隐藏字幕\
\| J |          切换字幕轨道\
\| # |          切换音轨
\| d |          开/关B站弹幕（默认开启，详见「B站在线播放与弹幕」）

# 插帧流程

1. mpv
   播放器本体,pacman直接安装\
   作用：\
       解码视频（硬件加速）\
       调用滤镜（VapourSynth）\
       输出画面（Vulkan）
2. VapourSynth\
   视频处理框架（核心中间层）\
   作用：\
       接收 mpv 解码后的视频\
       使用 Python 处理帧\
       把处理后的帧再交回 mpv
3. vsrife（RIFE 的"接口层"）\
   作用：\
       把 AI 插帧算法封装成 VapourSynth 可调用函数\
       提供 vsrife.rife(...)库函数
4. RIFE 模型真正干活的 AI 模型\
   作用：\
       输入两帧 → 生成中间帧
5. Vulkan / GPU\
   硬件加速层\
   作用：\
       让 RIFE 插帧在 GPU 上跑

如果想继续优化：\
自动判断低帧率才插帧\
降分辨率再插帧（大幅降负载）

# 超分流程

借由Anime4K实现，只需要在mpv.conf中定义需要的超分mode即可。


# B站在线播放与弹幕

直接把b站链接丢给 mpv 即可，不要复制m4s链接

```bash
mpv "https://www.bilibili.com/video/BVxxxxxxxx"
```

## 依赖安装

- yt-dlp\
   > sudo pacman -S yt-dlp\
   作用：解析页面链接 → 换回已授权的播放地址
- biliass\
   > paru -S python-biliass\
   作用：弹幕 XML → ASS 转换，提供 `/usr/bin/biliass`

mpv 内置的 `ytdl_hook` 会自动调用它，需要一个在 PATH 里的 `yt-dlp` 可执行文件。


## 画质与登录

B站对番剧等内容**未登录硬卡 480P**。`mpv.conf` 末尾的 `[bili]` profile 从 Edge 读取 cookie\
（前提：Edge 的 Default profile 里已登录 B站），从而解锁 720P / 1080P。

选流策略（两者同时生效）：\
  1) ytdl-format 强制 h264（avc1）：B站 DASH 的 av1 档只有 ~600kbps，h264 档有 ~2600kbps（4 倍多）。\
     拿低码率源喂 Anime4K 会把压缩伪影一起放大，所以这里限定 h264。\
  2) format-sort=br：在满足 h264 + 1080P 上限的候选里，选码率最高的一条。

自检命令：

```bash
yt-dlp --cookies-from-browser edge -f 'bv*[height<=1080][vcodec^=avc1]' --get-url "视频链接" \
  | grep -oE '_nb[0-9]*-1-[0-9]+\.m4s'
```

输出含 `_30080.m4s` = 1080P，登录态生效；输出 `_30032.m4s` = 480P，cookie 没读到。

## 弹幕是怎么挂上的

mpv 的 `ytdl_hook` 用 `yt-dlp -J` 模式运行，弹幕轨只有原始 XML，mpv 不认这个格式。\
所以 `bili-danmaku.lua` 会在加载后独立再跑一次 yt-dlp 把 XML 落盘，交给 biliass 转成 ASS，\
再用 `sub-add` 挂载，并移除那个无法解析的内置轨。

## 弹幕缓存

```
~/.cache/bili-danmaku/<URL>-<hash>/danmaku-v<版本>.ass
```

只缓存弹幕 ASS（几百 KB 量级），视频音频不落盘（mpv 流式播放）。默认 1 天过期。

## 快捷键

\| d | 开/关弹幕（默认开启）

## 可调参数

字体、字号、弹幕停留时长、分类屏蔽、关键词屏蔽、缓存天数等全部参数，\
见 `scripts/bili-danmaku.lua` 头部注释。在 `mpv.conf` 里用 script-opts 覆盖：

```ini
script-opts=bili-danmaku-font_face=Source Han Sans CN
script-opts-append=bili-danmaku-duration_marquee=12
```

改完风格参数后把 `style_version` +1，可让旧缓存失效。

## 排障

- **画质还是 480P**：Edge 的 `Default` profile 里没登录 B站；或 cookie 读取失败。\
  注意 Edge 有多个 profile 时 yt-dlp 默认只读 `Default`。
- **完全播不了 / 日志出现 `[ytdl_hook] youtube-dl failed`**：把 `mpv.conf` 末尾 `[bili]` 段里\
  `cookies-from-browser=edge,` 删掉即可降级为无登录。
- **没有弹幕**：先按 `d` 确认弹幕是开的；若仍没有可加上\
  `script-opts-append=bili-danmaku-keep_intermediate=yes` 保留中间 XML 便于排查；\
  想强制重新抓取可在 input.conf 里绑一个快捷键调用 `script-message bili-danmaku-reload`。



# 感谢
感谢DeepSeek大肥鱼，大部分配置和代码都是她写的。