# -*- coding: utf-8 -*-
"""
生成 APP 内置铃声音频（无需外部素材，纯代码合成 WAV）

说明：
- 输出 4 个 22050Hz / 16bit / 单声道 的 wav 文件，单文件约 170KB，体积极小。
- 生成后请同时拷贝到：
  - android/app/src/main/res/raw/   （安卓通知铃声，文件名需全小写+下划线）
  - ios/Runner/Ringtones/           （iOS 通知铃声，需在 Xcode 中加入 Copy Bundle Resources）
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 22050  # 采样率
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ringtones")


def _tone(freq: float, duration: float, kind: str = "sine") -> list:
    """生成一段固定频率的波形数据"""
    n = int(SAMPLE_RATE * duration)
    data = []
    for i in range(n):
        t = i / SAMPLE_RATE
        if kind == "sine":
            v = math.sin(2 * math.pi * freq * t)
        elif kind == "triangle":
            v = 2 * abs(2 * (freq * t - math.floor(freq * t + 0.5))) - 1
        else:  # square
            v = 1.0 if math.sin(2 * math.pi * freq * t) >= 0 else -1.0
        data.append(v)
    return data


def _silence(duration: float) -> list:
    return [0.0] * int(SAMPLE_RATE * duration)


def _fade(data: list, fade_in: float = 0.01, fade_out: float = 0.02) -> list:
    """首尾淡入淡出，避免爆音"""
    fi = int(SAMPLE_RATE * fade_in)
    fo = int(SAMPLE_RATE * fade_out)
    out = list(data)
    for i in range(min(fi, len(out))):
        out[i] *= i / fi
    for i in range(min(fo, len(out))):
        out[len(out) - 1 - i] *= i / fo
    return out


def _decay(data: list, rate: float = 3.0) -> list:
    """指数衰减，模拟敲击乐器的自然衰减"""
    n = len(data)
    return [v * math.exp(-rate * (i / n)) for i, v in enumerate(data)]


def _mix(*parts: list) -> list:
    length = max(len(p) for p in parts)
    out = [0.0] * length
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    # 归一化，避免叠加过载
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * 0.9 for v in out]


def _repeat(part: list, times: int) -> list:
    out = []
    for _ in range(times):
        out.extend(part)
    return out


def build_classic() -> list:
    """经典闹铃：急促的双短音 + 停顿，循环 2 轮"""
    beep = _fade(_tone(1046.5, 0.18))          # C6
    gap = _silence(0.12)
    unit = beep + gap + beep + _silence(0.6)
    return _repeat(unit, 4)


def build_gentle() -> list:
    """柔和晨曦：上行琶音，衰减柔和，适合晨间提醒"""
    seq = [523.25, 659.25, 783.99, 1046.5]     # C5 E5 G5 C6
    parts = []
    for f in seq:
        parts.append(_fade(_decay(_tone(f, 0.9), rate=2.2)))
    return _mix(*[ _repeat(p, 1) for p in _shift_each(parts) ])


def _shift_each(parts: list) -> list:
    """把每段声音错开 0.28 秒，形成琶音"""
    out = []
    for idx, p in enumerate(parts):
        out.append(_silence(0.28 * idx) + p)
    return out


def build_digital() -> list:
    """电子滴答：短促高频 tick，像电子表"""
    tick = _fade(_tone(1975.5, 0.045, kind="square"), 0.005, 0.01)
    unit = tick + _silence(0.205)
    return _repeat(unit, 16)


def build_bell() -> list:
    """商务钟声：三音和弦 + 泛音，稳重不刺耳"""
    base = 880.0
    parts = [
        _decay(_tone(base, 1.6), rate=2.0),
        _decay(_tone(base * 1.5, 1.6), rate=2.4) * 1,   # 五度
        _decay(_tone(base * 2.0, 1.6), rate=3.0),       # 八度
    ]
    mixed = _mix(*parts)
    return _repeat(_fade(mixed) + _silence(0.4), 2)


def save(name: str, data: list) -> None:
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in data)
        w.writeframes(frames)
    print(f"生成 {name}: {len(data) / SAMPLE_RATE:.2f}s, {os.path.getsize(path) / 1024:.0f}KB")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    # 注意：文件名与 lib/constants/app_constants.dart 中的铃声列表一一对应
    save("classic_alarm.wav", build_classic())
    save("gentle_morning.wav", build_gentle())
    save("digital_tick.wav", build_digital())
    save("business_bell.wav", build_bell())
