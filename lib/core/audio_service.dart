import 'package:audioplayers/audioplayers.dart';
import 'storage_service.dart';

class AudioService {
  static final AudioPlayer _bgmPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();
  
  static bool _musicEnabled = true;
  static bool _sfxEnabled = true;

  static Future<void> init() async {
    _musicEnabled = await StorageService.getMusic();
    _sfxEnabled = await StorageService.getSfx();
    
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  static Future<void> playBGM() async {
    if (!_musicEnabled) return;
    try {
      await _bgmPlayer.play(AssetSource('audio/bgm.mp3'));
      await _bgmPlayer.setVolume(0.4);
    } catch (e) {
      // Silently fail if file missing
    }
  }

  static Future<void> stopBGM() async {
    await _bgmPlayer.stop();
  }

  static Future<void> pauseBGM() async {
    await _bgmPlayer.pause();
  }

  static Future<void> resumeBGM() async {
    if (_musicEnabled) {
      await _bgmPlayer.resume();
    }
  }

  static Future<void> playSfx(String fileName) async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      // Silently fail if file missing
    }
  }

  static Future<void> playPourSfx() async {
    await playSfx('pour.wav');
  }

  static Future<void> playWinSfx() async {
    // Using lock.wav as fallback if win.wav is missing
    await playSfx('lock.wav');
  }

  static Future<void> playClickSfx() async {
    await playSfx('lock.wav');
  }

  static Future<void> playCoinSfx() async {
    // Play lock.wav as coin sound if coin.wav is not present.
    await playSfx('lock.wav');
  }

  static void toggleMusic(bool enabled) {
    _musicEnabled = enabled;
    StorageService.setMusic(enabled);
    if (enabled) {
      playBGM();
    } else {
      stopBGM();
    }
  }

  static void toggleSfx(bool enabled) {
    _sfxEnabled = enabled;
    StorageService.setSfx(enabled);
  }
}
