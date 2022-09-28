import 'package:flutter/material.dart';

import 'enums.dart';

class DrawItem {
  final Path path;
  final Paint paint;

  DrawItem(this.path, this.paint);
}

class HistoryItem {
  final ChangeType changeType;
  final List<DrawItem> drawItems;

  HistoryItem(this.changeType, this.drawItems);

  HistoryItem.single(this.changeType, DrawItem drawItem)
      : this.drawItems = [drawItem];

  // While we have only 2 types..
  HistoryItem _flipType() {
    switch (changeType) {
      case ChangeType.PAINT:
        return withItem1(ChangeType.REMOVE);
      case ChangeType.REMOVE:
        return withItem1(ChangeType.PAINT);
    }
  }

  HistoryItem toRedo() {
    return _flipType();
  }

  HistoryItem toUndo() {
    return _flipType();
  }

  HistoryItem withItem1(ChangeType newType) {
    return HistoryItem(newType, drawItems);
  }

  HistoryItem withItem2(List<DrawItem> newItems) {
    return HistoryItem(changeType, newItems);
  }
}

class DrawingState {
  Color color = Colors.black;

  double strokeWidth = 5;

  List<DrawItem> toDraw = [];

  List<HistoryItem> undo = [];
  List<HistoryItem> redo = [];

  Color backgroundColor = Colors.white;

  Offset shapeStart = Offset.zero;

  Matrix4 transform = Matrix4.identity();

  Color get nonWhiteColor => ColorTools.nonWhiteColor(color);
}

abstract class ColorTools {
  static final double maximumLightness = 0.8;

  static Color nonWhiteColor(Color originalColor) {
    HSLColor backgroundColor = HSLColor.fromColor(originalColor);
    return (backgroundColor.lightness > maximumLightness
            ? backgroundColor.withLightness(maximumLightness)
            : backgroundColor)
        .toColor();
  }
}
