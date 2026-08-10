import 'package:flutter/material.dart';

class Tube {
  final int capacity;
  final List<Color> colors;

  Tube({
    this.capacity = 4,
    List<Color>? initialColors,
  }) : colors = initialColors ?? [];

  bool get isFull => colors.length >= capacity;
  bool get isEmpty => colors.isEmpty;
  
  Color? get topColor => colors.isNotEmpty ? colors.last : null;

  Tube copyWith({List<Color>? colors}) {
    return Tube(
      capacity: capacity,
      initialColors: colors ?? List.from(this.colors),
    );
  }
}
