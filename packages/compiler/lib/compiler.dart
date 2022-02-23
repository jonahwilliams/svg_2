// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

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
  //    var left = commands[i]!;
  //    var right = commands[i + 1]!;
  //    if (left.canCombine(right)) {
  //      var newCommand = left.combine(right);
  //      commands[i + 1] = newCommand;
  //      commands[i] = null;
  //    }
  // }
  commands.removeWhere((element) => element == null);

  assert(() {
    for(final command in commands) {
      if (command is DrawPathCommand) {
        assert(paths.contains(command.path), 'Did not get ${command.path}');
        assert(paints.contains(command.paint));
      } else if (command is DrawVerticesCommand) {
        assert(paints.contains(command.paint));
      }
    }
    return true;
  }());

  var result  = codec.encodeMessage([
    paints.toList(),
    if (paths.isNotEmpty)
      paths.toList(),
    commands,
  ]);
  codec.decodeMessage(result);

  output.writeAsBytesSync(result!.buffer.asUint8List(0, lastZeroIndex));
}
