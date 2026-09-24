import 'package:audioplayers/audioplayers.dart';
import 'storage_service.dart';

class AudioService {
  static late final AudioPlayer _bgmPlayer;
  static late final AudioPlayer _sfxPlayer;

  static bool _musicEnabled = true;
  static bool _sfxEnabled = true;

  /// The players are only safe to touch once [init] has run, because creating
  /// an `AudioPlayer` talks to the platform plugin.
  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> init() async {
    if (_ready) return;
    _bgmPlayer = AudioPlayer();
    _sfxPlayer = AudioPlayer();
    _musicEnabled = await StorageService.getMusic();
    _sfxEnabled = await StorageService.getSfx();

    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _ready = true;
  }

  static Future<void> playBGM() async {
    if (!_ready || !_musicEnabled) return;
    try {
      await _bgmPlayer.play(AssetSource('audio/bgm.mp3'));
      await _bgmPlayer.setVolume(0.4);
    } catch (e) {
      // Silently fail if file missing
    }
  }

  static Future<void> stopBGM() async {
    if (!_ready) return;
    await _bgmPlayer.stop();
  }

  static Future<void> pauseBGM() async {
    if (!_ready) return;
    await _bgmPlayer.pause();
  }

  static Future<void> resumeBGM() async {
    if (!_ready || !_musicEnabled) return;
    await _bgmPlayer.resume();
  }

  static Future<void> playSfx(String fileName) async {
    if (!_ready || !_sfxEnabled) return;
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
    await playSfx('win.wav');
  }

  static Future<void> playClickSfx() async {
    await playSfx('click.wav');
  }

  static Future<void> playCoinSfx() async {
    await playSfx('coin.wav');
  }

  static Future<void> playErrorSfx() async {
    await playSfx('error.wav');
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
