import Foundation
import UIKit

/// Car screen UI strings for the app's locales (en, de, fr, es, it, tr).
enum CarText: String {
  case search, saved, nearby, voice, recent, home
  case noFavorites, noFavoritesDetail, noResults, searching
  case go, cancel, end, done, ok, overview
  case proTitle, setupTitle
  case noLocation, noRoute, genericError
  case arrived, voiceOn, voiceOff, voiceGuidance, voiceCharacter
  case restaurants, fastFood, coffee, gas, charging, parking, hotels, supermarkets, pharmacies, hospitals, subway, banks
}

enum CarStrings {
  static func t(_ key: CarText, _ locale: String) -> String {
    table[locale]?[key] ?? table["en"]?[key] ?? key.rawValue
  }

  private static let table: [String: [CarText: String]] = [
    "en": [
      .search: "Search", .saved: "Saved Places", .nearby: "Find Nearby", .voice: "Voice", .recent: "Recent", .home: "Home",
      .noFavorites: "No saved places", .noFavoritesDetail: "Add favorites from your phone", .noResults: "No results",
      .searching: "Searching…",
      .go: "Go", .cancel: "Cancel", .end: "End", .done: "Done", .ok: "OK", .overview: "Overview",
      .proTitle: "Unlock Overworld Pro on your iPhone to navigate with CarPlay",
      .setupTitle: "Open Overworld on your iPhone once to set up CarPlay",
      .noLocation: "Current location not found", .noRoute: "No route found", .genericError: "Something went wrong",
      .arrived: "You have arrived", .voiceOn: "On", .voiceOff: "Muted", .voiceGuidance: "Voice guidance",
      .voiceCharacter: "Voice character",
      .restaurants: "Restaurants", .fastFood: "Fast Food", .coffee: "Coffee Shops", .gas: "Gas Stations",
      .charging: "Charging Stations", .parking: "Parking", .hotels: "Hotels", .supermarkets: "Supermarkets",
      .pharmacies: "Pharmacies", .hospitals: "Hospitals", .subway: "Subway Stations", .banks: "Banks",
    ],
    "de": [
      .search: "Suche", .saved: "Gespeicherte Orte", .nearby: "In der Nähe", .voice: "Stimme", .recent: "Zuletzt", .home: "Zuhause",
      .noFavorites: "Keine gespeicherten Orte", .noFavoritesDetail: "Füge Favoriten auf deinem iPhone hinzu",
      .noResults: "Keine Ergebnisse", .searching: "Suche…",
      .go: "Los", .cancel: "Abbrechen", .end: "Beenden", .done: "Fertig", .ok: "OK", .overview: "Übersicht",
      .proTitle: "Schalte Overworld Pro auf deinem iPhone frei, um mit CarPlay zu navigieren",
      .setupTitle: "Öffne Overworld einmal auf deinem iPhone, um CarPlay einzurichten",
      .noLocation: "Aktueller Standort nicht gefunden", .noRoute: "Keine Route gefunden", .genericError: "Etwas ist schiefgelaufen",
      .arrived: "Du hast dein Ziel erreicht", .voiceOn: "An", .voiceOff: "Stumm", .voiceGuidance: "Sprachansagen",
      .voiceCharacter: "Stimme",
      .restaurants: "Restaurants", .fastFood: "Fast Food", .coffee: "Cafés", .gas: "Tankstellen",
      .charging: "Ladestationen", .parking: "Parkplätze", .hotels: "Hotels", .supermarkets: "Supermärkte",
      .pharmacies: "Apotheken", .hospitals: "Krankenhäuser", .subway: "U-Bahn-Stationen", .banks: "Banken",
    ],
    "fr": [
      .search: "Rechercher", .saved: "Lieux enregistrés", .nearby: "À proximité", .voice: "Voix", .recent: "Récents", .home: "Domicile",
      .noFavorites: "Aucun lieu enregistré", .noFavoritesDetail: "Ajoutez des favoris depuis votre iPhone",
      .noResults: "Aucun résultat", .searching: "Recherche…",
      .go: "Go", .cancel: "Annuler", .end: "Terminer", .done: "OK", .ok: "OK", .overview: "Aperçu",
      .proTitle: "Débloquez Overworld Pro sur votre iPhone pour naviguer avec CarPlay",
      .setupTitle: "Ouvrez Overworld une fois sur votre iPhone pour configurer CarPlay",
      .noLocation: "Position actuelle introuvable", .noRoute: "Aucun itinéraire trouvé", .genericError: "Une erreur s'est produite",
      .arrived: "Vous êtes arrivé", .voiceOn: "Activé", .voiceOff: "Muet", .voiceGuidance: "Guidage vocal",
      .voiceCharacter: "Personnage vocal",
      .restaurants: "Restaurants", .fastFood: "Restauration rapide", .coffee: "Cafés", .gas: "Stations-service",
      .charging: "Bornes de recharge", .parking: "Parkings", .hotels: "Hôtels", .supermarkets: "Supermarchés",
      .pharmacies: "Pharmacies", .hospitals: "Hôpitaux", .subway: "Stations de métro", .banks: "Banques",
    ],
    "es": [
      .search: "Buscar", .saved: "Lugares guardados", .nearby: "Cerca", .voice: "Voz", .recent: "Recientes", .home: "Casa",
      .noFavorites: "No hay lugares guardados", .noFavoritesDetail: "Añade favoritos desde tu iPhone",
      .noResults: "Sin resultados", .searching: "Buscando…",
      .go: "Ir", .cancel: "Cancelar", .end: "Finalizar", .done: "Listo", .ok: "OK", .overview: "Vista general",
      .proTitle: "Desbloquea Overworld Pro en tu iPhone para navegar con CarPlay",
      .setupTitle: "Abre Overworld una vez en tu iPhone para configurar CarPlay",
      .noLocation: "No se encontró la ubicación actual", .noRoute: "No se encontró ninguna ruta", .genericError: "Algo salió mal",
      .arrived: "Has llegado", .voiceOn: "Activada", .voiceOff: "Silenciada", .voiceGuidance: "Guía por voz",
      .voiceCharacter: "Personaje de voz",
      .restaurants: "Restaurantes", .fastFood: "Comida rápida", .coffee: "Cafeterías", .gas: "Gasolineras",
      .charging: "Puntos de carga", .parking: "Aparcamientos", .hotels: "Hoteles", .supermarkets: "Supermercados",
      .pharmacies: "Farmacias", .hospitals: "Hospitales", .subway: "Estaciones de metro", .banks: "Bancos",
    ],
    "it": [
      .search: "Cerca", .saved: "Luoghi salvati", .nearby: "Nelle vicinanze", .voice: "Voce", .recent: "Recenti", .home: "Casa",
      .noFavorites: "Nessun luogo salvato", .noFavoritesDetail: "Aggiungi preferiti dal tuo iPhone",
      .noResults: "Nessun risultato", .searching: "Ricerca…",
      .go: "Vai", .cancel: "Annulla", .end: "Termina", .done: "Fine", .ok: "OK", .overview: "Panoramica",
      .proTitle: "Sblocca Overworld Pro sul tuo iPhone per navigare con CarPlay",
      .setupTitle: "Apri Overworld una volta sul tuo iPhone per configurare CarPlay",
      .noLocation: "Posizione attuale non trovata", .noRoute: "Nessun percorso trovato", .genericError: "Qualcosa è andato storto",
      .arrived: "Sei arrivato", .voiceOn: "Attiva", .voiceOff: "Disattivata", .voiceGuidance: "Guida vocale",
      .voiceCharacter: "Personaggio vocale",
      .restaurants: "Ristoranti", .fastFood: "Fast food", .coffee: "Caffetterie", .gas: "Distributori",
      .charging: "Stazioni di ricarica", .parking: "Parcheggi", .hotels: "Hotel", .supermarkets: "Supermercati",
      .pharmacies: "Farmacie", .hospitals: "Ospedali", .subway: "Stazioni della metro", .banks: "Banche",
    ],
    "tr": [
      .search: "Ara", .saved: "Kayıtlı Yerler", .nearby: "Yakındakiler", .voice: "Ses", .recent: "Son aramalar", .home: "Ev",
      .noFavorites: "Kayıtlı yer yok", .noFavoritesDetail: "Favorileri iPhone'unuzdan ekleyin",
      .noResults: "Sonuç yok", .searching: "Aranıyor…",
      .go: "Başla", .cancel: "İptal", .end: "Bitir", .done: "Bitti", .ok: "Tamam", .overview: "Genel bakış",
      .proTitle: "CarPlay ile navigasyon için iPhone'unuzda Overworld Pro'nun kilidini açın",
      .setupTitle: "CarPlay'i kurmak için Overworld'ü iPhone'unuzda bir kez açın",
      .noLocation: "Mevcut konum bulunamadı", .noRoute: "Rota bulunamadı", .genericError: "Bir şeyler ters gitti",
      .arrived: "Vardınız", .voiceOn: "Açık", .voiceOff: "Sessiz", .voiceGuidance: "Sesli yönlendirme",
      .voiceCharacter: "Ses karakteri",
      .restaurants: "Restoranlar", .fastFood: "Fast food", .coffee: "Kafeler", .gas: "Benzin istasyonları",
      .charging: "Şarj istasyonları", .parking: "Otoparklar", .hotels: "Oteller", .supermarkets: "Süpermarketler",
      .pharmacies: "Eczaneler", .hospitals: "Hastaneler", .subway: "Metro istasyonları", .banks: "Bankalar",
    ],
  ]
}

/// Nearby categories (APP_MAP.md §5) → Nominatim `amenity` value + symbol.
struct CarCategory {
  let title: CarText
  let amenity: String
  let symbol: String

  static let all: [CarCategory] = [
    CarCategory(title: .restaurants, amenity: "restaurant", symbol: "fork.knife"),
    CarCategory(title: .fastFood, amenity: "fast_food", symbol: "takeoutbag.and.cup.and.straw"),
    CarCategory(title: .coffee, amenity: "cafe", symbol: "cup.and.saucer"),
    CarCategory(title: .gas, amenity: "fuel", symbol: "fuelpump"),
    CarCategory(title: .charging, amenity: "charging_station", symbol: "bolt.car"),
    CarCategory(title: .parking, amenity: "parking", symbol: "parkingsign.circle"),
    CarCategory(title: .hotels, amenity: "hotel", symbol: "bed.double"),
    CarCategory(title: .supermarkets, amenity: "supermarket", symbol: "cart"),
    CarCategory(title: .pharmacies, amenity: "pharmacy", symbol: "pills"),
    CarCategory(title: .hospitals, amenity: "hospital", symbol: "cross.case"),
    CarCategory(title: .subway, amenity: "station", symbol: "tram"),
    CarCategory(title: .banks, amenity: "bank", symbol: "building.columns"),
  ]
}

enum CarSymbols {
  /// First available SF Symbol of `names` (newer symbols fall back to older ones).
  static func image(_ names: String..., pointSize: CGFloat = 22, weight: UIImage.SymbolWeight = .regular) -> UIImage {
    let cfg = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    for n in names {
      if let img = UIImage(systemName: n, withConfiguration: cfg) { return img }
    }
    return UIImage(systemName: "circle", withConfiguration: cfg) ?? UIImage()
  }

  /// Turn-card symbol for a maneuver, white on the dark guidance card.
  static func maneuver(_ kind: CarManeuverKind) -> UIImage {
    let img: UIImage
    switch kind {
    case .left, .sharpLeft: img = image("arrow.turn.up.left", pointSize: 48, weight: .bold)
    case .right, .sharpRight: img = image("arrow.turn.up.right", pointSize: 48, weight: .bold)
    case .slightLeft, .rampLeft: img = image("arrow.up.left", pointSize: 48, weight: .bold)
    case .slightRight, .rampRight: img = image("arrow.up.right", pointSize: 48, weight: .bold)
    case .uturn: img = image("arrow.uturn.down", "arrow.uturn.left", pointSize: 48, weight: .bold)
    case .roundabout: img = image("arrow.triangle.turn.up.right.circle", "arrow.clockwise", pointSize: 48, weight: .bold)
    case .merge: img = image("arrow.triangle.merge", "arrow.up", pointSize: 48, weight: .bold)
    case .fork: img = image("arrow.triangle.branch", "arrow.up", pointSize: 48, weight: .bold)
    case .arrive: img = image("flag.checkered", "flag.fill", pointSize: 48, weight: .bold)
    case .depart, .straight: img = image("arrow.up", pointSize: 48, weight: .bold)
    }
    return img.withTintColor(.white, renderingMode: .alwaysOriginal)
  }
}

/// Distance / duration formatting honoring the synced unit + locale.
enum CarUnits {
  private static let metersPerMile = 1609.344
  private static let feetPerMeter = 3.28084

  /// Rounded the way drivers expect (same steps as lib/core/units.dart).
  /// `unit` is one of m, km, ft, mi.
  static func parts(_ meters: Double, imperial: Bool) -> (value: Double, unit: String) {
    let m = meters.isFinite ? max(0, meters) : 0
    if !imperial {
      if m < 1000 {
        let r = m < 100 ? (m / 5).rounded() * 5 : (m / 10).rounded() * 10
        if r >= 1000 { return (1, "km") }
        return (r, "m")
      }
      let km = m / 1000
      return (km < 10 ? (km * 10).rounded() / 10 : km.rounded(), "km")
    }
    let miles = m / metersPerMile
    if miles < 0.1 {
      return (((m * feetPerMeter) / 10).rounded() * 10, "ft")
    }
    return (miles < 10 ? (miles * 10).rounded() / 10 : miles.rounded(), "mi")
  }

  static func measurement(_ meters: Double, imperial: Bool) -> Measurement<UnitLength> {
    let p = parts(meters, imperial: imperial)
    let unit: UnitLength
    switch p.unit {
    case "km": unit = .kilometers
    case "ft": unit = .feet
    case "mi": unit = .miles
    default: unit = .meters
    }
    return Measurement(value: p.value, unit: unit)
  }

  /// Number as spoken/printed: "300", "1.5" (locale decimal separator).
  static func number(_ v: Double, locale: String) -> String {
    let f = NumberFormatter()
    f.locale = Locale(identifier: locale)
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 1
    return f.string(from: NSNumber(value: v)) ?? String(v)
  }

  static func format(_ meters: Double, imperial: Bool, locale: String) -> String {
    let f = MeasurementFormatter()
    f.locale = Locale(identifier: locale)
    f.unitOptions = .providedUnit
    f.unitStyle = .medium
    f.numberFormatter.maximumFractionDigits = 1
    return f.string(from: measurement(meters, imperial: imperial))
  }

  static func duration(_ seconds: Double, locale: String) -> String {
    let f = DateComponentsFormatter()
    var cal = Calendar(identifier: .gregorian)
    cal.locale = Locale(identifier: locale)
    f.calendar = cal
    f.unitsStyle = .short
    f.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
    let rounded = max(60, (seconds / 60).rounded() * 60)
    return f.string(from: rounded) ?? "\(Int(rounded / 60)) min"
  }
}
