import 'package:flutter/cupertino.dart';

extension MediaQueryExtension on BuildContext {
  Size get mediaSize => MediaQuery.sizeOf(this);
  bool get isLargeScreen => mediaSize.width > 960;
  bool get isMediumScreen => mediaSize.width > 640;
  bool get isSmallScreen => mediaSize.width <= 640;
  double get mediaHeight => mediaSize.height;
}
