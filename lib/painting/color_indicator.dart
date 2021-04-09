import 'package:flutter/widgets.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class RepaintIndicatorPainter extends IndicatorPainter {
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
