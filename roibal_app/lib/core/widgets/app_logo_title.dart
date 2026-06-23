import 'package:flutter/material.dart';

/// Logo + "ROIBAL" wordmark on a single row, with the name vertically
/// centered against the logo's full height.
class AppLogoTitle extends StatelessWidget {
  final double logoSize;
  final TextStyle? textStyle;

  const AppLogoTitle({super.key, this.logoSize = 32, this.textStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/images/logo.png', height: logoSize, width: logoSize),
        const SizedBox(width: 12),
        Text(
          'ROIBAL',
          style: textStyle ?? Theme.of(context).textTheme.headlineMedium,
        ),
      ],
    );
  }
}
