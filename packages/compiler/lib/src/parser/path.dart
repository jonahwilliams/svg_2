import 'dart:typed_data';
import 'package:path_parsing/path_parsing.dart';

enum PathFillType {
  nonZero,
  evenOdd,
}

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
}

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
}

abstract class PathCommand {
  const PathCommand();

  void write(buffer);
}

class OvalCommand extends PathCommand {
  const OvalCommand(this.oval);

  final Rect oval;

  void write(buffer) {
    print('  ..addOval($oval)');
  }
}

class RectCommand extends PathCommand {
  const RectCommand(this.rect);

  final Rect rect;

  void write(buffer) {
    print('..addRect($rect)');
  }
}

class RRectCommand extends PathCommand {
  const RRectCommand(this.rrect);

  final RRect rrect;

  void write(buffer) {
    print('..addRRect($rrect)');
  }
}

class LineToCommand extends PathCommand {
  const LineToCommand(this.x, this.y);

  final double x;
  final double y;

  void write(buffer) {
    print('  ..lineTo($x, $y)');
  }
}

class MoveToCommand extends PathCommand {
  const MoveToCommand(this.x, this.y);

  final double x;
  final double y;

  void write(buffer) {
    print('  ..moveTo($x, $y)');
  }
}

class CubicToCommand extends PathCommand {
  const CubicToCommand(this.x1, this.y1, this.x2, this.y2, this.x3, this.y3);

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x3;
  final double y3;

  void write(buffer) {
    print('  ..cubicTo($x1, $y1, $x2, $y2, $x3, $y3)');
  }
}

class CloseCommand extends PathCommand {
  const CloseCommand();

  void write(buffer) {
    print('  ..close()');
  }
}

class Path implements PathProxy {
  List<PathCommand> _commands = <PathCommand>[];
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

  Rect getBounds() {
    return Rect.largest;
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

  PathFillType fillType = PathFillType.nonZero;

  Path? transform(Float64List storage) {
    return this;
  }

  void write() {
    print('Path()');
    if (fillType != PathFillType.nonZero) {
      print('  ..fillType = $fillType');
    }
    for (final PathCommand command in _commands) {
      command.write(null);
    }
    print(';');
  }
}

Path parseSvgPathData(String svg) {
  if (svg == '') {
    return Path();
  }

  final SvgPathStringSource parser = SvgPathStringSource(svg);
  final Path path = Path();
  final SvgPathNormalizer normalizer = SvgPathNormalizer();
  for (PathSegmentData seg in parser.parseSegments()) {
    normalizer.emitSegment(seg, path);
  }
  return path;
}
