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
scripts/   -- 脚本文件目录，当前仅实现了从剪切板链接播放视频的功能\
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

> 需要安装 xclip：sudo pacman -S xclip

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
