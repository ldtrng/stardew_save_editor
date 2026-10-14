import '../data/game_data.dart';
import '../save/save_file.dart';
import '../state/tracker_state.dart';

class ImportSummary {
  final Map<String, int> counts = {};
  void add(String label, int n) => counts[label] = n;
}

/// Fills a tracker farm from a parsed save file.
class SaveImporter {
  SaveImporter(this.save, {this.playerIndex = 0});
  final SaveFile save;
  final int playerIndex;

  static String _strip(String id) => id.replaceFirst(RegExp(r'^\([A-Z]+\)'), '');

  String? _appId(String gameId) => GameData.i.gameIdToAppId[_strip(gameId)];

  static const _stardropFlags = ['CF_Fair', 'CF_Mines', 'CF_Spouse', 'CF_Sewer', 'CF_Statue', 'CF_Fish', 'museumComplete'];

  ImportSummary apply(TrackerState tracker) {
    final summary = ImportSummary();
    final player = save.players[playerIndex];
    final gd = GameData.i;
    tracker.applyImport((farm) {
      farm.name = player.farmName.isEmpty ? farm.name : player.farmName;
      farm.season = seasons.indexOf(save.season).clamp(0, 3);
      farm.day = save.dayOfMonth.clamp(1, 28);
      farm.year = save.year;

      Set<String> ids(Iterable<String> raw) => raw.map(_appId).whereType<String>().toSet();

      final fishIds = gd.fish.map((f) => f['id'].toString()).toSet();
      final caught = ids(player.dictionary('fishCaught').keys).intersection(fishIds);
      farm.set(Cat.fish).addAll(caught);
      summary.add('Fish caught', caught.length);

      final shippable = gd.shipping.map((s) => s['id'].toString()).toSet();
      final shipped = ids(player.dictionary('basicShipped').keys).intersection(shippable);
      farm.set(Cat.shipped).addAll(shipped);
      summary.add('Items shipped', shipped.length);

      final cookIds = gd.cooking.map((c) => c['id'].toString()).toSet();
      final cooked = ids(player.dictionary('recipesCooked').keys).intersection(cookIds);
      farm.set(Cat.cooked).addAll(cooked);
      summary.add('Dishes cooked', cooked.length);

      final craftKeys = gd.craftingRecipes.map((c) => c['key'].toString()).toSet();
      final crafted = player
          .recipes('craftingRecipes')
          .entries
          .where((e) => e.value > 0 && craftKeys.contains(e.key))
          .map((e) => e.key)
          .toSet();
      farm.set(Cat.crafted).addAll(crafted);
      summary.add('Items crafted', crafted.length);

      final museumIds = {...gd.artifacts, ...gd.minerals}.map((m) => m['id'].toString()).toSet();
      final donated = ids(save.museumDonations).intersection(museumIds);
      farm.set(Cat.museum).addAll(donated);
      summary.add('Museum donations', donated.length);

      final mail = player.mailReceived.toSet();
      var drops = 0;
      for (var i = 0; i < gd.stardrops.length && i < _stardropFlags.length; i++) {
        if (mail.contains(_stardropFlags[i])) {
          farm.set(Cat.stardrops).add(gd.stardrops[i]['id'].toString());
          drops++;
        }
      }
      summary.add('Stardrops', drops);

      var friends = 0;
      for (final f in player.friendships) {
        farm.hearts[f.name] = f.hearts;
        friends++;
      }
      summary.add('Villager hearts', friends);

      summary.add('Bundle items', _importBundles(farm));
    });
    return summary;
  }

  int _importBundles(FarmProfile farm) {
    final cc = save.communityCenter();
    if (cc == null) return 0;
    final data = GameData.i.bundles;
    List<Map<String, dynamic>> flatten(String set) => [
          for (final room in (data[set] as List))
            for (final b in ((room as Map)['bundles'] as List)) Map<String, dynamic>.from(b as Map),
        ];
    final normal = flatten('normal');
    final remixed = flatten('remixed');
    int matches(List<Map<String, dynamic>> list) =>
        cc.bundles.where((b) => list.any((t) => t['internalName'] == b.name || t['name'] == b.name)).length;
    final useRemixed = matches(remixed) > matches(normal);
    farm.remixedBundles = useRemixed;
    final pool = useRemixed ? remixed : normal;

    var marked = 0;
    for (final b in cc.bundles) {
      final t = pool.firstWhere(
        (t) => (t['internalName'] == b.name || t['name'] == b.name) && t['room'] == b.roomName,
        orElse: () => pool.firstWhere((t) => t['internalName'] == b.name || t['name'] == b.name, orElse: () => {}),
      );
      if (t.isEmpty) continue;
      final items = (t['items'] as List).cast<Map>();
      final used = <int>{};
      final reqs = b.requirements;
      for (var i = 0; i < reqs.length; i++) {
        if (!b.isSubmitted(i)) continue;
        final want = reqs[i].isMoney ? '-1' : (_appId(reqs[i].itemId) ?? reqs[i].itemId);
        var idx = -1;
        for (var k = 0; k < items.length; k++) {
          if (used.contains(k)) continue;
          final id = items[k]['id']?.toString() ?? (items[k]['category'] != null ? '-1' : '');
          if (id == want || (reqs[i].isMoney && items[k]['id'] == null)) {
            idx = k;
            break;
          }
        }
        if (idx < 0 && i < items.length && !used.contains(i)) idx = i;
        if (idx < 0) continue;
        used.add(idx);
        farm.set(Cat.bundleItems).add('${t['key']}#$idx');
        marked++;
      }
    }
    return marked;
  }
}
