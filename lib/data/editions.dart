import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// A single board space.
class BoardSpace {
  final int n; // 1..40
  final String name;
  final String nameFa;
  final String type; // go, street, railroad, utility, tax, chance, community_chest, jail, free_parking, go_to_jail
  final String? color;
  final int? price;
  final int? mortgage;
  final List<int>? rent; // [base, h1, h2, h3, h4, hotel]
  final List<int>? rentByCount; // railroads
  final int? houseCost;
  final int? amount; // tax

  BoardSpace({
    required this.n, required this.name, required this.nameFa, required this.type,
    this.color, this.price, this.mortgage, this.rent, this.rentByCount,
    this.houseCost, this.amount,
  });

  factory BoardSpace.fromJson(Map<String, dynamic> j) => BoardSpace(
        n: (j['n'] as num).toInt(),
        name: j['name'] as String,
        nameFa: (j['nameFa'] ?? j['name']) as String,
        type: j['type'] as String,
        color: j['color'] as String?,
        price: (j['price'] as num?)?.toInt(),
        mortgage: (j['mortgage'] as num?)?.toInt(),
        rent: (j['rent'] as List?)?.map((e) => (e as num).toInt()).toList(),
        rentByCount: (j['rentByCount'] as List?)?.map((e) => (e as num).toInt()).toList(),
        houseCost: (j['houseCost'] as num?)?.toInt(),
        amount: (j['amount'] as num?)?.toInt(),
      );

  String localizedName(String locale) =>
      (locale == 'fa' || locale == 'ar') ? nameFa : name;

  bool get isProperty =>
      type == 'street' || type == 'railroad' || type == 'utility';
}

/// A full Monopoly edition (board).
class Edition {
  final String id;
  final String nameEn;
  final String nameFa;
  final String currencySymbol;
  final String currencyCode;
  final int goSalary;
  final int jailFine;
  final Map<String, int> buildingCostsByColor;
  final List<BoardSpace> spaces; // 40

  Edition({
    required this.id, required this.nameEn, required this.nameFa,
    required this.currencySymbol, required this.currencyCode,
    required this.goSalary, required this.jailFine,
    required this.buildingCostsByColor, required this.spaces,
  });

  factory Edition.fromJson(Map<String, dynamic> j) => Edition(
        id: j['editionId'] as String,
        nameEn: (j['name'] as Map)['en'] as String,
        nameFa: (j['name'] as Map)['fa'] as String,
        currencySymbol: (j['currency'] as Map)['symbol'] as String,
        currencyCode: (j['currency'] as Map)['code'] as String,
        goSalary: (j['goSalary'] as num).toInt(),
        jailFine: (j['jailFine'] as num).toInt(),
        buildingCostsByColor: Map<String, int>.from(
            (j['buildingCostsByColor'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt()))),
        spaces: (j['spaces'] as List)
            .map((e) => BoardSpace.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String localizedName(String locale) =>
      (locale == 'fa' || locale == 'ar') ? nameFa : nameEn;

  BoardSpace space(int n) => spaces[n - 1];

  List<BoardSpace> spacesOfColor(String color) =>
      spaces.where((s) => s.color == color).toList();
}

const List<String> kEditionIds = ['london', 'us_classic', 'france'];

/// i18n keys for the edition picker cards.
String editionNameKey(String id) => 'edition.${id == 'us_classic' ? 'us' : id}';
String editionDescKey(String id) =>
    'edition.${id == 'us_classic' ? 'us' : id}Desc';

Future<Edition> loadEdition(String id) async {
  final raw = await rootBundle.loadString('assets/editions/$id.json');
  return Edition.fromJson(json.decode(raw) as Map<String, dynamic>);
}

final Map<String, Edition> _editionCache = {};

Future<Edition> getEdition(String id) async {
  if (_editionCache.containsKey(id)) return _editionCache[id]!;
  final e = await loadEdition(id);
  _editionCache[id] = e;
  return e;
}
