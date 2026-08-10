import 'package:flutter/material.dart';
import '../models/tube_model.dart';

class TubeWidget extends StatelessWidget {
  final Tube tube;
  final bool isSelected;
  final VoidCallback onTap;

  const TubeWidget({
    super.key,
    required this.tube,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, isSelected ? -20.0 : 0.0, 0),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // The Glass Tube Outline
            Container(
              width: 50,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white54,
                  width: 2,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
            ),
            // The Liquid Inside
            Padding(
              padding: const EdgeInsets.all(3.0),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
                child: Container(
                  width: 44,
                  height: 174,
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Fill empty space if tube is not full
                      if (tube.colors.length < tube.capacity)
                        Expanded(
                          flex: tube.capacity - tube.colors.length,
                          child: Container(color: Colors.transparent),
                        ),
                      for (int i = tube.colors.length - 1; i >= 0; i--)
                        Expanded(
                          flex: 1,
                          child: Container(
                            width: double.infinity,
                            color: tube.colors[i],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Tube Rim
            Positioned(
              top: 0,
              child: Container(
                width: 56,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white70,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
