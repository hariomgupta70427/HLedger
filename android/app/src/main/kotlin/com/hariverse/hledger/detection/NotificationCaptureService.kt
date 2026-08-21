package com.hariverse.hledger.detection

import android.app.Notification
import android.content.ComponentName
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Captures bank and UPI transaction alerts, and writes each one to disk the
 * moment it arrives.
 *
 * No Flutter engine is involved. Android starts, stops and rebinds this service
 * on its own schedule and keeps it bound long after the UI is gone, so any
 * capture path that depends on Dart being alive drops every alert that arrives
 * while the app is closed — which is most of them. This is why a real payment
 * went undetected while a promotional one was caught: the app happened to be
 * open for the second and not the first.
 *
 * Everything here therefore uses Android APIs only. Dart reads the queue
 * whenever it next runs, and confirms what it stored.
 */
class NotificationCaptureService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val context = applicationContext ?: return
        val pkg = sbn.packageName ?: return

        // The allowlist is checked before anything is read. This service can see
        // every notification on the device; a message from a friend must never be
        // opened, let alone stored.
        if (!TransactionSources.isTrusted(pkg)) {
            CaptureStore.recordSkip(context, pkg, "not-allowlisted")
            return
        }

        val notification = sbn.notification ?: return
        val flags = notification.flags

        // An ongoing notification is a status that re-posts as it changes, and a
        // group summary only repeats its children. Neither announces new money.
        if (flags and Notification.FLAG_ONGOING_EVENT != 0) {
            CaptureStore.recordSkip(context, pkg, "ongoing")
            return
        }
        if (flags and Notification.FLAG_GROUP_SUMMARY != 0) {
            CaptureStore.recordSkip(context, pkg, "group-summary")
            return
        }

        val extras = notification.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val body = (extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras?.getCharSequence(Notification.EXTRA_TEXT))
            ?.toString()
            .orEmpty()

        if (title.isBlank() && body.isBlank()) {
            CaptureStore.recordSkip(context, pkg, "no-text")
            return
        }

        val stored = CaptureStore.append(
            context,
            Capture(
                // sbn.key is Android's own stable identity for a notification.
                key = sbn.key ?: "$pkg:${sbn.id}:${sbn.postTime}",
                packageName = pkg,
                postedAt = sbn.postTime,
                title = title,
                body = body,
            ),
        )

        // Nudge the UI only if it happens to be running; the queue is the record.
        if (stored) CaptureBridge.notifyCaptured()
    }

    override fun onListenerConnected() {
        Log.i(TAG, "Capture service connected")
    }

    /**
     * Android drops the binding after an app update and does not always restore
     * it. Asking to be rebound is what stops detection silently dying on upgrade.
     */
    override fun onListenerDisconnected() {
        Log.w(TAG, "Capture service disconnected — requesting rebind")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(ComponentName(this, NotificationCaptureService::class.java))
            } catch (e: Exception) {
                Log.e(TAG, "Rebind request failed", e)
            }
        }
    }

    private companion object {
        const val TAG = "HLedgerCapture"
    }
}
