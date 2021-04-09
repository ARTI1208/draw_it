import 'dart:ui';

import 'package:draw_it/painting/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum LineSide { TOP, BOTTOM, LEFT, RIGHT }

class ToolRadioButton extends StatelessWidget {
  final PaintTool buttonType;
  final PaintTool selectedType;

  final Color selectedColor;
  final LineSide lineSide;

  final double size;
  final double splashRadius;
  final double selectedItemInset;
  final double borderWidth;

  final ValueChanged<PaintTool> onTypeSelected;

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

      Decoration decoration = BoxDecoration(
        color: PaintButton.nonWhiteColor(selectedColor),
        borderRadius: BorderRadius.circular(10),
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