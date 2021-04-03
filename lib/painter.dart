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

enum PaintType { PENCIL, ERASER, LINE, RECTANGLE }

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

  List<Tuple2<Path, Paint>> removed = [];

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
    setState(() {
      Path linePath = toDraw.last.item1;

      linePath.lineTo(details.localPosition.dx, details.localPosition.dy);
    });
  }

  void onStartShapeDraw(DragStartDetails details) {
    shapeStart = details.localPosition;
    setState(() {
      Path path = Path()
        ..moveTo(details.localPosition.dx, details.localPosition.dy);

      toDraw.add(Tuple2(path, basePaint));
    });
  }

  void onStartLineDraw(DragStartDetails details) {
    shapeStart = details.localPosition;

    Path path = Path()
      ..moveTo(details.localPosition.dx, details.localPosition.dy);

    setState(() {
      toDraw.add(Tuple2(path, linePaint));
    });
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
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DecoratedBox(
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
                  }
                },
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
                  }
                },
                child: Container(
                    // TODO match screen
                    height: 350,
                    child: CustomPaint(
                      painter: DrawPainter(toDraw),
                    )),
              )),
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
                  // this will take space as minimum as posible(to center)
                  children: List.generate(PaintType.values.length, (index) {
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
                  }))),
          ButtonBar(
            alignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.max,
            children: [
              ColorIndicator(
                color: color,
                hasBorder: true,
                onSelect: () async {
                  Color newColor = await _showColorPickerDialog();
                  if (newColor == color) return;

                  setState(() {
                    color = newColor;
                  });
                },
              ),
              ElevatedButton(
                  child: Text("Undo"),
                  onPressed: () {
                    if (toDraw.isEmpty) return;

                    setState(() {
                      var lastPath = toDraw.removeLast();
                      removed.add(lastPath);
                    });
                  }),
              ElevatedButton(
                  child: Text("Redo"),
                  onPressed: () {
                    if (removed.isEmpty) return;

                    setState(() {
                      var lastPath = removed.removeLast();
                      toDraw.add(lastPath);
                    });
                  }),
              ElevatedButton(
                  child: Text("Clear"),
                  onPressed: () {
                    setState(() {
                      toDraw.clear();
                      removed.clear();
                    });
                  }),
              Checkbox(
                  value: filled,
                  onChanged: (newValue) {
                    setState(() {
                      filled = newValue ?? false;
                    });
                  })
            ],
          ),
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
              border: Border(bottom: BorderSide(color: selectedColor, width: 2)),
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
