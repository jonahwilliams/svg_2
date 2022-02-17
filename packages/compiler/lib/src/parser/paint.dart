import 'package:meta/meta.dart';

import 'path.dart';
import 'util.dart';

enum BlendMode {
  srcOver,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  multiply,
  hue,
  saturation,
  color,
  luminosity,
}

enum StrokeCap {
  butt,
  round,
  square,
}

enum StrokeJoin {
  miter,
  round,
  bevel,
}

enum PaintingStyle {
  fill,
  stroke,
}

@immutable
class Color {
  const Color(this.value);

  const Color.fromRGBO(int r, int g, int b, double opacity)
      : value = ((((opacity * 0xff ~/ 1) & 0xff) << 24) |
                ((r & 0xff) << 16) |
                ((g & 0xff) << 8) |
                ((b & 0xff) << 0)) &
            0xFFFFFFFF;

  const Color.fromARGB(int a, int r, int g, int b)
      : value = (((a & 0xff) << 24) |
                ((r & 0xff) << 16) |
                ((g & 0xff) << 8) |
                ((b & 0xff) << 0)) &
            0xFFFFFFFF;

  static const Color opaqueBlack = Color(0xFF000000);

  Color withOpacity(double opacity) {
    return Color.fromRGBO(r, g, b, opacity);
  }

  final int value;

  int get r => (0x00ff0000 & value) >> 16;
  int get g => (0x0000ff00 & value) >> 8;
  int get b => (0x000000ff & value) >> 0;

  @override
  String toString() =>
      'const Color(0x${value.toRadixString(16).padLeft(8, '0')})';

  @override
  int get hashCode => value;

  @override
  bool operator ==(Object other) {
    return other is Color && other.value == value;
  }
}

@immutable
abstract class Shader {
  const Shader();

  void write(String name, buffer);
}

enum TileMode {
  clamp,
  decal,
  mirror,
  repeated,
}

@immutable
class LinearGradient extends Shader {
  const LinearGradient({
    required this.from,
    required this.to,
    required this.colors,
    this.offsets,
    required this.tileMode,
  });

  final Point from;
  final Point to;
  final List<Color> colors;
  final List<double>? offsets;
  final TileMode tileMode;

  @override
  void write(String name, buffer) {
    print('''
final $name = Gradient.linear(
  const Offset(${from.x}, ${from.y}),
  const Offset(${to.x}, ${to.y}),
  $colors,
  $offsets,
  $tileMode,
);
''');
  }

  @override
  int get hashCode => Object.hash(from, to, Object.hashAll(colors),
      Object.hashAll(offsets ?? <double>[]), tileMode);

  @override
  bool operator ==(Object other) {
    return other is LinearGradient &&
        other.from == from &&
        other.to == to &&
        listEquals(other.colors, colors) &&
        listEquals(other.offsets, offsets) &&
        other.tileMode == tileMode;
  }
}

@immutable
class RadialGradient extends Shader {
  const RadialGradient({
    required this.center,
    required this.radius,
    required this.colors,
    this.offsets,
    required this.tileMode,
    required this.transform,
    this.focalX = 0,
    this.focalY = 0,
  });

  final Point center;
  final double radius;
  final List<Color> colors;
  final List<double>? offsets;
  final TileMode tileMode;
  final AffineMatrix transform;
  final double focalX;
  final double focalY;

  void write(String name, buffer) {
    print('''
final $name = Gradient.radial(
  const Offset(${center.x}, ${center.y}),
  $radius,
  $colors,
  $offsets,
  $tileMode,
  Float64List.fromList(<double>${transform.toMatrix4()}),
  const Offset($focalX, $focalY),
  0.0,
);
''');
  }

  @override
  int get hashCode => Object.hash(
      center,
      radius,
      Object.hashAll(colors),
      Object.hashAll(offsets ?? <double>[]),
      tileMode,
      transform,
      focalX,
      focalY);

  @override
  bool operator ==(Object other) {
    return other is RadialGradient &&
        other.center == center &&
        other.radius == radius &&
        other.focalX == focalX &&
        other.focalY == focalY &&
        listEquals(other.colors, colors) &&
        listEquals(other.offsets, offsets) &&
        other.transform == transform &&
        other.tileMode == tileMode;
  }
}

@immutable
class Paint {
  const Paint({
    BlendMode? blendMode,
    Color? color,
    this.shader,
    StrokeCap? strokeCap,
    StrokeJoin? strokeJoin,
    double? strokeMiterLimit,
    double? strokeWidth,
    PaintingStyle? style,
  })  : this.blendMode = blendMode ?? BlendMode.srcOver,
        this.color = color ?? Color.opaqueBlack,
        this.strokeCap = strokeCap ?? StrokeCap.butt,
        this.strokeJoin = strokeJoin ?? StrokeJoin.miter,
        this.strokeMiterLimit = strokeMiterLimit ?? 4.0,
        this.strokeWidth = strokeWidth ?? 0.0,
        this.style = style ?? PaintingStyle.fill;

  final BlendMode blendMode;
  final Color color;
  final Shader? shader;
  final StrokeCap strokeCap;
  final StrokeJoin strokeJoin;
  final double strokeMiterLimit;
  final double strokeWidth;
  final PaintingStyle style;

  void write(buffer) {
    shader?.write('shade${shader.hashCode}', buffer);
    print('My color: $color $hashCode');
    print('final paint${hashCode} = Paint()');
    if (blendMode != BlendMode.srcOver) {
      print('  ..blendMode = $blendMode');
    }
    if (color != Color.opaqueBlack) {
      print('  ..color = $color');
    }
    if (shader != null) {
      print('  ..shader = shader${shader.hashCode}}');
    }
    if (strokeCap != StrokeCap.butt) {
      print('  ..strokeCap = $strokeCap');
    }
    if (strokeJoin != StrokeJoin.miter) {
      print('  ..strokeJoin = $strokeJoin');
    }
    if (strokeMiterLimit != 4) {
      print('  ..strokeMiterLimit = $strokeMiterLimit');
    }
    if (strokeWidth > 0) {
      print('  ..strokeWidth = $strokeWidth');
    }
    if (style != PaintingStyle.fill) {
      print('  ..style = $style');
    }
    print(';');
  }

  @override
  int get hashCode => Object.hash(blendMode, color, shader, strokeCap,
      strokeJoin, strokeMiterLimit, strokeWidth, style);

  @override
  bool operator ==(Object other) {
    return other is Paint &&
        other.blendMode == blendMode &&
        other.color == color &&
        other.shader == shader &&
        other.strokeCap == strokeCap &&
        other.strokeJoin == strokeJoin &&
        other.strokeMiterLimit == strokeMiterLimit &&
        other.strokeWidth == strokeWidth &&
        other.style == style;
  }
}
