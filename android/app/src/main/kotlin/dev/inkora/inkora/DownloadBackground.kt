package dev.inkora.inkora

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Private, atomic, Keystore-encrypted queue. Credentials never enter SQLite/logs. */
object DownloadBackground {
    private const val JOB = 4105
    private const val KEY = "inkora.background.transfer.v1"
    @Volatile var foreground = false
    @Volatile var worker: DownloadJobService? = null
    private lateinit var context: Context
    private lateinit var file: AtomicFile
    private var entries = JSONArray()

    @Synchronized fun initialize(app: Context) {
        if (::context.isInitialized) return
        context = app.applicationContext
        file = AtomicFile(File(context.filesDir, "background-transfers.enc"))
        if (file.baseFile.exists()) {
            try {
                val bytes = file.readFully()
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
                entries = JSONArray(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
            } catch (_: Exception) {
                // Lost/unavailable key or corrupt atomic file: Dart's durable jobs
                // remain authoritative and will restart assets on the next launch.
                entries = JSONArray(); file.delete()
            }
        }
        for (i in 0 until entries.length()) {
            val item = entries.getJSONObject(i)
            if (item.optString("state") == "running") item.put("state", "queued")
        }
    }
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(KeyGenParameterSpec.Builder(KEY, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())
        return generator.generateKey()
    }
    private fun save() {
        if (entries.length() == 0) { file.delete(); return }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val bytes = cipher.iv + cipher.doFinal(entries.toString().toByteArray(Charsets.UTF_8))
        val output = file.startWrite()
        try { output.write(bytes); file.finishWrite(output) } catch (e: Exception) { file.failWrite(output); throw e }
    }
    @Synchronized fun enqueue(tasks: List<Map<String, Any?>>, headers: Map<String, String>, wifiOnly: Boolean) {
        for (task in tasks) {
            val id = task["id"] as? String ?: error("Invalid task")
            require(id.matches(Regex("[a-f0-9]{64}-[0-9]+")))
            if ((0 until entries.length()).any { entries.getJSONObject(it).getString("id") == id }) continue
            val url = URL(task["url"] as String)
            require((url.protocol == "http" || url.protocol == "https") && url.userInfo == null)
            val output = File(task["path"] as String).canonicalFile
            require(output.path.startsWith(context.filesDir.canonicalPath + File.separator))
            val maximum = (task["maximumBytes"] as Number).toLong()
            require(maximum in 1..(512L * 1024 * 1024))
            val item = JSONObject(task).put("headers", JSONObject(headers)).put("wifiOnly", wifiOnly).put("state", "queued").put("attempt", 0)
            entries.put(item)
        }
        save()
        schedule()
    }
    @Synchronized fun schedule() {
        if (foreground || !(0 until entries.length()).any { entries.getJSONObject(it).optString("state") == "queued" }) return
        val wifiOnly = (0 until entries.length()).filter { entries.getJSONObject(it).optString("state") == "queued" }.any { entries.getJSONObject(it).optBoolean("wifiOnly", true) }
        val job = JobInfo.Builder(JOB, ComponentName(context, DownloadJobService::class.java))
            .setRequiredNetworkType(if (wifiOnly) JobInfo.NETWORK_TYPE_UNMETERED else JobInfo.NETWORK_TYPE_ANY)
            .setPersisted(true).setMinimumLatency(10_000).setBackoffCriteria(30_000, JobInfo.BACKOFF_POLICY_EXPONENTIAL).build()
        require((context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).schedule(job) == JobScheduler.RESULT_SUCCESS)
    }
    fun pause() {
        foreground = true
        worker?.stopTransfer()
        if (::context.isInitialized) (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(JOB)
    }
    @Synchronized fun next(): JSONObject? {
        if (foreground) return null
        val now = System.currentTimeMillis()
        for (i in 0 until entries.length()) {
            val item = entries.getJSONObject(i)
            if (item.optString("state") == "queued" && item.optLong("retryAt", 0) <= now) {
                item.put("state", "running")
                save()
                return JSONObject(item.toString())
            }
        }
        return null
    }
    @Synchronized fun hasPending() = (0 until entries.length()).any { entries.getJSONObject(it).optString("state") == "queued" }
    @Synchronized fun commit(id: String, partial: File, output: File, changes: JSONObject) {
        if (foreground || !present(id)) throw InterruptedException()
        check(partial.renameTo(output))
        update(id, changes)
    }
    @Synchronized fun present(id: String) = (0 until entries.length()).any { entries.getJSONObject(it).getString("id") == id }
    @Synchronized fun update(id: String, changes: JSONObject) {
        for (i in 0 until entries.length()) {
            val item = entries.getJSONObject(i)
            if (item.getString("id") == id) {
                for (name in changes.keys()) item.put(name, changes.get(name))
                save(); return
            }
        }
    }
    @Synchronized fun accounts(): List<String> = (0 until entries.length()).map { entries.getJSONObject(it).getString("account") }.distinct()
    @Synchronized fun results(): List<Map<String, Any?>> = (0 until entries.length()).map { entries.getJSONObject(it) }
        .filter { it.optString("state") == "complete" || it.optString("state") == "failed" }
        .map { item -> listOf("id", "account", "job", "page", "path", "state", "mediaType", "byteLength", "checksum").associateWith { if (item.has(it)) item.get(it) else null } }
    @Synchronized fun remove(id: String) {
        entries = JSONArray((0 until entries.length()).map { entries.getJSONObject(it) }.filter { it.getString("id") != id })
        save()
    }
    @Synchronized fun cancelAccount(account: String) {
        val removed = (0 until entries.length()).map { entries.getJSONObject(it) }.filter { it.getString("account") == account }
        entries = JSONArray((0 until entries.length()).map { entries.getJSONObject(it) }.filter { it.getString("account") != account })
        save()
        for (item in removed) { File(item.getString("path")).delete(); File(item.getString("path") + ".part").delete() }
    }
    @Synchronized fun resetInterrupted() {
        for (i in 0 until entries.length()) {
            val item = entries.getJSONObject(i)
            if (item.optString("state") == "running") item.put("state", "queued")
            File(item.getString("path") + ".part").delete()
        }
        save()
    }
    @Synchronized fun status(): Map<String, Any> = mapOf("count" to entries.length(), "foreground" to foreground,
        "scheduled" to ((context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).getPendingJob(JOB) != null))
}

class DownloadJobService : JobService() {
    private val stopped = AtomicBoolean(false)
    @Volatile private var connection: HttpURLConnection? = null
    @Volatile var thread: Thread? = null
    fun stopTransfer() { stopped.set(true); connection?.disconnect(); thread?.interrupt() }
    override fun onStartJob(params: JobParameters): Boolean {
        try { DownloadBackground.initialize(this) } catch (_: Exception) { return false }
        if (DownloadBackground.foreground) return false
        stopped.set(false)
        DownloadBackground.worker = this
        thread = Thread {
            var retry = false
            try {
                while (!stopped.get()) {
                    val item = DownloadBackground.next() ?: break
                    val id = item.getString("id")
                    val output = File(item.getString("path"))
                    val partial = File(output.path + ".part")
                    try {
                        val connectivity = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
                        if (Build.VERSION.SDK_INT >= 24 && connectivity.restrictBackgroundStatus == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED) throw java.io.IOException()
                        output.parentFile!!.mkdirs()
                        val http = URL(item.getString("url")).openConnection() as HttpURLConnection
                        connection = http
                        http.instanceFollowRedirects = false
                        http.connectTimeout = 15_000; http.readTimeout = 15_000
                        val headers = item.getJSONObject("headers")
                        for (header in headers.keys()) http.setRequestProperty(header, headers.getString(header))
                        val maximum = item.getLong("maximumBytes")
                        val code = http.responseCode
                        if (code != 200 || http.contentLengthLong > maximum) {
                            DownloadBackground.update(id, JSONObject().put("state", if (code == 429 || code >= 500) "queued" else "failed").put("retryAt", System.currentTimeMillis() + 30_000))
                            retry = code == 429 || code >= 500
                            if (retry) break else continue
                        }
                        val digest = MessageDigest.getInstance("SHA-256")
                        var length = 0L
                        http.inputStream.use { input ->
                            java.io.FileOutputStream(partial).use { sink ->
                                val buffer = ByteArray(64 * 1024)
                                while (true) {
                                    if (stopped.get() || !DownloadBackground.present(id)) throw InterruptedException()
                                    val count = input.read(buffer)
                                    if (count < 0) break
                                    length += count
                                    if (length > maximum) throw IllegalArgumentException()
                                    sink.write(buffer, 0, count); digest.update(buffer, 0, count)
                                }
                                sink.fd.sync()
                            }
                        }
                        require(length > 0 && (http.contentLengthLong < 0 || length == http.contentLengthLong))
                        if (stopped.get() || !DownloadBackground.present(id)) throw InterruptedException()
                        DownloadBackground.commit(id, partial, output, JSONObject().put("state", "complete").put("byteLength", length)
                            .put("mediaType", http.contentType?.substringBefore(';')?.lowercase() ?: "")
                            .put("checksum", digest.digest().joinToString("") { "%02x".format(it) }))
                    } catch (_: IllegalArgumentException) {
                        DownloadBackground.update(id, JSONObject().put("state", "failed"))
                    } catch (_: Exception) {
                        val attempt = (item.optInt("attempt", 0) + 1).coerceAtMost(8)
                        DownloadBackground.update(id, JSONObject().put("state", "queued").put("attempt", attempt).put("retryAt", System.currentTimeMillis() + (30_000L shl attempt)))
                        retry = true
                        break
                    } finally { connection?.disconnect(); connection = null; partial.delete() }
                }
            } finally {
                DownloadBackground.worker = null
                if (!stopped.get()) jobFinished(params, retry || DownloadBackground.hasPending())
            }
        }.also { it.start() }
        return true
    }
    override fun onStopJob(params: JobParameters): Boolean { stopTransfer(); return true }
}
