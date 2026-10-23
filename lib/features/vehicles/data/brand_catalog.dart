import 'dart:convert';

import 'package:http/http.dart' as http;

/// Marques et modèles pour l'autocomplétion du formulaire véhicule.
///
/// Source : API publique vPIC de la NHTSA (gratuite, sans clé)
/// https://vpic.nhtsa.dot.gov/api/ — complétée par une liste locale des
/// marques et modèles les plus courants en Tunisie (l'API est centrée sur
/// le marché américain). Sans connexion, la liste locale suffit.
class BrandCatalog {
  BrandCatalog({http.Client? client}) : _client = client ?? http.Client();

  static final BrandCatalog instance = BrandCatalog();

  static const String _baseUrl = 'https://vpic.nhtsa.dot.gov/api/vehicles';
  static const Duration _timeout = Duration(seconds: 8);

  /// Marques et modèles courants sur le marché tunisien.
  static const Map<String, List<String>> popular = {
    'Peugeot': ['208', '2008', '301', '308', '3008', '508', 'Partner'],
    'Renault': ['Clio', 'Symbol', 'Mégane', 'Captur', 'Kadjar', 'Kangoo'],
    'Dacia': ['Sandero', 'Logan', 'Duster', 'Jogger', 'Spring'],
    'Citroën': ['C3', 'C4', 'C-Elysée', 'Berlingo', 'C5 Aircross'],
    'Volkswagen': ['Polo', 'Golf', 'Passat', 'Tiguan', 'T-Roc', 'Caddy'],
    'Kia': ['Picanto', 'Rio', 'Ceed', 'Sportage', 'Seltos'],
    'Hyundai': ['i10', 'i20', 'Accent', 'Elantra', 'Tucson', 'Creta'],
    'Toyota': ['Yaris', 'Corolla', 'C-HR', 'RAV4', 'Hilux'],
    'Seat': ['Ibiza', 'Leon', 'Arona', 'Ateca'],
    'Skoda': ['Fabia', 'Octavia', 'Kamiq', 'Karoq', 'Kodiaq'],
    'Fiat': ['Panda', '500', 'Tipo', 'Doblo'],
    'Suzuki': ['Swift', 'Celerio', 'Vitara', 'S-Presso'],
    'Chery': ['Tiggo 2', 'Tiggo 4', 'Tiggo 7', 'Arrizo 5'],
    'MG': ['ZS', 'MG5', 'HS', 'RX5'],
    'Ford': ['Fiesta', 'Focus', 'Kuga', 'Ranger', 'Transit'],
    'Nissan': ['Micra', 'Qashqai', 'Juke', 'Navara'],
    'Opel': ['Corsa', 'Astra', 'Mokka', 'Grandland'],
    'BMW': ['Série 1', 'Série 3', 'Série 5', 'X1', 'X3', 'X5'],
    'Mercedes-Benz': ['Classe A', 'Classe C', 'Classe E', 'GLA', 'GLC'],
    'Audi': ['A3', 'A4', 'A6', 'Q3', 'Q5'],
  };

  final http.Client _client;
  List<String>? _makes;
  final Map<String, List<String>> _models = {};

  /// Vrai si la dernière liste de marques vient de l'API (sinon : locale).
  bool lastMakesFromApi = false;

  /// Toutes les marques : courantes d'abord, puis celles de l'API.
  Future<List<String>> makes() async {
    final cached = _makes;
    if (cached != null) return cached;
    final local = popular.keys.toList();
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/GetMakesForVehicleType/car?format=json'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final merged = mergeNames(local, parseMakes(response.body));
        _makes = merged;
        lastMakesFromApi = true;
        return merged;
      }
    } catch (_) {
      // Pas de réseau ou API indisponible : liste locale.
    }
    lastMakesFromApi = false;
    return local;
  }

  /// Modèles d'une marque : courants d'abord, puis ceux de l'API.
  Future<List<String>> models(String make) async {
    final key = make.trim().toLowerCase();
    if (key.isEmpty) return const [];
    final cached = _models[key];
    if (cached != null) return cached;

    final local = <String>[];
    for (final entry in popular.entries) {
      if (entry.key.toLowerCase() == key) local.addAll(entry.value);
    }
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/GetModelsForMake/'
              '${Uri.encodeComponent(make.trim())}?format=json'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final merged = mergeNames(local, parseModels(response.body));
        _models[key] = merged;
        return merged;
      }
    } catch (_) {
      // Liste locale seulement.
    }
    return local;
  }

  // ------------------------------------------- Lecture du JSON de l'API

  /// Réponse de GetMakesForVehicleType : Results[].MakeName.
  static List<String> parseMakes(String body) =>
      _parseField(body, 'MakeName', titleCase: true);

  /// Réponse de GetModelsForMake : Results[].Model_Name.
  static List<String> parseModels(String body) =>
      _parseField(body, 'Model_Name', titleCase: false);

  static List<String> _parseField(
    String body,
    String field, {
    required bool titleCase,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];
    final results = decoded['Results'];
    if (results is! List) return const [];
    final names = <String>{};
    for (final item in results) {
      if (item is Map<String, dynamic>) {
        final value = item[field];
        if (value is String && value.trim().isNotEmpty) {
          names.add(titleCase ? toTitleCase(value.trim()) : value.trim());
        }
      }
    }
    final list = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  /// « ASTON MARTIN » -> « Aston Martin », « MERCEDES-BENZ » ->
  /// « Mercedes-Benz » ; les sigles courts (BMW, MG) restent en majuscules.
  static String toTitleCase(String value) {
    String word(String w) {
      if (w.length <= 3) return w.toUpperCase();
      return w
          .split('-')
          .map((part) => part.isEmpty
              ? part
              : part[0].toUpperCase() + part.substring(1).toLowerCase())
          .join('-');
    }

    return value.split(RegExp(r'\s+')).map(word).join(' ');
  }

  /// [first] puis les éléments de [rest] absents de [first]
  /// (comparaison sans tenir compte des majuscules).
  static List<String> mergeNames(List<String> first, List<String> rest) {
    final seen = first.map((s) => s.toLowerCase()).toSet();
    return [
      ...first,
      for (final name in rest)
        if (seen.add(name.toLowerCase())) name,
    ];
  }
}
