import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gap/gap.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../styles/color.dart';
import '../../styles/dimension.dart';

class BaseButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool hasBorder;
  final bool isDisabled;
  final Color? borderColor;
  final Color? bgColor;
  final Color? labelColor;
  final TextStyle? labelStyle;
  final String? buttonIcon;
  final bool isBusy;
  const BaseButton({
    Key? key,
    this.isBusy = false,
    this.borderColor,
    this.buttonIcon,
    this.labelStyle,
    this.onPressed,
    this.labelColor,
    this.bgColor,
    required this.label,
    this.hasBorder = false,
    this.isDisabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      height: 56,
      focusElevation: 0,
      highlightElevation: 0,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimen.roundButtonRadius),
        side: hasBorder
            ? BorderSide(color: borderColor ?? appColor.primaryColor)
            : BorderSide.none,
      ),
      onPressed: isDisabled || isBusy ? null : onPressed,
      color: hasBorder ? Colors.transparent : bgColor ?? appColor.primaryColor,
      disabledColor: hasBorder
          ? null
          : bgColor?.withOpacity(0.3) ?? appColor.primaryColor.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: isBusy
          ? Center(
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: LoadingAnimationWidget.inkDrop(
                      color: Colors.white, size: 30)),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (buttonIcon != null)
                  Row(
                    children: [
                      SvgPicture.asset(
                        buttonIcon!,
                        height: 20,
                      ),
                      const Gap(10),
                    ],
                  ),
                Text(
                  label,
                  style: labelStyle ??
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: hasBorder
                                ? appColor.primaryColor
                                : labelColor ?? appColor.primaryButtonTextColor,
                          ),
                ),
              ],
            ),
    );
  }
}
