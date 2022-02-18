import 'dart:io';

void main() {
  var bytes = File('gst.dat').readAsBytesSync();
  File('lib/data.dart')
    ..createSync()
    ..writeAsStringSync('''
var data = [
${bytes.join(',')}

];
''');
}