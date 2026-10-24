package app.overworld.overworld.car.screens

import androidx.car.app.CarContext
import androidx.car.app.constraints.ConstraintManager
import androidx.car.app.model.CarLocation
import androidx.car.app.model.Metadata
import androidx.car.app.model.Place
import androidx.car.app.model.PlaceMarker
import androidx.car.app.model.Row
import app.overworld.overworld.R
import app.overworld.overworld.car.CarPlace
import app.overworld.overworld.car.Geo
import app.overworld.overworld.car.GeoPoint
import app.overworld.overworld.car.OverworldSession

internal object PlaceRows {
    /** Host list item limit (falls back to 6 on hosts without the constraint API). */
    fun listLimit(carContext: CarContext, type: Int = ConstraintManager.CONTENT_LIMIT_TYPE_LIST): Int = try {
        carContext.getCarService(ConstraintManager::class.java).getContentLimit(type)
    } catch (t: Throwable) {
        6
    }

    /**
     * A clickable row for [place]. With [from], the distance is shown via a
     * DistanceSpan (required by place-list templates) and a map marker is set
     * when [marker] is true.
     */
    fun row(
        session: OverworldSession,
        place: CarPlace,
        from: GeoPoint?,
        marker: Boolean = false,
        homeIcon: Boolean = false,
        onClick: () -> Unit,
    ): Row {
        val ui = session.ui
        val b = Row.Builder().setTitle(place.name.ifBlank { " " }).setOnClickListener(onClick)
        if (from != null) {
            b.addText(ui.distanceText(Geo.distanceM(from, place.point), place.address))
        } else if (!place.address.isNullOrBlank()) {
            b.addText(place.address)
        }
        if (marker) {
            b.setMetadata(
                Metadata.Builder()
                    .setPlace(Place.Builder(CarLocation.create(place.lat, place.lng)).setMarker(PlaceMarker.Builder().build()).build())
                    .build(),
            )
        } else if (homeIcon) {
            b.setImage(ui.icon(if (place.isHome) R.drawable.ic_car_home else R.drawable.ic_car_star))
        }
        return b.build()
    }
}
