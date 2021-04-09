import 'dart:ui';

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

  HistoryItem.single(this.changeType, DrawItem drawItem): this.drawItems = [drawItem];

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

class DrawingContext {

  Color backgroundColor;

  DrawingContext(this.backgroundColor);
}