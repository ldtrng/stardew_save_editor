import 'package:xml/xml.dart';

import 'save_file.dart';
import 'xml_ext.dart';

const animalEmojis = {
  'White Chicken': '🐔', 'Brown Chicken': '🐔', 'Blue Chicken': '🐔',
  'Void Chicken': '🐔', 'Golden Chicken': '🐔', 'Duck': '🦆', 'Rabbit': '🐰',
  'Dinosaur': '🦕', 'White Cow': '🐮', 'Brown Cow': '🐮', 'Goat': '🐐',
  'Sheep': '🐑', 'Pig': '🐷', 'Ostrich': '🦤',
};

const buildingCapacity = {
  'Coop': 4, 'Big Coop': 8, 'Deluxe Coop': 12,
  'Barn': 4, 'Big Barn': 8, 'Deluxe Barn': 12,
  'Slime Hutch': 20,
};

class BuildingView {
  BuildingView(this.el, this.save, this.locationName);
  final XmlElement el;
  final SaveFile save;
  final String locationName;

  String get type => el.str('buildingType') ?? 'Building';
  String get assetPath => 'assets/editor/buildings/$type.png';
  int get tileX => el.integer('tileX') ?? 0;
  int get tileY => el.integer('tileY') ?? 0;
  int get daysOfConstructionLeft => el.integer('daysOfConstructionLeft') ?? 0;
  set daysOfConstructionLeft(int v) => el.setInt('daysOfConstructionLeft', v);
  int get daysUntilUpgrade => el.integer('daysUntilUpgrade') ?? 0;
  set daysUntilUpgrade(int v) => el.setInt('daysUntilUpgrade', v);

  bool get isGreenhouse => type == 'Greenhouse';

  XmlElement? get indoors {
    final i = el.child('indoors');
    return (i == null || i.isNil) ? null : i;
  }

  List<FarmAnimalView> get animals {
    final a = indoors?.child('animals');
    if (a == null) return [];
    return a.childrenNamed('item').map(FarmAnimalView.new).toList();
  }

  int? get capacity => buildingCapacity[type];

  static List<BuildingView> all(SaveFile save) {
    final out = <BuildingView>[];
    for (final loc in save.locations) {
      final b = loc.child('buildings');
      if (b == null) continue;
      for (final building in b.childrenNamed('Building')) {
        out.add(BuildingView(building, save, loc.str('name') ?? ''));
      }
    }
    return out;
  }
}

class FarmAnimalView {
  FarmAnimalView(this.el);
  final XmlElement el;

  XmlElement get _a => el.path(['value', 'FarmAnimal'])!;
  String get type => _a.str('type') ?? 'Animal';
  String get emoji => animalEmojis[type] ?? '🐾';
  String get name => _a.str('name') ?? '';
  set name(String v) {
    _a.setStr('name', v);
    _a.setStr('displayName', v);
  }

  int get friendship => _a.integer('friendshipTowardFarmer') ?? 0;
  set friendship(int v) => _a.setInt('friendshipTowardFarmer', v.clamp(0, 1000));
  int get happiness => _a.integer('happiness') ?? 0;
  set happiness(int v) => _a.setInt('happiness', v.clamp(0, 255));
  int get fullness => _a.integer('fullness') ?? 0;
  set fullness(int v) => _a.setInt('fullness', v.clamp(0, 255));
  int get age => _a.integer('age') ?? 0;
  set age(int v) {
    _a.setInt('age', v);
    _a.setInt('daysOwned', v);
  }

  bool get wasPet => _a.boolean('wasPet') ?? false;
  set wasPet(bool v) => _a.setBool('wasPet', v);
  int get hearts => friendship ~/ 200;
}
