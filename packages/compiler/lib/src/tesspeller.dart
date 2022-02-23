import 'dart:ffi' as ffi;

import 'dart:typed_data';

import 'parser/path.dart';

final lib = ffi.DynamicLibrary.open('tesspeller.dll');

class _Vertices extends ffi.Struct {
  external ffi.Pointer<ffi.Float> points;

  @ffi.Uint32()
  external int size;
}

class _PathBuilder extends ffi.Opaque {}

typedef _CreatePathBuilderType = ffi.Pointer<_PathBuilder> Function();
typedef _create_path_builder_type = ffi.Pointer<_PathBuilder> Function();

final _createPathFn =
    lib.lookupFunction<_create_path_builder_type, _CreatePathBuilderType>(
        'CreatePathBuilder');

typedef _MoveToType = void Function(ffi.Pointer<_PathBuilder>, double, double);
typedef _move_to_type = ffi.Void Function(
    ffi.Pointer<_PathBuilder>, ffi.Float, ffi.Float);

final _moveToFn = lib.lookupFunction<_move_to_type, _MoveToType>('MoveTo');

typedef _LineToType = void Function(ffi.Pointer<_PathBuilder>, double, double);
typedef _line_to_type = ffi.Void Function(
    ffi.Pointer<_PathBuilder>, ffi.Float, ffi.Float);

final _lineToFn = lib.lookupFunction<_line_to_type, _LineToType>('LineTo');

typedef _CubicToType = void Function(
    ffi.Pointer<_PathBuilder>, double, double, double, double, double, double);
typedef _cubic_to_type = ffi.Void Function(ffi.Pointer<_PathBuilder>, ffi.Float,
    ffi.Float, ffi.Float, ffi.Float, ffi.Float, ffi.Float);

final _cubicToFn = lib.lookupFunction<_cubic_to_type, _CubicToType>('CubicTo');

typedef _CloseType = void Function(ffi.Pointer<_PathBuilder>, bool);
typedef _close_type = ffi.Void Function(ffi.Pointer<_PathBuilder>, ffi.Bool);

final closeFn = lib.lookupFunction<_close_type, _CloseType>('Close');

typedef _AddRectType = void Function(ffi.Pointer<_PathBuilder>, double, double, double, double);
typedef _add_rect_type = ffi.Void Function(ffi.Pointer<_PathBuilder>, ffi.Float, ffi.Float, ffi.Float, ffi.Float);

final addRectFn = lib.lookupFunction<_add_rect_type, _AddRectType>('AddRect');

typedef _AddRRectType = void Function(ffi.Pointer<_PathBuilder>, double, double, double, double, double, double);
typedef _add_rrect_type = ffi.Void Function(ffi.Pointer<_PathBuilder>, ffi.Float, ffi.Float, ffi.Float, ffi.Float, ffi.Float, ffi.Float);

final addRRectFn = lib.lookupFunction<_add_rrect_type, _AddRRectType>('AddRoundedRect');

typedef _TesselateType = ffi.Pointer<_Vertices> Function(
    ffi.Pointer<_PathBuilder>);
typedef _tesselate_type = ffi.Pointer<_Vertices> Function(
    ffi.Pointer<_PathBuilder>);

final _tessellateFn =
    lib.lookupFunction<_tesselate_type, _TesselateType>('Tessellate');

typedef _DestroyType = void Function(ffi.Pointer<_PathBuilder>);
typedef _destroy_type = ffi.Void Function(ffi.Pointer<_PathBuilder>);

final _destroyFn =
    lib.lookupFunction<_destroy_type, _DestroyType>('DestroyPathBuilder');

typedef _DestroyVerticesType = void Function(ffi.Pointer<_Vertices>);
typedef _destroy_vertices_type = ffi.Void Function(ffi.Pointer<_Vertices>);

final _destroyVerticesFn =
    lib.lookupFunction<_destroy_vertices_type, _DestroyVerticesType>(
        'DestroyVertices');

class PathBuilder {
  PathBuilder() : _builder = _createPathFn();

  final ffi.Pointer<_PathBuilder> _builder;
  final List<ffi.Pointer<_Vertices>> _vertices = <ffi.Pointer<_Vertices>>[];

  void moveTo(double x, double y) {
    _moveToFn(_builder, x, y);
  }

  void lineTo(double x, double y) {
    _lineToFn(_builder, x, y);
  }

  void addRect(double x, double y, double w, double h) {
    addRectFn(_builder, x, y, w, h);
  }

  void addRRect(double x, double y, double w, double h, double a, double b) {
    addRRectFn(_builder, x, y, w, h, a, b);
  }

  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    _cubicToFn(_builder, x1, y1, x2, y2, x3, y3);
  }

  void close() {
    closeFn(_builder, true);
  }

  Float32List tesselate() {
    final ffi.Pointer<_Vertices> vertices = _tessellateFn(_builder);
    _vertices.add(vertices);
    return vertices.ref.points.asTypedList(vertices.ref.size);
  }

  void dispose() {
    for (final vertices in _vertices) {
      _destroyVerticesFn(vertices);
    }
    _destroyFn(_builder);
  }
}

Float32List convertPathToVertices(Path path) {
  var builder = PathBuilder();
  for (var command in path.commands) {
    switch (command.type) {
      case PathCommandType.move:
        var moveTo = command as MoveToCommand;
        builder.moveTo(moveTo.x, moveTo.y);
        break;
      case PathCommandType.line:
        var lineTo = command as LineToCommand;
        builder.lineTo(lineTo.x, lineTo.y);
        break;
      case PathCommandType.cubic:
        var cubicTo = command as CubicToCommand;
        builder.cubicTo(
          cubicTo.x1,
          cubicTo.y1,
          cubicTo.x2,
          cubicTo.x2,
          cubicTo.y3,
          cubicTo.y3,
        );
        break;
      case PathCommandType.close:
        builder.close();
        break;
      case PathCommandType.rect:
        var rect = (command as RectCommand).rect;
        builder.addRect(rect.left, rect.top, rect.right, rect.bottom);
        break;
      case PathCommandType.rrect:
        var rrect = (command as RRectCommand).rrect;
        builder.addRRect(rrect.left, rrect.top, rrect.right, rrect.bottom, rrect.rx, rrect.ry);
        break;
      default:
        print(command);
        throw Error();
    }
  }
  return builder.tesselate();
}
