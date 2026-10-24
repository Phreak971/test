package app.overworld.overworld.car

import android.content.Context
import android.content.res.Configuration
import android.text.SpannableString
import android.text.Spanned
import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import androidx.car.app.CarContext
import androidx.car.app.model.CarColor
import androidx.car.app.model.CarIcon
import androidx.car.app.model.DateTimeWithZone
import androidx.car.app.model.Distance
import androidx.car.app.model.DistanceSpan
import androidx.car.app.navigation.model.Maneuver
import androidx.car.app.navigation.model.TravelEstimate
import androidx.core.graphics.drawable.IconCompat
import app.overworld.overworld.R
import java.util.Locale
import java.util.TimeZone

/**
 * Car UI helpers: strings localized to the synced app locale, icons, unit
 * conversion, and OSRM → [Maneuver] mapping.
 */
class CarUi(private val carContext: CarContext) {
    private var localeCode: String? = null
    private var localized: Context = carContext

    /** Resources for the synced phone locale (falls back to the car/device locale). */
    private fun ctx(): Context {
        val code = CarStore.snapshot.locale.take(2).lowercase(Locale.ROOT)
        if (code != localeCode) {
            localeCode = code
            localized = try {
                val config = Configuration(carContext.resources.configuration)
                config.setLocale(Locale.forLanguageTag(code))
                carContext.createConfigurationContext(config)
            } catch (t: Throwable) {
                carContext
            }
        }
        return localized
    }

    fun s(@StringRes id: Int): String = ctx().getString(id)
    fun s(@StringRes id: Int, vararg args: Any): String = ctx().getString(id, *args)

    fun icon(@DrawableRes id: Int, tint: Boolean = true): CarIcon {
        val b = CarIcon.Builder(IconCompat.createWithResource(carContext, id))
        if (tint) b.setTint(CarColor.DEFAULT)
        return b.build()
    }

    val imperial: Boolean get() = CarStore.snapshot.imperial

    fun distance(meters: Double): Distance {
        val d = Units.format(meters, imperial)
        val unit = when (d.unit) {
            DistUnit.M -> Distance.UNIT_METERS
            DistUnit.KM -> if (d.value < 10) Distance.UNIT_KILOMETERS_P1 else Distance.UNIT_KILOMETERS
            DistUnit.FT -> Distance.UNIT_FEET
            DistUnit.MI -> if (d.value < 10) Distance.UNIT_MILES_P1 else Distance.UNIT_MILES
        }
        return Distance.create(d.value, unit)
    }

    /** A text with a [DistanceSpan] (required by place-list rows). */
    fun distanceText(meters: Double, suffix: String? = null): CharSequence {
        val base = if (suffix.isNullOrEmpty()) " " else "  · $suffix"
        val s = SpannableString(base)
        s.setSpan(DistanceSpan.create(distance(meters)), 0, 1, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
        return s
    }

    fun travelEstimate(remainingM: Double, remainingS: Double): TravelEstimate {
        val secs = remainingS.coerceAtLeast(0.0).toLong()
        val arrival = DateTimeWithZone.create(System.currentTimeMillis() + secs * 1000, TimeZone.getDefault())
        return TravelEstimate.Builder(distance(remainingM), arrival)
            .setRemainingTimeSeconds(secs)
            .build()
    }

    /** OSRM step → car [Maneuver] with icon. */
    fun maneuver(step: RouteStep): Maneuver {
        val left = step.drivingSide == "left"
        val mod = step.osrmModifier
        val (type, iconRes) = when (step.osrmType) {
            "depart" -> Maneuver.TYPE_DEPART to R.drawable.ic_turn_depart
            "arrive" -> when (mod) {
                "left", "slight left", "sharp left" -> Maneuver.TYPE_DESTINATION_LEFT
                "right", "slight right", "sharp right" -> Maneuver.TYPE_DESTINATION_RIGHT
                "straight" -> Maneuver.TYPE_DESTINATION_STRAIGHT
                else -> Maneuver.TYPE_DESTINATION
            } to R.drawable.ic_turn_arrive
            "roundabout", "rotary" -> {
                val exit = step.roundaboutExit
                if (exit != null && exit >= 1) {
                    (if (left) Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CW else Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CCW) to R.drawable.ic_turn_roundabout
                } else {
                    (if (left) Maneuver.TYPE_ROUNDABOUT_ENTER_CW else Maneuver.TYPE_ROUNDABOUT_ENTER_CCW) to R.drawable.ic_turn_roundabout
                }
            }
            "exit roundabout", "exit rotary" ->
                (if (left) Maneuver.TYPE_ROUNDABOUT_EXIT_CW else Maneuver.TYPE_ROUNDABOUT_EXIT_CCW) to R.drawable.ic_turn_roundabout
            "merge" -> when {
                mod?.contains("left") == true -> Maneuver.TYPE_MERGE_LEFT
                mod?.contains("right") == true -> Maneuver.TYPE_MERGE_RIGHT
                else -> Maneuver.TYPE_MERGE_SIDE_UNSPECIFIED
            } to R.drawable.ic_turn_merge
            "fork" -> if (mod?.contains("left") == true) Maneuver.TYPE_FORK_LEFT to R.drawable.ic_turn_fork_left
            else Maneuver.TYPE_FORK_RIGHT to R.drawable.ic_turn_fork_right
            "on ramp" -> when (mod) {
                "slight left" -> Maneuver.TYPE_ON_RAMP_SLIGHT_LEFT to R.drawable.ic_turn_slight_left
                "left" -> Maneuver.TYPE_ON_RAMP_NORMAL_LEFT to R.drawable.ic_turn_left
                "sharp left" -> Maneuver.TYPE_ON_RAMP_SHARP_LEFT to R.drawable.ic_turn_sharp_left
                "slight right" -> Maneuver.TYPE_ON_RAMP_SLIGHT_RIGHT to R.drawable.ic_turn_slight_right
                "right" -> Maneuver.TYPE_ON_RAMP_NORMAL_RIGHT to R.drawable.ic_turn_right
                "sharp right" -> Maneuver.TYPE_ON_RAMP_SHARP_RIGHT to R.drawable.ic_turn_sharp_right
                "uturn" -> (if (left) Maneuver.TYPE_ON_RAMP_U_TURN_RIGHT else Maneuver.TYPE_ON_RAMP_U_TURN_LEFT) to
                    (if (left) R.drawable.ic_turn_uturn_right else R.drawable.ic_turn_uturn_left)
                else -> Maneuver.TYPE_STRAIGHT to R.drawable.ic_turn_straight
            }
            "off ramp" -> when {
                mod == "slight left" -> Maneuver.TYPE_OFF_RAMP_SLIGHT_LEFT to R.drawable.ic_turn_slight_left
                mod?.contains("left") == true -> Maneuver.TYPE_OFF_RAMP_NORMAL_LEFT to R.drawable.ic_turn_left
                mod == "slight right" -> Maneuver.TYPE_OFF_RAMP_SLIGHT_RIGHT to R.drawable.ic_turn_slight_right
                mod?.contains("right") == true -> Maneuver.TYPE_OFF_RAMP_NORMAL_RIGHT to R.drawable.ic_turn_right
                else -> Maneuver.TYPE_STRAIGHT to R.drawable.ic_turn_straight
            }
            else -> when (mod) {
                // turn, new name, continue, end of road, notification, roundabout turn, ...
                "uturn" -> if (left) Maneuver.TYPE_U_TURN_RIGHT to R.drawable.ic_turn_uturn_right
                else Maneuver.TYPE_U_TURN_LEFT to R.drawable.ic_turn_uturn_left
                "sharp right" -> Maneuver.TYPE_TURN_SHARP_RIGHT to R.drawable.ic_turn_sharp_right
                "right" -> Maneuver.TYPE_TURN_NORMAL_RIGHT to R.drawable.ic_turn_right
                "slight right" -> (if (step.osrmType == "continue") Maneuver.TYPE_KEEP_RIGHT else Maneuver.TYPE_TURN_SLIGHT_RIGHT) to
                    R.drawable.ic_turn_slight_right
                "sharp left" -> Maneuver.TYPE_TURN_SHARP_LEFT to R.drawable.ic_turn_sharp_left
                "left" -> Maneuver.TYPE_TURN_NORMAL_LEFT to R.drawable.ic_turn_left
                "slight left" -> (if (step.osrmType == "continue") Maneuver.TYPE_KEEP_LEFT else Maneuver.TYPE_TURN_SLIGHT_LEFT) to
                    R.drawable.ic_turn_slight_left
                else -> (if (step.osrmType == "new name") Maneuver.TYPE_NAME_CHANGE else Maneuver.TYPE_STRAIGHT) to
                    R.drawable.ic_turn_straight
            }
        }
        val b = Maneuver.Builder(type).setIcon(icon(iconRes, tint = false))
        if (type == Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CW || type == Maneuver.TYPE_ROUNDABOUT_ENTER_AND_EXIT_CCW) {
            b.setRoundaboutExitNumber(step.roundaboutExit ?: 1)
        }
        return b.build()
    }

    /** Short on-screen cue for a step, e.g. "Turn left onto Main St" → we show the localized direction. */
    fun cue(step: RouteStep): String {
        val dir = Phrases.direction(step, CarStore.snapshot.locale)
        return dir.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString() }
    }
}
