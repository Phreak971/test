package app.overworld.overworld.car.screens

import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ActionStrip
import androidx.car.app.model.Template
import androidx.car.app.navigation.model.MessageInfo
import androidx.car.app.navigation.model.NavigationTemplate
import androidx.car.app.navigation.model.RoutingInfo
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import app.overworld.overworld.R
import app.overworld.overworld.car.CarStore
import app.overworld.overworld.car.OverworldSession

/**
 * Root screen: the map with free-drive actions (Search, Saved, Nearby, Voice)
 * or, while guiding, the maneuver card, ETA and End/Mute actions.
 */
class MainNavScreen(carContext: CarContext, private val session: OverworldSession) : Screen(carContext) {
    private var panMode = false

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onCreate(owner: LifecycleOwner) {
                session.navigator.onChanged = { refresh() }
                session.renderer.onFollowingChanged = { refresh() }
            }

            override fun onDestroy(owner: LifecycleOwner) {
                session.navigator.onChanged = null
            }
        })
    }

    private fun refresh() {
        if (lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) invalidate()
    }

    override fun onGetTemplate(): Template {
        val ui = session.ui
        val nav = session.navigator
        val snap = CarStore.snapshot
        val b = NavigationTemplate.Builder()

        val actions = ActionStrip.Builder()
        if (nav.active) {
            actions.addAction(
                Action.Builder()
                    .setTitle(ui.s(R.string.car_end))
                    .setIcon(ui.icon(R.drawable.ic_car_close))
                    .setOnClickListener { nav.stop() }
                    .build(),
            )
            actions.addAction(muteAction())
            actions.addAction(searchAction())
            actions.addAction(nearbyAction())
        } else {
            actions.addAction(searchAction())
            actions.addAction(
                Action.Builder()
                    .setTitle(ui.s(R.string.car_saved))
                    .setIcon(ui.icon(R.drawable.ic_car_star))
                    .setOnClickListener { screenManager.push(SavedScreen(carContext, session)) }
                    .build(),
            )
            actions.addAction(nearbyAction())
            actions.addAction(
                Action.Builder()
                    .setTitle(ui.s(R.string.car_voice))
                    .setIcon(ui.icon(if (snap.muted) R.drawable.ic_car_volume_off else R.drawable.ic_car_voice))
                    .setOnClickListener { screenManager.push(VoiceScreen(carContext, session)) }
                    .build(),
            )
        }
        b.setActionStrip(actions.build())

        val map = ActionStrip.Builder().addAction(Action.PAN)
        map.addAction(
            Action.Builder().setIcon(ui.icon(R.drawable.ic_car_zoom_in)).setOnClickListener { session.renderer.zoomBy(1.0) }.build(),
        )
        map.addAction(
            Action.Builder().setIcon(ui.icon(R.drawable.ic_car_zoom_out)).setOnClickListener { session.renderer.zoomBy(-1.0) }.build(),
        )
        if (!session.renderer.following || panMode) {
            map.addAction(
                Action.Builder().setIcon(ui.icon(R.drawable.ic_car_recenter)).setOnClickListener { session.renderer.recenter() }.build(),
            )
        }
        b.setMapActionStrip(map.build())
        b.setPanModeListener { isInPanMode ->
            panMode = isInPanMode
            refresh()
        }

        when {
            nav.arrived -> {
                val dest = nav.destination
                val info = MessageInfo.Builder(ui.s(R.string.car_arrived)).setImage(ui.icon(R.drawable.ic_turn_arrive, tint = false))
                if (dest != null) info.setText(dest.name)
                b.setNavigationInfo(info.build())
            }
            nav.active -> {
                val p = nav.progress
                val next = p?.nextStep
                if (p == null || next == null || nav.rerouting) {
                    b.setNavigationInfo(RoutingInfo.Builder().setLoading(true).build())
                } else {
                    val routing = RoutingInfo.Builder().setCurrentStep(nav.carStep(next), ui.distance(p.distanceToNextM))
                    p.followingStep?.let { routing.setNextStep(nav.carStep(it)) }
                    b.setNavigationInfo(routing.build())
                    b.setDestinationTravelEstimate(ui.travelEstimate(p.remainingM, p.remainingS))
                }
            }
            !session.location.hasPermission() -> {
                b.setNavigationInfo(MessageInfo.Builder(ui.s(R.string.car_location_needed)).build())
            }
            !snap.synced -> {
                b.setNavigationInfo(MessageInfo.Builder(ui.s(R.string.car_setup_phone)).build())
            }
        }
        return b.build()
    }

    private fun muteAction(): Action {
        val ui = session.ui
        val muted = CarStore.snapshot.muted
        return Action.Builder()
            .setIcon(ui.icon(if (muted) R.drawable.ic_car_volume_off else R.drawable.ic_car_voice))
            .setOnClickListener {
                val nowMuted = !CarStore.snapshot.muted
                CarStore.setMuted(nowMuted)
                if (nowMuted) session.voice.stop()
                CarToast.makeText(carContext, ui.s(if (nowMuted) R.string.car_muted else R.string.car_unmuted), CarToast.LENGTH_SHORT).show()
            }
            .build()
    }

    private fun searchAction(): Action = Action.Builder()
        .setTitle(session.ui.s(R.string.car_search))
        .setIcon(session.ui.icon(R.drawable.ic_car_search))
        .setOnClickListener { screenManager.push(SearchScreen(carContext, session)) }
        .build()

    private fun nearbyAction(): Action = Action.Builder()
        .setTitle(session.ui.s(R.string.car_nearby))
        .setIcon(session.ui.icon(R.drawable.ic_car_place))
        .setOnClickListener { screenManager.push(NearbyScreen(carContext, session)) }
        .build()
}
