import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../l10n/names.dart';
import 'package:provider/provider.dart';

import '../../ads/ads_service.dart';
import '../../data/game_data.dart';
import '../../state/tracker_state.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../tracker/tracker_widgets.dart';
import 'villager_detail.dart';

class VillagersScreen extends StatefulWidget {
  const VillagersScreen({super.key});
  @override
  State<VillagersScreen> createState() => _VillagersScreenState();
}

class _VillagersScreenState extends State<VillagersScreen> {
  String _query = '';
  String? _gender;
  String? _datable;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TrackerState>();
    final p = context.farm;
    final q = _query.toLowerCase();
    final list = GameData.i.socialVillagers.where((v) {
      if (q.isNotEmpty && !villagerName(v['name']).toLowerCase().contains(q) && !v['name'].toString().toLowerCase().contains(q)) return false;
      if (_gender != null && v['gender'] != _gender) return false;
      if (_datable != null && (v['datable'] == true) != (_datable == 'yes')) return false;
      return true;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Villagers'))),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: tr('Search...')),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 12), children: [
            for (final g in [null, 'female', 'male'])
              Padding(
                padding: EdgeInsets.only(right: 6),
                child: ChoiceChip(label: Text(g == null ? tr('All') : tr(cap(g))), selected: _gender == g, onSelected: (_) => setState(() => _gender = g)),
              ),
            SizedBox(width: 8),
            for (final d in [null, 'yes', 'no'])
              Padding(
                padding: EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(d == null ? tr('Any') : (d == 'yes' ? tr('Dateable') : tr('Non-Dateable'))),
                  selected: _datable == d,
                  onSelected: (_) => setState(() => _datable = d),
                ),
              ),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final cols = (c.maxWidth / 112).floor().clamp(3, 8);
            return GridView.builder(
              padding: EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final v = list[i];
                final hearts = t.hearts(v['name'] as String);
                final bday = v['birthday'] as Map?;
                final today = bday != null && seasons.indexOf(bday['season'].toString()) == t.farm.season && bday['day'] == t.farm.day;
                return PixelPanel(
                  padding: EdgeInsets.all(6),
                  color: today ? p.wheat.withValues(alpha: 0.5) : null,
                  onTap: () {
                    AdsService.instance.onDetailViewed();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => VillagerDetail(villager: v)));
                  },
                  child: Column(children: [
                    Expanded(child: TImage(v['portrait'] ?? v['image'], size: 80)),
                    Text(villagerName(v['name']),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
                    if (hearts > 0)
                      Text('♥ $hearts', style: TextStyle(color: p.berry, fontSize: 12))
                    else if (today)
                      Text(tr('🎂 Today'), style: TextStyle(fontSize: 12)),
                  ]),
                );
              },
            );
          }),
        ),
      ]),
    );
  }
}
