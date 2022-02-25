import 'dart:convert';
import 'dart:typed_data';

import 'package:typed_data/typed_buffers.dart' show Uint8Buffer;

import 'parser/paint.dart';
import 'parser/path.dart';
import 'parser/vector_drawable.dart';

/// Rough outline of format. Except that all strings are replaced with
/// numbers for smaller format and faster parsing.
///
/// {
///   "version": 1, // version
///   "objects": [
///     {
///       "type": "paint",
///       "color": 0xFF112233,
///     },
///    ],
///    "commands": [
///       {
///          "type": "drawVertices",
///          "left": 0,
///          "top": 0,
///          "width": 100,
///          "height": 200,
///          "paint": 0 // use paint object 0
///          ...
///       },
///       // drawPath only supports absolute moveTo, lineTo, and cubicTo (The same as path_parsing/flutter_svg)
///       {
///          "type": "drawPath",
///           "commands": [
///             {
///               "type": "moveTo",
///               "x": 0,
///               "y": 1,
///             }
///           ]
///        }
///     ],
/// }
class PaintingCodec extends StandardMessageCodec {
  static const int _pathTag = 27;
  static const int _paintTag = 28;
  static const int _drawCommandTag = 29;
  static const int _drawVerticesTag = 30;

  final Map<Paint, int> _paintIds = {};
  final Map<Path, int> _pathIds = {};
  int _currentPaintId = 0;
  int _currentPathId = 0;

  PaintingCodecListener? _listener;

  Object? readValueOfType(int type, ReadBuffer buffer) {
    assert(type != 0);
    switch (type) {
      case _paintTag:
        return _readPaint(buffer);
      case _pathTag:
        return _readPath(buffer);
      case _drawCommandTag:
        return _readDrawCommand(buffer);
      case _drawVerticesTag:
        return _readDrawVertices(buffer);
      default:
        return super.readValueOfType(type, buffer);
    }
  }

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is Paint) {
      _writePaint(buffer, value);
    } else if (value is Path) {
      _writePath(buffer, value);
    } else if (value is DrawCommand) {
      _writeDrawCommand(buffer, value);
    } else {
      super.writeValue(buffer, value);
    }
  }

  void _writePaint(WriteBuffer buffer, Paint paint) {
    buffer.putUint8(_paintTag);
    buffer.putUint32(paint.color.value);
    buffer.putInt32(paint.strokeCap.index);
    buffer.putInt32(paint.strokeJoin.index);
    buffer.putInt32(paint.blendMode.index);
    buffer.putFloat64(paint.strokeMiterLimit);
    buffer.putFloat64(paint.strokeWidth);
    buffer.putInt32(paint.style.index);

    _currentPaintId += 1;
    _paintIds[paint] = _currentPaintId;
    buffer.putInt32(_currentPaintId);
  }

  Object? _readPaint(ReadBuffer buffer) {
    final int color = buffer.getUint32();
    final int strokeCap = buffer.getInt32();
    final int strokeJoin = buffer.getInt32();
    final int blendMode = buffer.getInt32();
    final double strokeMiterLimit = buffer.getFloat64();
    final double strokeWidth = buffer.getFloat64();
    final int paintStyle = buffer.getInt32();
    final int id = buffer.getInt32();
    _listener?.onPaintObject(
      color,
      strokeCap,
      strokeJoin,
      blendMode,
      strokeMiterLimit,
      strokeWidth,
      paintStyle,
      id,
    );
    return null;
  }

  void _writePath(WriteBuffer buffer, Path path) {
    buffer.putUint8(_pathTag);

    _currentPathId += 1;
    _pathIds[path] = _currentPathId;
    buffer.putInt32(_currentPathId);

    buffer.putInt32(path.fillType.index);
    var commands = path.commands.toList();
    buffer.putInt32(commands.length);
    for (var i = 0; i < commands.length; i += 1) {
      var command = commands[i];
      buffer.putUint8(command.type.index);
      if (command is MoveToCommand) {
        buffer.putFloat32List(Float32List.fromList([
          command.x,
          command.y,
        ]));
      } else if (command is LineToCommand) {
        buffer.putFloat32List(Float32List.fromList([
          command.x,
          command.y,
        ]));
      } else if (command is CubicToCommand) {
        buffer.putFloat32List(Float32List.fromList([
          command.x1,
          command.y1,
          command.x2,
          command.y2,
          command.x3,
          command.y3,
        ]));
      } else if (command is CloseCommand) {
        continue;
      } else {
        throw UnsupportedError(command.toString());
      }
    }
  }

  Object? _readPath(ReadBuffer buffer) {
    final int id = buffer.getInt32();
    final int fillType = buffer.getInt32();
    final int commandLength = buffer.getInt32();
    _listener?.onPathStart(id, fillType);

    for (var i = 0; i < commandLength; i++) {
      final int pathType = buffer.getUint8();
      if (pathType == PathCommandType.move.index) {
        var controlPoints = buffer.getFloat32List(2);
        _listener?.onPathMoveTo(controlPoints[0], controlPoints[1]);
      } else if (pathType == PathCommandType.line.index) {
        var controlPoints = buffer.getFloat32List(2);
        _listener?.onPathLineTo(controlPoints[0], controlPoints[1]);
      } else if (pathType == PathCommandType.cubic.index) {
        var controlPoints = buffer.getFloat32List(6);
        _listener?.onPathCubicTo(
          controlPoints[0],
          controlPoints[1],
          controlPoints[2],
          controlPoints[3],
          controlPoints[4],
          controlPoints[5],
        );
      } else if (pathType == PathCommandType.close.index) {
        _listener?.onPathClose();
      } else {
        throw UnsupportedError(pathType.toString());
      }
    }
    _listener?.onPathFinished();
    return null;
  }

  void _writeDrawCommand(WriteBuffer buffer, DrawCommand command) {
    if (command is DrawPathCommand) {
      buffer.putUint8(_drawCommandTag);
      assert(_pathIds.containsKey(command.path),
          'Expected to find ${command.path.hashCode}, have ${_pathIds.keys.map((p) => p.hashCode).toList()}');
      assert(_paintIds.containsKey(command.paint));
      buffer.putInt32(_pathIds[command.path]!);
      buffer.putInt32(_paintIds[command.paint]!);
    } else if (command is DrawVerticesCommand) {
      buffer.putUint8(_drawVerticesTag);
      buffer.putInt32(command.paint == null ? -1 : _paintIds[command.paint]!);
      buffer.putInt32(command.vertices.length);
      buffer.putFloat32List(command.vertices);
      // if (command.colors == null) {
      //   buffer.putInt32(0);
      // } else {
      buffer.putInt32(command.colors!.first);
      //   buffer.putInt32List(command.colors!);
      // }
      buffer.putInt32(command.indices!.length);
      buffer.putUint16List(command.indices!);
    }
  }

  Object? _readDrawCommand(ReadBuffer buffer) {
    final int pathId = buffer.getInt32();
    final int paintId = buffer.getInt32();
    _listener?.onDrawCommand(pathId, paintId);
    return null;
  }

  Object? _readDrawVertices(ReadBuffer buffer) {
    final int paintId = buffer.getInt32();
    final int verticesLength = buffer.getInt32();
    final Float32List vertices = buffer.getFloat32List(verticesLength);
    final int color = buffer.getInt32();
    final Int32List colors = Int32List(1);
    colors[0] = color;
    // Int32List? colors;
    // if (colorsLength != 0) {
    //   colors = buffer.getInt32List(colorsLength);
    // }
    final indicesLength = buffer.getInt32();
    if (indicesLength > 0) {
      buffer.getUint16List(indicesLength);
    }
    _listener?.onDrawVertices(vertices, colors, paintId);
    return null;
  }
}

abstract class PaintingCodecListener {
  void onPaintObject(
    int color,
    int strokeCap,
    int strokeJoin,
    int blendMode,
    double strokeMiterLimit,
    double strokeWidth,
    int paintStyle,
    int id,
  );

  void onPathStart(int id, int fillType);

  void onPathMoveTo(double x, double y);

  void onPathLineTo(double x, double y);

  void onPathCubicTo(
      double x1, double y1, double x2, double y2, double x3, double y3);

  void onPathClose();

  void onPathFinished();

  void onDrawCommand(
    int path,
    int paint,
  );

  void onDrawVertices(
    Float32List vertices,
    Int32List? colors,
    int paint,
  );
}

int? lastZeroIndex;

/// [MessageCodec] using the Flutter standard binary encoding.
class StandardMessageCodec {
  /// Creates a [MessageCodec] using the Flutter standard binary encoding.
  const StandardMessageCodec();

  // The type labels below must not change, since it's possible for this interface
  // to be used for persistent storage.
  static const int _valueNull = 0;
  static const int _valueTrue = 1;
  static const int _valueFalse = 2;
  static const int _valueInt32 = 3;
  static const int _valueInt64 = 4;
  static const int _valueLargeInt = 5;
  static const int _valueFloat64 = 6;
  static const int _valueString = 7;
  static const int _valueUint8List = 8;
  static const int _valueInt32List = 9;
  static const int _valueInt64List = 10;
  static const int _valueFloat64List = 11;
  static const int _valueList = 12;
  static const int _valueMap = 13;
  static const int _valueFloat32List = 14;

  ByteData? encodeMessage(Object? message) {
    if (message == null) return null;
    final WriteBuffer buffer = WriteBuffer();
    writeValue(buffer, message);
    return buffer.done();
  }

  Object? decodeMessage(ByteData? message) {
    if (message == null) return null;
    final ReadBuffer buffer = ReadBuffer(message);
    final Object? result = readValue(buffer);
    while (buffer.hasRemaining) {
      if (buffer.getUint8() != 0)
        throw const FormatException('Message corrupted');
    }
    return result;
  }

  /// Writes [value] to [buffer] by first writing a type discriminator
  /// byte, then the value itself.
  ///
  /// This method may be called recursively to serialize container values.
  ///
  /// Type discriminators 0 through 127 inclusive are reserved for use by the
  /// base class, as follows:
  ///
  ///  * null = 0
  ///  * true = 1
  ///  * false = 2
  ///  * 32 bit integer = 3
  ///  * 64 bit integer = 4
  ///  * larger integers = 5 (see below)
  ///  * 64 bit floating-point number = 6
  ///  * String = 7
  ///  * Uint8List = 8
  ///  * Int32List = 9
  ///  * Int64List = 10
  ///  * Float64List = 11
  ///  * List = 12
  ///  * Map = 13
  ///  * Float32List = 14
  ///  * Reserved for future expansion: 15..127
  ///
  /// The codec can be extended by overriding this method, calling super
  /// for values that the extension does not handle. Type discriminators
  /// used by extensions must be greater than or equal to 128 in order to avoid
  /// clashes with any later extensions to the base class.
  ///
  /// The "larger integers" type, 5, is never used by [writeValue]. A subclass
  /// could represent big integers from another package using that type. The
  /// format is first the type byte (0x05), then the actual number as an ASCII
  /// string giving the hexadecimal representation of the integer, with the
  /// string's length as encoded by [writeSize] followed by the string bytes. On
  /// Android, that would get converted to a `java.math.BigInteger` object. On
  /// iOS, the string representation is returned.
  void writeValue(WriteBuffer buffer, Object? value) {
    assert(value != null);
    if (value == null) {
      buffer.putUint8(_valueNull);
    } else if (value is bool) {
      buffer.putUint8(value ? _valueTrue : _valueFalse);
    } else if (value is double) {
      // Double precedes int because in JS everything is a double.
      // Therefore in JS, both `is int` and `is double` always
      // return `true`. If we check int first, we'll end up treating
      // all numbers as ints and attempt the int32/int64 conversion,
      // which is wrong. This precedence rule is irrelevant when
      // decoding because we use tags to detect the type of value.
      buffer.putUint8(_valueFloat64);
      buffer.putFloat64(value);
    } else if (value is int) {
      // ignore: avoid_double_and_int_checks, JS code always goes through the `double` path above
      if (-0x7fffffff - 1 <= value && value <= 0x7fffffff) {
        buffer.putUint8(_valueInt32);
        buffer.putInt32(value);
      } else {
        buffer.putUint8(_valueInt64);
        buffer.putInt64(value);
      }
    } else if (value is String) {
      buffer.putUint8(_valueString);
      final Uint8List bytes = utf8.encoder.convert(value);
      writeSize(buffer, bytes.length);
      buffer.putUint8List(bytes);
    } else if (value is Uint8List) {
      buffer.putUint8(_valueUint8List);
      writeSize(buffer, value.length);
      buffer.putUint8List(value);
    } else if (value is Int32List) {
      buffer.putUint8(_valueInt32List);
      writeSize(buffer, value.length);
      buffer.putInt32List(value);
    } else if (value is Int64List) {
      buffer.putUint8(_valueInt64List);
      writeSize(buffer, value.length);
      buffer.putInt64List(value);
    } else if (value is Float32List) {
      buffer.putUint8(_valueFloat32List);
      writeSize(buffer, value.length);
      buffer.putFloat32List(value);
    } else if (value is Float64List) {
      buffer.putUint8(_valueFloat64List);
      writeSize(buffer, value.length);
      buffer.putFloat64List(value);
    } else if (value is List) {
      buffer.putUint8(_valueList);
      writeSize(buffer, value.length);
      for (final Object? item in value) {
        writeValue(buffer, item);
      }
    } else if (value is Map) {
      buffer.putUint8(_valueMap);
      writeSize(buffer, value.length);
      value.forEach((Object? key, Object? value) {
        writeValue(buffer, key);
        writeValue(buffer, value);
      });
    } else {
      throw ArgumentError.value(value);
    }
  }

  /// Reads a value from [buffer] as written by [writeValue].
  ///
  /// This method is intended for use by subclasses overriding
  /// [readValueOfType].
  Object? readValue(ReadBuffer buffer) {
    if (!buffer.hasRemaining) throw const FormatException('Message corrupted');
    final int type = buffer.getUint8();
    return readValueOfType(type, buffer);
  }

  /// Reads a value of the indicated [type] from [buffer].
  ///
  /// The codec can be extended by overriding this method, calling super for
  /// types that the extension does not handle. See the discussion at
  /// [writeValue].
  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case _valueNull:
        return null;
      case _valueTrue:
        return true;
      case _valueFalse:
        return false;
      case _valueInt32:
        return buffer.getInt32();
      case _valueInt64:
        return buffer.getInt64();
      case _valueFloat64:
        return buffer.getFloat64();
      case _valueLargeInt:
      case _valueString:
        final int length = readSize(buffer);
        return utf8.decoder.convert(buffer.getUint8List(length));
      case _valueUint8List:
        final int length = readSize(buffer);
        return buffer.getUint8List(length);
      case _valueInt32List:
        final int length = readSize(buffer);
        return buffer.getInt32List(length);
      case _valueInt64List:
        final int length = readSize(buffer);
        return buffer.getInt64List(length);
      case _valueFloat32List:
        final int length = readSize(buffer);
        return buffer.getFloat32List(length);
      case _valueFloat64List:
        final int length = readSize(buffer);
        return buffer.getFloat64List(length);
      case _valueList:
        final int length = readSize(buffer);
        final List<Object?> result = List<Object?>.filled(length, null);
        for (int i = 0; i < length; i++) result[i] = readValue(buffer);
        return result;
      case _valueMap:
        final int length = readSize(buffer);
        final Map<Object?, Object?> result = <Object?, Object?>{};
        for (int i = 0; i < length; i++)
          result[readValue(buffer)] = readValue(buffer);
        return result;
      default:
        throw const FormatException('Message corrupted');
    }
  }

  /// Writes a non-negative 32-bit integer [value] to [buffer]
  /// using an expanding 1-5 byte encoding that optimizes for small values.
  ///
  /// This method is intended for use by subclasses overriding
  /// [writeValue].
  void writeSize(WriteBuffer buffer, int value) {
    assert(0 <= value && value <= 0xffffffff);
    if (value < 254) {
      buffer.putUint8(value);
    } else if (value <= 0xffff) {
      buffer.putUint8(254);
      buffer.putUint16(value);
    } else {
      buffer.putUint8(255);
      buffer.putUint32(value);
    }
  }

  /// Reads a non-negative int from [buffer] as written by [writeSize].
  ///
  /// This method is intended for use by subclasses overriding
  /// [readValueOfType].
  int readSize(ReadBuffer buffer) {
    final int value = buffer.getUint8();
    switch (value) {
      case 254:
        return buffer.getUint16();
      case 255:
        return buffer.getUint32();
      default:
        return value;
    }
  }
}

/// Write-only buffer for incrementally building a [ByteData] instance.
///
/// A WriteBuffer instance can be used only once. Attempts to reuse will result
/// in [StateError]s being thrown.
///
/// The byte order used is [Endian.host] throughout.
class WriteBuffer {
  /// Creates an interface for incrementally building a [ByteData] instance.
  WriteBuffer()
      : _buffer = Uint8Buffer(),
        _isDone = false,
        _eightBytes = ByteData(8) {
    _eightBytesAsList = _eightBytes.buffer.asUint8List();
  }

  Uint8Buffer _buffer;
  bool _isDone;
  final ByteData _eightBytes;
  late Uint8List _eightBytesAsList;
  static final Uint8List _zeroBuffer =
      Uint8List.fromList(<int>[0, 0, 0, 0, 0, 0, 0, 0]);

  /// Write a Uint8 into the buffer.
  void putUint8(int byte) {
    assert(!_isDone);
    _buffer.add(byte);
  }

  /// Write a Uint16 into the buffer.
  void putUint16(int value, {Endian? endian}) {
    assert(!_isDone);
    _eightBytes.setUint16(0, value, endian ?? Endian.host);
    _buffer.addAll(_eightBytesAsList, 0, 2);
  }

  /// Write a Uint32 into the buffer.
  void putUint32(int value, {Endian? endian}) {
    assert(!_isDone);
    _eightBytes.setUint32(0, value, endian ?? Endian.host);
    _buffer.addAll(_eightBytesAsList, 0, 4);
  }

  /// Write an Int32 into the buffer.
  void putInt32(int value, {Endian? endian}) {
    assert(!_isDone);
    _eightBytes.setInt32(0, value, endian ?? Endian.host);
    _buffer.addAll(_eightBytesAsList, 0, 4);
  }

  /// Write an Int64 into the buffer.
  void putInt64(int value, {Endian? endian}) {
    assert(!_isDone);
    _eightBytes.setInt64(0, value, endian ?? Endian.host);
    _buffer.addAll(_eightBytesAsList, 0, 8);
  }

  /// Write an Float64 into the buffer.
  void putFloat64(double value, {Endian? endian}) {
    assert(!_isDone);
    _alignTo(8);
    _eightBytes.setFloat64(0, value, endian ?? Endian.host);
    _buffer.addAll(_eightBytesAsList);
  }

  /// Write all the values from a [Uint8List] into the buffer.
  void putUint8List(Uint8List list) {
    assert(!_isDone);
    _buffer.addAll(list);
  }

  /// Write all the values from an [Uint16List] into the buffer.
  void putUint16List(Uint16List list) {
    assert(!_isDone);
    _alignTo(4);
    _buffer
        .addAll(list.buffer.asUint8List(list.offsetInBytes, 2 * list.length));
  }

  /// Write all the values from an [Int32List] into the buffer.
  void putInt32List(Int32List list) {
    assert(!_isDone);
    _alignTo(4);
    _buffer
        .addAll(list.buffer.asUint8List(list.offsetInBytes, 4 * list.length));
  }

  /// Write all the values from an [Int64List] into the buffer.
  void putInt64List(Int64List list) {
    assert(!_isDone);
    _alignTo(8);
    _buffer
        .addAll(list.buffer.asUint8List(list.offsetInBytes, 8 * list.length));
  }

  /// Write all the values from a [Float32List] into the buffer.
  void putFloat32List(Float32List list) {
    assert(!_isDone);
    _alignTo(4);
    _buffer
        .addAll(list.buffer.asUint8List(list.offsetInBytes, 4 * list.length));
  }

  /// Write all the values from a [Float64List] into the buffer.
  void putFloat64List(Float64List list) {
    assert(!_isDone);
    _alignTo(8);
    _buffer
        .addAll(list.buffer.asUint8List(list.offsetInBytes, 8 * list.length));
  }

  void _alignTo(int alignment) {
    assert(!_isDone);
    final int mod = _buffer.length % alignment;
    if (mod != 0) {
      _buffer.addAll(_zeroBuffer, 0, alignment - mod);
    }
  }

  /// Finalize and return the written [ByteData].
  ByteData done() {
    if (_isDone) {
      throw StateError(
          'done() must not be called more than once on the same $runtimeType.');
    }
    final ByteData result = _buffer.buffer.asByteData(0, _buffer.lengthInBytes);
    _buffer = Uint8Buffer();
    _isDone = true;
    return result;
  }
}

/// Read-only buffer for reading sequentially from a [ByteData] instance.
///
/// The byte order used is [Endian.host] throughout.
class ReadBuffer {
  /// Creates a [ReadBuffer] for reading from the specified [data].
  ReadBuffer(this.data);

  /// The underlying data being read.
  final ByteData data;

  /// The position to read next.
  int _position = 0;

  /// Whether the buffer has data remaining to read.
  bool get hasRemaining => _position < data.lengthInBytes;

  /// Reads a Uint8 from the buffer.
  int getUint8() {
    return data.getUint8(_position++);
  }

  /// Reads a Uint16 from the buffer.
  int getUint16({Endian? endian}) {
    final int value = data.getUint16(_position, endian ?? Endian.host);
    _position += 2;
    return value;
  }

  /// Reads a Uint32 from the buffer.
  int getUint32({Endian? endian}) {
    final int value = data.getUint32(_position, endian ?? Endian.host);
    _position += 4;
    return value;
  }

  /// Reads an Int32 from the buffer.
  int getInt32({Endian? endian}) {
    final int value = data.getInt32(_position, endian ?? Endian.host);
    _position += 4;
    return value;
  }

  /// Reads an Int64 from the buffer.
  int getInt64({Endian? endian}) {
    final int value = data.getInt64(_position, endian ?? Endian.host);
    _position += 8;
    return value;
  }

  /// Reads a Float64 from the buffer.
  double getFloat64({Endian? endian}) {
    _alignTo(8);
    final double value = data.getFloat64(_position, endian ?? Endian.host);
    _position += 8;
    return value;
  }

  /// Reads the given number of Uint8s from the buffer.
  Uint8List getUint8List(int length) {
    final Uint8List list =
        data.buffer.asUint8List(data.offsetInBytes + _position, length);
    _position += length;
    return list;
  }

  Uint16List getUint16List(int length) {
    _alignTo(4);
    final Uint16List list =
        data.buffer.asUint16List(data.offsetInBytes + _position, length);
    _position += 2 * length;
    return list;
  }

  /// Reads the given number of Int32s from the buffer.
  Int32List getInt32List(int length) {
    _alignTo(4);
    final Int32List list =
        data.buffer.asInt32List(data.offsetInBytes + _position, length);
    _position += 4 * length;
    return list;
  }

  /// Reads the given number of Int64s from the buffer.
  Int64List getInt64List(int length) {
    _alignTo(8);
    final Int64List list =
        data.buffer.asInt64List(data.offsetInBytes + _position, length);
    _position += 8 * length;
    return list;
  }

  /// Reads the given number of Float32s from the buffer
  Float32List getFloat32List(int length) {
    _alignTo(4);
    final Float32List list =
        data.buffer.asFloat32List(data.offsetInBytes + _position, length);
    _position += 4 * length;
    return list;
  }

  /// Reads the given number of Float64s from the buffer.
  Float64List getFloat64List(int length) {
    _alignTo(8);
    final Float64List list =
        data.buffer.asFloat64List(data.offsetInBytes + _position, length);
    _position += 8 * length;
    return list;
  }

  void _alignTo(int alignment) {
    final int mod = _position % alignment;
    if (mod != 0) _position += alignment - mod;
  }
}
