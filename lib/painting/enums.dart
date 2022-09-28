import 'package:draw_it/painting/models.dart';
import 'package:flutter/widgets.dart';

/*
 TODO
  some methods can be made enum fields once dart support anonymous functions
  as enum constructor parameter
 */

enum PaintTool {
  MOVE("move.svg", hasThickness: false),
  PENCIL("pencil.svg"),
  ERASER("eraser.svg"),
  LINE("line.svg"),
  RECTANGLE("rectangle.svg", fillable: true),
  OVAL("ellipse.svg", fillable: true);

  final String _imageFileName;
  final bool fillable;
  final bool hasThickness;

  const PaintTool(
    this._imageFileName, {
    this.fillable = false,
    this.hasThickness = true,
  });

  String get imagePath => "assets/drawables/" + _imageFileName;
}

enum ChangeType { PAINT, REMOVE }

enum PaintOption {
  FILLED("star_outline.svg", "star_filled.svg");

  final String _imageOffFileName;
  final String _imageOnFileName;

  const PaintOption(this._imageOffFileName, this._imageOnFileName);

  String get imageOffPath => "assets/drawables/" + _imageOffFileName;

  String get imageOnPath => "assets/drawables/" + _imageOnFileName;
}

enum PaintAction {
  UNDO("undo.svg"),
  REDO("redo.svg"),
  CLEAR("delete.svg"),
  RESET_POSITION("start_position.svg");

  final String _imageFileName;

  const PaintAction(this._imageFileName);

  String get imagePath => "assets/drawables/" + _imageFileName;
}

extension PaintToolProperties on PaintTool {
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

        path.addOval(
            Rect.fromCenter(center: startPoint, width: width, height: height));
        break;
    }
  }
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
