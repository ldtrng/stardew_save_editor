import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:stardew_save_editor/save/save_file.dart';

void main() {
  test('unedited export is byte-identical', () {
    final orig = File('test/fixtures/TestSave').readAsBytesSync();
    final out = SaveFile.parse(orig, 'TestSave').encode();
    var i = 0;
    while (i < orig.length && i < out.length && orig[i] == out[i]) { i++; }
    final ctx = String.fromCharCodes(orig.sublist(i, (i + 120).clamp(0, orig.length)));
    final ctx2 = String.fromCharCodes(out.sublist(i, (i + 120).clamp(0, out.length)));
    expect(i, orig.length, reason: 'diverges at $i\norig: $ctx\nout:  $ctx2');
    expect(out.length, orig.length);
  });
}
