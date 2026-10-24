package app.overworld.overworld.car.screens

import android.location.Location
import android.os.Handler
import android.os.Looper
import android.text.SpannableString
import android.text.Spanned
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.DurationSpan
import androidx.car.app.model.ItemList
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.RoutePreviewNavigationTemplate
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import app.overworld.overworld.R
import app.overworld.overworld.car.CarPlace
import app.overworld.overworld.car.Fix
import app.overworld.overworld.car.GeoPoint
import app.overworld.overworld.car.LocationTracker
import app.overworld.overworld.car.NoRouteException
import app.overworld.overworld.car.OverworldSession
import app.overworld.overworld.car.Route
import java.util.concurrent.Future

/** OSRM route to [place] with ETA; "Go" starts guidance. */
class RoutePreviewScreen(
    carContext: CarContext,
    private val session: OverworldSession,
    private val place: CarPlace,
) : Screen(carContext) {
    private val main = Handler(Looper.getMainLooper())
    private var route: Route? = null
    private var error: Int? = null
    private var call: Future<*>? = null
    private var started = false
    private var waitingForFix = false

    private val fixListener = object : LocationTracker.Listener {
        override fun onFix(fix: Fix, raw: Location) {
            if (!waitingForFix) return
            waitingForFix = false
            session.location.removeListener(this)
            main.removeCallbacksAndMessages(null)
            request(fix.position)
        }
    }

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onCreate(owner: LifecycleOwner) = load()

            override fun onDestroy(owner: LifecycleOwner) {
                main.removeCallbacksAndMessages(null)
                session.location.removeListener(fixListener)
                call?.cancel(true)
                if (!started) session.restoreMap()
            }
        })
    }

    private fun load() {
        error = null
        route = null
        val here = session.location.lastPoint
        if (here != null) {
            request(here)
        } else {
            // Wait up to 15 s for a first fix.
            waitingForFix = true
            session.location.start()
            session.location.addListener(fixListener)
            main.postDelayed({
                if (waitingForFix) {
                    waitingForFix = false
                    session.location.removeListener(fixListener)
                    error = R.string.car_waiting_location
                    invalidate()
                }
            }, 15_000)
        }
        invalidate()
    }

    private fun request(from: GeoPoint) {
        call?.cancel(true)
        call = session.services.route(from, place.point, null) { r ->
            call = null
            r.onSuccess { rt ->
                route = rt
                session.renderer.setRoute(rt.geometry, place)
                session.renderer.showOverview(rt.geometry)
            }.onFailure { t ->
                error = if (t is NoRouteException) R.string.car_route_failed else R.string.car_route_error
            }
            invalidate()
        }
    }

    override fun onGetTemplate(): Template {
        val ui = session.ui
        val title = ui.s(R.string.car_route_title, place.name)
        error?.let { msg ->
            return MessageTemplate.Builder(ui.s(msg))
                .setTitle(title)
                .setHeaderAction(Action.BACK)
                .addAction(Action.Builder().setTitle(ui.s(R.string.car_retry)).setOnClickListener { load() }.build())
                .build()
        }
        val b = RoutePreviewNavigationTemplate.Builder()
            .setTitle(title)
            .setHeaderAction(Action.BACK)
        val r = route
        if (r == null) {
            b.setLoading(true)
            return b.build()
        }
        val duration = SpannableString(" ")
        duration.setSpan(DurationSpan.create(r.durationS.toLong()), 0, 1, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
        val row = Row.Builder()
            .setTitle(duration)
            .addText(ui.distanceText(r.distanceM, place.address ?: ui.s(R.string.car_route_option)))
            .build()
        b.setItemList(
            ItemList.Builder()
                .addItem(row)
                .setSelectedIndex(0)
                .setOnSelectedListener { }
                .build(),
        )
        b.setNavigateAction(
            Action.Builder()
                .setTitle(ui.s(R.string.car_navigate))
                .setIcon(ui.icon(R.drawable.ic_car_navigation))
                .setOnClickListener {
                    started = true
                    session.startNavigation(r, place)
                }
                .build(),
        )
        return b.build()
    }
}
