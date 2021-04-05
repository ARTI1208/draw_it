import 'dart:io';
import 'dart:math';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tuple/tuple.dart';

class PainterWidget extends StatefulWidget {
  PainterWidget({Key? key}) : super(key: key);

  @override
  PainterState createState() => PainterState();
}

enum PaintType { PENCIL, ERASER, LINE, RECTANGLE, OVAL }

enum PaintOption { FILLED }

enum PaintAction { UNDO, REDO, CLEAR }

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
    }
  }

  String get imagePath => "assets/drawables/" + this.image;
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

class PainterState extends State<PainterWidget> {
  Color color = Colors.black;
  double strokeWidth = 5;

  bool filled = true;

  List<Tuple2<Path, Paint>> toDraw = [];

  List<Iterable<Tuple2<Path, Paint>>> removed = [];

  PaintType _paintType = PaintType.PENCIL;

  Color backgroundColor = Colors.amber;

  Offset? shapeStart;

  Random random = new Random();

  void onStartErase(DragStartDetails details) {
    setState(() {
      Path path = Path()
        ..moveTo(details.localPosition.dx, details.localPosition.dy);

      Paint paint = linePaint..color = backgroundColor;

      toDraw.add(Tuple2(path, paint));
    });
  }

  void onErase(DragUpdateDetails details) {
    setState(() {
      Path linePath = toDraw.last.item1;

      linePath.lineTo(details.localPosition.dx, details.localPosition.dy);
    });
  }

  Paint get basePaint {
    return Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke;
  }

  Paint get linePaint {
    return basePaint..style = PaintingStyle.stroke;
  }

  void onStartPencilDraw(DragStartDetails details) {
    setState(() {
      Path path = Path()
        ..moveTo(details.localPosition.dx, details.localPosition.dy);

      toDraw.add(Tuple2(path, linePaint));
    });
  }

  void onPencilDraw(DragUpdateDetails details) {

    Path linePath = toDraw.last.item1;

    setState(() {
      linePath.lineTo(details.localPosition.dx, details.localPosition.dy);
    });
  }

  void onStartShapeDraw(DragStartDetails details) {
    shapeStart = details.localPosition;
    Path path = Path();
    toDraw.add(Tuple2(path, basePaint));
  }

  void onStopDraw() {
    shapeStart = null;

    Path path = toDraw.last.item1;

    if (path.computeMetrics().isEmpty) {
      toDraw.removeLast();
    }
  }

  void onStartLineDraw(DragStartDetails details) {
    shapeStart = details.localPosition;

    Path path = Path();

    toDraw.add(Tuple2(path, linePaint));
  }

  void onLineDraw(DragUpdateDetails details) {
    assert(shapeStart != null);

    setState(() {
      Path linePath = toDraw.last.item1;

      linePath.reset();
      linePath.moveTo(shapeStart!.dx, shapeStart!.dy);

      linePath.lineTo(details.localPosition.dx, details.localPosition.dy);
    });
  }

  void onRectangleDraw(DragUpdateDetails details) {
    assert(shapeStart != null);

    setState(() {
      Path linePath = toDraw.last.item1;

      linePath.reset();
      linePath.addRect(Rect.fromPoints(shapeStart!, details.localPosition));
    });
  }

  void onOvalDraw(DragUpdateDetails details) {
    assert(shapeStart != null);

    var center = shapeStart;
    if (center == null) return;

    var width = (details.localPosition.dx - center.dx) * 2;
    var height = (details.localPosition.dy - center.dy) * 2;

    Path linePath = toDraw.last.item1;

    setState(() {
      linePath.reset();
      linePath.addOval(
          Rect.fromCenter(center: center, width: width, height: height));
    });
  }

  Future<Color> _showColorPickerDialog() async {
    Map<ColorPickerType, bool> pickersEnabled = <ColorPickerType, bool>{
      ColorPickerType.both: false,
      ColorPickerType.primary: false,
      ColorPickerType.accent: false,
      ColorPickerType.bw: false,
      ColorPickerType.custom: false,
      ColorPickerType.wheel: true,
    };

    Color newColor = color;

    return showDialog<Color>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Pick color'),
            titlePadding: EdgeInsets.all(20),
            content: ColorPicker(
                color: color,
                onColorChanged: (_) {},
                onColorChangeEnd: (color) => newColor = color,
                pickersEnabled: pickersEnabled,
                showColorCode: true,
                enableOpacity: true,
                enableShadesSelection: false,
                actionButtons: ColorPickerActionButtons(
                  dialogActionButtons: true,
                )),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop(color);
                },
              ),
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(newColor);
                },
              ),
            ],
          );
        }).then((value) => value ?? color);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> buttons = <Widget>[
          ColorIndicator(
              color: color,
              hasBorder: true,
              height: 30,
              width: 30,
              borderRadius: 40,
              onSelect: () async {
                Color newColor = await _showColorPickerDialog();
                if (newColor == color) return;

                setState(() {
                  color = newColor;
                });
              }),
          Container(
            height: 30,
            child: VerticalDivider(
              thickness: 1,
              color: Colors.black87,
            ),
          ),
          ActionButton(
              paintAction: PaintAction.UNDO,
              enabled: toDraw.isNotEmpty,
              // enabled: true,
              onPressed: () {
                if (toDraw.isEmpty) return;

                setState(() {
                  var lastPath = toDraw.removeLast();
                  removed.add([lastPath]);
                });
              }),
          ActionButton(
              paintAction: PaintAction.REDO,
              enabled: removed.isNotEmpty,
              // enabled: true,
              onPressed: () {
                if (removed.isEmpty) return;

                setState(() {
                  var lastPath = removed.removeLast();
                  toDraw.addAll(lastPath);
                });
              }),
          ActionButton(
              paintAction: PaintAction.CLEAR,
              enabled: toDraw.isNotEmpty,
              // enabled: true,
              onPressed: () {
                setState(() {
                  removed.add(List.from(toDraw));
                  toDraw.clear();
                });
              }),
          Container(
            height: 30,
            child: VerticalDivider(
              thickness: 1,
              color: Colors.black87,
            ),
          ),
          OptionCheckButton(
              buttonOption: PaintOption.FILLED,
              selected: filled,
              selectedColor: color,
              onOptionChanged: (newValue) {
                setState(() {
                  filled = newValue;
                });
              }),
          Container(
            height: 30,
            child: VerticalDivider(
              thickness: 1,
              color: Colors.black87,
            ),
          ),
        ] +
        List.generate(
          PaintType.values.length,
          (index) {
            PaintType type = PaintType.values[index];

            return ToolRadioButton(
              buttonType: type,
              selectedType: _paintType,
              selectedColor: color,
              onTypeSelected: (newType) {
                setState(() {
                  _paintType = newType;
                });
              },
            );
          },
        );

    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
              child: DecoratedBox(
                  decoration: BoxDecoration(color: backgroundColor),
                  child: GestureDetector(
                    onPanStart: (details) {
                      removed.clear();

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
                    onPanCancel: () => onStopDraw(),
                    onPanEnd: (_) => onStopDraw(),
                    onPanUpdate: (details) {
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
                      }
                    },
                    child: CustomPaint(
                      painter: DrawPainter(toDraw),
                    ),
                  ))),
          // Slider(
          //     value: strokeWidth,
          //     min: 0.0,
          //     max: 50.0,
          //     onChanged: (newValue) {
          //       setState(() {
          //         strokeWidth = newValue;
          //       });
          //     }),
          // SingleChildScrollView(
          //     scrollDirection: Axis.horizontal,
          //     child: ButtonBar(
          //         mainAxisSize: MainAxisSize.max,
          //         alignment: MainAxisAlignment.spaceEvenly,
          //         children: buttons)),
          DecoratedBox(
              decoration: BoxDecoration(
                  // color: Theme.of(context).scaffoldBackgroundColor
              ),
              child: Column(
                children: [
                  Slider(
                      value: strokeWidth,
                      min: 0.0,
                      max: 50.0,
                      onChanged: (newValue) {
                        setState(() {
                          strokeWidth = newValue;
                        });
                      }),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ButtonBar(
                          mainAxisSize: MainAxisSize.max,
                          alignment: MainAxisAlignment.spaceEvenly,
                          buttonHeight: 30,
                          children: buttons)),
                ],
              )),
        ]);
  }
}

class ToolRadioButton extends StatelessWidget {
  final PaintType buttonType;
  final PaintType selectedType;

  final Color selectedColor;

  final ValueChanged<PaintType> onTypeSelected;

  ToolRadioButton(
      {required this.buttonType,
      required this.selectedType,
      required this.onTypeSelected,
      required Color selectedColor})
      : this.selectedColor = selectedColor.withAlpha(255);

  @override
  Widget build(BuildContext context) {
    VoidCallback onPressed = () {
      if (buttonType != selectedType) {
        onTypeSelected(buttonType);
      }
    };

    if (buttonType == selectedType) {
      return Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Ink(
            decoration: BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: selectedColor, width: 2)),
            ),
            child: IconButton(
                onPressed: onPressed,
                icon: SvgPicture.asset(
                  buttonType.imagePath,
                  height: 30,
                  color: selectedColor,
                )),
          ));
    } else {
      return IconButton(
          onPressed: onPressed,
          icon: SvgPicture.asset(
            buttonType.imagePath,
            height: 30,
          ));
    }
  }
}

class OptionCheckButton extends StatelessWidget {
  final PaintOption buttonOption;

  final bool selected;
  final Color selectedColor;

  final ValueChanged<bool> onOptionChanged;

  OptionCheckButton(
      {required this.buttonOption,
      required this.selected,
      required this.onOptionChanged,
      required Color selectedColor})
      : this.selectedColor = selectedColor.withAlpha(255);

  @override
  Widget build(BuildContext context) {
    VoidCallback onPressed = () {
      onOptionChanged(!selected);
    };

    return IconButton(
        onPressed: onPressed,
        icon: SvgPicture.asset(
          selected ? buttonOption.imageOnPath : buttonOption.imageOffPath,
          color: selected ? selectedColor : null,
          height: 30,
        ));
  }
}

class ActionButton extends StatelessWidget {
  final PaintAction paintAction;

  final bool enabled;

  final VoidCallback onPressed;

  ActionButton({
    required this.paintAction,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: enabled ? onPressed : null,
        icon: SvgPicture.asset(
          paintAction.imagePath,
          color: enabled ? null : Colors.black.withAlpha(100),
          height: 30,
        ));
  }
}

class DrawPainter extends CustomPainter {
  List<Tuple2<Path, Paint>> data;

  DrawPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    for (Tuple2<Path, Paint> entry in data) {
      canvas.drawPath(entry.item1, entry.item2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return true;
  }
}
