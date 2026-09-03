import 'package:flutter/material.dart';

class Tube {
  final int capacity;
  final List<Color> colors;
  int hiddenCount;

  Tube({
    this.capacity = 4,
    List<Color>? initialColors,
    this.hiddenCount = 0,
  }) : colors = initialColors ?? [];

  bool get isFull => colors.length >= capacity;
  bool get isEmpty => colors.isEmpty;
  bool get isNotEmpty => colors.isNotEmpty;
  
  bool get isComplete {
    if (!isFull) return false;
    final firstColor = colors.first;
    for (final color in colors) {
      if (color != firstColor) return false;
    }
    return true;
  }
  
  Color? get topColor => colors.isNotEmpty ? colors.last : null;

  Tube copyWith({List<Color>? colors, int? hiddenCount}) {
    return Tube(
      capacity: capacity,
      initialColors: colors ?? List.from(this.colors),
      hiddenCount: hiddenCount ?? this.hiddenCount,
    );
  }
}
