import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../ads/ads_service.dart';
import '../../ads/banner_ad.dart';
import '../../ads/native_ad.dart';
import '../../data/game_data.dart';
import '../../state/settings_state.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'tracker_widgets.dart';

class CollectionFilter {
  const CollectionFilter(this.label, this.options, this.test, {this.optionLabel});
  final String label;
  final List<String?> options;
  final bool Function(Json item, String value) test;
  final String Function(String?)? optionLabel;
}

class CollectionSort {
  const CollectionSort(this.label, this.compare);
  final String label;
  final int Function(Json a, Json b)? compare;
}

/// Generic searchable checklist used by most collections.
class CollectionScreen extends StatefulWidget {
  CollectionScreen({
    super.key,
    required this.title,
    required this.items,
    required this.idOf,
    this.category,
    this.subtitle,
    this.trailing,
    this.detail,
    this.filters = const [],
    this.sorts = const [],
    this.groupBy,
    this.imageOf,
    this.nameOf,
  });

  final String title;
  final List<Json> items;
  final String Function(Json) idOf;
  final String? category;
  final Widget? Function(Json)? subtitle;
  final Widget? Function(Json)? trailing;
  final Widget Function(Json)? detail;
  final List<CollectionFilter> filters;
  final List<CollectionSort> sorts;
  final String Function(Json)? groupBy;
  final Object? Function(Json)? imageOf;
  final String Function(Json)? nameOf;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String _query = '';
  late final List<String?> _filterValues = List.filled(widget.filters.length, null);
  int _sort = 0;

  String _name(Json j) => widget.nameOf?.call(j) ?? (j['name'] ?? j['id']).toString();

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerState>();
    final settings = context.watch<SettingsState>();
    final cat = widget.category;
    final q = _query.toLowerCase();
    var list = widget.items.where((j) {
      if (q.isNotEmpty && !_name(j).toLowerCase().contains(q)) return false;
      for (var i = 0; i < widget.filters.length; i++) {
        final v = _filterValues[i];
        if (v != null && !widget.filters[i].test(j, v)) return false;
      }
      if (cat != null && settings.hideCompleted && tracker.isChecked(cat, widget.idOf(j))) return false;
      return true;
    }).toList();
    final cmp = widget.sorts.isEmpty ? null : widget.sorts[_sort].compare;
    if (cmp != null) list.sort(cmp);
    final done = cat == null ? 0 : widget.items.where((j) => tracker.isChecked(cat, widget.idOf(j))).length;

    final rows = <Widget>[];
    String? lastGroup;
    // Native ad after the first few rows, then every [AdsService.nativeEvery].
    var nextAd = AdsService.instance.nativeOffset(widget.title.hashCode);
    var itemIndex = 0;
    for (final j in list) {
      if (itemIndex == nextAd && list.length > 10) {
        rows.add(NativeListAd());
        nextAd += AdsService.nativeEvery;
      }
      itemIndex++;
      final g = widget.groupBy?.call(j);
      if (g != null && g != lastGroup) {
        rows.add(Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: PlankHeader(g)));
        lastGroup = g;
      }
      rows.add(_row(context, j, tracker, cat));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (cat != null)
            IconButton(
              tooltip: settings.hideCompleted ? tr('Show completed') : tr('Hide completed'),
              icon: Icon(settings.hideCompleted ? Icons.visibility_off : Icons.visibility),
              onPressed: () => settings.setHideCompleted(!settings.hideCompleted),
            ),
          if (widget.sorts.length > 1)
            PopupMenuButton<int>(
              icon: Icon(Icons.sort),
              tooltip: tr('Sort by'),
              onSelected: (i) => setState(() => _sort = i),
              itemBuilder: (_) => [
                for (var i = 0; i < widget.sorts.length; i++)
                  CheckedPopupMenuItem(value: i, checked: i == _sort, child: Text(widget.sorts[i].label)),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(child: AdBanner()),
      body: Column(children: [
        if (cat != null)
          Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: ProgressHeader(done: done, total: widget.items.length)),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: tr('Search...')),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        for (var i = 0; i < widget.filters.length; i++)
          FilterRow<String>(
            options: [null, ...widget.filters[i].options.whereType<String>()],
            value: _filterValues[i],
            label: (v) => v == null
                ? tr('{filter}: Any', {'filter': widget.filters[i].label})
                : (widget.filters[i].optionLabel?.call(v) ?? tr(cap(v))),
            onChanged: (v) => setState(() => _filterValues[i] = v),
          ),
        SizedBox(height: 4),
        Expanded(
          child: list.isEmpty
              ? EmptyState(icon: Icons.search_off, title: tr('No results..'))
              : ListView(padding: EdgeInsets.only(bottom: 24), children: rows),
        ),
      ]),
    );
  }

  Widget _row(BuildContext context, Json j, TrackerState tracker, String? cat) {
    final p = context.farm;
    final id = widget.idOf(j);
    final checked = cat != null && tracker.isChecked(cat, id);
    return InkWell(
      onTap: widget.detail == null
          ? (cat == null ? null : () => tracker.toggle(cat, id))
          : () {
              AdsService.instance.onDetailViewed();
              Navigator.push(context, MaterialPageRoute(builder: (_) => widget.detail!(j)));
            },
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 6, 4, 6),
        decoration: BoxDecoration(
          color: checked ? p.grass.withValues(alpha: 0.12) : null,
          border: Border(bottom: BorderSide(color: p.outline.withValues(alpha: 0.15))),
        ),
        child: Row(children: [
          TImage(widget.imageOf?.call(j) ?? j['image'], size: 40),
          SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name(j),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked ? p.textMuted : p.text,
                  )),
              if (widget.subtitle?.call(j) case final s?) DefaultTextStyle.merge(style: TextStyle(fontSize: 12, color: p.textMuted), child: s),
            ]),
          ),
          if (widget.trailing?.call(j) case final t?) t,
          if (cat != null) PixelCheck(value: checked, onChanged: (v) => tracker.toggle(cat, id, v)),
        ]),
      ),
    );
  }
}

/// Header block for detail pages: big image, name, description and an
/// optional checkbox.
class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.item, this.category, this.id, this.extra, this.name, this.description});
  final Json item;
  final String? name;
  final String? description;
  final String? category;
  final String? id;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerState>();
    final p = context.farm;
    final cat = category;
    return PixelPanel(
      color: p.panelAlt,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PixelPanel(padding: EdgeInsets.all(6), shadow: false, child: TImage(item['image'], size: 64)),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name ?? (item['name'] ?? '').toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            if ((description ?? item['description']) != null)
              Text((description ?? item['description']).toString(), style: TextStyle(color: p.textMuted, fontStyle: FontStyle.italic)),
            if (extra != null) ...[SizedBox(height: 6), extra!],
          ]),
        ),
        if (cat != null && id != null)
          PixelCheck(value: tracker.isChecked(cat, id!), onChanged: (v) => tracker.toggle(cat, id!, v), size: 30),
      ]),
    );
  }
}

class DetailScaffold extends StatelessWidget {
  const DetailScaffold({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        bottomNavigationBar: SafeArea(child: AdBanner(collapsible: true)),
        body: ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 32), children: children),
      );
}
