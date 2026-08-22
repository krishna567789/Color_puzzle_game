import 'dart:async';
import 'package:flutter/material.dart';

class LevelCompleteDialog extends StatefulWidget {
  final int level;
  final int coinsEarned;
  final int gemsEarned;
  final VoidCallback onNext;
  final VoidCallback onHome;

  const LevelCompleteDialog({
    super.key,
    required this.level,
    required this.coinsEarned,
    required this.gemsEarned,
    required this.onNext,
    required this.onHome,
  });

  @override
  State<LevelCompleteDialog> createState() => _LevelCompleteDialogState();
}

class _LevelCompleteDialogState extends State<LevelCompleteDialog> {
  int _currentFrame = 1;
  Timer? _timer;
  final int _totalFrames = 240; // Blender से रेंडर हुए कुल फ्रेम्स

  @override
  void initState() {
    super.initState();
    // 24 FPS (Frames Per Second) के लिए लगभग हर 41 मिलीसेकंड में फ्रेम बदलें
    _timer = Timer.periodic(const Duration(milliseconds: 41), (timer) {
      if (mounted) {
        setState(() {
          // 240 के बाद वापस 1 से शुरू (लूप)
          _currentFrame = (_currentFrame % _totalFrames) + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // फ्रेम का नाम 0001, 0002 के फॉर्मेट में बनाएं
    String frameName = _currentFrame.toString().padLeft(4, '0');
    String imagePath = 'assets/blender/complete_level/$frameName.png';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: 350,
        height: 520,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Blender Animation Background
            Positioned(
              top: 0,
              bottom: 0,
              left: -80, // बैकग्राउंड इमेजेज को फिट करने के लिए एडजस्टमेंट
              right: -80,
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                gaplessPlayback: true, // फ्रेम बदलते वक्त फ्लिकर (झपकी) न आए
              ),
            ),
            
            // 2. The UI Overlay (Flutter Widgets)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // Crown Placeholder
                const Icon(Icons.workspace_premium, color: Colors.amber, size: 70),
                
                // Ribbon Placeholder
                Container(
                  transform: Matrix4.translationValues(0, -10, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red[600],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[900]!, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 4)
                    ]
                  ),
                  child: Text(
                    'LEVEL ${widget.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // COMPLETE Text
                const Text(
                  'COMPLETE!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: Colors.black87, offset: Offset(2, 2), blurRadius: 4),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // You Earned Section
                const Text(
                  'YOU EARNED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                
                // Rewards Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                      const SizedBox(width: 6),
                      Text('+${widget.coinsEarned}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 25),
                      const Icon(Icons.diamond, color: Colors.purpleAccent, size: 28),
                      const SizedBox(width: 6),
                      Text('+${widget.gemsEarned}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 25),
                
                // NEXT Button
                ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64D224),
                    minimumSize: const Size(220, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  child: const Text('NEXT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                
                const SizedBox(height: 15),
                
                // HOME Button
                ElevatedButton(
                  onPressed: widget.onHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2490D2),
                    minimumSize: const Size(220, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  child: const Text('HOME', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                
                const SizedBox(height: 30),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
