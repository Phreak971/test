import '../core/geo.dart';

/// A place from search, reverse geocoding, a map tap, or a nearby query.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.location,
    this.address,
    this.category,
    this.phone,
    this.website,
    this.osmKey,
    this.osmValue,
    this.isPinned = false,
  });

  final String id;
  final String name;
  final Geo location;
  final String? address;

  /// Human readable category ("Cafe", "Fuel"...).
  final String? category;
  final String? phone;
  final String? website;
  final String? osmKey;
  final String? osmValue;

  /// Dropped by long-press rather than found by search.
  final bool isPinned;

  Place copyWith({String? name, String? address, bool? isPinned}) => Place(
        id: id,
        name: name ?? this.name,
        location: location,
        address: address ?? this.address,
        category: category,
        phone: phone,
        website: website,
        osmKey: osmKey,
        osmValue: osmValue,
        isPinned: isPinned ?? this.isPinned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location.toJson(),
        if (address != null) 'address': address,
        if (category != null) 'category': category,
        if (phone != null) 'phone': phone,
        if (website != null) 'website': website,
        if (osmKey != null) 'osmKey': osmKey,
        if (osmValue != null) 'osmValue': osmValue,
        'isPinned': isPinned,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: j['id'] as String,
        name: j['name'] as String,
        location: Geo.fromJson((j['location'] as Map).cast<String, dynamic>()),
        address: j['address'] as String?,
        category: j['category'] as String?,
        phone: j['phone'] as String?,
        website: j['website'] as String?,
        osmKey: j['osmKey'] as String?,
        osmValue: j['osmValue'] as String?,
        isPinned: j['isPinned'] as bool? ?? false,
      );
}

/// Icons a user can pick for a saved place. Ids are stable (persisted).
enum PlaceIcon {
  star,
  home,
  work,
  food,
  coffee,
  bar,
  shop,
  gym,
  heart,
  flag,
  car,
  school;

  static PlaceIcon parse(String? s) =>
      PlaceIcon.values.firstWhere((e) => e.name == s, orElse: () => PlaceIcon.star);
}

/// A user-saved place (custom marker). The home location is a SavedPlace with
/// [isHome] set; at most one exists.
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.location,
    required this.icon,
    required this.createdAt,
    this.address,
    this.isHome = false,
  });

  final String id;
  final String name;
  final Geo location;
  final PlaceIcon icon;
  final DateTime createdAt;
  final String? address;
  final bool isHome;

  SavedPlace copyWith({String? name, PlaceIcon? icon, bool? isHome, String? address}) =>
      SavedPlace(
        id: id,
        name: name ?? this.name,
        location: location,
        icon: icon ?? this.icon,
        createdAt: createdAt,
        address: address ?? this.address,
        isHome: isHome ?? this.isHome,
      );

  Place toPlace() => Place(id: id, name: name, location: location, address: address);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location.toJson(),
        'icon': icon.name,
        'createdAt': createdAt.toIso8601String(),
        if (address != null) 'address': address,
        'isHome': isHome,
      };

  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(
        id: j['id'] as String,
        name: j['name'] as String,
        location: Geo.fromJson((j['location'] as Map).cast<String, dynamic>()),
        icon: PlaceIcon.parse(j['icon'] as String?),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime(2025),
        address: j['address'] as String?,
        isHome: j['isHome'] as bool? ?? false,
      );
}

/// Nearby search categories (mirrors the reference app's list).
enum NearbyCategory {
  restaurant('amenity', 'restaurant'),
  fastFood('amenity', 'fast_food'),
  cafe('amenity', 'cafe'),
  fuel('amenity', 'fuel'),
  charging('amenity', 'charging_station'),
  parking('amenity', 'parking'),
  hotel('tourism', 'hotel'),
  supermarket('shop', 'supermarket'),
  pharmacy('amenity', 'pharmacy'),
  hospital('amenity', 'hospital'),
  subway('railway', 'station'),
  bank('amenity', 'bank');

  const NearbyCategory(this.osmKey, this.osmValue);

  final String osmKey;
  final String osmValue;
}

enum ManeuverKind {
  depart,
  arrive,
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uturn,
  roundabout,
  merge,
  fork,
  rampLeft,
  rampRight,
}

class RouteStep {
  const RouteStep({
    required this.kind,
    required this.location,
    required this.distanceM,
    required this.durationS,
    required this.streetName,
    required this.geometry,
    this.roundaboutExit,
  });

  /// Maneuver performed at [location], at the start of this step.
  final ManeuverKind kind;
  final Geo location;

  /// Length of this step (from its maneuver to the next maneuver).
  final double distanceM;
  final double durationS;

  /// Road name driven *after* the maneuver; may be empty.
  final String streetName;
  final List<Geo> geometry;
  final int? roundaboutExit;
}

class RouteResult {
  const RouteResult({
    required this.geometry,
    required this.distanceM,
    required this.durationS,
    required this.steps,
  });

  final List<Geo> geometry;
  final double distanceM;
  final double durationS;
  final List<RouteStep> steps;
}

class SearchHistoryEntry {
  const SearchHistoryEntry({required this.place, required this.at});

  final Place place;
  final DateTime at;

  Map<String, dynamic> toJson() => {'place': place.toJson(), 'at': at.toIso8601String()};

  factory SearchHistoryEntry.fromJson(Map<String, dynamic> j) => SearchHistoryEntry(
        place: Place.fromJson((j['place'] as Map).cast<String, dynamic>()),
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime(2025),
      );
}
