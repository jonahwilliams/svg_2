// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:compiler/src/parser/paint.dart';
import 'package:compiler/src/parser/parser_state.dart';
import 'package:compiler/src/parser/path.dart';
import 'package:compiler/src/parser/picture_stream.dart';
import 'package:xml/xml_events.dart';

void main(List<String> args) async {
  final String xml = File(args.first).readAsStringSync();
  final SvgParserState state = SvgParserState(
    parseEvents(xml),
    const SvgTheme(),
    'testing',
    true,
  );
  final root = await state.parse();
  final Set<Paint> paints = <Paint>{};
  print('''
import 'dart:ui';

void main() {
  window.onBeginFrame = (_) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    doDraw(canvas);
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

void doDraw(Canvas canvas) {
''');
  root.write(paints, AffineMatrix.identity);
  print('}');
}
