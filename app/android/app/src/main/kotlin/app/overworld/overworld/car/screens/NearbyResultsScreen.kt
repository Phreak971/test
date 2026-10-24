package app.overworld.overworld.car.screens

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.constraints.ConstraintManager
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.PlaceListNavigationTemplate
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import app.overworld.overworld.R
import app.overworld.overworld.car.CarPlace
import app.overworld.overworld.car.GeoPoint
import app.overworld.overworld.car.LocationTracker
import app.overworld.overworld.car.OverworldSession
import java.util.concurrent.Future

/** Nominatim results for one amenity around the current location, nearest first. */
class NearbyResultsScreen(
    carContext: CarContext,
    private val session: OverworldSession,
    private val amenity: String,
    private val title: String,
) : Screen(carContext) {
    private var results: List<CarPlace>? = null
    private var center: GeoPoint? = null
    private var failed = false
    private var call: Future<*>? = null
    private val fixListener = LocationTracker.Listener { fix, _ ->
        if (center == null && call == null) load(fix.position)
    }

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onCreate(owner: LifecycleOwner) {
                val here = session.location.lastPoint
                if (here != null) load(here) else session.location.addListener(fixListener)
            }

            override fun onDestroy(owner: LifecycleOwner) {
                session.location.removeListener(fixListener)
                call?.cancel(true)
            }
        })
    }

    private fun load(at: GeoPoint) {
        session.location.removeListener(fixListener)
        center = at
        failed = false
        results = null
        call = session.services.nearby(amenity, at) { r ->
            call = null
            r.onSuccess { results = it }.onFailure { failed = true }
            invalidate()
        }
        invalidate()
    }

    override fun onGetTemplate(): Template {
        val ui = session.ui
        if (failed) {
            return MessageTemplate.Builder(ui.s(R.string.car_nearby_failed))
                .setTitle(title)
                .setHeaderAction(Action.BACK)
                .addAction(
                    Action.Builder()
                        .setTitle(ui.s(R.string.car_retry))
                        .setOnClickListener { (session.location.lastPoint ?: center)?.let { load(it) } }
                        .build(),
                )
                .build()
        }
        val b = PlaceListNavigationTemplate.Builder()
            .setTitle(title)
            .setHeaderAction(Action.BACK)
        val list = results
        val from = center
        if (list == null || from == null) {
            b.setLoading(true)
            return b.build()
        }
        val items = ItemList.Builder()
        val limit = PlaceRows.listLimit(carContext, ConstraintManager.CONTENT_LIMIT_TYPE_PLACE_LIST)
        for (p in list.take(limit)) {
            items.addItem(PlaceRows.row(session, p, from = from, marker = true) { session.openDestination(p) })
        }
        if (list.isEmpty()) items.setNoItemsMessage(ui.s(R.string.car_no_results))
        b.setItemList(items.build())
        return b.build()
    }
}
