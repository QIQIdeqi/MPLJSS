"""Render the original Greyford score and effects as 44.1 kHz PCM WAVs."""
from pathlib import Path
import wave

import numpy as np


RATE = 44100
OUT = Path(__file__).resolve().parents[1] / 'ArtSource' / 'GameAudio'
TAU = 2 * np.pi


def time(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def shape(t, attack=.008, release=.04):
    return np.minimum(1, t / attack) * np.clip((t[-1] - t) / release, 0, 1)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def note(midi, seconds, instrument):
    t = time(seconds)
    p = TAU * hz(midi) * t
    if instrument == 'lute':
        y = sum(a * np.sin(p * h) * np.exp(-t * (4 + h))
                for h, a in ((1, 1), (2, .38), (3, .21), (4, .13), (7, .06)))
        return y * shape(t, .005, .06)
    if instrument == 'flute':
        p += .15 * np.sin(TAU * 5.1 * t) * np.minimum(t / .18, 1)
        y = np.sin(p) + .23 * np.sin(2 * p) + .08 * np.sin(3 * p)
        return y * shape(t, .085, .13) * (.89 + .11 * np.sin(TAU * 2.1 * t))
    if instrument == 'bell':
        y = np.sin(p) * np.exp(-4 * t) + .31 * np.sin(2.76 * p) * np.exp(-10 * t)
        return y * shape(t, .003, .06)
    y = sum(np.sin(p * h) * a for h, a in ((1, 1), (2, .44), (3, .22), (5, .12)))
    y += .15 * np.sin(p * 1.003)
    return y * shape(t, .09, .16)


def sweep(seconds, start, stop, decay=4, bite=.15):
    t = time(seconds)
    frequency = start * (stop / start) ** (t / seconds)
    p = TAU * np.cumsum(frequency) / RATE
    return (np.sin(p) + bite * np.sin(2 * p)) * shape(t) * np.exp(-decay * t / seconds)


def texture(seconds, seed, smooth, attack=.006, decay=5):
    t = time(seconds)
    n = np.random.default_rng(seed).standard_normal(len(t))
    blurred = np.convolve(n, np.ones(smooth) / smooth, mode='same')
    return blurred * np.sqrt(smooth) * shape(t, attack) * np.exp(-decay * t / seconds)


def place(dst, src, start, gain=1, pan=0, loop=False):
    start = round(start * RATE)
    if dst.ndim == 2:
        src = src[:, None] * np.sqrt([(1 - pan) / 2, (1 + pan) / 2])
    src = src * gain
    length = min(len(src), len(dst) - start)
    dst[start:start + length] += src[:length]
    if loop and length < len(src):
        dst[:len(src) - length] += src[length:]


def track(bpm, chords, phrases, mood):
    beat = round(60 * RATE / bpm) / RATE
    music = np.zeros((round(32 * beat * RATE), 2))
    for bar, chord in enumerate(chords):
        start = bar * 4
        bass, third, fifth = chord
        for tick, tone in enumerate((bass, fifth, third, fifth, bass + 12, third, fifth, third)):
            if mood == 'menu' and tick in (3, 7):
                continue
            place(music, note(tone + 12, beat * 1.65, 'lute'),
                  (start + tick * .5) * beat, .23 if tick % 2 == 0 else .13, -.35, True)
        for tone, gain, pan in ((bass - 12, .25, -.1), (fifth, .11, .22)):
            place(music, note(tone, beat * 4.4, 'bow'), start * beat, gain, pan, True)
        if mood in ('field', 'boss'):
            for i, offset in enumerate((0, 1.5, 2, 3.5) if mood == 'boss' else (0, 2.5)):
                drum = sweep(.23, 125 if i % 2 == 0 else 95, 43)
                drum += .18 * texture(.23, 200 + 5 * bar + i, 18)
                place(music, drum, (start + offset) * beat, .34 if mood == 'boss' else .21, -.08, True)
        if mood == 'village' and bar % 2 == 1:
            place(music, note(fifth + 24, .8, 'bell'), (start + 2.5) * beat, .09, .50, True)
        for offset, midi, beats in phrases[bar]:
            timbre = 'bow' if mood == 'boss' else 'flute'
            lead = note(midi, beats * beat + .12, timbre)
            place(music, lead, (start + offset) * beat, .23, .30, True)
            place(music, lead, (start + offset) * beat + .133, .045, -.48, True)
    # Circular early reflections retain the tails through the loop seam.
    return music + .11 * np.roll(music[:, ::-1], round(.081 * RATE), axis=0)


DM, C, G, AM, F, BB, A = ((50, 53, 57), (48, 52, 55), (43, 47, 50),
                          (45, 48, 52), (41, 45, 48), (46, 50, 53), (45, 49, 52))


def music_tracks():
    # Each tuple is (beat offset, MIDI note, duration in beats).
    yield 'Music_Menu', track(82, [DM, C, G, DM, BB, F, A, DM], [
        [(0, 69, 1.5), (2, 65, 1), (3, 67, .8)], [(0, 64, 2), (2.5, 60, 1)],
        [(0, 67, 1), (1, 69, .7), (2, 71, 1.7)], [(0, 69, 1.4), (2, 62, 1.7)],
        [(0, 65, 1.8), (2, 70, 1.5)], [(0, 69, 1.2), (1.5, 65, 2)],
        [(0, 64, .8), (1, 69, 1.2), (2.5, 73, 1.2)], [(0, 74, 2), (2.5, 69, 1.35)]], 'menu')
    yield 'Music_Village', track(104, [G, C, DM, G, F, C, G, DM], [
        [(0, 67, .7), (1, 69, .7), (2, 71, 1.6)], [(0, 72, 1), (1.5, 67, .7), (2.5, 64, 1)],
        [(0, 65, .75), (1, 69, .75), (2, 74, 1.3)], [(0, 71, 1), (1.5, 69, .6), (2.5, 67, 1)],
        [(0, 69, .8), (1, 72, .8), (2, 77, 1.4)], [(0, 76, 1), (1.5, 74, .7), (2.5, 72, 1.3)],
        [(0, 71, .7), (1, 69, .7), (2, 67, 1.8)], [(0, 65, .8), (1, 64, .8), (2, 62, 1.8)]], 'village')
    yield 'Music_Field', track(116, [DM, G, C, DM, BB, C, G, DM], [
        [(0, 62, .55), (.75, 65, .55), (1.5, 69, .75), (2.5, 67, 1.1)], [(0, 71, .7), (1, 69, .65), (2, 67, 1.45)],
        [(0, 64, .7), (1, 67, .7), (2, 72, 1.55)], [(0, 69, 1), (1.5, 65, .6), (2.5, 62, 1.2)],
        [(0, 65, .55), (.75, 70, .55), (1.5, 74, .65), (2.5, 77, 1.1)], [(0, 76, 1), (1.5, 72, 1), (3, 67, .8)],
        [(0, 71, .7), (1, 74, .65), (2, 79, 1.4)], [(0, 77, .7), (1, 76, .7), (2, 74, 1.8)]], 'field')
    yield 'Music_Boss', track(138, [DM, BB, A, DM, DM, F, BB, A], [
        [(0, 62, .75), (1, 62, .5), (2, 69, .7), (3, 65, .65)], [(0, 70, 1), (1.5, 69, .5), (2.5, 65, .85)],
        [(0, 64, .7), (1, 69, .7), (2, 73, 1.7)], [(0, 74, .7), (1, 69, .5), (2, 65, .5), (3, 62, .7)],
        [(0, 62, .7), (1, 65, .7), (2, 69, .7), (3, 74, .8)], [(0, 77, .8), (1.5, 76, .6), (2.5, 72, 1)],
        [(0, 74, .8), (1, 70, .65), (2, 65, 1.6)], [(0, 64, .7), (1, 69, .65), (2, 73, 1.8)]], 'boss')


def chimes(seconds, events, timbre='bell'):
    result = np.zeros(round(seconds * RATE))
    for start, pitch, gain in events:
        place(result, note(pitch, min(.72, seconds - start), timbre), start, gain)
    return result


def effects():
    yield 'PlayerStep', .66 * texture(.13, 11, 13) + .37 * sweep(.13, 145, 78)
    yield 'PlayerDodge', .70 * texture(.28, 12, 4, .045, 2) + .16 * sweep(.28, 680, 260)
    yield 'PlayerAttack', .46 * texture(.22, 13, 6, .024, 4) + .43 * sweep(.22, 820, 270, 3)
    yield 'PlayerHurt', .58 * sweep(.24, 205, 86, 3, .43) + .32 * texture(.24, 14, 22)
    yield 'PlayerDeath', chimes(.92, [(0, 57, .7), (.14, 53, .55), (.35, 50, .65)], 'bow')
    yield 'EnemyStep', .49 * texture(.18, 15, 28) + .55 * sweep(.18, 105, 43, 3)
    yield 'EnemyAttack', .54 * texture(.30, 16, 9, .052, 2) + .50 * sweep(.30, 310, 76, 2, .63)
    yield 'EnemyWarn', chimes(.42, [(0, 60, .55), (.14, 66, .86)], 'flute')
    yield 'EnemyHit', .57 * texture(.14, 17, 5) + .40 * sweep(.14, 185, 81)
    yield 'EnemyDeath', .56 * sweep(.43, 158, 40, 2.5) + .42 * texture(.43, 18, 35, .014, 3)
    yield 'BossAttack', .64 * sweep(.59, 94, 28, 2, .42) + .61 * texture(.59, 19, 19, .036, 3)
    yield 'PickupCoin', chimes(.29, [(0, 83, .55), (.043, 90, .85)])
    yield 'PickupXP', chimes(.36, [(0, 74, .55), (.065, 81, .68), (.13, 86, .72)], 'flute')
    yield 'PickupMaterial', chimes(.27, [(0, 65, .78), (.06, 72, .58)], 'lute')
    yield 'PickupChest', chimes(.75, [(0, 50, .55), (.09, 57, .52), (.17, 65, .5), (.24, 74, .78)])
    yield 'UISelect', chimes(.09, [(0, 75, .77)], 'lute')
    yield 'UIConfirm', chimes(.20, [(0, 69, .63), (.062, 74, .64)], 'lute')
    yield 'UICancel', chimes(.20, [(0, 69, .59), (.072, 62, .58)], 'lute')
    yield 'UIError', .69 * sweep(.19, 264, 138, 2, .42) + .22 * sweep(.19, 284, 155, 2)
    yield 'BrewStart', chimes(.55, [(0, 57, .5), (.08, 64, .46), (.18, 68, .58), (.30, 72, .48)], 'lute')
    yield 'BrewDone', chimes(.86, [(0, 65, .55), (.08, 72, .6), (.17, 77, .62), (.26, 81, .7)])
    yield 'LevelUp', chimes(.82, [(0, 62, .55), (.07, 69, .62), (.14, 74, .73), (.25, 78, .64), (.31, 81, .62)])
    yield 'Portal', .54 * sweep(.72, 94, 430, 1.7, .36) + .27 * texture(.72, 20, 8, .2, 1.6)
    yield 'Victory', chimes(1.25, [(0, 62, .6), (.12, 69, .65), (.25, 74, .8), (.42, 78, .68), (.42, 81, .65), (.42, 86, .65)])
    yield 'Defeat', chimes(1.15, [(0, 61, .65), (.17, 58, .65), (.36, 53, .64), (.51, 46, .65)], 'bow')
    yield 'Interact', chimes(.21, [(0, 60, .63), (.045, 67, .53)], 'lute')
    yield 'Fragment', chimes(.17, [(0, 88, .76), (.037, 91, .47)])
    yield 'MerchantArrive', chimes(.86, [(0, 67, .71), (.12, 71, .63), (.24, 74, .65), (.40, 79, .68)], 'flute')


def save(name, signal, peak):
    signal = signal - signal.mean(axis=0)
    if signal.ndim == 1:
        signal *= shape(time(len(signal) / RATE), .003, .025)
    signal *= peak / np.max(np.abs(signal))
    pcm = np.rint(signal * 32767).astype('<i2')
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setnchannels(2 if signal.ndim == 2 else 1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(pcm.tobytes())
    rms = np.sqrt(np.mean(signal ** 2))
    print(f'{name} {len(pcm) / RATE:.3f}s peak={20 * np.log10(peak):.1f} dBFS rms={20 * np.log10(rms):.1f} dBFS')


def write_extras():
    t = time(12)
    rng = np.random.default_rng(302)
    frequencies = np.fft.rfftfreq(len(t), 1 / RATE)
    hiss = np.fft.rfft(rng.standard_normal(len(t)))
    wind = np.fft.irfft(hiss / (1 + (frequencies / 240) ** 4), len(t))
    creek = np.fft.irfft(hiss * np.exp(-((frequencies - 1650) / 1150) ** 2), len(t))
    wind *= .85 + .15 * np.cos(TAU * t / 6)
    creek *= .89 + .11 * np.cos(TAU * t / 3)
    bed = .22 * wind + .045 * creek
    ambience = np.stack((bed, .86 * bed + .14 * np.roll(bed, 479)), axis=1)
    for offset, pitch, pan in ((2.4, 2150, -.57), (7.7, 2610, .50), (10.1, 1920, -.32)):
        place(ambience, sweep(.14, pitch, pitch * 1.28, 2), offset, .022, pan, True)
        place(ambience, sweep(.10, pitch * 1.18, pitch * .97, 2), offset + .21, .016, pan, True)
    save('Ambient_Village', ambience, .17)
    save('S_EnemySpawn', .67 * sweep(.36, 102, 194, 2.2) + .24 * texture(.36, 31, 24, .08), .37)
    save('S_Upgrade', chimes(.52, [(0, 65, .66), (.10, 72, .64), (.18, 76, .58)], 'lute'), .45)
    save('S_Wave', chimes(.54, [(0, 52, .55), (.17, 59, .63)], 'bow'), .37)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, signal in music_tracks():
        save(name, signal, .62)
    for name, signal in effects():
        peak = .42 if name.startswith(('UI', 'PlayerStep', 'EnemyStep', 'Fragment')) else .70
        save('S_' + name, signal, peak)
    write_extras()


if __name__ == '__main__':
    main()
