import 'dart:ffi' as ffi;

final lib = ffi.DynamicLibrary.open('../lyon_wrapper/target/debug/lyon_wrapper.dll');

class PathBuilder extends ffi.Opaque {}

typedef CreatePathType = ffi.Pointer<PathBuilder> Function();
typedef create_path_type = ffi.Pointer<PathBuilder> Function();

final createPathFn = lib.lookupFunction<create_path_type, CreatePathType>('create_path');

typedef BeginType = void Function(ffi.Pointer<PathBuilder>, double, double);
typedef begin_type = ffi.Void Function(ffi.Pointer<PathBuilder>, ffi.Float, ffi.Float);

final beginFn = lib.lookupFunction<begin_type, BeginType>('begin');

typedef LineToType = void Function(ffi.Pointer<PathBuilder>, double, double);
typedef line_to_type = ffi.Void Function(ffi.Pointer<PathBuilder>, ffi.Float, ffi.Float);

final lineToFn = lib.lookupFunction<line_to_type, LineToType>('line_to');

typedef CubicToType = void Function(ffi.Pointer<PathBuilder>, double, double, double, double, double, double);
typedef cubic_to_type = ffi.Void Function(ffi.Pointer<PathBuilder>, ffi.Float, ffi.Float, ffi.Float, ffi.Float, ffi.Float, ffi.Float);

final cubicToFn = lib.lookupFunction<cubic_to_type, CubicToType>('cubic_to');

typedef CloseType = void Function(ffi.Pointer<PathBuilder>, bool);
typedef close_type = ffi.Void Function(ffi.Pointer<PathBuilder>, ffi.Bool);

final closeFn = lib.lookupFunction<close_type, CloseType>('close');

typedef TesselateType = void Function(ffi.Pointer<PathBuilder>);
typedef tesselate_type = ffi.Void Function(ffi.Pointer<PathBuilder>);

final tessellateFn = lib.lookupFunction<tesselate_type, TesselateType>('tessellate');

extension PathHelpers on ffi.Pointer<PathBuilder> {
  static ffi.Pointer<PathBuilder> create() {
    return createPathFn();
  }

  void begin(double x, double y) {
    beginFn(this, x, y);
  }

  void lineTo(double x, double y) {
    lineToFn(this, x, y);
  }

  void close() {
    closeFn(this, true);
  }

  void tesselate() {
    tessellateFn(this);
  }
}


void main() {
  var builder = PathHelpers.create();
  builder.begin(10, 10);
  builder.lineTo(20, 10);
  builder.lineTo(20, 20);
  builder.lineTo(10, 20);
  builder.close();
  builder.tesselate();
}
