import 'dart:ffi' as ffi;

import 'dart:typed_data';

final lib = ffi.DynamicLibrary.open(
    '/Users/dnfield/src/flutter/engine/src/out/host_debug_unopt/libtesspeller.dylib');

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

void main() {
  var builder = PathBuilder();
  builder.moveTo(10, 10);
  builder.lineTo(20, 10);
  builder.lineTo(20, 20);
  builder.lineTo(10, 20);
  builder.cubicTo(100, 100, 200, 150, 30, 30);
  builder.close();
  var arr = builder.tesselate();
  print(arr);
  // print(arr.size);

  builder.dispose();
}
