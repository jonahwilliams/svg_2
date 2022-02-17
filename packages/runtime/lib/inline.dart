import 'dart:io';

void main() {
  var bytes = File('binary.dat').readAsBytesSync();
  File('lib/data.dart')
    ..createSync()
    ..writeAsStringSync('''
var data = [
${bytes.join(',')}

];
''');
}