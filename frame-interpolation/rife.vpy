import os
import sys
from fractions import Fraction

import vapoursynth as vs
core = vs.core

# vsrife 来自子模块 third_party/vs-rife，不走 pip 安装。
sys.path.insert(0, os.path.expanduser("~/.config/mpv/third_party/vs-rife"))
import vsrife

# 插帧倍数。RTX 4070 上 1080p 半精度实测约 88 帧/秒，2 倍够用；
# 24 -> 60 约 56 帧/秒、24 -> 120 约 47 帧/秒，会卡。
factor = 2

clip = video_in

# mpv 给的 video_in 是可变帧率（fps 为 0），真实帧率在 container_fps 里。
src_fps = Fraction(container_fps).limit_denominator(1001)
out_fps = src_fps * factor

# 明确输入色彩（非常关键）。RGBH 让 vsrife 走半精度，比 RGBS 快约 40%。
clip = core.resize.Bicubic(
    clip,
    format=vs.RGBH,
    matrix_in_s="709"
)

clip = vsrife.rife(
    clip,
    model="4.22.lite",
    factor_num=factor,
    # 2K 以上光流降到半分辨率算，vsrife 文档对 4K 的建议值。
    scale=0.5 if clip.height > 1440 else 1.0,
    auto_download=True
)

# 明确输出色彩
clip = core.resize.Bicubic(
    clip,
    format=vs.YUV420P8,
    matrix_s="709"
)

# mpv 靠这两项累加每帧时间。vsrife 会把源帧时长拷到插出来的每一帧上，
# 弹幕按这个时间走，就会变慢并且一跳一跳。
clip = core.std.SetFrameProp(clip, prop="_DurationNum", intval=out_fps.denominator)
clip = core.std.SetFrameProp(clip, prop="_DurationDen", intval=out_fps.numerator)

clip.set_output()
