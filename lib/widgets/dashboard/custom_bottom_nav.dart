import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 24, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_filled, 'Home'),
          _buildNavItem(1, Icons.leaderboard, 'Levels'),
          _buildNavItem(2, Icons.science, 'Play', isCenter: true),
          _buildNavItem(3, Icons.bar_chart, 'Stats'),
          _buildNavItem(4, Icons.person, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool isCenter = false}) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? AppColors.bottomNavSelected : AppColors.bottomNavUnselected;

    return GestureDetector(
      onTap: () => onItemSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: isCenter ? 36 : 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          )
        ],
      ),
    );
  }
}
