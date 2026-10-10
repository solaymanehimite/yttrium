#!/usr/bin/env python3
"""Stream 16 audio-frequency levels from the default output monitor as JSON lines."""

import array
import json
import math
import signal
import subprocess
import sys

try:
    import numpy as np
except ImportError:
    np = None

SAMPLE_RATE = 16000
SAMPLES_PER_FRAME = 800  # 50 ms / 20 frames per second
BARS = 16
WINDOW = [0.5 - 0.5 * math.cos(2 * math.pi * i / (SAMPLES_PER_FRAME - 1))
          for i in range(SAMPLES_PER_FRAME)]
EDGES = [65 * (7000 / 65) ** (i / BARS) for i in range(BARS + 1)]
if np is not None:
    FFT_WINDOW = np.asarray(WINDOW, dtype=np.float32)
    FFT_FREQUENCIES = np.fft.rfftfreq(SAMPLES_PER_FRAME, 1 / SAMPLE_RATE)
    FFT_BANDS = [np.flatnonzero((FFT_FREQUENCIES >= EDGES[i])
                                & (FFT_FREQUENCIES < EDGES[i + 1]))
                 for i in range(BARS)]

COEFFICIENTS = [
    tuple(2 * math.cos(2 * math.pi * frequency / SAMPLE_RATE)
          for frequency in (math.sqrt(EDGES[i] * EDGES[i + 1]) * factor
                            for factor in (0.9, 1.0, 1.1)))
    for i in range(BARS)
]


def read_frame(stream):
    chunks = []
    remaining = SAMPLES_PER_FRAME * 2
    while remaining:
        data = stream.read(remaining)
        if not data:
            return None
        chunks.append(data)
        remaining -= len(data)
    samples = array.array("h")
    samples.frombytes(b"".join(chunks))
    if sys.byteorder != "little":
        samples.byteswap()
    return samples


def levels_for(samples, previous):
    if np is not None:
        spectrum = np.abs(np.fft.rfft(np.asarray(samples, dtype=np.float32) * FFT_WINDOW))
        spectrum *= 4 / SAMPLES_PER_FRAME
        magnitudes = [float(np.max(spectrum[band])) if len(band) else 0.0
                      for band in FFT_BANDS]
        return [round(max(min(1.0, (value / 4000) ** 0.7) if value > 35 else 0.0,
                          old * 0.68), 3)
                for value, old in zip(magnitudes, previous)]

    # Goertzel fallback for systems without NumPy.
    windowed = [sample * weight for sample, weight in zip(samples, WINDOW)]
    levels = []
    for coefficients, old in zip(COEFFICIENTS, previous):
        strongest = 0.0
        for coefficient in coefficients:
            q1 = q2 = 0.0
            for sample in windowed:
                q0 = sample + coefficient * q1 - q2
                q2, q1 = q1, q0
            magnitude = math.sqrt(max(0.0, q1 * q1 + q2 * q2 - coefficient * q1 * q2))
            strongest = max(strongest, magnitude * 4 / SAMPLES_PER_FRAME)
        level = min(1.0, (strongest / 4000) ** 0.7) if strongest > 35 else 0.0
        levels.append(round(max(level, old * 0.68), 3))
    return levels


def main():
    # @DEFAULT_MONITOR@ is the output sink monitor, never the microphone.
    capture = subprocess.Popen(
        ["parec", "--device=@DEFAULT_MONITOR@", "--raw", "--format=s16le",
         f"--rate={SAMPLE_RATE}", "--channels=1", "--latency-msec=50"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )

    def stop(_signal, _frame):
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    previous = [0.0] * BARS
    try:
        while True:
            samples = read_frame(capture.stdout)
            if samples is None:
                break
            previous = levels_for(samples, previous)
            try:
                print(json.dumps(previous, separators=(",", ":")), flush=True)
            except BrokenPipeError:
                break
    finally:
        capture.terminate()
        try:
            capture.wait(timeout=1)
        except subprocess.TimeoutExpired:
            capture.kill()
            capture.wait()


if __name__ == "__main__":
    main()
