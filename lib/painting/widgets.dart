import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:draw_it/extensions/collections.dart';
import 'package:draw_it/extensions/platform.dart';
import 'package:draw_it/painting/buttons.dart';
import 'package:draw_it/painting/color_indicator.dart';
import 'package:draw_it/painting/enums.dart';
import 'package:draw_it/painting/models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as fcp;
import 'package:matrix4_transform/matrix4_transform.dart';
import 'package:matrix_gesture_detector/matrix_gesture_detector.dart';

class PainterWidget extends StatefulWidget {
  PainterWidget({Key? key}) : super(key: key);

  @override
  PainterState createState() => PainterState();
}

class PainterState extends State<PainterWidget> {
  static const double _minPaintThickness = 0;
  static const double _maxPaintThickness = 50;

  static const double _minScale = 0.05;
  static const double _maxScale = 10;

  static const double _minAngle = 0;
  static const double _maxAngle = 2 * pi;

  static const double _wheelScale = 0.05;

  static const double _axisDividerSize = 30;
  static const double _crossAxisDividerSize = 20;
  static const double _dividerThickness = 1;

  static const double _buttonSize = 30;

  PaintTool _paintTool = PaintTool.PENCIL;
  Map<PaintOption, bool> _options = {};

  DrawingState _drawingState = DrawingState();

  GlobalKey _paintingAreaKey = GlobalKey();

  List<Offset> _continuousPoints = [];

  Paint get _currentPaint {
    var paint = Paint()
      ..color = _drawingState.color
      ..strokeWidth = _drawingState.strokeWidth
      ..strokeCap = StrokeCap.round;

    paint = PaintOption.values.fold(paint, (currentPaint, option) {
      return option.setupPaint(currentPaint, _drawingState, hasOption(option));
    });

    return _paintTool.setupPaint(paint, _drawingState);
  }

  @override
  void initState() {
    super.initState();
    _options[PaintOption.FILLED] = true;
  }

  void draw(DrawItem item, {bool updateLast = false}) {
    HistoryItem historyItem = HistoryItem.single(ChangeType.PAINT, item);

    if (updateLast) {
      _drawingState.toDraw.safeLast = item;
      _drawingState.undo.safeLast = historyItem;
    } else {
      _drawingState.toDraw.add(item);
      _drawingState.undo.add(historyItem);
    }
  }

  void onStartContinuousDrawingOffset(Offset pointerPosition) {
    _continuousPoints = [];
    onStartShapeDrawOffset(pointerPosition);
  }

  void updateContinuousDrawingOffset(Offset pointerPosition) {
    updateDrawing((path) {
      path.moveTo(_drawingState.shapeStart.dx, _drawingState.shapeStart.dy);

      _continuousPoints.add(applyOffsetTransformations(pointerPosition));
      for (var point in _continuousPoints) {
        path.lineTo(point.dx, point.dy);
      }
    });
  }

  void onStartShapeDrawOffset(Offset pointerPosition) {
    _drawingState.shapeStart = applyOffsetTransformations(pointerPosition);
    Path path = Path();
    setState(() {
      draw(DrawItem(path, _currentPaint));
    });
  }

  void updateShapeOffset(Offset pointerPosition) {
    updateDrawing((path) {
      Offset actualPosition = applyOffsetTransformations(pointerPosition);
      _paintTool.drawPath(path, _drawingState.shapeStart, actualPosition);
    });
  }

  void updateDrawing(void drawPath(Path path)) {
    DrawItem lastItem = _drawingState.toDraw.last;

    Path linePath = lastItem.path;
    linePath.reset();

    drawPath(linePath);

    Path resultPath = applyPathTransformations(linePath);

    Paint paint = lastItem.paint;

    var data = DrawItem(resultPath, paint);

    setState(() {
      draw(data, updateLast: true);
    });
  }

  Path applyPathTransformations(Path path) {
    var decomposed =
        MatrixGestureDetector.decomposeToValues(_drawingState.transform);

    Matrix4 matrix4 = Matrix4Transform()
        .rotate(-decomposed.rotation)
        .scale(1 / decomposed.scale)
        .matrix4;

    return path.transform(matrix4.storage);
  }

  Offset applyOffsetTransformations(Offset offset) {
    var decomposed =
        MatrixGestureDetector.decomposeToValues(_drawingState.transform);

    Offset actualMoveOffset = -decomposed.translation;
    return offset.translate(actualMoveOffset.dx, actualMoveOffset.dy);
  }

  Future<Color> _showColorPickerDialog() async {
    Color newColor = _drawingState.color;

    Widget colorPicker = fcp.ColorPicker(
        pickerColor: newColor,
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

  Widget _createDivider(bool vertical) {
    if (vertical) {
      return Container(
        height: _axisDividerSize,
        width: _crossAxisDividerSize,
        child: VerticalDivider(
          thickness: _dividerThickness,
          color: Colors.black87,
        ),
      );
    } else {
      return Container(
        height: _crossAxisDividerSize,
        width: _axisDividerSize,
        child: Divider(
          thickness: _dividerThickness,
          color: Colors.black87,
        ),
      );
    }
  }

  bool hasOption(PaintOption option) {
    return _options[option] == true;
  }

  bool get _isThicknessAvailable {
    return _paintTool.hasThickness &&
        !(_paintTool.fillable && hasOption(PaintOption.FILLED));
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
                if (newColor == _drawingState.color) return;

                setState(() {
                  _drawingState.color = newColor;
                });
              },
              child: Padding(
                padding: isPortrait
                    ? EdgeInsets.only(left: 10)
                    : EdgeInsets.only(top: 10),
                child: RepaintColorIndicator(
                  _drawingState.color,
                  height: _buttonSize,
                  width: _buttonSize,
                ),
              )),
          _createDivider(isPortrait)
        ] +
        List.generate(PaintAction.values.length, (index) {
          PaintAction paintAction = PaintAction.values[index];
          return ActionButton(
            paintAction: paintAction,
            enabled: paintAction.isEnabled(_drawingState),
            size: _buttonSize,
            onPressed: () => setState(() {
              paintAction.onPressed(_drawingState);
            }),
          );
        }) +
        [_createDivider(isPortrait)] +
        List.generate(PaintOption.values.length, (index) {
          PaintOption paintOption = PaintOption.values[index];
          return OptionCheckButton(
              buttonOption: paintOption,
              selected: hasOption(paintOption),
              selectedColor: _drawingState.color,
              size: _buttonSize,
              onOptionChanged: (newValue) {
                setState(() {
                  _options[paintOption] = newValue;
                });
              });
        }) +
        [_createDivider(isPortrait)] +
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
                  selectedColor: _drawingState.color,
                  lineSide: lineSide,
                  size: _buttonSize,
                  onTypeSelected: (newType) {
                    setState(() {
                      _paintTool = newType;
                    });
                  },
                ));
          },
        );

    var decomposed =
        MatrixGestureDetector.decomposeToValues(_drawingState.transform);
    double angleZero2Pi = decomposed.rotation >= 0
        ? decomposed.rotation
        : decomposed.rotation + _maxAngle;

    Color nonWhiteColor = _drawingState.nonWhiteColor;
    Color sliderActiveColor = nonWhiteColor.withAlpha(255);
    Color sliderInactiveColor = nonWhiteColor.withAlpha(80);

    Widget scaleSlider = RotatedBox(
        quarterTurns: isPortrait ? 0 : -1,
        child: Slider(
            activeColor: sliderActiveColor,
            inactiveColor: sliderInactiveColor,
            value: decomposed.scale,
            min: min(_minScale, decomposed.scale),
            max: max(_maxScale, decomposed.scale),
            onChanged: (newValue) {
              // TODO : make scale origin equal to canvas center

              Matrix4 scaled = Matrix4Transform()
                  .translateOffset(decomposed.translation)
                  .rotate(angleZero2Pi)
                  .scale(newValue)
                  .matrix4;

              setState(() {
                _drawingState.transform = scaled;
              });
            }));

    Widget rotateSlider = RotatedBox(
        quarterTurns: isPortrait ? 0 : -1,
        child: Slider(
            activeColor: sliderActiveColor,
            inactiveColor: sliderInactiveColor,
            value: angleZero2Pi,
            min: _minAngle,
            max: _maxAngle,
            onChanged: (newValue) {
              // TODO : make rotate origin equal to canvas center

              Matrix4 rotated = Matrix4Transform()
                  .translateOffset(decomposed.translation)
                  .rotate(newValue)
                  .scale(decomposed.scale)
                  .matrix4;

              setState(() {
                _drawingState.transform = rotated;
              });
            }));

    Widget thicknessSlider = RotatedBox(
        quarterTurns: isPortrait ? 0 : -1,
        child: Slider(
            activeColor: sliderActiveColor,
            inactiveColor: sliderInactiveColor,
            value: _drawingState.strokeWidth,
            min: _minPaintThickness,
            max: _maxPaintThickness,
            onChanged: (newValue) {
              setState(() {
                _drawingState.strokeWidth = newValue;
              });
            }));

    Widget painter = CustomPaint(
      key: _paintingAreaKey,
      painter: DrawPainter(_drawingState.toDraw, _drawingState.transform),
    );

    Widget drawingWidget;

    if (_paintTool == PaintTool.MOVE) {
      drawingWidget = MatrixGestureDetector(
        onMatrixUpdate: (_, mt, ms, mr) {
          setState(() {
            _drawingState.transform = MatrixGestureDetector.compose(
                _drawingState.transform, mt, ms, mr);
          });
        },
        child: painter,
      );
    } else {
      drawingWidget = GestureDetector(
        onPanStart: (details) {
          switch (_paintTool) {
            case PaintTool.PENCIL:
            case PaintTool.ERASER:
              onStartContinuousDrawingOffset(details.localPosition);
              break;
            case PaintTool.LINE:
            case PaintTool.RECTANGLE:
            case PaintTool.OVAL:
              onStartShapeDrawOffset(details.localPosition);
              break;
            case PaintTool.MOVE:
              break;
          }

          _drawingState.redo.clear();
        },
        onPanUpdate: (details) {
          switch (_paintTool) {
            case PaintTool.PENCIL:
            case PaintTool.ERASER:
              updateContinuousDrawingOffset(details.localPosition);
              break;
            case PaintTool.LINE:
            case PaintTool.RECTANGLE:
            case PaintTool.OVAL:
              updateShapeOffset(details.localPosition);
              break;
            case PaintTool.MOVE:
              break;
          }
        },
        child: CustomPaint(
          painter: DrawPainter(_drawingState.toDraw, _drawingState.transform),
        ),
      );
    }

    drawingWidget = Listener(
      onPointerSignal: (pointerSignal) {
        // mouse wheel scroll
        if (pointerSignal is PointerScrollEvent) {
          // TODO : make scale origin equal pointer position

          var scale = decomposed.scale +
              (pointerSignal.scrollDelta.dy < 0 ? _wheelScale : -_wheelScale);
          if (scale < _minScale) {
            scale = _minScale;
          } else if (scale > _maxScale) {
            scale = _maxScale;
          }

          Matrix4 scaled = Matrix4Transform()
              .translateOffset(decomposed.translation)
              .rotate(angleZero2Pi)
              .scale(scale)
              .matrix4;

          setState(() {
            _drawingState.transform = scaled;
          });
        }
      },
      child: drawingWidget,
    );

    EdgeInsets buttonInsets = EdgeInsets.all(5);

    List<Widget> rootChildren = <Widget>[
      Expanded(
          child: DecoratedBox(
              decoration: BoxDecoration(color: _drawingState.backgroundColor),
              child: drawingWidget)),
      DecoratedBox(
          decoration:
              BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
          child: Flex(
            direction: direction,
            children: [
              if (DesktopPlatform.isDesktop) scaleSlider,
              if (DesktopPlatform.isDesktop) rotateSlider,
              if (_isThicknessAvailable) thicknessSlider,
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
  final List<DrawItem> _data;
  final Matrix4 _transform;

  DrawPainter(this._data, this._transform);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.transform(Float64List.fromList(_transform.storage));

    for (DrawItem entry in _data) {
      canvas.drawPath(entry.path, entry.paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawPainter oldDelegate) => true;
}
