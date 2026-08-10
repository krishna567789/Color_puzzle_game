import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class TopPlayerBar extends StatelessWidget {
  const TopPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Player Info
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryButton.withValues(alpha: 0.2),
                  border: Border.all(color: AppColors.primaryButton, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 32), // Placeholder for avatar
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Player', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.goldCoin, size: 14),
                      const SizedBox(width: 4),
                      Text('Level 25', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.goldCoin, size: 14),
                      const SizedBox(width: 4),
                      Text('11:56', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          
          // Currency Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildCurrencyPill(Icons.monetization_on, AppColors.goldCoin, '12,560'),
              const SizedBox(height: 8),
              _buildCurrencyPill(Icons.diamond, AppColors.purpleGem, '850'),
            ],
          ),
          
          const SizedBox(width: 8),

          // Settings Gear
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 1),
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPill(IconData icon, Color iconColor, String amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(width: 12),
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.purpleGem,
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 14),
        )
      ],
    );
  }
}
