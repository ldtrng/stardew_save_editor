import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../save/character_colors.dart';
import '../../save/farmer.dart';
import '../../save/items.dart';
import '../../save/xml_ext.dart';

/// Layered, tinted render of the farmer facing down (port of the web editor's
/// CSS preview).
class FarmerPreview extends StatefulWidget {
  const FarmerPreview({super.key, required this.farmer, this.scale = 5});
  final Farmer farmer;
  final double scale;

  @override
  State<FarmerPreview> createState() => _FarmerPreviewState();
}

class _FarmerPreviewState extends State<FarmerPreview> {
  static final Map<String, ui.Image> _cache = {};
  bool _ready = false;

  static const _sheets = [
    'assets/editor/farmer/male_farmer.png',
    'assets/editor/farmer/male_farmer_arms.png',
    'assets/editor/farmer/male_farmer_other.png',
    'assets/editor/farmer/male_farmer_boots.png',
    'assets/editor/farmer/female_farmer.png',
    'assets/editor/farmer/female_farmer_arms.png',
    'assets/editor/farmer/female_farmer_other.png',
    'assets/editor/farmer/female_farmer_boots.png',
    'assets/editor/sheets/hairstyles.png',
    'assets/editor/sheets/hairstyles2.png',
    'assets/editor/sheets/accessories.png',
    'assets/editor/sheets/shirts.png',
    'assets/editor/sheets/pants.png',
    'assets/editor/sheets/hats.png',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final s in _sheets) {
      if (_cache.containsKey(s)) continue;
      final data = await rootBundle.load(s);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _cache[s] = (await codec.getNextFrame()).image;
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(24 * widget.scale, 36 * widget.scale);
    if (!_ready) return SizedBox.fromSize(size: size);
    return CustomPaint(size: size, painter: _FarmerPainter(widget.farmer, _cache, widget.scale));
  }
}

class _FarmerPainter extends CustomPainter {
  _FarmerPainter(this.f, this.images, this.scale);
  final Farmer f;
  final Map<String, ui.Image> images;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Farmer occupies 16x32 starting at (4, 3) in a 24x36 box (room for hats).
    canvas.translate(4 * scale, 3 * scale);
    canvas.scale(scale);
    final g = f.isMale ? 'male' : 'female';
    final base = images['assets/editor/farmer/${g}_farmer.png']!;
    final arms = images['assets/editor/farmer/${g}_farmer_arms.png']!;
    final other = images['assets/editor/farmer/${g}_farmer_other.png']!;
    final bootsImg = images['assets/editor/farmer/${g}_farmer_boots.png']!;

    Color c(List<List<int>> table, int i) {
      if (i < 0 || i >= table.length) return Colors.transparent;
      final v = table[i];
      return Color.fromARGB(255, v[0], v[1], v[2]);
    }

    void layer(ui.Image img, Rect src, Offset at, {Color? fill, Color? multiply}) {
      final paint = Paint()..filterQuality = FilterQuality.none;
      if (fill != null) paint.colorFilter = ColorFilter.mode(fill, BlendMode.srcIn);
      if (multiply != null) paint.colorFilter = ColorFilter.mode(multiply, BlendMode.modulate);
      canvas.drawImageRect(img, src, Rect.fromLTWH(at.dx, at.dy, src.width, src.height), paint);
    }

    final skin = f.skin;
    const body = Size(16, 32);
    Rect r(double x, double y, [Size s = body]) => Rect.fromLTWH(x, y, s.width, s.height);

    layer(base, r(16, 0), Offset.zero, fill: c(tertiarySkinColors, skin));
    layer(base, r(32, 0), Offset.zero, fill: c(secondarySkinColors, skin));
    layer(base, r(48, 0), Offset.zero, fill: c(primarySkinColors, skin));
    layer(other, r(0, 0), Offset.zero);
    final eye = f.eyeColor;
    layer(other, r(32, 0), Offset.zero, fill: Color.fromARGB(255, eye.r, eye.g, eye.b));

    final boots = f.equipment('boots');
    if (boots != null) {
      final idx = boots.el.integer('indexInColorSheet') ?? 0;
      layer(bootsImg, r(48, 0), Offset.zero, fill: c(primaryBootColors, idx));
      layer(bootsImg, r(32, 0), Offset.zero, fill: c(secondaryBootColors, idx));
      layer(bootsImg, r(0, 0), Offset.zero, fill: c(tertiaryBootColors, idx));
      layer(bootsImg, r(16, 0), Offset.zero, fill: c(quaternaryBootColors, idx));
    }

    // Pants (facing-down frame 0 of the pants block).
    final pantsView = f.equipment('pantsItem');
    final pantsInfo = pantsView?.info ?? ItemDb.instance.byName['Polka Dot Shorts'];
    if (pantsInfo != null) {
      final idx = pantsInfo.spriteIndex ?? 0;
      final left = (idx * 192) % 1920 + (f.isMale ? 0 : 96);
      final top = (idx * 192 ~/ 1920) * 688;
      final pc = pantsView?.clothesColor;
      layer(images['assets/editor/sheets/pants.png']!, r(left.toDouble(), top.toDouble()), Offset.zero,
          multiply: pantsInfo.canBeDyed && pc != null ? Color.fromARGB(255, pc.r, pc.g, pc.b) : null);
    }

    // Shirt (8x8 torso patch).
    final shirtView = f.equipment('shirtItem');
    final shirtInfo = shirtView?.info ??
        ItemDb.instance.byName[f.isMale ? 'Basic Pullover (M)' : 'Basic Pullover (F)'];
    if (shirtInfo != null) {
      final idx = shirtInfo.spriteIndex ?? 0;
      final left = (idx * 8) % 128;
      final top = (idx * 8 ~/ 128) * 32;
      final shirts = images['assets/editor/sheets/shirts.png']!;
      final at = Offset(4, f.isMale ? 15 : 16);
      layer(shirts, r(left.toDouble(), top.toDouble(), Size(8, 8)), at);
      final sc = shirtView?.clothesColor;
      if (shirtInfo.canBeDyed && sc != null) {
        layer(shirts, r(left + 128.0, top.toDouble(), Size(8, 8)), at,
            multiply: Color.fromARGB(255, sc.r, sc.g, sc.b));
      }
    }

    final hair = f.hairColor;
    final hairTint = Color.fromARGB(255, hair.r, hair.g, hair.b);
    final acc = f.accessory;
    if (acc >= 0) {
      final left = (acc * 16) % 128;
      final top = (acc * 16 ~/ 128) * 32;
      layer(images['assets/editor/sheets/accessories.png']!, r(left.toDouble(), top.toDouble(), Size(16, 16)),
          Offset(0, f.isMale ? 2 : 3),
          multiply: acc <= 5 ? hairTint : null);
    }

    final hat = f.equipment('hat');
    final showHair = hat?.info == null || hat!.info!.raw['showRealHair'] != true;
    if (showHair) {
      final h = f.hairstyle;
      final sheet = h >= 56 ? 'hairstyles2' : 'hairstyles';
      final i = h >= 56 ? h - 56 : h;
      final left = (i * 16) % 128;
      final top = (i * 16 ~/ 128) * (h >= 56 ? 128 : 96);
      layer(images['assets/editor/sheets/$sheet.png']!, r(left.toDouble(), top.toDouble()),
          Offset(0, f.isMale ? 0 : 1),
          multiply: hairTint);
    }

    if (hat?.info?.sprite != null) {
      final s = hat!.info!.sprite!;
      layer(images['assets/editor/sheets/hats.png']!, s.src, Offset(-2, f.isMale ? -2 : -1));
    }

    layer(arms, r(16, 0), Offset.zero, fill: c(tertiarySkinColors, skin));
    layer(arms, r(32, 0), Offset.zero, fill: c(secondarySkinColors, skin));
    layer(arms, r(48, 0), Offset.zero, fill: c(primarySkinColors, skin));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
