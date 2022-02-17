// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:compiler/src/parser/parser_state.dart';
import 'package:compiler/src/parser/picture_stream.dart';
import 'package:xml/xml_events.dart';

void main() async {
  final String xml = File('Ghostscript_Tiger.svg').readAsStringSync();
  final SvgParserState state = SvgParserState(
    parseEvents(xml),
    const SvgTheme(),
    'testing',
    true,
  );
  final root = await state.parse();
  root.write();
}
