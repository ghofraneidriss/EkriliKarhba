import 'dart:convert';

import 'package:ekrili_karhba/features/vehicles/data/brand_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Tests de l'API publique marques/modèles (vPIC), sans réseau :
/// les réponses sont simulées avec MockClient.
void main() {
  test('lecture des marques et mise en forme', () {
    final body = jsonEncode({
      'Count': 3,
      'Results': [
        {'MakeId': 1, 'MakeName': 'ASTON MARTIN'},
        {'MakeId': 2, 'MakeName': 'MERCEDES-BENZ'},
        {'MakeId': 3, 'MakeName': 'BMW'},
      ],
    });
    expect(BrandCatalog.parseMakes(body),
        ['Aston Martin', 'BMW', 'Mercedes-Benz']);
  });

  test('les marques courantes en Tunisie passent en premier', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('GetMakesForVehicleType'));
      return http.Response(
        jsonEncode({
          'Results': [
            {'MakeName': 'PEUGEOT'},
            {'MakeName': 'TESLA'},
          ],
        }),
        200,
      );
    });
    final makes = await BrandCatalog(client: client).makes();
    expect(makes.first, 'Peugeot');
    expect(makes.where((m) => m.toLowerCase() == 'peugeot'), hasLength(1));
    expect(makes, contains('Tesla'));
  });

  test('sans réseau : liste locale', () async {
    final client = MockClient((_) async => throw Exception('hors ligne'));
    final catalog = BrandCatalog(client: client);
    expect(await catalog.makes(), BrandCatalog.popular.keys.toList());
    expect(await catalog.models('Renault'), contains('Clio'));
  });

  test('modèles : locaux puis API, sans doublon', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('GetModelsForMake'));
      return http.Response(
        jsonEncode({
          'Results': [
            {'Model_Name': '208'},
            {'Model_Name': '405'},
          ],
        }),
        200,
      );
    });
    final models = await BrandCatalog(client: client).models('Peugeot');
    expect(models.first, '208');
    expect(models.where((m) => m == '208'), hasLength(1));
    expect(models, contains('405'));
  });
}
