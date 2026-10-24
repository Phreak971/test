package app.overworld.overworld.car.screens

import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.SearchTemplate
import androidx.car.app.model.Template
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import app.overworld.overworld.R
import app.overworld.overworld.car.CarPlace
import app.overworld.overworld.car.CarStore
import app.overworld.overworld.car.OverworldSession
import java.util.concurrent.Future

/** Photon autocomplete. With an empty query it suggests recent destinations and saved places. */
class SearchScreen(
    carContext: CarContext,
    private val session: OverworldSession,
    private val initialQuery: String? = null,
) : Screen(carContext) {
    private val main = Handler(Looper.getMainLooper())
    private var query: String = initialQuery.orEmpty()
    private var results: List<CarPlace>? = null
    private var loading = false
    private var failed = false
    private var call: Future<*>? = null
    private var generation = 0

    init {
        lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onCreate(owner: LifecycleOwner) {
                if (query.isNotBlank()) runSearch(query)
            }

            override fun onDestroy(owner: LifecycleOwner) {
                main.removeCallbacksAndMessages(null)
                call?.cancel(true)
            }
        })
    }

    private fun schedule(text: String, immediate: Boolean) {
        query = text
        main.removeCallbacksAndMessages(null)
        call?.cancel(true)
        if (text.isBlank()) {
            results = null
            loading = false
            failed = false
            invalidate()
            return
        }
        if (immediate) runSearch(text) else main.postDelayed({ runSearch(text) }, 400)
    }

    private fun runSearch(text: String) {
        val gen = ++generation
        loading = true
        failed = false
        invalidate()
        call = session.services.search(text.trim(), session.location.lastPoint, CarStore.snapshot.locale) { r ->
            if (gen != generation) return@search
            loading = false
            r.onSuccess { results = it }.onFailure { results = emptyList(); failed = true }
            invalidate()
        }
    }

    override fun onGetTemplate(): Template {
        val ui = session.ui
        val b = SearchTemplate.Builder(object : SearchTemplate.SearchCallback {
            override fun onSearchTextChanged(searchText: String) = schedule(searchText, immediate = false)
            override fun onSearchSubmitted(searchText: String) = schedule(searchText, immediate = true)
        })
            .setHeaderAction(Action.BACK)
            .setSearchHint(ui.s(R.string.car_search_hint))
            .setShowKeyboardByDefault(initialQuery.isNullOrBlank())
        if (query.isNotEmpty()) b.setInitialSearchText(query)

        if (loading) {
            b.setLoading(true)
            return b.build()
        }
        val limit = PlaceRows.listLimit(carContext)
        val list = ItemList.Builder()
        val shown: List<CarPlace> = results ?: suggestions()
        for (p in shown.take(limit)) {
            list.addItem(PlaceRows.row(session, p, from = null) { session.openDestination(p) })
        }
        if (shown.isEmpty() && results != null) {
            list.setNoItemsMessage(ui.s(if (failed) R.string.car_search_failed else R.string.car_no_results))
        }
        b.setItemList(list.build())
        return b.build()
    }

    private fun suggestions(): List<CarPlace> {
        val snap = CarStore.snapshot
        val seen = HashSet<String>()
        return (snap.history + snap.places.sortedByDescending { it.isHome })
            .filter { seen.add("${it.name}|${"%.4f".format(java.util.Locale.US, it.lat)}|${"%.4f".format(java.util.Locale.US, it.lng)}") }
    }
}
