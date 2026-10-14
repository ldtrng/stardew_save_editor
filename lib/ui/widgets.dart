import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../save/items.dart';
import 'theme.dart';

/// Wooden-framed panel with a hard drop shadow.
class PixelPanel extends StatelessWidget {
  PixelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.borderColor,
    this.shadow = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    final box = Container(
      decoration: BoxDecoration(
        color: color ?? p.panel,
        border: Border.all(color: borderColor ?? p.outline, width: 3),
        boxShadow: shadow ? [BoxShadow(color: p.shadow, offset: Offset(4, 4))] : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 2),
            left: BorderSide(color: Colors.white.withValues(alpha: 0.35), width: 2),
          ),
        ),
        padding: padding,
        child: child,
      ),
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

/// Section title in a wooden plank.
class PlankHeader extends StatelessWidget {
  const PlankHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Container(
      margin: EdgeInsets.only(top: 16, bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.wood,
        border: Border.all(color: p.outline, width: 2),
      ),
      child: Row(children: [
        Expanded(
          child: Text(text,
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class _SheetCache {
  static final Map<String, Future<ui.Image>> _images = {};
  static Future<ui.Image> load(String asset) => _images.putIfAbsent(asset, () async {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        return (await codec.getNextFrame()).image;
      });
}

/// Draws a crisp (nearest-neighbour) sub-rectangle of a sprite sheet.
class SheetSprite extends StatefulWidget {
  const SheetSprite({super.key, required this.asset, required this.src, this.size = 32, this.tint});
  final String asset;
  final Rect? src;
  final double size;
  final Color? tint;

  @override
  State<SheetSprite> createState() => _SheetSpriteState();
}

class _SheetSpriteState extends State<SheetSprite> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SheetSprite old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset) _load();
  }

  void _load() {
    _SheetCache.load(widget.asset).then((img) {
      if (mounted) setState(() => _image = img);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final src = widget.src ??
        (img == null ? Rect.zero : Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
    final aspect = src.height == 0 ? 1.0 : src.width / src.height;
    final w = aspect >= 1 ? widget.size : widget.size * aspect;
    final h = aspect >= 1 ? widget.size / aspect : widget.size;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: img == null
          ? null
          : Center(
              child: CustomPaint(
                size: Size(w, h),
                painter: _SpritePainter(img, src, widget.tint),
              ),
            ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.image, this.src, this.tint);
  final ui.Image image;
  final Rect src;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.none;
    if (tint != null) paint.colorFilter = ColorFilter.mode(tint!, BlendMode.modulate);
    canvas.drawImageRect(image, src, Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_SpritePainter old) => old.image != image || old.src != src || old.tint != tint;
}

/// Item icon from metadata; falls back to a crate glyph.
class ItemIcon extends StatelessWidget {
  const ItemIcon({super.key, this.info, this.sprite, this.size = 32, this.tint});
  final ItemInfo? info;
  final SpriteRef? sprite;
  final double size;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final s = sprite ?? info?.sprite;
    if (s == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.inventory_2_outlined, size: size * 0.7, color: context.farm.textMuted),
      );
    }
    return SheetSprite(asset: s.assetPath, src: s.src, size: size, tint: tint);
  }
}

/// Crisp asset image (whole file) scaled with nearest-neighbour filtering.
class PixelImage extends StatelessWidget {
  const PixelImage(this.asset, {super.key, this.size = 40, this.fit = BoxFit.contain});
  final String asset;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        width: size,
        height: size,
        fit: fit,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.image_not_supported_outlined, color: context.farm.textMuted, size: size * 0.6),
        ),
      );
}

/// Labeled integer field that commits on submit/blur.
class NumberField extends StatefulWidget {
  NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99999999,
    this.prefix,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String? prefix;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _c = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(NumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _c.text = '${widget.value}';
  }

  void _commit() {
    final v = int.tryParse(_c.text.trim());
    if (v == null) {
      _c.text = '${widget.value}';
      return;
    }
    final clamped = v.clamp(widget.min, widget.max);
    if (clamped != v) _c.text = '$clamped';
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _focus,
      keyboardType: TextInputType.numberWithOptions(signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
      decoration: InputDecoration(labelText: widget.label, prefixText: widget.prefix),
      onSubmitted: (_) => _commit(),
    );
  }
}

/// Text field that commits on submit/blur.
class CommitTextField extends StatefulWidget {
  const CommitTextField({super.key, required this.label, required this.value, required this.onChanged, this.maxLength});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int? maxLength;

  @override
  State<CommitTextField> createState() => _CommitTextFieldState();
}

class _CommitTextFieldState extends State<CommitTextField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(CommitTextField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _c.text = widget.value;
  }

  void _commit() {
    if (_c.text != widget.value) widget.onChanged(_c.text);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        focusNode: _focus,
        maxLength: widget.maxLength,
        decoration: InputDecoration(labelText: widget.label, counterText: ''),
        onSubmitted: (_) => _commit(),
      );
}

/// Row of heart icons for friendship levels.
class HeartRow extends StatelessWidget {
  const HeartRow({super.key, required this.hearts, required this.max, this.onTap, this.size = 18});
  final int hearts;
  final int max;
  final ValueChanged<int>? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Wrap(
      spacing: 1,
      runSpacing: 1,
      children: [
        for (var i = 0; i < max; i++)
          GestureDetector(
            onTap: onTap == null ? null : () => onTap!(hearts == i + 1 ? i : i + 1),
            child: Icon(i < hearts ? Icons.favorite : Icons.favorite_border,
                size: size, color: i < hearts ? p.berry : p.textMuted),
          ),
      ],
    );
  }
}

/// Small pixel tag.
class PixelTag extends StatelessWidget {
  const PixelTag(this.text, {super.key, this.color, this.textColor});
  final String text;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color ?? p.panelAlt, border: Border.all(color: p.outline, width: 1.5)),
      child: Text(text, style: TextStyle(fontSize: 12, color: textColor ?? p.text)),
    );
  }
}

/// Empty / info state.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.farm;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: p.woodDark),
          SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          if (message != null) ...[
            SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: p.textMuted)),
          ],
          if (action != null) ...[SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
