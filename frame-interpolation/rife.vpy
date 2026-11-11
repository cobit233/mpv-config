import os
import sys

import vapoursynth as vs
core = vs.core

# vsrife 来自子模块 third_party/vs-rife，不走 pip 安装。
sys.path.insert(0, os.path.expanduser("~/.config/mpv/third_party/vs-rife"))
import vsrife

clip = video_in

# 明确输入色彩（非常关键）
clip = core.resize.Bicubic(
    clip,
    format=vs.RGBS,
    matrix_in_s="709"
)

# 插帧。fps_den 必须一起给，否则当前 vsrife 会忽略 fps_num，只做 2 倍。
target_fps = 120
clip = vsrife.rife(
    clip,
    model="4.22.lite",
    fps_num=target_fps,
    fps_den=1,
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
clip = core.std.SetFrameProp(clip, prop="_DurationNum", intval=1)
clip = core.std.SetFrameProp(clip, prop="_DurationDen", intval=target_fps)

clip.set_output()
