import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:tuple/tuple.dart';

class PainterWidget extends StatefulWidget {
  PainterWidget({Key? key}) : super(key: key);

  @override
  PainterState createState() => PainterState();
}

enum PaintType { PENCIL, ERASER, LINE, RECTANGLE }

extension NamedPaintType on PaintType {
  String get name {
    switch (this) {
      case PaintType.PENCIL:
        return "Pencil";
      case PaintType.ERASER:
        return "Eraser";
      case PaintType.LINE:
        return "Line";
      case PaintType.RECTANGLE:
        return "Rectangle";
    }
  }
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

  List<Tuple2<Path, Paint>> toDraw = [];

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
      ..strokeWidth = 5;
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

  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      DecoratedBox(
          decoration: BoxDecoration(color: backgroundColor),
          child: GestureDetector(
            onPanStart: (details) {
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
                height: 520,
                width: 400,
                child: CustomPaint(
                  painter: DrawPainter(toDraw),
                )),
          )),
      ButtonBar(
          mainAxisSize: MainAxisSize.min,
          // this will take space as minimum as posible(to center)
          children: List.generate(PaintType.values.length, (index) {
            PaintType type = PaintType.values[index];

            return ElevatedButton(
                child: Text(type.name),
                onPressed: () {
                  _paintType = type;
                });
          })),
      ButtonBar(
        alignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          ElevatedButton(
              child: Text("Color"),
              onPressed: () {
                int alpha = 255;
                int red = random.nextInt(256);
                int green = random.nextInt(256);
                int blue = random.nextInt(256);

                color = Color.fromARGB(alpha, red, green, blue);
              }),
          ElevatedButton(
              child: Text("Clear"),
              onPressed: () {
                setState(() {
                  toDraw.clear();
                });
              })
        ],
      )
    ]);
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
