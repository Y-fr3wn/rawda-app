/// IANA zone resolution for the prayer clock and AlAdhan calendar.
/// Avoid fixed offsets: Egypt observes daylight saving time during summer.
/// Do not override a user-selected zone or infer Egypt for foreign GPS points.
String? prayerZoneHint(Map<String, dynamic> config) {
  final selected = (config['timezone'] ?? '').toString().trim();
  if (selected.isNotEmpty) return selected;

  // A GPS selection may leave an old city/country in settings. Use only the
  // coordinates, not the stale country name, when coordinates are present.
  if (config['lat'] != null || config['lon'] != null) {
    final lat = double.tryParse('${config['lat']}');
    final lon = double.tryParse('${config['lon']}');
    if (lat != null &&
        lon != null &&
        lat >= 21.7 &&
        lat <= 31.8 &&
        lon >= 24.6 &&
        lon <= 37.0) {
      return 'Africa/Cairo';
    }
    return null;
  }

  final country = (config['country'] ?? 'Egypt')
      .toString()
      .trim()
      .toLowerCase();
  if (country == 'egypt' ||
      country == 'مصر' ||
      country == 'جمهورية مصر العربية' ||
      country == 'eg') {
    return 'Africa/Cairo';
  }
  return null;
}

String? prayerZoneForRow(dynamic row, Map<String, dynamic> config) {
  if (row is Map) {
    final meta = row['meta'];
    if (meta is Map) {
      final zone = (meta['timezone'] ?? '').toString().trim();
      if (zone.isNotEmpty) return zone;
    }
  }
  return prayerZoneHint(config);
}

String? prayerClockZone(Map<String, dynamic> config, List<dynamic> rows) {
  if (rows.isNotEmpty) return prayerZoneForRow(rows.first, config);
  return prayerZoneHint(config);
}
