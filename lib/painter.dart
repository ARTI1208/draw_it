import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as fcp;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gesture_x_detector/gesture_x_detector.dart';
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:tuple/tuple.dart';

class PainterWidget extends StatefulWidget {
  PainterWidget({Key? key}) : super(key: key);

  @override
  PainterState createState() => PainterState();
}

enum PaintType { MOVE, PENCIL, ERASER, LINE, RECTANGLE, OVAL }

enum ChangeType { PAINT, REMOVE }

enum PaintOption { FILLED }

enum PaintAction { UNDO, REDO, CLEAR, CLEAR_MODS }

extension VisualPaintType on PaintType {
  String get image {
    switch (this) {
      case PaintType.PENCIL:
        return "pencil.svg";
      case PaintType.ERASER:
        return "eraser.svg";
      case PaintType.LINE:
        return "line.svg";
      case PaintType.RECTANGLE:
        return "rectangle.svg";
      case PaintType.OVAL:
        return "ellipse.svg";
      case PaintType.MOVE:
        return "move.svg";
    }
  }

  String get imagePath => "assets/drawables/" + this.image;
}

extension StatePaintControlled on PaintType {
  bool get fillable {
    switch (this) {
      case PaintType.PENCIL:
        return false;
      case PaintType.ERASER:
        return false;
      case PaintType.LINE:
        return false;
      case PaintType.RECTANGLE:
        return true;
      case PaintType.OVAL:
        return true;
      case PaintType.MOVE:
        return false;
    }
  }

  bool get hasThickness {
    switch (this) {
      case PaintType.PENCIL:
        return true;
      case PaintType.ERASER:
        return true;
      case PaintType.LINE:
        return true;
      case PaintType.RECTANGLE:
        return true;
      case PaintType.OVAL:
        return true;
      case PaintType.MOVE:
        return false;
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
      case PaintAction.CLEAR_MODS:
        return "delete.svg";
    }
  }

  String get imagePath => "assets/drawables/" + this.image;
}

extension PathOffsetExtension on Path {
  void moveTo(Offset offset) {
    this.moveTo(offset.dx, offset.dy);
  }

  void lineTo(Offset offset) {
    this.lineTo(offset.dx, offset.dy);
  }
}

extension ExtendedList<E> on List<E> {

  set safeLast(E newLast) {
    if (isEmpty) {
      add(newLast);
    } else {
      this[length - 1] = newLast;
    }
  }
}

mixin Alias {}

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

class PainterState extends State<PainterWidget> {
  Color color = Colors.black;
  HSVColor hsvColor = HSVColor.fromColor(Colors.black);

  double strokeWidth = 5;

  bool filled = true;

  List<DrawItem> toDraw = [];

  List<HistoryItem> redo = [];
  List<HistoryItem> undo = [];

  PaintType _paintType = PaintType.MOVE;

  Color backgroundColor = Colors.white;

  Offset? shapeStart;

  Offset moveStart = Offset.zero;
  Offset moveOffset = Offset.zero;
  double scale = 1;
  double scaleStart = 1;
  double angleStart = 0;
  double angle = 0;

  Offset fp = Offset.zero;
  Offset lastFp = Offset.zero;

  static const double minScale = 0.05;

  Random random = new Random();

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

  void onStartErase(MoveEvent details) {
    Paint paint = linePaint..color = backgroundColor;

    Offset actualPosition = toActualPosition(details.localPos);

    Path path = Path()..moveTo(actualPosition.dx, actualPosition.dy);

    setState(() {
      draw(DrawItem(path, paint));
    });
  }

  void onErase(MoveEvent details) {
    Path linePath = toDraw.last.path;
    Offset actualPosition = toActualPosition(details.localPos);

    setState(() {
      linePath.lineTo(actualPosition.dx, actualPosition.dy);
    });
  }

  Paint get basePaint {
    return Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth / scale
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke;
  }

  Paint get linePaint {
    return basePaint..style = PaintingStyle.stroke;
  }

  Offset toActualPosition(Offset position, [bool rotate = true]) {
    Offset pos = position.translate(-moveOffset.dx, -moveOffset.dy);

    if (rotate) {
      double newX = moveStart.dx +
          (pos.dx - moveStart.dx) * cos(angle) +
          (pos.dy - moveStart.dy) * sin(angle);

      double newY = moveStart.dy -
          (pos.dx - moveStart.dx) * sin(angle) +
          (pos.dy - moveStart.dy) * cos(angle);

      pos = Offset(newX, newY);
    }

    return pos.scale(1 / scale, 1 / scale);
  }

  void onStartPencilDraw(MoveEvent details) {
    Offset actualPosition = toActualPosition(details.localPos);

    Path path = Path()..moveTo(actualPosition.dx, actualPosition.dy);

    var data = DrawItem(path, linePaint);

    setState(() {
      draw(data);
    });
  }

  void onPencilDraw(MoveEvent details) {
    Path linePath = toDraw.last.path;

    Offset actualPosition = toActualPosition(details.localPos);

    setState(() {
      linePath.lineTo(actualPosition.dx, actualPosition.dy);
    });
  }

  void onPencilDrawSc(ScaleEvent details) {
    Path linePath = toDraw.last.path;

    // details.focalPoint;

    Offset actualPosition = toActualPosition(details.focalPoint);

    setState(() {
      linePath.lineTo(actualPosition.dx, actualPosition.dy);
    });
  }

  void onStartShapeDraw(MoveEvent details) {
    shapeStart = toActualPosition(details.localPos, false);
    Path path = Path();
    draw(DrawItem(path, basePaint));
  }

  void onStopDraw() {
    shapeStart = null;

    Path path = toDraw.last.path;

    if (path.computeMetrics().isEmpty) {
      toDraw.removeLast();
    }
  }

  void onStartLineDraw(MoveEvent details) {
    shapeStart = toActualPosition(details.localPos);

    Path path = Path();

    draw(DrawItem(path, linePaint));
  }

  void onLineDraw(MoveEvent details) {
    assert(shapeStart != null);

    Offset actualPosition = toActualPosition(details.localPos);

    Path linePath = toDraw.last.path;
    linePath.reset();
    linePath.moveTo(shapeStart!.dx, shapeStart!.dy);

    setState(() {
      linePath.lineTo(actualPosition.dx, actualPosition.dy);
    });
  }

  void onRectangleDraw(MoveEvent details) {
    updateShape(details, (path, startPosition, currentPosition) {
      path.addRect(Rect.fromPoints(startPosition, currentPosition));
    });
  }

  void onOvalDraw(MoveEvent details) {
    updateShape(details, (path, startPosition, currentPosition) {

      var width = (currentPosition.dx - startPosition.dx) * 2;
      var height = (currentPosition.dy - startPosition.dy) * 2;

      path.addOval(Rect.fromCenter(center: startPosition, width: width, height: height));
    });
  }
  
  void updateShape(MoveEvent details, void addShape(Path path, Offset startPosition, Offset currentPosition)) {
    
    Offset? shapeStartPoint = shapeStart;
    if (shapeStartPoint == null) return;
    
    Path linePath = toDraw.last.path;
    linePath.reset();

    Matrix4 matrix4 = Matrix4Transform().rotate(-angle).matrix4;

    Offset actualPosition = toActualPosition(details.localPos, false);
    
    addShape(linePath, shapeStartPoint, actualPosition);

    Path resultPath = linePath.transform(matrix4.storage);

    Paint paint = toDraw.removeLast().paint;

    var data = DrawItem(resultPath, paint);

    setState(() {
      draw(data, removeLastUndo: true);
    });
  }

  void onMove(MoveEvent details) {
    // stdout.writeln("moveUpd");
    setState(() {
      moveOffset += details.delta;
      lastFp += details.delta;
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

      moveOffset += details.focalPoint - lastFp;
      lastFp = details.focalPoint;
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
    return _paintType.hasThickness && !(_paintType.fillable && filled);
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
                hsvColor = HSVColor.fromColor(newColor);
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
            paintAction: PaintAction.CLEAR_MODS,
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
          ActionButton(
            paintAction: PaintAction.CLEAR_MODS,
            onPressed: () {
              setState(() {
                angle += pi / 2;
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
          PaintType.values.length,
          (index) {
            PaintType type = PaintType.values[index];

            double insetSize = 2.5;
            EdgeInsets insets = isPortrait
                ? EdgeInsets.symmetric(horizontal: insetSize)
                : EdgeInsets.symmetric(vertical: insetSize);

            return Padding(
                padding: insets,
                child: ToolRadioButton(
                  buttonType: type,
                  selectedType: _paintType,
                  selectedColor: color,
                  lineSide: lineSide,
                  onTypeSelected: (newType) {
                    setState(() {
                      _paintType = newType;
                    });
                  },
                ));
          },
        );

    Widget slider = RotatedBox(
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
        redo.clear();

        switch (_paintType) {
          case PaintType.PENCIL:
            onStartPencilDraw(details);
            break;
          case PaintType.ERASER:
            onStartErase(details);
            break;
          case PaintType.LINE:
            onStartLineDraw(details);
            break;
          case PaintType.RECTANGLE:
            onStartShapeDraw(details);
            break;
          case PaintType.OVAL:
            onStartShapeDraw(details);
            break;
        }
      },
      onMoveEnd: (_) => onStopDraw(),
      onMoveUpdate: (details) {
        switch (_paintType) {
          case PaintType.PENCIL:
            onPencilDraw(details);
            break;
          case PaintType.ERASER:
            onErase(details);
            break;
          case PaintType.LINE:
            onLineDraw(details);
            break;
          case PaintType.RECTANGLE:
            onRectangleDraw(details);
            break;
          case PaintType.OVAL:
            onOvalDraw(details);
            break;
          case PaintType.MOVE:
            onMove(details);
            break;
        }
      },
      onScaleStart: (focalPoint) {
        if (_paintType == PaintType.MOVE) {
          onScaleStart(focalPoint);
        }
      },
      onScaleEnd: () {
        if (_paintType == PaintType.MOVE) {
          onScaleEnd();
        }
      },
      onScaleUpdate: (details) {
        if (_paintType == PaintType.MOVE) {
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
              decoration: BoxDecoration(color: backgroundColor),
              child: drawingWidget)),
      DecoratedBox(
          decoration:
              BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
          child: Flex(
            direction: direction,
            children: [
              if (isThicknessAvailable()) slider,
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

enum LineSide { TOP, BOTTOM, LEFT, RIGHT }

class ToolRadioButton extends StatelessWidget {
  final PaintType buttonType;
  final PaintType selectedType;

  final Color selectedColor;
  final LineSide lineSide;

  final double size;
  final double splashRadius;
  final double selectedItemInset;
  final double borderWidth;

  final ValueChanged<PaintType> onTypeSelected;

  ToolRadioButton(
      {required this.buttonType,
      required this.selectedType,
      required this.onTypeSelected,
      required Color selectedColor,
      required this.lineSide,
      this.size = 30,
      this.splashRadius = 25,
      this.selectedItemInset = 20,
      this.borderWidth = 2})
      : this.selectedColor = selectedColor.withAlpha(255);

  @override
  Widget build(BuildContext context) {
    VoidCallback onPressed = () {
      if (buttonType != selectedType) {
        onTypeSelected(buttonType);
      }
    };

    // Color? buttonColor = buttonType == selectedType ? selectedColor : null;
    Color? buttonColor = buttonType == selectedType ? Colors.white : null;

    Widget button = PaintButton.createInk(
        onPressed,
        SvgPicture.asset(
          buttonType.imagePath,
          height: size,
          color: buttonColor,
        ),
        selectedColor: selectedColor);

    if (buttonType == selectedType) {
      final BorderSide borderSide =
          BorderSide(color: selectedColor, width: borderWidth);
      Border border = Border();
      EdgeInsets insets = EdgeInsets.zero;

      switch (lineSide) {
        case LineSide.TOP:
          insets = EdgeInsets.only(top: selectedItemInset);
          border = Border(top: borderSide);
          break;
        case LineSide.BOTTOM:
          insets = EdgeInsets.only(bottom: selectedItemInset);
          border = Border(bottom: borderSide);
          break;
        case LineSide.LEFT:
          insets = EdgeInsets.only(left: selectedItemInset);
          border = Border(left: borderSide);
          break;
        case LineSide.RIGHT:
          insets = EdgeInsets.only(right: selectedItemInset);
          border = Border(right: borderSide);
          break;
      }

      Decoration decoration = BoxDecoration(
        color: PaintButton.nonWhiteColor(selectedColor),
        borderRadius: BorderRadius.circular(10),
        // border: border,
      );

      return DecoratedBox(
        decoration: decoration,
        child: button,
      );
    } else {
      return button;
    }
  }
}

class OptionCheckButton extends StatelessWidget {
  final PaintOption buttonOption;

  final bool selected;
  final Color selectedColor;

  final double size;
  final double splashRadius;

  final ValueChanged<bool> onOptionChanged;

  OptionCheckButton(
      {required this.buttonOption,
      required this.selected,
      required this.onOptionChanged,
      required Color selectedColor,
      this.size = 30,
      this.splashRadius = 25})
      : this.selectedColor = selectedColor.withAlpha(255);

  @override
  Widget build(BuildContext context) {
    VoidCallback onPressed = () {
      onOptionChanged(!selected);
    };

    return PaintButton.createInk(
        onPressed,
        SvgPicture.asset(
          selected ? buttonOption.imageOnPath : buttonOption.imageOffPath,
          color: selected ? PaintButton.nonWhiteColor(selectedColor) : null,
          height: size,
        ),
        selectedColor: selectedColor);
  }
}

class ActionButton extends PaintButton {
  final PaintAction paintAction;

  final bool enabled;

  final VoidCallback onPressed;

  final double size;
  final double splashRadius;

  ActionButton(
      {required this.paintAction,
      required this.onPressed,
      this.enabled = true,
      this.size = 30,
      this.splashRadius = 25});

  @override
  Widget build(BuildContext context) {

    return PaintButton.createInk(
        enabled ? onPressed : null,
        SvgPicture.asset(
          paintAction.imagePath,
          color: enabled ? null : Colors.black.withAlpha(100),
          height: size,
        ));
  }
}

abstract class PaintButton extends StatelessWidget {
  static final double maximumLightness = 0.8;

  static InkWell createInk(VoidCallback? onPressed, Widget child,
      {Color? selectedColor}) {
    return InkWell(
      // splashRadius: splashRadius,
      // onPressed: onPressed,
      highlightColor: selectedColor?.withAlpha(40),
      splashColor: selectedColor?.withAlpha(40),
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: child,
      ),
    );
  }

  static Color nonWhiteColor(Color originalColor) {
    HSLColor backgroundColor = HSLColor.fromColor(originalColor);
    return (backgroundColor.lightness > maximumLightness
            ? backgroundColor.withLightness(maximumLightness)
            : backgroundColor)
        .toColor();
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
    canvas.translate(moveOffset.dx, moveOffset.dy);

    Offset pivot = Offset.zero;

    if (!added) {
      added = true;
      Size? s = widgetKey.currentContext?.size;
      if (s != null) {
        pivot = Offset(s.width / 2, s.height / 2);

        Path path = Path()
          ..moveTo(10, 10)
          ..lineTo(s.width / 2, s.height / 2);
        Paint paint = Paint()
          ..strokeWidth = 5
          ..color = Colors.black
          ..style = PaintingStyle.stroke;

        data.insert(0, DrawItem(path, paint));
      }
    }

    pivot = fp;

    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.translate(-pivot.dx, -pivot.dy);

    // canvas.scale(scale);

    for (DrawItem entry in data) {
      canvas.drawPath(entry.path, entry.paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) => true;
}

class RepaintIndicatorPainter extends fcp.IndicatorPainter {
  RepaintIndicatorPainter(Color color) : super(color);

  @override
  bool shouldRepaint(covariant RepaintIndicatorPainter oldDelegate) =>
      color != oldDelegate.color;
}

// Copy of ColorIndicator from flutter_colorpicker with fixed repainting
class RepaintColorIndicator extends StatelessWidget {
  const RepaintColorIndicator(
    this.color, {
    this.width: 50.0,
    this.height: 50.0,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(const Radius.circular(1000.0)),
        border: Border.all(color: const Color(0xffdddddd)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(1000.0)),
        child: CustomPaint(painter: RepaintIndicatorPainter(color)),
      ),
    );
  }
}
