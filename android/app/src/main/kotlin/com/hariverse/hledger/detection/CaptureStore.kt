package com.hariverse.hledger.detection

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/** One captured alert, exactly as the posting app worded it. */
data class Capture(
    val key: String,
    val packageName: String,
    val postedAt: Long,
    val title: String,
    val body: String,
)

/**
 * Disk-backed queue of captured transaction alerts.
 *
 * Written from [NotificationCaptureService], which routinely runs with no
 * Flutter engine attached and can be killed between any two notifications. So
 * every write is committed synchronously, to this class's own preferences file,
 * using nothing but Android APIs.
 *
 * Records leave the queue only once Dart confirms it has stored them. A drain
 * that cleared on read would lose the whole queue whenever the app died
 * mid-processing — or whenever nobody had signed in yet, which is exactly when
 * captures pile up.
 */
object CaptureStore {
    private const val FILE = "hledger_notification_capture"
    private const val KEY_QUEUE = "queue"
    private const val KEY_SKIPPED = "skipped_sources"
    private const val MAX_QUEUE = 200
    private const val MAX_SKIPPED = 80
    private const val TAG = "HLedgerCapture"

    private val lock = Any()

    /** Sources already reported this process, so a chatty app logs once. */
    private val reported = mutableSetOf<String>()

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    /** Appends [capture]; returns whether it was new. */
    fun append(context: Context, capture: Capture): Boolean {
        synchronized(lock) {
            return try {
                val queue = readQueue(context)

                // Android re-posts a notification every time it updates, so
                // identity has to include the text: an unchanged repost is not a
                // new event.
                val incoming = fingerprint(capture.key, capture.title, capture.body)
                var duplicate = false
                for (i in 0 until queue.length()) {
                    val existing = queue.optJSONObject(i) ?: continue
                    val seen = fingerprint(
                        existing.optString("key"),
                        existing.optString("title"),
                        existing.optString("body"),
                    )
                    if (seen == incoming) {
                        duplicate = true
                        break
                    }
                }

                if (duplicate) {
                    false
                } else {
                    queue.put(
                        JSONObject().apply {
                            put("key", capture.key)
                            put("package", capture.packageName)
                            put("postedAt", capture.postedAt)
                            put("title", capture.title)
                            put("body", capture.body)
                        }
                    )
                    while (queue.length() > MAX_QUEUE) queue.remove(0)
                    prefs(context).edit().putString(KEY_QUEUE, queue.toString()).commit()
                    Log.i(TAG, "Captured alert from ${capture.packageName}")
                    true
                }
            } catch (e: Exception) {
                Log.e(TAG, "Capture write failed", e)
                false
            }
        }
    }

    /** Everything currently queued. Does NOT remove — see [acknowledge]. */
    fun drain(context: Context): List<Map<String, Any>> {
        synchronized(lock) {
            val out = mutableListOf<Map<String, Any>>()
            try {
                val queue = readQueue(context)
                for (i in 0 until queue.length()) {
                    val entry = queue.optJSONObject(i) ?: continue
                    out.add(
                        mapOf(
                            "key" to entry.optString("key"),
                            "package" to entry.optString("package"),
                            "postedAt" to entry.optLong("postedAt"),
                            "title" to entry.optString("title"),
                            "body" to entry.optString("body"),
                        )
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Capture read failed", e)
            }
            return out
        }
    }

    /** Drops exactly the records Dart has stored. */
    fun acknowledge(context: Context, keys: Set<String>) {
        if (keys.isEmpty()) return
        synchronized(lock) {
            try {
                val queue = readQueue(context)
                val kept = JSONArray()
                for (i in 0 until queue.length()) {
                    val entry = queue.optJSONObject(i) ?: continue
                    if (entry.optString("key") !in keys) kept.put(entry)
                }
                prefs(context).edit().putString(KEY_QUEUE, kept.toString()).commit()
                Log.i(TAG, "Acknowledged ${keys.size} capture(s), ${kept.length()} left")
            } catch (e: Exception) {
                Log.e(TAG, "Acknowledge failed", e)
            }
        }
    }

    /**
     * Records that a source was passed over, and why.
     *
     * A skipped notification must not vanish without trace, or an app that posts
     * perfectly good alerts stays invisible forever. Only the package name and
     * the reason are kept — never the message — and only the first sighting of
     * each source is written, so a chat app cannot turn this into a disk-write
     * loop.
     */
    fun recordSkip(context: Context, packageName: String, reason: String) {
        val id = "$packageName/$reason"
        synchronized(lock) {
            if (!reported.add(id)) return
        }
        Log.i(TAG, "Skipped $packageName ($reason)")
        synchronized(lock) {
            try {
                val store = prefs(context)
                val existing = JSONObject(store.getString(KEY_SKIPPED, "{}") ?: "{}")
                if (existing.length() < MAX_SKIPPED) {
                    existing.put(packageName, reason)
                    store.edit().putString(KEY_SKIPPED, existing.toString()).commit()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Skip record failed", e)
            }
        }
    }

    /** Sources passed over, for diagnostics. */
    fun skipped(context: Context): Map<String, String> {
        synchronized(lock) {
            val out = mutableMapOf<String, String>()
            try {
                val stored = JSONObject(prefs(context).getString(KEY_SKIPPED, "{}") ?: "{}")
                for (key in stored.keys()) out[key] = stored.optString(key)
            } catch (e: Exception) {
                Log.e(TAG, "Skip read failed", e)
            }
            return out
        }
    }

    fun clearSkipped(context: Context) {
        synchronized(lock) {
            reported.clear()
            prefs(context).edit().remove(KEY_SKIPPED).commit()
        }
    }

    private fun readQueue(context: Context): JSONArray {
        val raw = prefs(context).getString(KEY_QUEUE, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: Exception) {
            Log.e(TAG, "Queue corrupt, starting over", e)
            JSONArray()
        }
    }

    private fun fingerprint(key: String, title: String, body: String): String =
        "$key|$title|$body"
}
