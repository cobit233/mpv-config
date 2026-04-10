import vapoursynth as vs
core = vs.core

import vsrife

clip = video_in

# 明确输入色彩（非常关键）
clip = core.resize.Bicubic(
    clip,
    format=vs.RGBS,
    matrix_in_s="709"
)

# 插帧
target_fps = 120
clip = vsrife.rife(
    clip,
    model="4.22.lite",
    fps_num=target_fps,
    auto_download=True
)

# 明确输出色彩
clip = core.resize.Bicubic(
    clip,
    format=vs.YUV420P8,
    matrix_s="709"
)

clip.set_output()
