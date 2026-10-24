package app.overworld.overworld.car.screens

import androidx.annotation.StringRes
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import app.overworld.overworld.R
import app.overworld.overworld.car.OverworldSession

/** Nominatim `amenity` categories offered under "Nearby". */
internal enum class NearbyCategory(val amenity: String, @StringRes val label: Int) {
    RESTAURANT("restaurant", R.string.car_cat_restaurant),
    FAST_FOOD("fast_food", R.string.car_cat_fast_food),
    CAFE("cafe", R.string.car_cat_cafe),
    FUEL("fuel", R.string.car_cat_fuel),
    CHARGING("charging_station", R.string.car_cat_charging_station),
    PARKING("parking", R.string.car_cat_parking),
    HOTEL("hotel", R.string.car_cat_hotel),
    SUPERMARKET("supermarket", R.string.car_cat_supermarket),
    PHARMACY("pharmacy", R.string.car_cat_pharmacy),
    HOSPITAL("hospital", R.string.car_cat_hospital),
    STATION("station", R.string.car_cat_station),
    BANK("bank", R.string.car_cat_bank),
}

/** Category picker; each opens [NearbyResultsScreen]. */
class NearbyScreen(carContext: CarContext, private val session: OverworldSession) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val ui = session.ui
        val list = ItemList.Builder()
        for (c in NearbyCategory.entries.take(PlaceRows.listLimit(carContext))) {
            list.addItem(
                Row.Builder()
                    .setTitle(ui.s(c.label))
                    .setBrowsable(true)
                    .setOnClickListener { screenManager.push(NearbyResultsScreen(carContext, session, c.amenity, ui.s(c.label))) }
                    .build(),
            )
        }
        return ListTemplate.Builder()
            .setTitle(ui.s(R.string.car_nearby_title))
            .setHeaderAction(Action.BACK)
            .setSingleList(list.build())
            .build()
    }
}
