import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:path_parsing/path_parsing.dart';

import 'util.dart';

enum PathFillType {
  nonZero,
  evenOdd,
}

@immutable
class Rect {
  const Rect.fromLTRB(this.left, this.top, this.right, this.bottom);
  const Rect.fromLTWH(double left, double top, double width, double height)
      : this.fromLTRB(left, top, left + width, top + height);
  const Rect.fromCircle(double x, double y, double r)
      : this.fromLTRB(x - r, y - r, x + r, y + r);

  static const Rect largest = Rect.fromLTRB(-1e9, -1e9, 1e9, 1e9);
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  @override
  String toString() => 'Rect.fromLTRB($left, $top, $right, $bottom)';

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  bool operator ==(Object other) {
    return other is Rect &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom;
  }
}

@immutable
class RRect {
  const RRect.fromLTRBXY(
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.rx,
    this.ry,
  );

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double rx;
  final double ry;

  String toString() =>
      'RRect.fromLTRBXY($left, $top, $right, $bottom, $rx, $ry)';

  @override
  int get hashCode => Object.hash(left, top, right, bottom, rx, ry);

  @override
  bool operator ==(Object other) {
    return other is RRect &&
        other.left == left &&
        other.top == top &&
        other.right == right &&
        other.bottom == bottom &&
        other.rx == rx &&
        other.ry == ry;
  }
}

enum PathCommandType {
  oval,
  rect,
  rrect,
  move,
  line,
  cubic,
  close,
}

@immutable
abstract class PathCommand {
  const PathCommand(this.type);

  final PathCommandType type;
  void write(buffer);
}

@immutable
class OvalCommand extends PathCommand {
  const OvalCommand(this.oval) : super(PathCommandType.oval);

  final Rect oval;

  void write(buffer) {
    print('  ..addOval($oval)');
  }

  @override
  int get hashCode => Object.hash(type, oval);

  @override
  bool operator ==(Object other) {
    return other is OvalCommand && other.oval == oval;
  }
}

class RectCommand extends PathCommand {
  const RectCommand(this.rect) : super(PathCommandType.rect);

  final Rect rect;

  void write(buffer) {
    print('..addRect($rect)');
  }

  @override
  int get hashCode => Object.hash(type, rect);

  @override
  bool operator ==(Object other) {
    return other is RectCommand && other.rect == rect;
  }
}

class RRectCommand extends PathCommand {
  const RRectCommand(this.rrect) : super(PathCommandType.rrect);

  final RRect rrect;

  void write(buffer) {
    print('..addRRect($rrect)');
  }

  @override
  int get hashCode => Object.hash(type, rrect);

  @override
  bool operator ==(Object other) {
    return other is RRectCommand && other.rrect == rrect;
  }
}

class LineToCommand extends PathCommand {
  const LineToCommand(this.x, this.y) : super(PathCommandType.line);

  final double x;
  final double y;

  void write(buffer) {
    print('  ..lineTo($x, $y)');
  }

  @override
  int get hashCode => Object.hash(type, x, y);

  @override
  bool operator ==(Object other) {
    return other is LineToCommand && other.x == x && other.y == y;
  }
}

class MoveToCommand extends PathCommand {
  const MoveToCommand(this.x, this.y) : super(PathCommandType.move);

  final double x;
  final double y;

  void write(buffer) {
    print('  ..moveTo($x, $y)');
  }

  @override
  int get hashCode => Object.hash(type, x, y);

  @override
  bool operator ==(Object other) {
    return other is MoveToCommand && other.x == x && other.y == y;
  }
}

class CubicToCommand extends PathCommand {
  const CubicToCommand(this.x1, this.y1, this.x2, this.y2, this.x3, this.y3)
      : super(PathCommandType.cubic);

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;

  void write(buffer) {
    print('  ..cubicTo($x1, $y1, $x2, $y2, $x3, $y3)');
  }

  @override
  int get hashCode => Object.hash(type, x1, y1, x2, y2, x3, y3);

  @override
  bool operator ==(Object other) {
    return other is CubicToCommand &&
        other.x1 == x1 &&
        other.y1 == y1 &&
        other.x2 == x2 &&
        other.y2 == y2 &&
        other.x3 == x3 &&
        other.y3 == y3;
    ;
  }
}

class CloseCommand extends PathCommand {
  const CloseCommand() : super(PathCommandType.close);

  void write(buffer) {
    print('  ..close()');
  }

  @override
  int get hashCode => type.hashCode;

  @override
  bool operator ==(Object other) {
    return other is CloseCommand;
  }
}

class PathBuilder implements PathProxy {
  PathBuilder([PathFillType? fillType])
      : this.fillType = fillType ?? PathFillType.nonZero;

  PathBuilder.fromPath(Path path) {
    addPath(path);
    fillType = path.fillType;
  }

  final List<PathCommand> _commands = <PathCommand>[];
  @override
  void close() {
    _commands.add(const CloseCommand());
  }

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    _commands.add(CubicToCommand(x1, y1, x2, y2, x3, y3));
  }

  @override
  void lineTo(double x, double y) {
    _commands.add(LineToCommand(x, y));
  }

  @override
  void moveTo(double x, double y) {
    _commands.add(MoveToCommand(x, y));
  }

  void addPath(Path other) {
    _commands.addAll(other._commands);
  }

  void addOval(Rect oval) {
    _commands.add(OvalCommand(oval));
  }

  void addRect(Rect rect) {
    _commands.add(RectCommand(rect));
  }

  void addRRect(RRect rrect) {
    _commands.add(RRectCommand(rrect));
  }

  late PathFillType fillType;

  Path toPath() {
    return Path(commands: _commands, fillType: fillType);
  }
}

@immutable
class Point {
  const Point(this.x, this.y);

  final double x;
  final double y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  bool operator ==(Object other) {
    return other is Point && other.x == x && other.y == y;
  }
}

@immutable
class AffineMatrix {
  const AffineMatrix(
    this.a,
    this.b,
    this.c,
    this.d,
    this.e,
    this.f,
  );

  static const AffineMatrix identity = AffineMatrix(1, 0, 0, 0, 1, 0);

  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  AffineMatrix rotated(double angle) {
    if (angle == 0) {
      return this;
    }
    final double cosAngle = math.cos(angle);
    final double sinAngle = math.sin(angle);
    return AffineMatrix(
      a * cosAngle,
      b * -sinAngle,
      c,
      d * sinAngle,
      e * cosAngle,
      f,
    );
  }

  AffineMatrix scaled(double x, [double? y]) {
    y ??= x;
    if (x == 1 && y == 1) {
      return this;
    }
    return AffineMatrix(
      a * x,
      b * x,
      c * y,
      d * y,
      e,
      f,
    );
  }

  AffineMatrix translated(double x, double y) {
    return AffineMatrix(
      a,
      b,
      c,
      d,
      e + x,
      f + y,
    );
  }

  AffineMatrix multiplied(AffineMatrix other) {
    return AffineMatrix(
      (a * other.a) + (c * other.b),
      (b * other.a) + (d * other.b),
      (a * other.c) + (c * other.d),
      (b * other.c) + (d * other.d),
      (a * other.e) + (c * other.f) + e,
      (b * other.e) + (d * other.f) + f,
    );
  }

  Point transformPoint(Point point) {
    return Point(
      (a * point.x) + (c * point.y) + e,
      (b * point.x) + (d * point.y) + f,
    );
  }

  Float64List toMatrix4() {
    return Float64List.fromList(<double>[
      a, b, 0, 0, //
      c, d, 0, 0, //
      0, 0, 1, 0, //
      e, f, 0, 1, //
    ]);
  }

  @override
  int get hashCode => Object.hash(a, b, c, d, e, f);

  @override
  bool operator ==(Object other) {
    return other is AffineMatrix &&
        other.a == a &&
        other.b == b &&
        other.d == d &&
        other.e == e;
  }

  @override
  String toString() => '''
[ $a, $b, $c ]
[ $d, $e, $f ]
[ 0.0, 0.0, 1.0 ]
''';
}

@immutable
class Path {
  Path({
    List<PathCommand> commands = const <PathCommand>[],
    this.fillType = PathFillType.nonZero,
  }) {
    _commands.addAll(commands);
  }

  final List<PathCommand> _commands = <PathCommand>[];
  final PathFillType fillType;

  void transform(AffineMatrix matrix) {}

  Rect getBounds() {
    // TODO
    return Rect.largest;
  }

  void write() {
    print('final path${hashCode} = ');
    if (transform != null) {
      print('(');
    }
    print('Path()');
    if (fillType != PathFillType.nonZero) {
      print('  ..fillType = $fillType');
    }
    for (final PathCommand command in _commands) {
      command.write(null);
    }
    if (transform != null) {
      print(').transform(Float64List.fromList(<double>$transform)');
    }
    print(';');
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(_commands), fillType, transform);

  @override
  bool operator ==(Object other) {
    return other is Path &&
        listEquals(_commands, other._commands) &&
        other.fillType == fillType &&
        other.transform == transform;
  }
}

Path parseSvgPathData(String svg) {
  if (svg == '') {
    return Path();
  }

  final SvgPathStringSource parser = SvgPathStringSource(svg);
  final PathBuilder pathBuilder = PathBuilder();
  final SvgPathNormalizer normalizer = SvgPathNormalizer();
  for (PathSegmentData seg in parser.parseSegments()) {
    normalizer.emitSegment(seg, pathBuilder);
  }
  return pathBuilder.toPath();
}
