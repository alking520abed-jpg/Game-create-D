"""Synthesize every sound effect and the music loops (no external audio). usage: sounds.py <out_dir>"""
import sys, os, wave
import numpy as np
SR = 32000
rng = np.random.default_rng(7)


def save(name, x, out):
    x = np.asarray(x, dtype=np.float64)
    x = x / max(1e-9, np.abs(x).max()) * 0.92
    with wave.open(os.path.join(out, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def t(d):
    return np.arange(int(SR * d)) / SR


def noise(d):
    return rng.standard_normal(int(SR * d))


def lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x); s = 0.0
    for i in range(len(x)):
        s = a * s + (1 - a) * x[i]; y[i] = s
    return y


def hp(x, fc):
    return x - lp(x, fc)


def env(d, attack, decay):
    tt = t(d)
    return np.minimum(1.0, tt / max(attack, 1e-5)) * np.exp(-tt / decay)


def shot(d, crack, body, thump_f, tail, bright):
    tt = t(d)
    n = noise(d)
    x = hp(n, bright) * env(d, 0.0005, crack) * 1.2
    x += lp(n, 1400) * env(d, 0.001, body) * 1.4
    x += np.sin(2 * np.pi * thump_f * tt * np.exp(-tt * 6)) * env(d, 0.001, 0.07) * 1.6
    x += lp(noise(d), 600) * env(d, 0.02, tail) * 0.5      # room tail
    return np.tanh(x * 2.2)


def tone(f, d, a=0.005, dec=0.2, shape="sin"):
    tt = t(d)
    ph = 2 * np.pi * f * tt
    w = np.sin(ph) if shape == "sin" else (np.sign(np.sin(ph)) if shape == "sq" else 2 * ((f * tt) % 1) - 1)
    return w * env(d, a, dec)


def pad(x, d):
    y = np.zeros(int(SR * d)); y[:min(len(x), len(y))] = x[:len(y)]; return y


def mix(d, *parts):
    y = np.zeros(int(SR * d))
    for off, x in parts:
        i = int(off * SR); n = min(len(x), len(y) - i)
        if n > 0:
            y[i:i + n] += x[:n]
    return y


def main(out):
    os.makedirs(out, exist_ok=True)
    save("shot_pistol", shot(0.55, 0.012, 0.05, 150, 0.16, 2500), out)
    save("shot_smg", shot(0.4, 0.009, 0.035, 190, 0.1, 3200), out)
    save("shot_rifle", shot(0.7, 0.014, 0.07, 110, 0.22, 2200), out)
    save("shot_shotgun", shot(0.9, 0.03, 0.12, 80, 0.3, 1500), out)
    save("shot_enemy", lp(shot(0.5, 0.012, 0.06, 140, 0.2, 1800), 3500), out)
    click = hp(noise(0.05), 2500) * env(0.05, 0.0005, 0.008)
    save("empty", mix(0.12, (0, click)), out)
    save("reload", mix(0.9, (0.0, click), (0.07, tone(900, 0.05, dec=0.02) * 0.3), (0.42, lp(noise(0.08), 2500) * env(0.08, 0.002, 0.03)),
                       (0.68, click * 1.3), (0.72, tone(600, 0.06, dec=0.02) * 0.4)), out)
    save("pump", mix(0.5, (0.0, lp(noise(0.1), 1800) * env(0.1, 0.01, 0.04)), (0.2, lp(noise(0.1), 2400) * env(0.1, 0.005, 0.03)), (0.22, click)), out)
    save("switch", mix(0.25, (0, lp(noise(0.12), 1500) * env(0.12, 0.02, 0.05)), (0.12, click)), out)
    for i, fc in enumerate((700, 900, 800, 1000)):
        save("step%d" % (i + 1), lp(noise(0.16), fc) * env(0.16, 0.004, 0.035) + tone(70 + i * 9, 0.16, dec=0.03) * 0.5, out)
    save("impact", hp(noise(0.18), 1200) * env(0.18, 0.0005, 0.025) + tone(1900, 0.18, dec=0.02) * 0.2, out)
    save("ricochet", tone(1, 0.35) * 0 + np.sin(2 * np.pi * (2600 * t(0.35) - 2400 * t(0.35) ** 2)) * env(0.35, 0.002, 0.1) * 0.6 + hp(noise(0.35), 3000) * env(0.35, 0.001, 0.02), out)
    save("hit", tone(1400, 0.09, dec=0.02, shape="sq") * 0.5 + tone(2100, 0.09, dec=0.015), out)
    save("kill", mix(0.3, (0, tone(900, 0.1, dec=0.03, shape="sq") * 0.5), (0.07, tone(1350, 0.2, dec=0.06))), out)
    save("hurt", lp(noise(0.25), 500) * env(0.25, 0.003, 0.06) + tone(90, 0.25, dec=0.08), out)
    save("body", lp(noise(0.5), 300) * env(0.5, 0.01, 0.1) + tone(55, 0.5, dec=0.12), out)
    save("click", mix(0.06, (0, tone(1100, 0.06, dec=0.012)), (0, click * 0.4)), out)
    save("pickup", mix(0.3, (0, tone(880, 0.12, dec=0.04)), (0.08, tone(1320, 0.2, dec=0.06))), out)
    save("objective", mix(0.7, (0, tone(660, 0.25, dec=0.1)), (0.14, tone(880, 0.25, dec=0.1)), (0.28, tone(1320, 0.4, dec=0.16))), out)
    save("fail", mix(0.9, (0, tone(300, 0.4, dec=0.15, shape="saw") * 0.6), (0.25, tone(210, 0.6, dec=0.25, shape="saw") * 0.6)), out)
    save("cash", mix(0.5, (0, hp(noise(0.3), 4000) * env(0.3, 0.002, 0.05) * 0.5), (0.02, tone(2400, 0.3, dec=0.08)), (0.09, tone(3200, 0.35, dec=0.1))), out)
    save("door", lp(noise(0.5), 500) * env(0.5, 0.03, 0.12) + tone(60, 0.5, dec=0.1), out)
    save("beep", tone(1800, 0.12, a=0.002, dec=0.3) * (t(0.12) < 0.09), out)
    save("glass", sum(tone(f, 0.6, dec=0.05 + 0.03 * i) for i, f in enumerate((3100, 4300, 5200, 6900))) + hp(noise(0.6), 5000) * env(0.6, 0.001, 0.08), out)
    # explosion
    d = 1.8
    save("explosion", np.tanh((lp(noise(d), 500) * env(d, 0.002, 0.4) * 2 + np.sin(2 * np.pi * 50 * t(d) * np.exp(-t(d) * 2)) * env(d, 0.002, 0.3) * 2 + hp(noise(d), 2000) * env(d, 0.001, 0.05)) * 2), out)
    # loops
    d = 2.0; tt = t(d)
    sweep = 620 + 330 * (0.5 - 0.5 * np.cos(2 * np.pi * tt / d))
    save("alarm_loop", np.sign(np.sin(2 * np.pi * np.cumsum(sweep) / SR)) * 0.5 + np.sin(2 * np.pi * np.cumsum(sweep) / SR), out)
    d = 1.0; tt = t(d)
    drill = np.sign(np.sin(2 * np.pi * 170 * tt)) * 0.4 + hp(noise(d), 1500) * 0.35 * (0.7 + 0.3 * np.sin(2 * np.pi * 21 * tt)) + np.sin(2 * np.pi * 85 * tt) * 0.5
    save("drill_loop", lp(drill, 5000), out)
    d = 4.0; tt = t(d)
    save("siren_loop", np.sin(2 * np.pi * np.cumsum(np.where((tt % 1.0) < 0.5, 650, 870)) / SR) * 0.8 + 0.2 * np.sin(4 * np.pi * np.cumsum(np.where((tt % 1.0) < 0.5, 650, 870)) / SR), out)
    d = 3.0; tt = t(d)
    hum = sum(np.sin(2 * np.pi * f * tt) * a for f, a in ((60, 1.0), (120, 0.5), (180, 0.2), (240, 0.1))) + lp(noise(d), 400) * 0.6
    save("room_loop", hum, out)
    # music: tense pulse (8 s loop, 120 bpm) and action variant
    def music(name, action):
        bpm = 120 if not action else 140
        beat = 60.0 / bpm
        bars = 4
        d = beat * 4 * bars
        y = np.zeros(int(SR * d))
        roots = [55.0, 55.0, 51.91, 61.74]  # A1 A1 G#1 B1
        for bar in range(bars):
            f0 = roots[bar]
            for s in range(16):
                off = bar * 4 * beat + s * beat / 4
                if s % (2 if action else 4) == 0 or (s % 8 == 6):
                    y_part = lp(tone(f0 * (2 if s % 8 == 6 else 1), beat / 2, dec=0.12, shape="saw"), 500 if not action else 900) * 0.9
                    i = int(off * SR); n = min(len(y_part), len(y) - i); y[i:i + n] += y_part[:n]
                if s % 4 == 0:  # kick
                    k = np.sin(2 * np.pi * 95 * t(0.25) * np.exp(-t(0.25) * 9)) * env(0.25, 0.001, 0.07) * (1.2 if action else 0.7)
                    i = int(off * SR); n = min(len(k), len(y) - i); y[i:i + n] += k[:n]
                if action and s % 4 == 2:
                    h = hp(noise(0.06), 5000) * env(0.06, 0.001, 0.012) * 0.25
                    i = int(off * SR); n = min(len(h), len(y) - i); y[i:i + n] += h[:n]
                if action and s % 8 == 4:
                    sn = (hp(noise(0.18), 1200) * env(0.18, 0.001, 0.04) + tone(190, 0.18, dec=0.03)) * 0.5
                    i = int(off * SR); n = min(len(sn), len(y) - i); y[i:i + n] += sn[:n]
            # pad
            tt = t(beat * 4)
            padw = sum(np.sin(2 * np.pi * f0 * m * tt + i) for i, m in enumerate((4, 4.76, 6, 8.02))) * 0.07 * (0.6 + 0.4 * np.sin(2 * np.pi * tt / (beat * 4)))
            i = int(bar * 4 * beat * SR); n = min(len(padw), len(y) - i); y[i:i + n] += padw[:n]
            # arp melody
            notes = [8, 9.51, 12, 9.51, 8, 12, 14.25, 12] if not action else [8, 12, 9.51, 12, 16, 12, 9.51, 14.25]
            for j, m in enumerate(notes):
                a = tone(f0 * m / 2, beat / 2, dec=0.09) * (0.12 if not action else 0.16)
                i = int((bar * 4 * beat + j * beat / 2) * SR); n = min(len(a), len(y) - i); y[i:i + n] += a[:n]
        save(name, np.tanh(y * 1.3), out)
    music("music_tense", False)
    music("music_action", True)
    print("sounds ok")


main(sys.argv[1])
