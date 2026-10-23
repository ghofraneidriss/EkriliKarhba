import 'package:ekrili_karhba/features/vehicles/domain/fleet_dates.dart';
import 'package:ekrili_karhba/features/vehicles/domain/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Matricule tunisien', () {
    test('formats acceptés', () {
      expect(FleetValidators.registrationPlate('234 TUN 1987'), isNull);
      expect(FleetValidators.registrationPlate('12tun345'), isNull);
    });

    test('formats refusés', () {
      expect(FleetValidators.registrationPlate(''), isNotNull);
      expect(FleetValidators.registrationPlate('ABC'), isNotNull);
      expect(FleetValidators.registrationPlate('1234 TUN 1'), isNotNull);
    });

    test('normalisation', () {
      expect(FleetValidators.normalizePlate('234tun1987'), '234 TUN 1987');
      expect(FleetValidators.normalizePlate(' 12  TUN 5 '), '12 TUN 5');
    });
  });

  test('prix, année, places', () {
    expect(FleetValidators.price('180'), isNull);
    expect(FleetValidators.price('72,5'), isNull);
    expect(FleetValidators.price('0'), isNotNull);
    expect(FleetValidators.year('1985'), isNotNull);
    expect(FleetValidators.seats('5'), isNull);
    expect(FleetValidators.seats('12'), isNotNull);
  });

  test('chevauchement de périodes (bornes incluses)', () {
    final d = DateTime(2026, 10, 1);
    expect(
      FleetDates.overlaps(d, d.add(const Duration(days: 2)),
          d.add(const Duration(days: 2)), d.add(const Duration(days: 4))),
      isTrue,
    );
    expect(
      FleetDates.overlaps(d, d.add(const Duration(days: 1)),
          d.add(const Duration(days: 2)), d.add(const Duration(days: 4))),
      isFalse,
    );
  });

  test('formats tunisiens', () {
    expect(FleetFormat.dt(180), '180 DT');
    expect(FleetFormat.km(82450), '82 450 km');
  });
}
