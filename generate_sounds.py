import math
import wave
import struct
import os

def generate_wav(filename, duration, sample_rate, generate_sample):
    num_samples = int(duration * sample_rate)
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            sample = generate_sample(t)
            # Clip
            sample = max(-1.0, min(1.0, sample))
            # Convert to 16-bit PCM
            value = int(sample * 32767.0)
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

# 1. Click (Soft Pop)
def click_sample(t):
    freq = 600.0
    envelope = math.exp(-t * 60.0) # Fast decay
    return math.sin(2 * math.pi * freq * t) * envelope * 0.5

# 2. Coin (High Bell/Ding)
def coin_sample(t):
    freq1 = 1200.0
    freq2 = 1600.0
    envelope = math.exp(-t * 15.0)
    return (math.sin(2 * math.pi * freq1 * t) + math.sin(2 * math.pi * freq2 * t)) * 0.4 * envelope

# 3. Win (Magical Chime Arpeggio)
def win_sample(t):
    # C major: C5 (523.25), E5 (659.25), G5 (783.99), C6 (1046.50)
    freqs = [523.25, 659.25, 783.99, 1046.50]
    sample = 0
    for i, freq in enumerate(freqs):
        delay = i * 0.1
        if t > delay:
            envelope = math.exp(-(t - delay) * 3.0)
            sample += math.sin(2 * math.pi * freq * (t - delay)) * envelope * 0.2
    return sample

# 4. Error (Low buzz)
def error_sample(t):
    freq = 150.0
    envelope = math.exp(-t * 10.0)
    # create a slightly square-like sound using harmonics
    val = math.sin(2 * math.pi * freq * t) + 0.5 * math.sin(2 * math.pi * freq * 3 * t)
    return val * envelope * 0.4

os.makedirs('assets/audio', exist_ok=True)
generate_wav('assets/audio/click.wav', 0.1, 44100, click_sample)
generate_wav('assets/audio/coin.wav', 0.5, 44100, coin_sample)
generate_wav('assets/audio/win.wav', 1.5, 44100, win_sample)
generate_wav('assets/audio/error.wav', 0.4, 44100, error_sample)

print("Generated custom professional sounds!")
