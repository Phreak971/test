package app.overworld.overworld.car.screens

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.car.app.model.Toggle
import app.overworld.overworld.R
import app.overworld.overworld.car.CarStore
import app.overworld.overworld.car.Phrases
import app.overworld.overworld.car.OverworldSession

/** Voice guidance: mute toggle, current voice (chosen on the phone) and a test phrase. */
class VoiceScreen(carContext: CarContext, private val session: OverworldSession) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val ui = session.ui
        val snap = CarStore.snapshot
        val list = ItemList.Builder()
            .addItem(
                Row.Builder()
                    .setTitle(ui.s(R.string.car_voice_mute))
                    .setToggle(
                        Toggle.Builder { checked ->
                            CarStore.setMuted(checked)
                            if (checked) session.voice.stop()
                            invalidate()
                        }.setChecked(snap.muted).build(),
                    )
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle(ui.s(R.string.car_voice_current, snap.voice.name))
                    .addText(ui.s(R.string.car_voice_change_on_phone))
                    .setImage(ui.icon(R.drawable.ic_car_voice))
                    .build(),
            )
            .addItem(
                Row.Builder()
                    .setTitle(ui.s(R.string.car_voice_test))
                    .setOnClickListener {
                        session.voice.speak(Phrases.sample(snap.imperial, snap.locale), force = true, flush = true)
                    }
                    .build(),
            )
            .build()
        return ListTemplate.Builder()
            .setTitle(ui.s(R.string.car_voice_title))
            .setHeaderAction(Action.BACK)
            .setSingleList(list)
            .build()
    }
}
