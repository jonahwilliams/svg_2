import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime/runtime.dart';

void main() {
  test('SMC validates structure', () {
    expect(() => decodeGraphics(bytes([0])), throwsA(isA<Error>()));
  });

  test('Validates toplevel object', () {
    expect(() => decodeGraphics(object([])), throwsException);
  });

  test('Validates version', () {
    expect(() => decodeGraphics(object({
      0: 23,
    })), throwsException);
  });
}

ByteData bytes(List<int> data) {
  return Uint8List.fromList(data).buffer.asByteData();
}

ByteData object(Object data) {
  return const StandardMessageCodec().encodeMessage(data)!;
}
