import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime/runtime.dart';

void main() {

}

ByteData bytes(List<int> data) {
  return Uint8List.fromList(data).buffer.asByteData();
}

ByteData object(Object data) {
  return const StandardMessageCodec().encodeMessage(data)!;
}
