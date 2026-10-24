package app.overworld.overworld.car

import java.util.Locale
import kotlin.math.roundToLong

/** Unit of a rounded display distance. */
enum class DistUnit(val code: String) { M("m"), KM("km"), FT("ft"), MI("mi") }

/** A rounded display distance, e.g. 1.2 km or 300 m. */
data class DisplayDistance(val value: Double, val text: String, val unit: DistUnit)

/** Distance rounding identical to `formatDistanceParts` in lib/core/units.dart. */
object Units {
    private const val METERS_PER_MILE = 1609.344
    private const val FEET_PER_METER = 3.28084

    fun isImperial(unit: String?): Boolean = unit == "imperial"

    fun format(metersIn: Double, imperial: Boolean): DisplayDistance {
        val meters = if (metersIn.isNaN() || metersIn < 0) 0.0 else metersIn
        if (!imperial) {
            if (meters < 1000) {
                val m = if (meters < 100) (meters / 5).roundToLong() * 5 else (meters / 10).roundToLong() * 10
                if (m >= 1000) return DisplayDistance(1.0, "1", DistUnit.KM)
                return DisplayDistance(m.toDouble(), m.toString(), DistUnit.M)
            }
            val km = meters / 1000
            return if (km < 10) {
                val r = (km * 10).roundToLong() / 10.0
                DisplayDistance(r, oneDecimal(r), DistUnit.KM)
            } else {
                val r = km.roundToLong()
                DisplayDistance(r.toDouble(), r.toString(), DistUnit.KM)
            }
        }
        val miles = meters / METERS_PER_MILE
        if (miles < 0.1) {
            val ft = ((meters * FEET_PER_METER) / 10).roundToLong() * 10
            return DisplayDistance(ft.toDouble(), ft.toString(), DistUnit.FT)
        }
        return if (miles < 10) {
            val r = (miles * 10).roundToLong() / 10.0
            DisplayDistance(r, oneDecimal(r), DistUnit.MI)
        } else {
            val r = miles.roundToLong()
            DisplayDistance(r.toDouble(), r.toString(), DistUnit.MI)
        }
    }

    private fun oneDecimal(v: Double): String = String.format(Locale.US, "%.1f", v)
}

/**
 * Plain spoken guidance in en/de/fr/es/it/tr. A port of the `_langs` table and
 * `phraseFor` in lib/nav/voice.dart (without the English persona flavour packs).
 */
object Phrases {
    private class Lang(
        val dirs: Map<ManeuverKind, String>,
        val roundabout: (Int?) -> String,
        val inDist: String,
        val continueFor: String,
        val now: String,
        val arrive: String,
        val reroute: String,
        val onto: String,
        val units: Map<DistUnit, String>,
    )

    private fun ordEn(n: Int): String = when (n) {
        1 -> "first"; 2 -> "second"; 3 -> "third"; 4 -> "fourth"; 5 -> "fifth"; else -> "${n}th"
    }

    private val langs: Map<String, Lang> = mapOf(
        "en" to Lang(
            dirs = mapOf(
                ManeuverKind.DEPART to "head out",
                ManeuverKind.STRAIGHT to "continue straight",
                ManeuverKind.SLIGHT_LEFT to "bear left",
                ManeuverKind.LEFT to "turn left",
                ManeuverKind.SHARP_LEFT to "make a sharp left",
                ManeuverKind.SLIGHT_RIGHT to "bear right",
                ManeuverKind.RIGHT to "turn right",
                ManeuverKind.SHARP_RIGHT to "make a sharp right",
                ManeuverKind.UTURN to "make a U-turn",
                ManeuverKind.MERGE to "merge",
                ManeuverKind.FORK to "keep at the fork",
                ManeuverKind.RAMP_LEFT to "take the ramp on the left",
                ManeuverKind.RAMP_RIGHT to "take the ramp on the right",
                ManeuverKind.ARRIVE to "arrive",
            ),
            roundabout = { e -> if (e == null) "take the roundabout" else "at the roundabout, take the ${ordEn(e)} exit" },
            inDist = "In {dist}, {dir}",
            continueFor = "Continue for {dist}, then {dir}",
            now = "{dir}",
            arrive = "You have arrived at your destination",
            reroute = "Rerouting",
            onto = " onto {street}",
            units = mapOf(DistUnit.M to "meters", DistUnit.KM to "kilometers", DistUnit.FT to "feet", DistUnit.MI to "miles"),
        ),
        "de" to Lang(
            dirs = mapOf(
                ManeuverKind.DEPART to "losfahren",
                ManeuverKind.STRAIGHT to "geradeaus weiterfahren",
                ManeuverKind.SLIGHT_LEFT to "leicht links halten",
                ManeuverKind.LEFT to "links abbiegen",
                ManeuverKind.SHARP_LEFT to "scharf links abbiegen",
                ManeuverKind.SLIGHT_RIGHT to "leicht rechts halten",
                ManeuverKind.RIGHT to "rechts abbiegen",
                ManeuverKind.SHARP_RIGHT to "scharf rechts abbiegen",
                ManeuverKind.UTURN to "wenden",
                ManeuverKind.MERGE to "einfädeln",
                ManeuverKind.FORK to "an der Gabelung halten",
                ManeuverKind.RAMP_LEFT to "die Ausfahrt links nehmen",
                ManeuverKind.RAMP_RIGHT to "die Ausfahrt rechts nehmen",
                ManeuverKind.ARRIVE to "ankommen",
            ),
            roundabout = { e -> if (e == null) "in den Kreisverkehr fahren" else "im Kreisverkehr die $e. Ausfahrt nehmen" },
            inDist = "In {dist} {dir}",
            continueFor = "{dist} weiterfahren, dann {dir}",
            now = "Jetzt {dir}",
            arrive = "Sie haben Ihr Ziel erreicht",
            reroute = "Route wird neu berechnet",
            onto = " auf {street}",
            units = mapOf(DistUnit.M to "Metern", DistUnit.KM to "Kilometern", DistUnit.FT to "Fuß", DistUnit.MI to "Meilen"),
        ),
        "fr" to Lang(
            dirs = mapOf(
                ManeuverKind.DEPART to "partez",
                ManeuverKind.STRAIGHT to "continuez tout droit",
                ManeuverKind.SLIGHT_LEFT to "serrez à gauche",
                ManeuverKind.LEFT to "tournez à gauche",
                ManeuverKind.SHARP_LEFT to "tournez franchement à gauche",
                ManeuverKind.SLIGHT_RIGHT to "serrez à droite",
                ManeuverKind.RIGHT to "tournez à droite",
                ManeuverKind.SHARP_RIGHT to "tournez franchement à droite",
                ManeuverKind.UTURN to "faites demi-tour",
                ManeuverKind.MERGE to "insérez-vous",
                ManeuverKind.FORK to "restez sur la bifurcation",
                ManeuverKind.RAMP_LEFT to "prenez la bretelle à gauche",
                ManeuverKind.RAMP_RIGHT to "prenez la bretelle à droite",
                ManeuverKind.ARRIVE to "arrivez",
            ),
            roundabout = { e ->
                if (e == null) "prenez le rond-point" else "au rond-point, prenez la ${if (e == 1) "1re" else "${e}e"} sortie"
            },
            inDist = "Dans {dist}, {dir}",
            continueFor = "Continuez sur {dist}, puis {dir}",
            now = "{dir} maintenant",
            arrive = "Vous êtes arrivé à destination",
            reroute = "Recalcul de l'itinéraire",
            onto = " sur {street}",
            units = mapOf(DistUnit.M to "mètres", DistUnit.KM to "kilomètres", DistUnit.FT to "pieds", DistUnit.MI to "miles"),
        ),
        "es" to Lang(
            dirs = mapOf(
                ManeuverKind.DEPART to "sal",
                ManeuverKind.STRAIGHT to "sigue recto",
                ManeuverKind.SLIGHT_LEFT to "mantente a la izquierda",
                ManeuverKind.LEFT to "gira a la izquierda",
                ManeuverKind.SHARP_LEFT to "gira bruscamente a la izquierda",
                ManeuverKind.SLIGHT_RIGHT to "mantente a la derecha",
                ManeuverKind.RIGHT to "gira a la derecha",
                ManeuverKind.SHARP_RIGHT to "gira bruscamente a la derecha",
                ManeuverKind.UTURN to "cambia de sentido",
                ManeuverKind.MERGE to "incorpórate",
                ManeuverKind.FORK to "mantente en la bifurcación",
                ManeuverKind.RAMP_LEFT to "toma la salida a la izquierda",
                ManeuverKind.RAMP_RIGHT to "toma la salida a la derecha",
                ManeuverKind.ARRIVE to "llega",
            ),
            roundabout = { e -> if (e == null) "entra en la rotonda" else "en la rotonda, toma la salida $e" },
            inDist = "En {dist}, {dir}",
            continueFor = "Continúa {dist} y luego {dir}",
            now = "{dir} ahora",
            arrive = "Has llegado a tu destino",
            reroute = "Recalculando la ruta",
            onto = " hacia {street}",
            units = mapOf(DistUnit.M to "metros", DistUnit.KM to "kilómetros", DistUnit.FT to "pies", DistUnit.MI to "millas"),
        ),
        "it" to Lang(
            dirs = mapOf(
                ManeuverKind.DEPART to "parti",
                ManeuverKind.STRAIGHT to "prosegui dritto",
                ManeuverKind.SLIGHT_LEFT to "tieni la sinistra",
                ManeuverKind.LEFT to "svolta a sinistra",
                ManeuverKind.SHARP_LEFT to "svolta decisamente a sinistra",
                ManeuverKind.SLIGHT_RIGHT to "tieni la destra",
                ManeuverKind.RIGHT to "svolta a destra",
                ManeuverKind.SHARP_RIGHT to "svolta decisamente a destra",
                ManeuverKind.UTURN to "fai inversione",
                ManeuverKind.MERGE to "immettiti",
                ManeuverKind.FORK to "tieniti al bivio",
                ManeuverKind.RAMP_LEFT to "prendi la rampa a sinistra",
                ManeuverKind.RAMP_RIGHT to "prendi la rampa a destra",
                ManeuverKind.ARRIVE to "arriva",
            ),
            roundabout = { e -> if (e == null) "entra nella rotonda" else "alla rotonda, prendi la uscita numero $e" },
            inDist = "Tra {dist}, {dir}",
            continueFor = "Prosegui per {dist}, poi {dir}",
            now = "Ora {dir}",
            arrive = "Sei arrivato a destinazione",
            reroute = "Ricalcolo del percorso",
            onto = " su {street}",
            units = mapOf(DistUnit.M to "metri", DistUnit.KM to "chilometri", DistUnit.FT to "piedi", DistUnit.MI to "miglia"),
        ),
        "tr" to Lang(
            dirs = mapOf(
                ManeuverKind.DEPART to "yola çıkın",
                ManeuverKind.STRAIGHT to "düz devam edin",
                ManeuverKind.SLIGHT_LEFT to "hafif sola yönelin",
                ManeuverKind.LEFT to "sola dönün",
                ManeuverKind.SHARP_LEFT to "keskin sola dönün",
                ManeuverKind.SLIGHT_RIGHT to "hafif sağa yönelin",
                ManeuverKind.RIGHT to "sağa dönün",
                ManeuverKind.SHARP_RIGHT to "keskin sağa dönün",
                ManeuverKind.UTURN to "U dönüşü yapın",
                ManeuverKind.MERGE to "yola katılın",
                ManeuverKind.FORK to "yol ayrımında devam edin",
                ManeuverKind.RAMP_LEFT to "soldaki rampayı kullanın",
                ManeuverKind.RAMP_RIGHT to "sağdaki rampayı kullanın",
                ManeuverKind.ARRIVE to "varın",
            ),
            roundabout = { e -> if (e == null) "döner kavşağa girin" else "döner kavşaktan $e. çıkışı kullanın" },
            inDist = "{dist} sonra {dir}",
            continueFor = "{dist} devam edin, ardından {dir}",
            now = "Şimdi {dir}",
            arrive = "Varış noktanıza ulaştınız",
            reroute = "Rota yeniden hesaplanıyor",
            onto = ", {street} yönüne",
            units = mapOf(DistUnit.M to "metre", DistUnit.KM to "kilometre", DistUnit.FT to "fit", DistUnit.MI to "mil"),
        ),
    )

    val supportedLanguages: Set<String> get() = langs.keys

    private fun lang(code: String?): Lang = langs[code?.lowercase(Locale.ROOT)?.take(2)] ?: langs.getValue("en")

    private fun capitalize(s: String): String =
        if (s.isEmpty()) s else s.substring(0, 1).uppercase(Locale.ROOT) + s.substring(1)

    /** Spoken direction for [step], e.g. "turn left" / "at the roundabout, take the second exit". */
    fun direction(step: RouteStep, langCode: String?): String {
        val l = lang(langCode)
        return if (step.kind == ManeuverKind.ROUNDABOUT) l.roundabout(step.roundaboutExit)
        else l.dirs[step.kind] ?: l.dirs.getValue(ManeuverKind.STRAIGHT)
    }

    /** Spoken distance, e.g. "300 meters". Decimal separator stays '.', which TTS engines read fine. */
    fun spokenDistance(meters: Double, imperial: Boolean, langCode: String?): String {
        val d = Units.format(meters, imperial)
        return "${d.text} ${lang(langCode).units[d.unit] ?: d.unit.code}"
    }

    /** The sentence spoken for [cue]. */
    fun phraseFor(cue: VoiceCue, imperial: Boolean, langCode: String?): String {
        val l = lang(langCode)
        if (cue.stage == CueStage.ARRIVE) return l.arrive
        var dir = direction(cue.step, langCode)
        if (cue.step.streetName.isNotEmpty() && cue.stage != CueStage.PREPARE) {
            dir += l.onto.replace("{street}", cue.step.streetName)
        }
        val template = when (cue.stage) {
            CueStage.PREPARE -> l.continueFor
            CueStage.APPROACH -> l.inDist
            CueStage.NOW -> l.now
            CueStage.ARRIVE -> l.arrive
        }
        val dist = spokenDistance(cue.distanceM, imperial, langCode)
        return capitalize(template.replace("{dir}", dir).replace("{dist}", dist))
    }

    fun reroute(langCode: String?): String = lang(langCode).reroute

    /** Short sample for the voice test button. */
    fun sample(imperial: Boolean, langCode: String?): String {
        val l = lang(langCode)
        val dist = spokenDistance(if (imperial) 0.25 * 1609.344 else 300.0, imperial, langCode)
        return capitalize(l.inDist.replace("{dist}", dist).replace("{dir}", l.dirs.getValue(ManeuverKind.LEFT)))
    }
}
