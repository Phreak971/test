enum DistanceUnit {
  metric,
  imperial;

  static DistanceUnit parse(String? s) =>
      s == 'imperial' ? DistanceUnit.imperial : DistanceUnit.metric;
}

const _metersPerMile = 1609.344;
const _feetPerMeter = 3.28084;

/// Value + unit label, rounded the way drivers expect: coarse when far,
/// fine when close.
({String value, String unit}) formatDistanceParts(double meters, DistanceUnit unit) {
  if (meters.isNaN || meters < 0) meters = 0;
  if (unit == DistanceUnit.metric) {
    if (meters < 1000) {
      final m = meters < 100 ? (meters / 5).round() * 5 : (meters / 10).round() * 10;
      if (m >= 1000) return (value: '1', unit: 'km');
      return (value: '$m', unit: 'm');
    }
    final km = meters / 1000;
    return (value: km < 10 ? km.toStringAsFixed(1) : km.round().toString(), unit: 'km');
  }
  final miles = meters / _metersPerMile;
  if (miles < 0.1) {
    final ft = ((meters * _feetPerMeter) / 10).round() * 10;
    return (value: '$ft', unit: 'ft');
  }
  return (value: miles < 10 ? miles.toStringAsFixed(1) : miles.round().toString(), unit: 'mi');
}

String formatDistance(double meters, DistanceUnit unit) {
  final p = formatDistanceParts(meters, unit);
  return '${p.value} ${p.unit}';
}

/// "1 h 5 min" / "12 min" / "<1 min".
String formatDuration(double seconds, {String h = 'h', String min = 'min'}) {
  final totalMin = (seconds / 60).round();
  if (totalMin < 1) return '<1 $min';
  final hours = totalMin ~/ 60;
  final mins = totalMin % 60;
  if (hours == 0) return '$mins $min';
  if (mins == 0) return '$hours $h';
  return '$hours $h $mins $min';
}
