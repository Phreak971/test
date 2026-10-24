package app.overworld.overworld.car.screens

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Template
import app.overworld.overworld.R
import app.overworld.overworld.car.OverworldSession

/** Shown instead of route preview/navigation when the phone reports no Pro entitlement. */
class ProGateScreen(carContext: CarContext, private val session: OverworldSession) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val ui = session.ui
        return MessageTemplate.Builder(ui.s(R.string.car_pro_message))
            .setTitle(ui.s(R.string.car_pro_title))
            .setHeaderAction(Action.BACK)
            .setIcon(ui.icon(R.drawable.ic_car_star))
            .addAction(
                Action.Builder()
                    .setTitle(ui.s(R.string.car_ok))
                    .setOnClickListener { screenManager.pop() }
                    .build(),
            )
            .build()
    }
}
