import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo + "ROIBAL" wordmark on a single row, with the name vertically
/// centered against the logo's full height.
class AppLogoTitle extends StatelessWidget {
  final double logoSize;
  final TextStyle? textStyle;
  final Color? color;

  const AppLogoTitle({super.key, this.logoSize = 32, this.textStyle, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/images/logo.svg',
          width: logoSize,
          height: logoSize,
          colorFilter: color != null
              ? ColorFilter.mode(color!, BlendMode.srcIn)
              : null,
        ),
        const SizedBox(width: 12),
        Text(
          'ROIBAL',
          style: (textStyle ?? Theme.of(context).textTheme.headlineMedium)
              ?.copyWith(color: color),
        ),
      ],
    );
  }
}
