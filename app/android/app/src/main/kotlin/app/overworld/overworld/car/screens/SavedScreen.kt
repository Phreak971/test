package app.overworld.overworld.car.screens

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.SectionedItemList
import androidx.car.app.model.Template
import app.overworld.overworld.R
import app.overworld.overworld.car.CarStore
import app.overworld.overworld.car.OverworldSession

/** Saved places (Home first) and recent destinations, synced from the phone. */
class SavedScreen(carContext: CarContext, private val session: OverworldSession) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val ui = session.ui
        val snap = CarStore.snapshot
        val limit = PlaceRows.listLimit(carContext)
        val saved = snap.places.sortedByDescending { it.isHome }
        val recent = snap.history
        val b = ListTemplate.Builder()
            .setTitle(ui.s(R.string.car_saved_title))
            .setHeaderAction(Action.BACK)

        if (saved.isEmpty() && recent.isEmpty()) {
            b.setSingleList(ItemList.Builder().setNoItemsMessage(ui.s(R.string.car_no_saved)).build())
            return b.build()
        }
        // Hosts cap the total number of rows; give saved places priority.
        val savedCount = minOf(saved.size, limit)
        val recentCount = minOf(recent.size, (limit - savedCount).coerceAtLeast(0))
        if (savedCount > 0 && recentCount == 0) {
            val list = ItemList.Builder()
            saved.take(savedCount).forEach { p ->
                list.addItem(PlaceRows.row(session, p, from = null, homeIcon = true) { session.openDestination(p) })
            }
            b.setSingleList(list.build())
            return b.build()
        }
        if (savedCount > 0) {
            val list = ItemList.Builder()
            saved.take(savedCount).forEach { p ->
                list.addItem(PlaceRows.row(session, p, from = null, homeIcon = true) { session.openDestination(p) })
            }
            b.addSectionedList(SectionedItemList.create(list.build(), ui.s(R.string.car_saved_title)))
        }
        if (recentCount > 0) {
            val list = ItemList.Builder()
            recent.take(recentCount).forEach { p ->
                list.addItem(PlaceRows.row(session, p, from = null) { session.openDestination(p) })
            }
            b.addSectionedList(SectionedItemList.create(list.build(), ui.s(R.string.car_recent)))
        }
        return b.build()
    }
}
