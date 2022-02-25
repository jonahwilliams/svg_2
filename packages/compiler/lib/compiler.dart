// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'dart:typed_data';

import 'package:compiler/src/parser/paint.dart';
import 'package:compiler/src/parser/parser_state.dart';
import 'package:compiler/src/parser/path.dart';
import 'package:compiler/src/parser/picture_stream.dart';
import 'package:compiler/src/parser/vector_drawable.dart';
import 'package:xml/xml_events.dart';

import 'src/encoder.dart';
import 'src/parser/path.dart';

void main(List<String> args) async {
  final String xml = File(args.first).readAsStringSync();
  final File output = File(args.last);
  final SvgParserState state = SvgParserState(
    parseEvents(xml),
    const SvgTheme(),
    'testing',
    true,
  );
  final root = await state.parse();
  final Set<Paint> paints = <Paint>{};
  final Set<Path> paths = <Path>{};
  final List<DrawCommand?> commands = <DrawCommand?>[];
  root.write(paints, paths, commands, AffineMatrix.identity);

  var codec = PaintingCodec();
  // for (var i = 0; i < commands.length - 1; i++) {
  //    var left = commands[i]! as DrawVerticesCommand;
  //    var right = commands[i + 1]! as DrawVerticesCommand;
  //    if (left.canCombine(right)) {
  //      var newCommand = left.combine(right);
  //      commands[i + 1] = newCommand;
  //      commands[i] = null;
  //    }
  // }
  // commands.removeWhere((element) => element == null);
  Map<int, DrawVerticesCommand> combinedCommands = <int, DrawVerticesCommand>{};
  for (final command in commands) {
    var verticesCommand = command as DrawVerticesCommand;
    final int color = verticesCommand.colors!.first;
    final accumulatedCommand = combinedCommands[color];
    if (accumulatedCommand != null) {
      verticesCommand = DrawVerticesCommand(
        Float32List.fromList(
            accumulatedCommand.vertices + verticesCommand.vertices),
        null,
        Int32List.fromList(
            accumulatedCommand.colors! + verticesCommand.colors!),
        null,
      );
    }
    combinedCommands[color] = verticesCommand;
  }

  final List<DrawVerticesCommand> indexedCommands = [];
  for (final command in combinedCommands.values) {
    // final points = mapPoints(command.vertices);
    // print('I have ${points.length} vertices, ${points.toSet().length} unique');
    final indexedVertices = IndexedVertices.fromVertices(command.vertices);
    // print(
    //     'I took ${command.vertices.lengthInBytes} to: ${indexedVertices.vertexBuffer.lengthInBytes} ${indexedVertices.indexBuffer.lengthInBytes} (${indexedVertices.vertexBuffer.lengthInBytes + indexedVertices.indexBuffer.lengthInBytes})');
    indexedCommands.add(DrawVerticesCommand(
      indexedVertices.vertexBuffer,
      command.paint,
      command.colors,
      indexedVertices.indexBuffer,
    ));
  }
  // assert(() {
  //   for(final command in commands) {
  //     if (command is DrawPathCommand) {
  //       assert(paths.contains(command.path), 'Did not get ${command.path}');
  //       assert(paints.contains(command.paint));
  //     } else if (command is DrawVerticesCommand) {
  //       // assert(paints.contains(command.paint));
  //     }
  //   }
  //   return true;
  // }());

  var result = codec.encodeMessage([
    paints.toList(),
    if (paths.isNotEmpty) paths.toList(),
    indexedCommands,
  ]);
  codec.decodeMessage(result);

  output.writeAsBytesSync(result!.buffer.asUint8List(0, lastZeroIndex));
}

class IndexedVertices {
  const IndexedVertices(this.vertexBuffer, this.indexBuffer);

  static List<Point> mapPoints(Float32List rawPoints) {
    List<Point> points = [];
    for (int i = 0; i < rawPoints.length; i += 2) {
      points.add(Point(rawPoints[i], rawPoints[i + 1]));
    }
    return points;
  }

  factory IndexedVertices.fromVertices(Float32List vertices) {
    final points = mapPoints(vertices);
    final pointMap = <Point, int>{};
    int index = 0;
    final List<int> indices = [];
    for (final point in points) {
      indices.add(pointMap.putIfAbsent(point, () => index++));
    }
    final Float32List vertexBuffer = Float32List(pointMap.keys.length * 2);
    int vertexIndex = 0;
    for (final point in pointMap.keys) {
      vertexBuffer[vertexIndex++] = point.x;
      vertexBuffer[vertexIndex++] = point.y;
    }
    print(Uint16List.fromList(indices).length);
    print(Uint16List.fromList(indices));
    return IndexedVertices(vertexBuffer, Uint16List.fromList(indices));
  }

  final Float32List vertexBuffer;
  final Uint16List indexBuffer;
}
