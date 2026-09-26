import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/audio_service.dart';
import '../core/storage_service.dart';
import '../core/play_games_service.dart';
import '../core/review_service.dart';
import '../core/haptic_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _vibrationEnabled = true;
  bool _colorblindPatterns = false;
  bool _leftHandedLayout = false;

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
    final patterns = await StorageService.getColorblindPatterns();
    final leftHanded = await StorageService.getLeftHandedLayout();
    setState(() {
      _musicEnabled = music;
      _sfxEnabled = sfx;
      _vibrationEnabled = vibration;
      _colorblindPatterns = patterns;
      _leftHandedLayout = leftHanded;
      _isSignedIn = PlayGamesService.isSignedIn;
    });
  }

  /// The accessibility switches are read by the game board when it is next
  /// opened, so the write has to land before the player leaves this screen.
  void _setColorblindPatterns(bool value) {
    setState(() => _colorblindPatterns = value);
    StorageService.setColorblindPatterns(value);
  }

  void _setLeftHandedLayout(bool value) {
    setState(() => _leftHandedLayout = value);
    StorageService.setLeftHandedLayout(value);
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildSettingTile('Music', Icons.music_note, _musicEnabled, (val) {
              setState(() => _musicEnabled = val);
              AudioService.toggleMusic(val);
            }),
            const SizedBox(height: 16),
            _buildSettingTile('Sound Effects', Icons.volume_up, _sfxEnabled, (
              val,
            ) {
              setState(() => _sfxEnabled = val);
              AudioService.toggleSfx(val);
            }),
            const SizedBox(height: 16),
            _buildSettingTile('Vibration', Icons.vibration, _vibrationEnabled, (
              val,
            ) {
              setState(() => _vibrationEnabled = val);
              HapticService.toggleVibration(val);
              HapticService.lightImpact(); // Test feedback
            }),
            const SizedBox(height: 24),
            const _SectionLabel('ACCESSIBILITY'),
            _buildSettingTile(
              'Layer Patterns',
              Icons.pattern,
              _colorblindPatterns,
              _setColorblindPatterns,
              subtitle: 'Each colour keeps its own shape',
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              'Left-Handed Controls',
              Icons.back_hand,
              _leftHandedLayout,
              _setLeftHandedLayout,
              subtitle: 'Keep the tools along the left edge',
            ),
            const SizedBox(height: 24),
            _buildActionTile(
              _isSignedIn ? 'Play Games Connected' : 'Sign in to Play Games',
              FontAwesomeIcons.google,
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
            const SizedBox(height: 16),
            _buildActionTile('Rate Us', Icons.star_rate, Colors.orange, () {
              ReviewService.openStoreListing();
            }),
            const SizedBox(height: 16),
            _buildActionTile('Share App', Icons.share, Colors.blueAccent, () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Check out this magical Color Puzzle Game! Can you '
                      'solve all the levels? Download it now!',
                  subject: 'Color Puzzle Game',
                ),
              );
            }),
            // A fixed gap, not a Spacer: this list scrolls now, and a flex child
            // in an unbounded column is an error rather than an alignment.
            const SizedBox(height: 32),
            const Text(
              'Version 1.1.0',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    String? subtitle,
  }) {
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
          const SizedBox(width: 16),
          // The label gets the space that is left, and wraps into it: a title
          // this side of a switch is what overflowed the smallest phone.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryButton,
            activeTrackColor: AppColors.primaryButton.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white24,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    dynamic icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(icon, color: iconColor, size: 28);
    } else {
      iconWidget = FaIcon(icon, color: iconColor, size: 28);
    }

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
            iconWidget,
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white24,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// The heading over a block of switches.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.primaryButton,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}
