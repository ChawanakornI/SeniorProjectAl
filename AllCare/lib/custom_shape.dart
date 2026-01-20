import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
class MyShapePathProvider extends NeumorphicPathProvider {
  @override
  bool shouldReclip(NeumorphicPathProvider oldClipper) {
    return true;
  }

  @override
  @override
Path getPath(Size size) {
  final path = Path();
  path.addRRect(RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, size.width, size.height),
    const Radius.circular(12),
  ));
  return path;
}


  @override
  bool get oneGradientPerPath => false;
}