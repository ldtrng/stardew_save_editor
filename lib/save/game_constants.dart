const socialNpcs = [
  'Abigail', 'Alex', 'Caroline', 'Clint', 'Demetrius', 'Dwarf', 'Elliott',
  'Emily', 'Evelyn', 'George', 'Gus', 'Haley', 'Harvey', 'Jas', 'Jodi', 'Kent',
  'Krobus', 'Leah', 'Leo', 'Lewis', 'Linus', 'Marnie', 'Maru', 'Pam', 'Penny',
  'Pierre', 'Robin', 'Sam', 'Sandy', 'Sebastian', 'Shane', 'Vincent', 'Willy',
  'Wizard',
];

const dateableNpcs = [
  'Abigail', 'Alex', 'Elliott', 'Emily', 'Haley', 'Harvey', 'Leah', 'Maru',
  'Penny', 'Sam', 'Sebastian', 'Shane',
];

const friendshipStatuses = ['Friendly', 'Dating', 'Engaged', 'Married', 'Divorced'];

class Profession {
  const Profession(this.id, this.name, this.description);
  final int id;
  final String name;
  final String description;
}

class SkillTree {
  const SkillTree(this.skill, this.primary, this.secondary);
  final String skill;
  final List<int> primary;
  final Map<int, List<int>> secondary;
}

class Professions {
  static const all = <int, Profession>{
    0: Profession(0, 'Rancher', 'Animal products worth 20% more.'),
    1: Profession(1, 'Tiller', 'Crops worth 10% more.'),
    2: Profession(2, 'Coopmaster', 'Befriend coop animals quicker. Incubation time cut in half.'),
    3: Profession(3, 'Shepherd', 'Befriend barn animals quicker. Sheep produce wool faster.'),
    4: Profession(4, 'Artisan', 'Artisan goods worth 40% more.'),
    5: Profession(5, 'Agriculturist', 'All crops grow 10% faster.'),
    6: Profession(6, 'Fisher', 'Fish worth 25% more.'),
    7: Profession(7, 'Trapper', 'Resources required to craft crab pots reduced.'),
    8: Profession(8, 'Angler', 'Fish worth 50% more.'),
    9: Profession(9, 'Pirate', 'Chance to find treasure doubled.'),
    10: Profession(10, 'Mariner', 'Crab pots no longer produce junk items.'),
    11: Profession(11, 'Luremaster', 'Crab pots no longer require bait.'),
    12: Profession(12, 'Forester', 'Gain 25% more wood when chopping.'),
    13: Profession(13, 'Gatherer', 'Chance for double harvest of foraged items.'),
    14: Profession(14, 'Lumberjack', 'All trees have a chance to drop hardwood.'),
    15: Profession(15, 'Tapper', 'Syrups worth 25% more.'),
    16: Profession(16, 'Botanist', 'Foraged items are always iridium-quality.'),
    17: Profession(17, 'Tracker', 'Location of forageable items revealed.'),
    18: Profession(18, 'Miner', '+1 ore per vein.'),
    19: Profession(19, 'Geologist', 'Chance for gems to appear in pairs.'),
    20: Profession(20, 'Blacksmith', 'Metal bars worth 50% more.'),
    21: Profession(21, 'Prospector', 'Chance to find coal doubled.'),
    22: Profession(22, 'Excavator', 'Chance to find geodes doubled.'),
    23: Profession(23, 'Gemologist', 'Gems worth 30% more.'),
    24: Profession(24, 'Fighter', 'All attacks deal 10% more damage (+15 HP).'),
    25: Profession(25, 'Scout', 'Critical strike chance increased by 50%.'),
    26: Profession(26, 'Brute', 'Deal 15% more damage.'),
    27: Profession(27, 'Defender', '+25 HP.'),
    28: Profession(28, 'Acrobat', 'Cooldown on special moves cut in half.'),
    29: Profession(29, 'Desperado', 'Critical strikes are deadly.'),
  };

  static const trees = [
    SkillTree('farming', [0, 1], {0: [2, 3], 1: [4, 5]}),
    SkillTree('fishing', [6, 7], {6: [8, 9], 7: [10, 11]}),
    SkillTree('foraging', [12, 13], {12: [14, 15], 13: [16, 17]}),
    SkillTree('mining', [18, 19], {18: [20, 21], 19: [22, 23]}),
    SkillTree('combat', [24, 25], {24: [26, 27], 25: [28, 29]}),
  ];

  static bool isPrimary(int p) => trees.any((t) => t.primary.contains(p));

  static List<int> secondariesOf(int p) {
    for (final t in trees) {
      final s = t.secondary[p];
      if (s != null) return s;
    }
    return const [];
  }

  static int? parentOf(int p) {
    for (final t in trees) {
      for (final e in t.secondary.entries) {
        if (e.value.contains(p)) return e.key;
      }
    }
    return null;
  }
}

/// Wallet special items, stored as mail flags in 1.6.
const walletItems = [
  ('HasDwarvishTranslationGuide', 'Dwarvish Translation Guide', '📙'),
  ('HasRustyKey', 'Rusty Key', '🗝️'),
  ('HasClubCard', 'Club Card', '🃏'),
  ('HasSpecialCharm', 'Special Charm', '🍀'),
  ('HasSkullKey', 'Skull Key', '💀'),
  ('HasMagnifyingGlass', 'Magnifying Glass', '🔍'),
  ('HasDarkTalisman', 'Dark Talisman', '🌑'),
  ('HasMagicInk', 'Magic Ink', '🖋️'),
  ('HasTownKey', 'Town Key', '🏘️'),
];

/// Cooking recipe internal names that differ from item names.
const recipeDisplayNames = {
  'Cheese Cauli.': 'Cheese Cauliflower',
  'Vegetable Stew': 'Vegetable Medley',
  'Cookies': 'Cookie',
  'Eggplant Parm.': 'Eggplant Parmesan',
  'Cran. Sauce': 'Cranberry Sauce',
  "Dish o' The Sea": "Dish O' The Sea",
  'Transmute (Fe)': 'Iron Bar',
  'Transmute (Au)': 'Gold Bar',
  'Wild Seeds (Sp)': 'Spring Seeds',
  'Wild Seeds (Su)': 'Summer Seeds',
  'Wild Seeds (Fa)': 'Fall Seeds',
  'Wild Seeds (Wi)': 'Winter Seeds',
  'Oil Of Garlic': 'Oil of Garlic',
};
