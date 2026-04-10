# 系统
Arch Linux

# 使用方式
文件放在~/.config/mpv下，mpv会自行读取配置

# 插帧流程

🧩 1. mpv
	👉 播放器本体,pacman直接安装
	作用：
		解码视频（硬件加速）
		调用滤镜（VapourSynth）
		输出画面（Wayland / Vulkan）


🧩 2. VapourSynth,paru直接安装
	👉 视频处理框架（核心中间层）

	作用：
		接收 mpv 解码后的视频
		允许你用 Python 写处理逻辑
		把处理后的帧再交回 mpv

		👉 你写的 .vpy 就是在这里执行

🧩 3. vsrife（pip install vsrife --break-system-packages 安装）
	👉 RIFE 的“接口层”

	作用：
		把 AI 插帧算法封装成 VapourSynth 可调用函数
		提供 vsrife.rife(...)库函数
	
	注意：
		该项由
			pip install vsrife --break-system-packages
		下载，而非pacman/paru/yay管理，大约2个G（？）
		配置结束后，可pip cache purge可清理下载过程中的whl缓存文件

🧩 4. RIFE 模型（自动下载）
	👉 真正干活的 AI 模型

	作用：
		输入两帧 → 生成中间帧
		实现： 视频插帧（30fps → 60fps / 120fps）
	
	注意：
		python -m vsrife下载相应的模型，例如这里使用的4.22.lite
		rife.vpy中设置了auto_download=True，如果没有模型播放视频的时候自动下载。

🧩 5. Vulkan / GPU（系统已有）
	👉 硬件加速层
	
	作用：
		让 RIFE 在 GPU 上跑
		否则 CPU 会直接爆炸


🧠 整体流程
mpv 播放视频
   ↓
VapourSynth 接管帧
   ↓
vsrife 调用 RIFE 模型（GPU）
   ↓
生成新帧（插帧）
   ↓
返回 mpv 播放



如果你后面想继续优化：
	自动判断低帧率才插帧
	降分辨率再插帧（大幅降负载）


# 超分流程
借由Anime4K实现，只需要在mpv.conf中定义需要的mode即可


# 从剪切板链接播放视频
通过scripts/clipboard.lua实现handler，input.conf中Ctrl + C绑定该lua
	注意：需要安装xclip软件实现剪切板的获取，sudo pacman -S xclip 


