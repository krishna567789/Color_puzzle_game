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
      padding: const EdgeInsets.only(top: 12, bottom: 20, left: 8, right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF080B1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, 'Home'),
          _buildNavItem(1, Icons.grid_view_rounded, 'Levels'),
          _buildNavItem(2, Icons.science_rounded, 'Play', isCenter: true),
          _buildNavItem(3, Icons.bar_chart_rounded, 'Stats'),
          _buildNavItem(4, Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool isCenter = false}) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? AppColors.bottomNavSelected : AppColors.bottomNavUnselected;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onItemSelected(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isSelected ? 8 : 0),
            decoration: isSelected ? BoxDecoration(
              color: AppColors.bottomNavSelected.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bottomNavSelected.withValues(alpha: 0.2)),
            ) : null,
            child: Icon(
              icon,
              color: color,
              size: isCenter ? 32 : 26,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(color: AppColors.bottomNavSelected, shape: BoxShape.circle),
            )
          else
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.normal),
            )
        ],
      ),
    );
  }
}
