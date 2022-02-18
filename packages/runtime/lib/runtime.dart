// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
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

  PaintingCodecListener? _listener;

  Object? readValueOfType(int type, ReadBuffer buffer) {
    switch (type) {
      case _paintTag:
        return _readPaint(buffer);
      case _pathTag:
        return _readPath(buffer);
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
    final int fillType = buffer.getInt32();
    final int paint = buffer.getInt32();
    final int commandLength = buffer.getInt32();
    _listener?.onDrawPathStart();

    for (var i = 0; i < commandLength; i++) {
      final int pathType = buffer.getUint8();
      if (pathType == PathCommandType.move.index) {
        var controlPoints = buffer.getFloat32List(2);
        _listener?.onDrawPathMoveTo(controlPoints[0], controlPoints[1]);
      } else if (pathType == PathCommandType.line.index) {
        var controlPoints = buffer.getFloat32List(2);
        _listener?.onDrawPathLineTo(controlPoints[0], controlPoints[1]);
      } else if (pathType == PathCommandType.cubic.index) {
        var controlPoints = buffer.getFloat32List(6);
        _listener?.onDrawPathCubicTo(
          controlPoints[0],
          controlPoints[1],
          controlPoints[2],
          controlPoints[3],
          controlPoints[4],
          controlPoints[5],
        );
      } else if (pathType == PathCommandType.close.index) {
        _listener?.onDrawPathClose();
      } else {
        throw UnsupportedError(pathType.toString());
      }
    }
    _listener?.onDrawPathStop(fillType, paint);
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

  void onDrawPathStart();

  void onDrawPathMoveTo(double x, double y);

  void onDrawPathLineTo(double x, double y);

  void onDrawPathCubicTo(
      double x1, double y1, double x2, double y2, double x3, double y3);

  void onDrawPathClose();

  void onDrawPathStop(
    int fillType,
    int paint,
  );
}

class FlutterPaintCodecListener extends PaintingCodecListener {
  FlutterPaintCodecListener(this.canvas);

  final Map<int, Paint> _paints = {};
  final Canvas canvas;
  Path? currentPath;

  @override
  void onDrawPathClose() {
    currentPath!.close();
  }

  @override
  void onDrawPathCubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    currentPath!.cubicTo(x1, y1, x2, y2, x3, y3);
  }

  @override
  void onDrawPathLineTo(double x, double y) {
    currentPath!.lineTo(x, y);
  }

  @override
  void onDrawPathMoveTo(double x, double y) {
    currentPath!.moveTo(x, y);
  }

  @override
  void onDrawPathStart() {
    currentPath = Path();
  }

  @override
  void onDrawPathStop(int fillType, int paint) {
    currentPath!.fillType = PathFillType.values[fillType];
    //canvas.drawPath(currentPath!, _paints[paint]!);
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
    canvas.drawRect(Rect.fromLTWH(0, 0, 1000, 1000),Paint()..color = Colors.white);
    canvas.translate(200, 200);
    try {
      var sw = Stopwatch()..start();
      codec.decodeMessage(bytes.buffer.asByteData());
      print(sw.elapsedMilliseconds);
    } on FormatException catch (err) {
      print(err);
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
