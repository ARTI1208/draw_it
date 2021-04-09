import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:draw_it/painting/buttons.dart';
import 'package:draw_it/painting/color_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as fcp;
import 'package:gesture_x_detector/gesture_x_detector.dart';
import 'package:matrix4_transform/matrix4_transform.dart';

import 'package:draw_it/painting/enums.dart';
import 'package:draw_it/extensions/collections.dart';
import 'package:draw_it/painting/models.dart';

class PainterWidget extends StatefulWidget {
  PainterWidget({Key? key}) : super(key: key);

  @override
  PainterState createState() => PainterState();
}

class PainterState extends State<PainterWidget> {
  Color color = Colors.black;

  double strokeWidth = 5;

  bool filled = true;

  List<DrawItem> toDraw = [];

  List<HistoryItem> redo = [];
  List<HistoryItem> undo = [];

  PaintTool _paintTool = PaintTool.MOVE;

  DrawingContext drawingContext = DrawingContext(Colors.white);

  Offset? shapeStart;

  Offset moveStart = Offset.zero;
  Offset moveOffset = Offset.zero;
  double scale = 1;
  double scaleStart = 1;
  double angleStart = 0;
  double angle = 3 * pi / 2;

  Offset fp = Offset.zero;
  Offset lastFp = Offset.zero;

  static const double minScale = 0.05;
  static const double maxScale = 10;

  GlobalKey _paintingAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Path path = Path()
    //   ..moveTo(10, 10)
    //   ..lineTo(200, 200);
    //
    // toDraw.add(Tuple2(path, linePaint));
  }

  void draw(DrawItem item, {bool removeLastUndo = false}) {
    toDraw.add(item);

    HistoryItem historyItem = HistoryItem.single(ChangeType.PAINT, item);

    if (removeLastUndo) {
      undo.safeLast = historyItem;
    } else {
      undo.add(historyItem);
    }
  }

  Paint get basePaint {
    return Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth / scale
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke;
  }

  Offset toActualPosition(Offset position, { bool translate = true,
    bool rotate = true, bool scaled = true, Offset? pivot
  }) {
    Offset pos = position;

    if (translate) {
      // Offset actualMoveOffset = toActualPosition(moveOffset, translate: false);
      Offset actualMoveOffset = -moveOffset;

      pos = pos.translate(actualMoveOffset.dx, actualMoveOffset.dy);
    }

    if (rotate) {
      Offset actualPivot = pivot ?? moveStart;

      double newX = actualPivot.dx +
          (pos.dx - actualPivot.dx) * cos(angle) +
          (pos.dy - actualPivot.dy) * sin(angle);

      double newY = actualPivot.dy -
          (pos.dx - actualPivot.dx) * sin(angle) +
          (pos.dy - actualPivot.dy) * cos(angle);

      pos = Offset(newX, newY);
    }

    if (scaled) {
      pos = pos.scale(1 / scale, 1 / scale);
    }

    return pos;
  }

  List<Offset> continuousPoints = [];

  void onStartContinuousDrawing(MoveEvent details) {
    shapeStart = applyOffsetTransformations(details.localPos);
    continuousPoints = [];
    Offset actualPosition = details.localPos;

    Path path = Path()..moveTo(actualPosition.dx, actualPosition.dy);

    var data = DrawItem(path, _paintTool.setupPaint(basePaint, drawingContext));

    setState(() {
      draw(data);
    });
  }

  void onStartShapeDraw(MoveEvent details) {
    // shapeStart = toActualPosition(details.localPos, rotate: false, translate: false);
    shapeStart = details.localPos;
    Path path = Path();
    draw(DrawItem(path, _paintTool.setupPaint(basePaint, drawingContext)));
  }

  void onStopDraw() {
    // shapeStart = null;
    //
    // Path path = toDraw.last.path;
    //
    // if (path.computeMetrics().isEmpty) {
    //   toDraw.removeLast();
    // }
  }

  Path applyPathTransformations(Path path) {
    Matrix4 matrix4 = Matrix4Transform()
    // .translateOffset(-moveOffset)
        .rotate(-angle)
        .scale(1 / scale, origin: fp)
        .matrix4;

    return path.transform(matrix4.storage);
  }

  Offset applyOffsetTransformations(Offset offset) {
    bool globalTranslate = true;
    bool globalRotate = false;
    bool globalScale = false;

    return toActualPosition(offset, translate: globalTranslate, rotate: globalRotate, scaled: globalScale);
  }

  void updateContinuousDrawing(MoveEvent details) {
    DrawItem lastItem = toDraw.last;

    Offset actualStart = shapeStart!;
    continuousPoints.add(applyOffsetTransformations(details.localPos));

    Path linePath = lastItem.path;

    linePath.reset();
    linePath.moveTo(actualStart.dx, actualStart.dy);

    for (var point in continuousPoints) {
      linePath.lineTo(point.dx, point.dy);
    }

    // linePath.lineTo(actualPosition.dx, actualPosition.dy);
    Path resultPath = applyPathTransformations(linePath);

    var data = DrawItem(resultPath, lastItem.paint);

    setState(() {
      toDraw.last = data;
    });
  }

  void updateShape(MoveEvent details) {
    
    Offset? shapeStartPoint = shapeStart;
    if (shapeStartPoint == null) return;
    
    Path linePath = toDraw.last.path;
    linePath.reset();

    Offset actualPosition = applyOffsetTransformations(details.localPos);
    Offset actualStart = applyOffsetTransformations(shapeStartPoint);


    debugPrint("Orig: " + shapeStartPoint.toString() + "|||" + details.localPos.toString());
    debugPrint("Act: " + actualStart.toString() + "|||" + actualPosition.toString());

    _paintTool.drawPath(linePath, actualStart, actualPosition);

    Path resultPath = applyPathTransformations(linePath);
    // resultPath = linePath;

    Paint paint = toDraw.removeLast().paint;

    var data = DrawItem(resultPath, paint);

    setState(() {
      draw(data, removeLastUndo: true);
    });
  }

  void onMoveStart(MoveEvent details) {
    moveStart = toActualPosition(details.localPos, translate: false, rotate: false);
    // moveOffset = toActualPosition(moveOffset, translate: false, rotate: true);
  }

  void onMove(MoveEvent details) {
    // stdout.writeln("moveUpd");

    Offset delta = details.localDelta;

    // debugPrint(DateTime.now().toString() + ": " + delta.toString());

    setState(() {
      moveOffset += delta;
      // lastFp = toActualPosition(details.localPos);
    });
  }

  void onScaleStart(Offset focalPoint) {
    // stdout.writeln("scaleStart");
    moveStart = focalPoint;
    fp = focalPoint;
    lastFp = focalPoint;
  }

  void onScaleEnd() {
    // stdout.writeln("scaleEnd");
    scaleStart = scale;
    angleStart = angle;
  }

  void onScale(ScaleEvent details) {
    // stdout.writeln("scaleUpd");
    //
    // stdout.writeln("fp: ${details.focalPoint.dx}; ${details.focalPoint.dy}");

    double newScale = scaleStart + details.scale - 1;

    if (newScale < minScale) {
      newScale = minScale;
    }

    setState(() {
      // fp = details.focalPoint;
      scale = newScale;
      angle = angleStart - details.rotationAngle;

      moveOffset = toActualPosition(moveOffset, translate: false);
      // lastFp += details.focalPoint;
    });
  }

  Future<Color> _showColorPickerDialog() async {
    Color newColor = color;

    Widget colorPicker = fcp.ColorPicker(
        pickerColor: color,
        onColorChanged: (color) {
          newColor = color;
        });

    return showModalBottomSheet<Color>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return Padding(
            padding: EdgeInsets.all(20),
            child: Wrap(
              children: [colorPicker],
            ),
          );
        }).then((value) => value ?? newColor);
  }

  Widget createDivider(bool vertical) {
    if (vertical) {
      return Container(
        height: 30,
        width: 30,
        child: VerticalDivider(
          thickness: 1,
          color: Colors.black87,
        ),
      );
    } else {
      return Container(
        height: 30,
        width: 30,
        child: Divider(
          thickness: 1,
          color: Colors.black87,
        ),
      );
    }
  }

  bool isThicknessAvailable() {
    return _paintTool.hasThickness && !(_paintTool.fillable && filled);
  }

  @override
  Widget build(BuildContext context) {
    bool isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    Axis direction = isPortrait ? Axis.vertical : Axis.horizontal;
    Axis crossDirection = isPortrait ? Axis.horizontal : Axis.vertical;

    LineSide lineSide = isPortrait ? LineSide.BOTTOM : LineSide.RIGHT;

    List<Widget> buttons = <Widget>[
          GestureDetector(
            onTap: () async {
              Color newColor = await _showColorPickerDialog();

              // stdout.writeln("PaintColor: picker closed");

              if (newColor == color) return;

              setState(() {
                // stdout.writeln("PaintColor: apply new color");
                color = newColor;
              });
            },
            child: Padding(
              padding: isPortrait ? EdgeInsets.only(left: 10) : EdgeInsets.only(top: 10),
              child: RepaintColorIndicator(
                color,
                height: 30,
                width: 30,
              ),
            )
    ),
          createDivider(isPortrait),
          ActionButton(
              paintAction: PaintAction.UNDO,
              enabled: undo.isNotEmpty,
              // enabled: true,
              onPressed: () {
                if (undo.isEmpty) return;

                var lastItem = undo.removeLast();

                HistoryItem redoItem = lastItem.toRedo();

                setState(() {
                  redo.add(redoItem);

                  switch (lastItem.changeType) {
                    case ChangeType.PAINT:
                      toDraw.removeRange(toDraw.length - lastItem.drawItems.length, toDraw.length);
                      break;
                    case ChangeType.REMOVE:
                      toDraw.addAll(redoItem.drawItems);
                      break;
                  }
                });
              }),
          ActionButton(
              paintAction: PaintAction.REDO,
              enabled: redo.isNotEmpty,
              // enabled: true,
              onPressed: () {
                if (redo.isEmpty) return;

                var lastItem = redo.removeLast();

                HistoryItem undoItem = lastItem.toUndo();

                setState(() {
                  undo.add(undoItem);

                  switch (lastItem.changeType) {
                    case ChangeType.PAINT:
                      toDraw.removeRange(toDraw.length - lastItem.drawItems.length, toDraw.length);
                      break;
                    case ChangeType.REMOVE:
                      toDraw.addAll(undoItem.drawItems);
                      break;
                  }
                });
              }),
          ActionButton(
            paintAction: PaintAction.CLEAR,
            enabled: toDraw.isNotEmpty,
            // enabled: true,
            onPressed: () {
              setState(() {
                undo.clear();
                redo.clear();

                undo.add(HistoryItem(ChangeType.REMOVE, toDraw));
                toDraw = [];
              });
            },
          ),
          ActionButton(
            paintAction: PaintAction.CLEAR,
            onPressed: () {
              setState(() {
                moveOffset = Offset.zero;
                moveStart = Offset.zero;
                scale = 1;
                scaleStart = 1;
                angle = 0;
                angleStart = 0;
              });
            },
          ),
          createDivider(isPortrait),
          OptionCheckButton(
              buttonOption: PaintOption.FILLED,
              selected: filled,
              selectedColor: color,
              onOptionChanged: (newValue) {
                setState(() {
                  filled = newValue;
                });
              }),
          createDivider(isPortrait),
        ] +
        List.generate(
          PaintTool.values.length,
          (index) {
            PaintTool type = PaintTool.values[index];

            double insetSize = 2.5;
            EdgeInsets insets = isPortrait
                ? EdgeInsets.symmetric(horizontal: insetSize)
                : EdgeInsets.symmetric(vertical: insetSize);

            return Padding(
                padding: insets,
                child: ToolRadioButton(
                  buttonType: type,
                  selectedType: _paintTool,
                  selectedColor: color,
                  lineSide: lineSide,
                  onTypeSelected: (newType) {
                    setState(() {
                      _paintTool = newType;
                    });
                  },
                ));
          },
        );

    Widget scaleSlider = RotatedBox(
        quarterTurns: isPortrait ? 0 : -1,
        child: Slider(
            value: scale,
            min: 0.1,
            max: 10.0,
            onChanged: (newValue) {
              setState(() {
                scale = newValue;
                // moveOffset = toActualPosition(moveOffset, translate: false);
              });
            }));

    Widget rotateSlider = RotatedBox(
        quarterTurns: isPortrait ? 0 : -1,
        child: Slider(
            value: angle,
            min: 0,
            max: 2 * pi,
            onChanged: (newValue) {
              setState(() {
                angle = newValue;
                // moveOffset = toActualPosition(moveOffset, translate: false);
              });
            }));

    Widget thicknessSlider = RotatedBox(
        quarterTurns: isPortrait ? 0 : -1,
        child: Slider(
            value: strokeWidth,
            min: 0.0,
            max: 50.0,
            onChanged: (newValue) {
              setState(() {
                strokeWidth = newValue;
              });
            }));

    Widget drawingWidget = XGestureDetector(
      onMoveStart: (details) {

        switch (_paintTool) {
          case PaintTool.PENCIL:
          case PaintTool.ERASER:
            onStartContinuousDrawing(details);
            break;
          case PaintTool.LINE:
          case PaintTool.RECTANGLE:
          case PaintTool.OVAL:
            onStartShapeDraw(details);
            break;
          case PaintTool.MOVE:
            onMoveStart(details);
            return;
        }

        redo.clear();
      },
      onMoveEnd: (_) => onStopDraw(),
      onMoveUpdate: (details) {
        switch (_paintTool) {
          case PaintTool.PENCIL:
          case PaintTool.ERASER:
            updateContinuousDrawing(details);
            break;
          case PaintTool.LINE:
          case PaintTool.RECTANGLE:
          case PaintTool.OVAL:
            updateShape(details);
            break;
          case PaintTool.MOVE:
            onMove(details);
            break;
        }
      },
      onScaleStart: (focalPoint) {
        if (_paintTool == PaintTool.MOVE) {
          onScaleStart(focalPoint);
        }
      },
      onScaleEnd: () {
        if (_paintTool == PaintTool.MOVE) {
          onScaleEnd();
        }
      },
      onScaleUpdate: (details) {
        if (_paintTool == PaintTool.MOVE) {
          onScale(details);
        }
      },
      child: CustomPaint(
        key: _paintingAreaKey,
        painter: DrawPainter(
            toDraw, moveOffset, scale, angle, _paintingAreaKey, lastFp),
      ),
    );

    EdgeInsets buttonInsets = EdgeInsets.symmetric(horizontal: 5, vertical: 5);

    List<Widget> rootChildren = <Widget>[
      Expanded(
          child: DecoratedBox(
              decoration: BoxDecoration(color: drawingContext.backgroundColor),
              child: drawingWidget)),
      DecoratedBox(
          decoration:
              BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
          child: Flex(
            direction: direction,
            children: [
              scaleSlider,
              rotateSlider,
              if (isThicknessAvailable()) thicknessSlider,
              SingleChildScrollView(
                scrollDirection: crossDirection,
                padding: buttonInsets,
                child: Material(
                    type: MaterialType.transparency,
                    child: Flex(direction: crossDirection, children: buttons)),
              ),
            ],
          )),
    ];

    return Flex(
      direction: direction,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rootChildren,
    );
  }
}

class DrawPainter extends CustomPainter {
  List<DrawItem> data;

  Offset moveOffset;
  Offset fp;
  GlobalKey widgetKey;
  double scale;
  double angle;

  static bool added = false;

  DrawPainter(this.data, this.moveOffset, this.scale, this.angle,
      this.widgetKey, this.fp);

  @override
  void paint(Canvas canvas, Size size) {
    // canvas.translate(moveOffset.dx, moveOffset.dy);
    // canvas.translate(fp.dx, fp.dy);

    Offset pivot = Offset.zero;

    if (!added) {
      added = true;
      Size? s = widgetKey.currentContext?.size;
      if (s != null) {
        pivot = Offset(s.width / 2, s.height / 2);

        Path path = Path()
          ..addRect(Rect.fromLTWH(10, 10, s.width - 35, s.height - 35))
        ;

        Paint paint = Paint()
          ..strokeWidth = 5
          ..color = Colors.black
          ..style = PaintingStyle.stroke;

        data.insert(0, DrawItem(path, paint));
      }
    }

    pivot = fp;

    // debugPrint("Pivot: " + pivot.toString());
    //
    // Size? s = widgetKey.currentContext?.size;
    // if (s != null) {
    //   debugPrint("Size: " + s.toString());
    // }

    // canvas.translate(-pivot.dx, -pivot.dy);
    // canvas.rotate(angle);
    // canvas.translate(pivot.dx, pivot.dy);

    Matrix4 matrix4 = Matrix4Transform()
        .translateOffset(moveOffset)
        .rotate(angle, origin: pivot)
        .scale(scale, origin: pivot)
        .matrix4;

    canvas.transform(matrix4.storage);

    // canvas.translate(fp.dx, fp.dy);

    // canvas.translate(fp.dx / scale, fp.dy / scale);
    //
    // canvas.scale(scale);

    for (DrawItem entry in data) {
      canvas.drawPath(entry.path, entry.paint);
    }

    // canvas.translate(-fp.dx, -fp.dy);
  }

  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) => true;
}

