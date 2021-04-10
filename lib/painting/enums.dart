import 'package:draw_it/painting/models.dart';
import 'package:flutter/widgets.dart';

enum PaintTool { MOVE, PENCIL, ERASER, LINE, RECTANGLE, OVAL }

enum ChangeType { PAINT, REMOVE }

enum PaintOption { FILLED }

enum PaintAction { UNDO, REDO, CLEAR, RESET_POSITION }

extension VisualPaintType on PaintTool {
  String get image {
    switch (this) {
      case PaintTool.PENCIL:
        return "pencil.svg";
      case PaintTool.ERASER:
        return "eraser.svg";
      case PaintTool.LINE:
        return "line.svg";
      case PaintTool.RECTANGLE:
        return "rectangle.svg";
      case PaintTool.OVAL:
        return "ellipse.svg";
      case PaintTool.MOVE:
        return "move.svg";
    }
  }

  String get imagePath => "assets/drawables/" + this.image;
}

extension PaintToolProperties on PaintTool {
  bool get fillable {
    switch (this) {
      case PaintTool.MOVE:
      case PaintTool.PENCIL:
      case PaintTool.ERASER:
      case PaintTool.LINE:
        return false;
      case PaintTool.RECTANGLE:
      case PaintTool.OVAL:
        return true;
    }
  }

  bool get hasThickness {
    switch (this) {
      case PaintTool.PENCIL:
      case PaintTool.ERASER:
      case PaintTool.LINE:
      case PaintTool.RECTANGLE:
      case PaintTool.OVAL:
        return true;
      case PaintTool.MOVE:
        return false;
    }
  }

  Paint setupPaint(Paint paint, DrawingState state) {
    // ignore: missing_enum_constant_in_switch
    switch (this) {

      case PaintTool.PENCIL:
        continue stroke_painting;
      case PaintTool.ERASER:
        paint.color = state.backgroundColor;
        continue stroke_painting;
      stroke_painting:
      case PaintTool.LINE:
        paint.style = PaintingStyle.stroke;
        break;
    }

    return paint;
  }

  void drawPath(Path path, Offset startPoint, Offset otherPoint) {
    // ignore: missing_enum_constant_in_switch
    switch (this) {

      case PaintTool.PENCIL:
      case PaintTool.ERASER:
        break;
      case PaintTool.LINE:
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(otherPoint.dx, otherPoint.dy);
        break;
      case PaintTool.RECTANGLE:
        path.addRect(Rect.fromPoints(startPoint, otherPoint));
        break;
      case PaintTool.OVAL:
        var width = (otherPoint.dx - startPoint.dx) * 2;
        var height = (otherPoint.dy - startPoint.dy) * 2;

        path.addOval(Rect.fromCenter(center: startPoint, width: width, height: height));
        break;
    }
  }
}

extension VisualPaintOption on PaintOption {
  String get _imageOff {
    switch (this) {
      case PaintOption.FILLED:
        return "star_outline.svg";
    }
  }

  String get _imageOn {
    switch (this) {
      case PaintOption.FILLED:
        return "star_filled.svg";
    }
  }

  String get imageOffPath => "assets/drawables/" + this._imageOff;

  String get imageOnPath => "assets/drawables/" + this._imageOn;
}

extension VisualPaintAction on PaintAction {
  String get image {
    switch (this) {
      case PaintAction.UNDO:
        return "undo.svg";
      case PaintAction.REDO:
        return "redo.svg";
      case PaintAction.CLEAR:
        return "delete.svg";
      case PaintAction.RESET_POSITION:
        return "start_position.svg";
    }
  }

  String get imagePath => "assets/drawables/" + this.image;
}

extension PaintOptionModification on PaintOption {
  Paint setupPaint(Paint paint, DrawingState state, bool value) {
    switch (this) {
      case PaintOption.FILLED:
        paint.style = value ? PaintingStyle.fill : PaintingStyle.stroke;
        break;
    }

    return paint;
  }
}

extension PaintActionModifier on PaintAction {

  void _undoLast(DrawingState drawingState) {
    if (drawingState.undo.isEmpty) return;

    var lastItem = drawingState.undo.removeLast();

    HistoryItem redoItem = lastItem.toRedo();

    drawingState.redo.add(redoItem);
    _addOrRemoveItems(drawingState, lastItem);
  }

  void _redoLast(DrawingState drawingState) {
    if (drawingState.redo.isEmpty) return;

    var lastItem = drawingState.redo.removeLast();

    HistoryItem undoItem = lastItem.toUndo();

    drawingState.undo.add(undoItem);
    _addOrRemoveItems(drawingState, lastItem);
  }

  void _addOrRemoveItems(DrawingState drawingState, HistoryItem historyItem) {
    var toDraw = drawingState.toDraw;
    switch (historyItem.changeType) {
      case ChangeType.PAINT:
        toDraw.removeRange(
            toDraw.length - historyItem.drawItems.length, toDraw.length);
        break;
      case ChangeType.REMOVE:
        toDraw.addAll(historyItem.drawItems);
        break;
    }
  }

  void _clearCanvas(DrawingState drawingState) {
    drawingState.undo.clear();
    drawingState.redo.clear();

    drawingState.undo.add(HistoryItem(ChangeType.REMOVE, drawingState.toDraw));
    drawingState.toDraw = [];
  }

  void onPressed(DrawingState drawingState) {
    switch (this) {

      case PaintAction.UNDO:
        _undoLast(drawingState);
        break;
      case PaintAction.REDO:
        _redoLast(drawingState);
        break;
      case PaintAction.CLEAR:
        _clearCanvas(drawingState);
        break;
      case PaintAction.RESET_POSITION:
        drawingState.transform = Matrix4.identity();
        break;
    }
  }

  bool isEnabled(DrawingState drawingState) {

    switch (this) {

      case PaintAction.UNDO:
        return drawingState.undo.isNotEmpty;
      case PaintAction.REDO:
        return drawingState.redo.isNotEmpty;
      case PaintAction.CLEAR:
        return drawingState.toDraw.isNotEmpty;
      case PaintAction.RESET_POSITION:
        return !drawingState.transform.isIdentity();
    }
  }
}