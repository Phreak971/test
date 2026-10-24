package app.overworld.overworld.car.screens

import android.Manifest
import android.util.Log
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.ParkedOnlyOnClickListener
import androidx.car.app.model.Template
import app.overworld.overworld.R
import app.overworld.overworld.car.OverworldSession

/** Asks for location permission (the grant dialog opens on the phone). */
class PermissionScreen(carContext: CarContext, private val session: OverworldSession) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val ui = session.ui
        val grant = Action.Builder()
            .setTitle(ui.s(R.string.car_grant))
            .setOnClickListener(
                ParkedOnlyOnClickListener.create {
                    try {
                        carContext.requestPermissions(
                            listOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                        ) { granted, _ ->
                            if (granted.isNotEmpty()) {
                                session.location.start()
                                screenManager.pop()
                            } else {
                                invalidate()
                            }
                        }
                    } catch (t: Throwable) {
                        Log.w("OverworldCar", "permission request failed", t)
                    }
                },
            )
            .build()
        return MessageTemplate.Builder(ui.s(R.string.car_location_needed))
            .setTitle(ui.s(R.string.car_app_name))
            .setHeaderAction(Action.APP_ICON)
            .addAction(grant)
            .build()
    }
}
