/// Petites fonctions de dates partagées par le module Véhicules.
class FleetDates {
  FleetDates._();

  /// Date sans heure (minuit), pour comparer des jours.
  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Format de stockage SQLite : yyyy-MM-dd.
  static String toDbDay(DateTime d) {
    final day = dayOnly(d);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  static DateTime fromDbDay(String value) => dayOnly(DateTime.parse(value));

  /// Format d'affichage : jj/mm/aaaa.
  static String display(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Format d'affichage avec l'heure : jj/mm/aaaa hh:mm.
  static String displayWithTime(DateTime d) =>
      '${display(d)} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  /// Vrai si les périodes [aStart, aEnd] et [bStart, bEnd] ont au moins
  /// un jour en commun (bornes incluses).
  static bool overlaps(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final s1 = dayOnly(aStart), e1 = dayOnly(aEnd);
    final s2 = dayOnly(bStart), e2 = dayOnly(bEnd);
    return !s1.isAfter(e2) && !s2.isAfter(e1);
  }
}

/// Formatage des montants et des kilomètres à la tunisienne.
class FleetFormat {
  FleetFormat._();

  /// 82450 -> « 82 450 ».
  static String thousands(num value) {
    final digits = value.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }

  static String km(num value) => '${thousands(value)} km';

  /// 180 -> « 180 DT », 72.5 -> « 72,5 DT ».
  static String dt(num value) {
    if (value == value.roundToDouble()) return '${thousands(value)} DT';
    return '${value.toStringAsFixed(1).replaceAll('.', ',')} DT';
  }
}
