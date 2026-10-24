import AVFoundation
import Foundation

/// Plain guidance phrases per language (port of `_langs` in lib/nav/voice.dart).
struct CarLang {
  let dirs: [CarManeuverKind: String]
  let roundabout: (Int?) -> String
  let inDist: String      // "In {dist}, {dir}"
  let continueFor: String // "Continue for {dist}, then {dir}"
  let now: String         // "{dir}"
  let arrive: String
  let reroute: String
  let onto: String        // " onto {street}"
  let units: [String: String]
}

enum CarPhrases {
  static func lang(_ code: String) -> CarLang { langs[code] ?? langs["en"]! }

  /// Sentence spoken for `cue` (plain guidance; persona phrase packs are
  /// phone-only for now).
  static func phrase(for cue: CarCue, imperial: Bool, locale: String) -> String {
    let l = lang(locale)
    if cue.stage == .arrive { return l.arrive }
    var dir = direction(cue.step, l)
    if !cue.step.street.isEmpty && cue.stage != .prepare {
      dir += l.onto.replacingOccurrences(of: "{street}", with: cue.step.street)
    }
    let parts = CarUnits.parts(cue.distanceM, imperial: imperial)
    let dist = "\(CarUnits.number(parts.value, locale: locale)) \(l.units[parts.unit] ?? parts.unit)"
    let template: String
    switch cue.stage {
    case .prepare: template = l.continueFor
    case .approach: template = l.inDist
    case .now: template = l.now
    case .arrive: template = l.arrive
    }
    return capitalized(template.replacingOccurrences(of: "{dir}", with: dir).replacingOccurrences(of: "{dist}", with: dist))
  }

  static func reroute(locale: String) -> String { lang(locale).reroute }

  /// "In 300 meters, turn left" (voice preview).
  static func sample(locale: String) -> String {
    let l = lang(locale)
    return capitalized(l.inDist
      .replacingOccurrences(of: "{dist}", with: "300 \(l.units["m"] ?? "m")")
      .replacingOccurrences(of: "{dir}", with: l.dirs[.left] ?? ""))
  }

  /// Turn-card text: [with street, without street].
  static func instructions(for step: CarStep, locale: String) -> [String] {
    let l = lang(locale)
    if step.kind == .arrive { return [l.arrive] }
    let dir = capitalized(direction(step, l))
    if step.street.isEmpty { return [dir] }
    return [dir + l.onto.replacingOccurrences(of: "{street}", with: step.street), dir]
  }

  private static func direction(_ step: CarStep, _ l: CarLang) -> String {
    if step.kind == .roundabout { return l.roundabout(step.roundaboutExit) }
    return l.dirs[step.kind] ?? l.dirs[.straight] ?? ""
  }

  private static func capitalized(_ s: String) -> String {
    guard let first = s.first else { return s }
    return first.uppercased() + s.dropFirst()
  }

  private static func ordinal(_ n: Int) -> String {
    switch n {
    case 1: return "first"
    case 2: return "second"
    case 3: return "third"
    case 4: return "fourth"
    case 5: return "fifth"
    default: return "\(n)th"
    }
  }

  private static let langs: [String: CarLang] = [
    "en": CarLang(
      dirs: [
        .depart: "head out", .straight: "continue straight", .slightLeft: "bear left", .left: "turn left",
        .sharpLeft: "make a sharp left", .slightRight: "bear right", .right: "turn right",
        .sharpRight: "make a sharp right", .uturn: "make a U-turn", .merge: "merge", .fork: "keep at the fork",
        .rampLeft: "take the ramp on the left", .rampRight: "take the ramp on the right", .arrive: "arrive",
      ],
      roundabout: { e in e.map { "at the roundabout, take the \(CarPhrases.ordinal($0)) exit" } ?? "take the roundabout" },
      inDist: "In {dist}, {dir}", continueFor: "Continue for {dist}, then {dir}", now: "{dir}",
      arrive: "You have arrived at your destination", reroute: "Rerouting", onto: " onto {street}",
      units: ["m": "meters", "km": "kilometers", "ft": "feet", "mi": "miles"]),
    "de": CarLang(
      dirs: [
        .depart: "losfahren", .straight: "geradeaus weiterfahren", .slightLeft: "leicht links halten",
        .left: "links abbiegen", .sharpLeft: "scharf links abbiegen", .slightRight: "leicht rechts halten",
        .right: "rechts abbiegen", .sharpRight: "scharf rechts abbiegen", .uturn: "wenden", .merge: "einfädeln",
        .fork: "an der Gabelung halten", .rampLeft: "die Ausfahrt links nehmen",
        .rampRight: "die Ausfahrt rechts nehmen", .arrive: "ankommen",
      ],
      roundabout: { e in e.map { "im Kreisverkehr die \($0). Ausfahrt nehmen" } ?? "in den Kreisverkehr fahren" },
      inDist: "In {dist} {dir}", continueFor: "{dist} weiterfahren, dann {dir}", now: "Jetzt {dir}",
      arrive: "Sie haben Ihr Ziel erreicht", reroute: "Route wird neu berechnet", onto: " auf {street}",
      units: ["m": "Metern", "km": "Kilometern", "ft": "Fuß", "mi": "Meilen"]),
    "fr": CarLang(
      dirs: [
        .depart: "partez", .straight: "continuez tout droit", .slightLeft: "serrez à gauche",
        .left: "tournez à gauche", .sharpLeft: "tournez franchement à gauche", .slightRight: "serrez à droite",
        .right: "tournez à droite", .sharpRight: "tournez franchement à droite", .uturn: "faites demi-tour",
        .merge: "insérez-vous", .fork: "restez sur la bifurcation", .rampLeft: "prenez la bretelle à gauche",
        .rampRight: "prenez la bretelle à droite", .arrive: "arrivez",
      ],
      roundabout: { e in e.map { "au rond-point, prenez la \($0 == 1 ? "1re" : "\($0)e") sortie" } ?? "prenez le rond-point" },
      inDist: "Dans {dist}, {dir}", continueFor: "Continuez sur {dist}, puis {dir}", now: "{dir} maintenant",
      arrive: "Vous êtes arrivé à destination", reroute: "Recalcul de l'itinéraire", onto: " sur {street}",
      units: ["m": "mètres", "km": "kilomètres", "ft": "pieds", "mi": "miles"]),
    "es": CarLang(
      dirs: [
        .depart: "sal", .straight: "sigue recto", .slightLeft: "mantente a la izquierda",
        .left: "gira a la izquierda", .sharpLeft: "gira bruscamente a la izquierda",
        .slightRight: "mantente a la derecha", .right: "gira a la derecha",
        .sharpRight: "gira bruscamente a la derecha", .uturn: "cambia de sentido", .merge: "incorpórate",
        .fork: "mantente en la bifurcación", .rampLeft: "toma la salida a la izquierda",
        .rampRight: "toma la salida a la derecha", .arrive: "llega",
      ],
      roundabout: { e in e.map { "en la rotonda, toma la salida \($0)" } ?? "entra en la rotonda" },
      inDist: "En {dist}, {dir}", continueFor: "Continúa {dist} y luego {dir}", now: "{dir} ahora",
      arrive: "Has llegado a tu destino", reroute: "Recalculando la ruta", onto: " hacia {street}",
      units: ["m": "metros", "km": "kilómetros", "ft": "pies", "mi": "millas"]),
    "it": CarLang(
      dirs: [
        .depart: "parti", .straight: "prosegui dritto", .slightLeft: "tieni la sinistra",
        .left: "svolta a sinistra", .sharpLeft: "svolta decisamente a sinistra", .slightRight: "tieni la destra",
        .right: "svolta a destra", .sharpRight: "svolta decisamente a destra", .uturn: "fai inversione",
        .merge: "immettiti", .fork: "tieniti al bivio", .rampLeft: "prendi la rampa a sinistra",
        .rampRight: "prendi la rampa a destra", .arrive: "arriva",
      ],
      roundabout: { e in e.map { "alla rotonda, prendi la uscita numero \($0)" } ?? "entra nella rotonda" },
      inDist: "Tra {dist}, {dir}", continueFor: "Prosegui per {dist}, poi {dir}", now: "Ora {dir}",
      arrive: "Sei arrivato a destinazione", reroute: "Ricalcolo del percorso", onto: " su {street}",
      units: ["m": "metri", "km": "chilometri", "ft": "piedi", "mi": "miglia"]),
    "tr": CarLang(
      dirs: [
        .depart: "yola çıkın", .straight: "düz devam edin", .slightLeft: "hafif sola yönelin",
        .left: "sola dönün", .sharpLeft: "keskin sola dönün", .slightRight: "hafif sağa yönelin",
        .right: "sağa dönün", .sharpRight: "keskin sağa dönün", .uturn: "U dönüşü yapın",
        .merge: "yola katılın", .fork: "yol ayrımında devam edin", .rampLeft: "soldaki rampayı kullanın",
        .rampRight: "sağdaki rampayı kullanın", .arrive: "varın",
      ],
      roundabout: { e in e.map { "döner kavşaktan \($0). çıkışı kullanın" } ?? "döner kavşağa girin" },
      inDist: "{dist} sonra {dir}", continueFor: "{dist} devam edin, ardından {dir}", now: "Şimdi {dir}",
      arrive: "Varış noktanıza ulaştınız", reroute: "Rota yeniden hesaplanıyor", onto: ", {street} yönüne",
      units: ["m": "metre", "km": "kilometre", "ft": "fit", "mi": "mil"]),
  ]
}

/// On-device TTS for the car: persona pitch/rate, ducking other audio, and
/// releasing the audio session after each prompt.
final class CarVoice: NSObject, AVSpeechSynthesizerDelegate {
  private let synth = AVSpeechSynthesizer()

  override init() {
    super.init()
    synth.delegate = self
  }

  /// Speaks `text` unless muted. Call on the main thread.
  func speak(_ text: String, interrupt: Bool = false) {
    let state = CarStore.shared.state
    guard !state.muted, !text.isEmpty else { return }
    if interrupt && synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .voicePrompt,
                              options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
      try session.setActive(true)
    } catch {
      NSLog("Overworld CarVoice: audio session error \(error)")
    }

    let u = AVSpeechUtterance(string: text)
    // voice.rate is 0..1 like flutter_tts on iOS, where 0.5 is the default rate.
    let rate = Float(state.voice.rate.isFinite ? state.voice.rate : 0.5)
    u.rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, rate))
    u.pitchMultiplier = Float(min(2.0, max(0.5, state.voice.pitch.isFinite ? state.voice.pitch : 1.0)))
    u.voice = AVSpeechSynthesisVoice(language: Self.bcp47(state.locale))
      ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    synth.speak(u)
  }

  func stop() {
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    deactivateIfIdle()
  }

  private static func bcp47(_ code: String) -> String {
    switch code {
    case "de": return "de-DE"
    case "fr": return "fr-FR"
    case "es": return "es-ES"
    case "it": return "it-IT"
    case "tr": return "tr-TR"
    default: return "en-US"
    }
  }

  private func deactivateIfIdle() {
    guard !synth.isSpeaking else { return }
    // Lets ducked audio (music, podcasts) return to full volume.
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    DispatchQueue.main.async { [weak self] in self?.deactivateIfIdle() }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
    DispatchQueue.main.async { [weak self] in self?.deactivateIfIdle() }
  }
}
