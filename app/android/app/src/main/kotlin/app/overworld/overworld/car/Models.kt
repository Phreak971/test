package app.overworld.overworld.car

/** A destination / search result / saved place. */
data class CarPlace(
    val name: String,
    val lat: Double,
    val lng: Double,
    val address: String? = null,
    val isHome: Boolean = false,
    val id: String? = null,
) {
    val point: GeoPoint get() = GeoPoint(lat, lng)
}

/** Mirrors `ManeuverKind` in lib/data/models.dart. */
enum class ManeuverKind {
    DEPART, ARRIVE, STRAIGHT, SLIGHT_LEFT, LEFT, SHARP_LEFT, SLIGHT_RIGHT, RIGHT, SHARP_RIGHT,
    UTURN, ROUNDABOUT, MERGE, FORK, RAMP_LEFT, RAMP_RIGHT,
}

data class RouteStep(
    val kind: ManeuverKind,
    /** Raw OSRM maneuver type/modifier, used for the more detailed car maneuver icons. */
    val osrmType: String,
    val osrmModifier: String?,
    val location: GeoPoint,
    val distanceM: Double,
    val durationS: Double,
    val streetName: String,
    val roundaboutExit: Int?,
    /** "left" for left-hand traffic, else "right". */
    val drivingSide: String = "right",
)

data class Route(
    val geometry: List<GeoPoint>,
    val distanceM: Double,
    val durationS: Double,
    val steps: List<RouteStep>,
)

object Maneuvers {
    /** OSRM type/modifier → [ManeuverKind]; same mapping as `maneuverKind` in routing_service.dart. */
    fun kindOf(type: String?, modifier: String?): ManeuverKind {
        when (type) {
            "depart" -> return ManeuverKind.DEPART
            "arrive" -> return ManeuverKind.ARRIVE
            "roundabout", "rotary", "roundabout turn", "exit roundabout", "exit rotary" -> return ManeuverKind.ROUNDABOUT
            "merge" -> return ManeuverKind.MERGE
            "fork" -> return when (modifier) {
                "slight left", "left", "sharp left" -> ManeuverKind.SLIGHT_LEFT
                "slight right", "right", "sharp right" -> ManeuverKind.SLIGHT_RIGHT
                else -> ManeuverKind.FORK
            }
            "on ramp", "off ramp" -> {
                if (modifier != null && modifier.contains("left")) return ManeuverKind.RAMP_LEFT
                if (modifier != null && modifier.contains("right")) return ManeuverKind.RAMP_RIGHT
                return ManeuverKind.STRAIGHT
            }
        }
        return when (modifier) {
            "uturn" -> ManeuverKind.UTURN
            "sharp right" -> ManeuverKind.SHARP_RIGHT
            "right" -> ManeuverKind.RIGHT
            "slight right" -> ManeuverKind.SLIGHT_RIGHT
            "sharp left" -> ManeuverKind.SHARP_LEFT
            "left" -> ManeuverKind.LEFT
            "slight left" -> ManeuverKind.SLIGHT_LEFT
            else -> ManeuverKind.STRAIGHT
        }
    }
}
