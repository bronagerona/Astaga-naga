package id.bronagerona.zenia

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.view.Gravity
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity : Activity() {
    companion object { private const val PICK_MODEL = 4107 }

    private val worker = Executors.newSingleThreadExecutor()
    private lateinit var web: WebView
    private lateinit var status: TextView
    private var modelFd: ParcelFileDescriptor? = null
    @Volatile private var modelReady = false

    external fun nativeLoadModel(path: String): String
    external fun nativeGenerate(prompt: String): String
    external fun nativeUnloadModel()

    init { System.loadLibrary("zenia-llama") }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = android.graphics.Color.rgb(31, 36, 72)
        window.navigationBarColor = android.graphics.Color.rgb(12, 15, 31)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(android.graphics.Color.rgb(12, 15, 31))
        }
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(10, 8, 10, 8)
            setBackgroundColor(android.graphics.Color.rgb(31, 36, 72))
        }
        val load = Button(this).apply {
            text = "📂 Muat Gemma lokal"
            isAllCaps = false
            setOnClickListener { chooseModel() }
        }
        status = TextView(this).apply {
            text = "AI belum dimuat · pilih file GGUF lokal"
            setTextColor(android.graphics.Color.WHITE)
            textSize = 12f
            setPadding(10, 0, 4, 0)
        }
        bar.addView(load, LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        bar.addView(status, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        web = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            settings.allowContentAccess = false
            settings.javaScriptCanOpenWindowsAutomatically = false
            webChromeClient = WebChromeClient()
            webViewClient = WebViewClient()
            addJavascriptInterface(GameBridge(), "ZeniaNativeAI")
            setLayerType(View.LAYER_TYPE_HARDWARE, null)
        }
        root.addView(bar, LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
        root.addView(web, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)
        web.loadUrl("file:///android_asset/Zenia%20Quest%20Companion.html")
    }

    private fun chooseModel() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/octet-stream", "application/x-gguf"))
            putExtra(Intent.EXTRA_TITLE, "Pilih Gemma 3 1B GGUF yang sudah ada")
        }
        startActivityForResult(intent, PICK_MODEL)
    }

    @Deprecated("Uses the Activity result API for compatibility with the minimal wrapper")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_MODEL || resultCode != RESULT_OK) return
        val uri: Uri = data?.data ?: return
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: Exception) { /* Some document providers do not offer persistable grants. */ }
        setStatus("Membuka model lokal… jangan tutup aplikasi", false)
        worker.execute {
            modelReady = false
            try { nativeUnloadModel() } catch (_: Exception) {}
            try { modelFd?.close() } catch (_: Exception) {}
            modelFd = null
            var candidate: ParcelFileDescriptor? = null
            try {
                candidate = contentResolver.openFileDescriptor(uri, "r")
                    ?: throw IllegalStateException("Provider tidak memberikan file descriptor.")
                val error = nativeLoadModel("/proc/self/fd/${candidate.fd}")
                if (error.isNotEmpty()) {
                    candidate.close()
                    runOnUiThread { setStatus(error, false) }
                    return@execute
                }
                val old = modelFd
                modelFd = candidate
                candidate = null
                modelReady = true
                old?.close()
                runOnUiThread { setStatus("Gemma siap · komentar lokal aktif", true) }
            } catch (e: Exception) {
                candidate?.close()
                runOnUiThread { setStatus("Gagal memuat file: ${e.message ?: "provider tidak kompatibel"}", false) }
            }
        }
    }

    private fun setStatus(message: String, ready: Boolean = modelReady) {
        if (::status.isInitialized) status.text = message
        if (::web.isInitialized) {
            val js = "window.ZeniaAI&&window.ZeniaAI.nativeStatus(" +
                JSONObject.quote(message) + "," + ready + ");"
            web.evaluateJavascript(js, null)
        }
    }

    private inner class GameBridge {
        @JavascriptInterface
        fun pickModel() {
            runOnUiThread { chooseModel() }
        }

        @JavascriptInterface
        fun requestComment(payloadJson: String) {
            if (!modelReady) return
            worker.execute {
                try {
                    val p = JSONObject(payloadJson)
                    val g = p.optJSONObject("game") ?: JSONObject()
                    val event = p.optString("event", "ambient")
                    val promptText = buildString {
                        append("Kamu Zenia, companion petualang di game RPG berbahasa Indonesia. ")
                        append("Tulis satu komentar spontan, lucu atau natural, maksimal 8 kata. ")
                        append("Jangan mengarang aksi dan jangan menjelaskan bahwa kamu AI. ")
                        append("Event: ").append(event).append(". ")
                        append("Lokasi: ").append(g.optString("map", "tidak diketahui")).append(". ")
                        append("Level pemain: ").append(g.optInt("level", 1)).append(". ")
                        append("HP: ").append(g.optInt("hp", 0)).append("/")
                            .append(g.optInt("maxHp", 0)).append(". ")
                        append("MP: ").append(g.optInt("mp", 0)).append("/")
                            .append(g.optInt("maxMp", 0)).append(". ")
                        append("Emas: ").append(g.optInt("gold", 0)).append(". ")
                        append("Quest: ").append(g.optString("quest", "tidak ada")).append(". ")
                        append("Musuh dekat: ").append(g.optString("enemy", "tidak ada")).append(". ")
                        append("NPC dekat: ").append(g.optString("npc", "tidak ada")).append(". ")
                        append("Catatan: ").append(g.optString("note", "")).append(". ")
                        append("Balas hanya komentar Zenia, tanpa tanda kutip.")
                    }
                    // Gemma 3 chat-turn format; llama.cpp parses these as special tokens.
                    val prompt = "<bos><start_of_turn>user\n" + promptText +
                        "<end_of_turn>\n<start_of_turn>model\n"
                    val raw = nativeGenerate(prompt)
                    val answer = raw.replace(Regex("<[^>]+>"), " ")
                        .replace(Regex("[\\r\\n]+"), " ").trim()
                        .split(Regex("\\s+")).take(8).joinToString(" ")
                    if (answer.isNotBlank()) {
                        val id = p.optString("id", "")
                        val js = "window.ZeniaAI&&window.ZeniaAI.receive(" +
                            JSONObject.quote(id) + "," + JSONObject.quote(answer) + ");"
                        runOnUiThread { web.evaluateJavascript(js, null) }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("ZeniaLocalAI", "Comment inference failed", e)
                }
            }
        }
    }

    override fun onDestroy() {
        modelReady = false
        worker.execute {
            try { nativeUnloadModel() } catch (_: Exception) {}
            try { modelFd?.close() } catch (_: Exception) {}
            modelFd = null
        }
        worker.shutdown()
        web.removeJavascriptInterface("ZeniaNativeAI")
        web.destroy()
        super.onDestroy()
    }
}
