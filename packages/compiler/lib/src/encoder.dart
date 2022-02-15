import 'dart:typed_data';
import 'dart:ui';

abstract class _FormatKeys {
  // keys
  static const int version = 0;
  static const int objects = 1;
  static const int commands = 2;
  static const int objectType = 3;
  static const int paintColor = 4;
  static const int commandType = 5;

  // paint
  static const int paintType = 23;

  // commands
  static const int drawRect = 100;
  static const int drawRectLeft = 101;
  static const int drawRectTop = 102;
  static const int drawRectWidth = 103;
  static const int drawRectHeight = 104;
  static const int drawRectPaint = 105;

  static const int drawVertices = 106;
  static const int drawVerticesMode = 107;
  static const int drawVerticesPositions = 108;
  // nullable
  static const int drawVerticesTextureCoordinates = 109;
  static const int drawVerticesColors = 110;
  static const int drawVerticesIndices = 111;

  static const int drawVerticesBlendMode = 112;
  static const int drawVerticesPaint = 113;

  static const int drawPath = 120;
  static const int drawPathObjects = 121;
  static const int drawPathPaint = 122;

  static const int pathCommandType = 123;
  static const int moveTo = 124;
  static const int lineTo = 125;
  static const int cubicTo = 126;
  static const int controlPoints = 127;
}

enum PathCommandType {
  moveTo,
  lineTo,
  cubicTo,
}

class PathCommand {
  PathCommand.moveTo(double x, double y)
      : type = PathCommandType.moveTo,
        points = [x, y];

  PathCommand.lineTo(double x, double y)
      : type = PathCommandType.lineTo,
        points = [x, y];

  PathCommand.cubicTo(
      double x1, double y1, double x2, double y2, double x3, double y3)
      : type = PathCommandType.cubicTo,
        points = [x1, y1, x2, y2, x3, y3];

  final PathCommandType type;
  final List<double> points;
}

class FlutterPath {
  final List<PathCommand> commands = <PathCommand>[];

  void moveTo(double x, double y) {
    commands.add(PathCommand.moveTo(x, y));
  }

  void lineTo(double x, double y) {
    commands.add(PathCommand.lineTo(x, y));
  }

  void cubicTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    commands.add(PathCommand.cubicTo(x1, y1, x2, y2, x3, y3));
  }
}

class FlutterPaint {
  Color color = Color(0);
}

Map<Object?, Object?> encodePaint(Paint paint) {
  return {
    _FormatKeys.objectType: _FormatKeys.paintType,
    _FormatKeys.paintColor: paint.color.value,
  };
}

Map<Object?, Object?> encodeDrawPath(Path path, int paintIndex) {
  return {
    _FormatKeys.commandType: _FormatKeys.drawPath,
    _FormatKeys.drawPathObjects: encodePathCommands(path),
    _FormatKeys.drawPathPaint: paintIndex,
  };
}

List<Object?> encodePathCommands(Path path) {
  // TODO: paths can't be introspected.
  return [];
}

Map<Object?, Object?> encodeDrawVertices(
  VertexMode vertexMode,
  Float32List positions,
  Float32List? textureCoordinates,
  Int32List? colors,
  Uint16List? indices,
  BlendMode blendMode,
  int paintIndex,
) {
  return {
    _FormatKeys.commandType: _FormatKeys.drawVertices,
    _FormatKeys.drawVerticesMode: vertexMode.index,
    _FormatKeys.drawVerticesPositions: positions.buffer.asUint8List(),
    _FormatKeys.drawVerticesTextureCoordinates:
        textureCoordinates?.buffer.asUint8List(),
    _FormatKeys.drawVerticesColors: colors,
    _FormatKeys.drawVerticesIndices: indices?.buffer.asUint8List(),
    _FormatKeys.drawVerticesBlendMode: blendMode.index,
    _FormatKeys.drawVerticesPaint: paintIndex,
  };
}
