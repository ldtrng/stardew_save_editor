import 'package:xml/xml.dart';

import 'xml_ext.dart';

/// XNA `Color` as serialized in saves (`<B/><G/><R/><A/><PackedValue/>`).
class SdvColor {
  SdvColor(this.r, this.g, this.b, [this.a = 255]);

  int r, g, b, a;

  factory SdvColor.fromElement(XmlElement el) => SdvColor(
        el.integer('R') ?? 0,
        el.integer('G') ?? 0,
        el.integer('B') ?? 0,
        el.integer('A') ?? 255,
      );

  /// Parses "#RRGGBB", "rgb(r, g, b)" or "R G B [A]".
  factory SdvColor.parse(String s) {
    s = s.trim();
    if (s.startsWith('#')) {
      int h(int i) => int.tryParse(s.substring(i, i + 2), radix: 16) ?? 0;
      return SdvColor(h(1), h(3), h(5), s.length == 9 ? h(7) : 255);
    }
    final rgb = RegExp(r'^rgb\((\d{1,3}),\s*(\d{1,3}),\s*(\d{1,3})\)$').firstMatch(s);
    if (rgb != null) {
      return SdvColor(int.parse(rgb[1]!), int.parse(rgb[2]!), int.parse(rgb[3]!));
    }
    final p = s.split(RegExp(r'\s+')).map((e) => int.tryParse(e) ?? 0).toList();
    return SdvColor(p.isNotEmpty ? p[0] : 0, p.length > 1 ? p[1] : 0,
        p.length > 2 ? p[2] : 0, p.length > 3 ? p[3] : 255);
  }

  int get packedValue =>
      ((a & 0xff) << 24) | ((b & 0xff) << 16) | ((g & 0xff) << 8) | (r & 0xff);

  int get argb => (a << 24) | (r << 16) | (g << 8) | b;

  String toHex() =>
      '#${[r, g, b].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';

  Map<String, Object?> toMap() =>
      {'B': b, 'G': g, 'R': r, 'A': a, 'PackedValue': packedValue};

  void writeTo(XmlElement el) {
    el.removeAttribute('xsi:nil');
    el.children.clear();
    toMap().forEach((k, v) => el.children.add(buildElement(k, v)));
  }
}
