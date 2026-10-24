package app.overworld.overworld.car

import android.content.pm.ApplicationInfo
import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

/** Entry point for Android Auto (declared in AndroidManifest.xml with the NAVIGATION category). */
class OverworldCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        val debuggable = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
        return if (debuggable) {
            // Debug builds: allow any host (Desktop Head Unit, emulators, test hosts).
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            // Release: only Google's Android Auto / Automotive hosts, using the signature
            // allowlist shipped with androidx.car.app. Hardening option: copy that list into
            // res/values/ and pin the exact hosts you support.
            HostValidator.Builder(applicationContext)
                .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                .build()
        }
    }

    override fun onCreateSession(): Session = OverworldSession()
}
