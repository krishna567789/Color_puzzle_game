import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/audio_service.dart';
import '../core/storage_service.dart';
import '../core/play_games_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  bool _isSignedIn = false;

  Future<void> _loadSettings() async {
    final music = await StorageService.getMusic();
    final sfx = await StorageService.getSfx();
    final vibration = await StorageService.getVibration();
    setState(() {
      _musicEnabled = music;
      _sfxEnabled = sfx;
      _vibrationEnabled = vibration;
      _isSignedIn = PlayGamesService.isSignedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SETTINGS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildSettingTile(
              'Music',
              Icons.music_note,
              _musicEnabled,
              (val) {
                setState(() => _musicEnabled = val);
                AudioService.toggleMusic(val);
              },
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              'Sound Effects',
              Icons.volume_up,
              _sfxEnabled,
              (val) {
                setState(() => _sfxEnabled = val);
                AudioService.toggleSfx(val);
              },
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              'Vibration',
              Icons.vibration,
              _vibrationEnabled,
              (val) {
                setState(() => _vibrationEnabled = val);
                StorageService.setVibration(val);
              },
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              _isSignedIn ? 'Play Games Connected' : 'Sign in to Play Games',
              Icons.games,
              _isSignedIn ? Colors.green : AppColors.primaryButton,
              () async {
                if (!_isSignedIn) {
                  bool success = await PlayGamesService.signIn();
                  if (success) {
                    setState(() {
                      _isSignedIn = true;
                    });
                  }
                }
              },
            ),
            if (_isSignedIn) ...[
              const SizedBox(height: 16),
              _buildActionTile(
                'Leaderboard',
                Icons.leaderboard,
                AppColors.primaryButton,
                () {
                  PlayGamesService.showLeaderboards();
                },
              ),
            ],
            const Spacer(),
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(String title, IconData icon, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryButton, size: 28),
          const SizedBox(width: 20),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryButton,
            activeTrackColor: AppColors.primaryButton.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}
