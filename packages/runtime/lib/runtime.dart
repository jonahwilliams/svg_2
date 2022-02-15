// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/services.dart';


const int _kVersion = 1;

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
}

final Paint _emptyPaint = Paint();

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
///          "type": "drawRect",
///          "left": 0,
///          "top": 0,
///          "width": 100,
///          "height": 200,
///          "paint": 0 // use paint object 0
///          ...
///        },
///     ],
/// }
///
///
///
///
///
Picture decodeGraphics(ByteData byteData) {
  final Object message = const StandardMessageCodec().decodeMessage(byteData);

  // Retain the check for the toplevel structure in all modes so that we have
  // a chance to check the version.
  if (message is! Map<Object?, Object?>) {
    // Wrong format.
    throw Exception();
  }
  if (message[_FormatKeys.version] != _kVersion) {
    // Wrong version.
    throw Exception();
  }

  final List<Object?> objects = _as<List<Object?>>(message[_FormatKeys.objects]);
  final List<Object?> commands = _as<List<Object?>>(message[_FormatKeys.commands]);

  // Typed objects
  final Map<int, Paint> paints = <int, Paint>{};

  for (int i = 0; i < objects.length; i += 1) {
    final Map<Object?, Object?> object = _as<Map<Object?, Object?>>(objects[i]);
    final int type = _as<int>(object[_FormatKeys.objectType]);
    switch (type) {
      case _FormatKeys.paintType:
        final int color = _as<int>(object[_FormatKeys.paintColor]);
        final Paint paint = Paint()..color = Color(color);
        paints[i] = paint;
        break;
      default:
        // Wrong format.
        throw Exception();
    }
  }

  final PictureRecorder recorder = PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  for (int i = 0; i < commands.length; i += 1) {
    final Map<Object?, Object?> command = _as<Map<Object?, Object?>>(commands[i]);
    final int type = _as<int>(command[_FormatKeys.commandType]);
    switch (type) {
      case _FormatKeys.drawRect:
        final double left = _as<double>(command[_FormatKeys.drawRectLeft]);
        final double top = _as<double>(command[_FormatKeys.drawRectTop]);
        final double width = _as<double>(command[_FormatKeys.drawRectWidth]);
        final double height = _as<double>(command[_FormatKeys.drawRectHeight]);
        // -1 means default empty paint or null depending on what command
        // accepts.
        final int paintIndex = _as<int>(command[_FormatKeys.drawRectPaint]);
        final Paint paint;
        if (paintIndex == -1) {
          paint = _emptyPaint;
        } else {
          paint = _as<Paint>(paints[paintIndex]);
        }
        canvas.drawRect(Rect.fromLTWH(left, top, width, height), paint);
        break;
      default:
        throw Exception();
    }
  }

  return recorder.endRecording();
}

// TODO: add inline hints
T _as<T>(Object? value) {
  assert(value is T, 'Parsing Error in binary format. Expected $value to be an instance of $T');
  return value as T;
}
