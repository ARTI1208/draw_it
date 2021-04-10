import 'dart:ui';

import 'package:draw_it/painting/enums.dart';
import 'package:draw_it/painting/models.dart';
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
  final double borderRadius;

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
      this.borderRadius = 15})
      : this.selectedColor = selectedColor.withAlpha(255);

  @override
  Widget build(BuildContext context) {
    VoidCallback onPressed = () {
      if (buttonType != selectedType) {
        onTypeSelected(buttonType);
      }
    };

    Color? buttonColor = buttonType == selectedType ? Colors.white : null;

    Widget button = PaintButton.createInk(
        onPressed,
        SvgPicture.asset(
          buttonType.imagePath,
          height: size,
          color: buttonColor,
        ),
        borderRadius: borderRadius,
        selectedColor: selectedColor);

    if (buttonType == selectedType) {
      Decoration decoration = BoxDecoration(
        color: ColorTools.nonWhiteColor(selectedColor),
        borderRadius: BorderRadius.circular(borderRadius),
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
          color: selected ? ColorTools.nonWhiteColor(selectedColor) : null,
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
  static InkWell createInk(VoidCallback? onPressed, Widget child,
      {Color? selectedColor,
      double borderRadius = 20,
      double insets = 8,
      int highlightAlpha = 40,
      int splashAlpha = 40}) {
    return InkWell(
      highlightColor: selectedColor?.withAlpha(highlightAlpha),
      splashColor: selectedColor?.withAlpha(splashAlpha),
      borderRadius: BorderRadius.circular(borderRadius),
      onTap: onPressed,
      child: Padding(
        padding: EdgeInsets.all(insets),
        child: child,
      ),
    );
  }
}
