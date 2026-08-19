import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import '../core/app_colors.dart';
import '../widgets/common/game_button.dart';

class LevelCompleteScreen extends StatefulWidget {
  final int stars;
  final int coinsEarned;
  final int moves;
  final String timeTaken;
  final VoidCallback onNextLevel;
  final VoidCallback onRestart;

  const LevelCompleteScreen({
    super.key,
    required this.stars,
    required this.coinsEarned,
    required this.moves,
    required this.timeTaken,
    required this.onNextLevel,
    required this.onRestart,
  });

  @override
  State<LevelCompleteScreen> createState() => _LevelCompleteScreenState();
}

class _LevelCompleteScreenState extends State<LevelCompleteScreen> {
  SMINumber? _starInput;

  void _onRiveInit(Artboard artboard) {
    // Standard Rive rating files often use 'State Machine 1' and 'Rating' input
    final controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (controller != null) {
      artboard.addController(controller);
      _starInput = controller.findInput<double>('Rating') as SMINumber?;
      
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _starInput != null) {
          _starInput!.value = widget.stars.toDouble();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Background Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.7)),
            ),
          ),
          
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.primaryButton.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(color: AppColors.primaryButton.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FANTASTIC!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'LEVEL COMPLETED',
                    style: TextStyle(color: AppColors.primaryButton, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  
                  // Rive Animation
                  SizedBox(
                    height: 180,
                    child: RiveAnimation.asset(
                      'assets/rive/finalRatingStar.riv',
                      onInit: _onRiveInit,
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Reward
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: AppColors.goldCoin, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '+${widget.coinsEarned}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(Icons.touch_app, 'MOVES', widget.moves.toString()),
                      _buildStatItem(Icons.timer, 'TIME', widget.timeTaken),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Buttons
                  GameButton(
                    width: double.infinity,
                    onTap: widget.onNextLevel,
                    child: const Text('NEXT LEVEL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: widget.onRestart,
                    child: const Text('REPLAY', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
