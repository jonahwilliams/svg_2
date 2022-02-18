// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';

enum PathCommandType {
  oval,
  rect,
  rrect,
  move,
  line,
  cubic,
  close,
}

class PaintingCodec extends StandardMessageCodec {
  PaintingCodec(this._listener);

  static const int _pathTag = 27;
  static const int _paintTag = 28;
  static const int _drawCommandTag = 29;

  PaintingCodecListener? _listener;

  Object? readValueOfType(int type, ReadBuffer buffer) {
    print(type);
    switch (type) {
      case _paintTag:
        return _readPaint(buffer);
      case _pathTag:
        return _readPath(buffer);
      case _drawCommandTag:
        return _readDrawCommand(buffer);
      default:
        return super.readValueOfType(type, buffer);
    }
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

  Object? _readPath(ReadBuffer buffer) {
    final int id = buffer.getInt32();
    final int fillType = buffer.getInt32();
    final int commandLength = buffer.getInt32();
    print('path $id has $commandLength commands');
    _listener?.onPathStart(id, fillType);

    for (var i = 0; i < commandLength; i++) {
      final int pathType = buffer.getUint8();
      if (pathType == PathCommandType.move.index) {
        var controlPoints = buffer.getFloat32List(2);
        print('moveTo $controlPoints');
        _listener?.onPathMoveTo(controlPoints[0], controlPoints[1]);
      } else if (pathType == PathCommandType.line.index) {
        var controlPoints = buffer.getFloat32List(2);
        print('lineTo $controlPoints');
        _listener?.onPathLineTo(controlPoints[0], controlPoints[1]);
      } else if (pathType == PathCommandType.cubic.index) {
        var controlPoints = buffer.getFloat32List(6);
        print('cubicTo $controlPoints');
        _listener?.onPathCubicTo(
          controlPoints[0],
          controlPoints[1],
          controlPoints[2],
          controlPoints[3],
          controlPoints[4],
          controlPoints[5],
        );
      } else if (pathType == PathCommandType.close.index) {
        print('close');
        _listener?.onPathClose();
      } else {
        throw UnsupportedError(pathType.toString());
      }
    }
    _listener?.onPathFinished();
    return null;
  }

  Object? _readDrawCommand(ReadBuffer buffer) {
    final int pathId = buffer.getInt32();
    final int paintId = buffer.getInt32();
    _listener?.onDrawCommand(pathId, paintId);
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
}

class FlutterPaintCodecListener extends PaintingCodecListener {
  FlutterPaintCodecListener(this.canvas);

  final Map<int, Paint> _paints = {};
  final Canvas canvas;
  Path? currentPath;
  final Map<int, Path> _paths = {};

  @override
  void onPathClose() {
    currentPath!.close();
  }

  @override
  void onPathCubicTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    currentPath!.cubicTo(x1, y1, x2, y2, x3, y3);
  }

  @override
  void onPathLineTo(double x, double y) {
    currentPath!.lineTo(x, y);
  }

  @override
  void onPathMoveTo(double x, double y) {
    currentPath!.moveTo(x, y);
  }

  @override
  void onPathStart(int id, int fillType) {
    currentPath = Path()..fillType = PathFillType.values[fillType];
    _paths[id] = currentPath!;
  }

  void onPathFinished() {
    currentPath = null;
  }

  @override
  void onDrawCommand(int path, int paint) {
    print('canvas.drawPath($path, $paint)');
    canvas.drawPath(_paths[path]!, _paints[paint]!);
  }

  @override
  void onPaintObject(
    int color,
    int strokeCap,
    int strokeJoin,
    int blendMode,
    double strokeMiterLimit,
    double strokeWidth,
    int paintStyle,
    int id,
  ) {
    _paints[id] = Paint()
      ..color = Color(color)
      ..strokeCap = StrokeCap.values[strokeCap]
      ..strokeJoin = StrokeJoin.values[strokeJoin]
      ..blendMode = BlendMode.values[blendMode]
      ..strokeMiterLimit = strokeMiterLimit
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.values[paintStyle];
  }
}

Future<void> main() async {
  var bytes = Uint8List.fromList(data);
  window.onBeginFrame = (_) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final listener = FlutterPaintCodecListener(canvas);
    var codec = PaintingCodec(listener);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, 1000, 1000), Paint()..color = Colors.white);
    canvas.translate(200, 200);
    try {
      var sw = Stopwatch()..start();
      codec.decodeMessage(bytes.buffer.asByteData());
      print(sw.elapsedMilliseconds);
    } on FormatException catch (err, s) {
      print(err);
      print(s);
      // This is expected.
    }

    final picture = recorder.endRecording();
    final builder = SceneBuilder();
    builder.addPicture(Offset.zero, picture);
    final scene = builder.build();
    window.render(scene);

    picture.dispose();
    scene.dispose();
  };
  window.scheduleFrame();
}
