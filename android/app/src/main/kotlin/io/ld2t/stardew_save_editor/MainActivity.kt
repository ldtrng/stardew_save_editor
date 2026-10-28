package io.ld2t.stardew_save_editor

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/**
 * Storage Access Framework bridge used to reach the game's save folder
 * (Android/data/com.chucklefish.stardewvalley/files/Saves). Folder access via
 * SAF works up to Android 12; on Android 13+ the system blocks Android/data and
 * the app falls back to the plain file picker plus the in-app guide.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "sdv/saf"
    private val requestTree = 4201
    private val requestCreate = 4202
    private var pendingTree: MethodChannel.Result? = null
    private var pendingCreate: MethodChannel.Result? = null
    private var pendingCreateBytes: ByteArray? = null
    private val main = Handler(Looper.getMainLooper())

    companion object {
        const val GAME_PACKAGE = "com.chucklefish.stardewvalley"
        const val EXTERNAL_AUTHORITY = "com.android.externalstorage.documents"
        const val SAVES_DOC_ID = "primary:Android/data/$GAME_PACKAGE/files/Saves"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "svSmall", SvNativeAdFactory(this, medium = false))
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "svMedium", SvNativeAdFactory(this, medium = true))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "svSmall")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "svMedium")
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "isGameInstalled" -> result.success(isInstalled(GAME_PACKAGE))
            "createDocument" -> createDocument(
                call.argument<String>("name") ?: "save",
                call.argument<ByteArray>("bytes")!!,
                result
            )
            "pickTree" -> pickTree(call.argument<Boolean>("gameFolder") ?: true, result)
            "persistedTrees" -> result.success(
                contentResolver.persistedUriPermissions
                    .filter { it.isReadPermission && it.isWritePermission }
                    .map { it.uri.toString() }
            )
            "releaseTree" -> {
                val uri = Uri.parse(call.argument<String>("uri"))
                try {
                    contentResolver.releasePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                } catch (_: Exception) {
                }
                result.success(null)
            }
            "listSaves" -> background(result) { listSaves(Uri.parse(call.argument<String>("uri"))) }
            "readDoc" -> background(result) {
                val uri = Uri.parse(call.argument<String>("uri"))
                contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw IllegalStateException("Cannot open $uri")
            }
            "writeDoc" -> background(result) {
                val uri = Uri.parse(call.argument<String>("uri"))
                val bytes = call.argument<ByteArray>("bytes")!!
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) }
                    ?: throw IllegalStateException("Cannot write $uri")
                true
            }
            else -> result.notImplemented()
        }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: Exception) {
        false
    }

    private fun <T> background(result: MethodChannel.Result, block: () -> T) {
        Thread {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("io", e.message ?: e.toString(), null) }
            }
        }.start()
    }

    private fun pickTree(gameFolder: Boolean, result: MethodChannel.Result) {
        if (pendingTree != null) {
            result.error("busy", "Picker already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
            if (gameFolder && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    DocumentsContract.buildDocumentUri(EXTERNAL_AUTHORITY, SAVES_DOC_ID)
                )
            }
        }
        pendingTree = result
        try {
            startActivityForResult(intent, requestTree)
        } catch (e: Exception) {
            pendingTree = null
            result.error("picker", e.message, null)
        }
    }

    /** "Save as" without letting the system append an extension. */
    private fun createDocument(name: String, bytes: ByteArray, result: MethodChannel.Result) {
        if (pendingCreate != null) {
            result.error("busy", "Picker already open", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        pendingCreate = result
        pendingCreateBytes = bytes
        try {
            startActivityForResult(intent, requestCreate)
        } catch (e: Exception) {
            pendingCreate = null
            pendingCreateBytes = null
            result.error("picker", e.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == requestCreate) {
            val result = pendingCreate ?: return
            val bytes = pendingCreateBytes
            pendingCreate = null
            pendingCreateBytes = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
                result.success(null)
                return
            }
            background(result) {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(bytes) }
                    ?: throw IllegalStateException("Cannot write $uri")
                uri.toString()
            }
            return
        }
        if (requestCode != requestTree) return
        val result = pendingTree ?: return
        pendingTree = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (_: Exception) {
        }
        result.success(uri.toString())
    }

    private data class Doc(val id: String, val name: String, val mime: String, val modified: Long, val size: Long) {
        val isDir get() = mime == DocumentsContract.Document.MIME_TYPE_DIR
    }

    private fun children(tree: Uri, parentId: String): List<Doc> {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val out = mutableListOf<Doc>()
        contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                DocumentsContract.Document.COLUMN_SIZE
            ),
            null, null, null
        )?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    Doc(
                        c.getString(0),
                        c.getString(1) ?: "",
                        c.getString(2) ?: "",
                        if (c.isNull(3)) 0 else c.getLong(3),
                        if (c.isNull(4)) 0 else c.getLong(4)
                    )
                )
            }
        }
        return out
    }

    /**
     * Accepts a tree pointing at the game package folder, its files/ or Saves/
     * folder, or a single save folder, and returns every save found.
     */
    private fun listSaves(tree: Uri): List<Map<String, Any>> {
        var currentId = DocumentsContract.getTreeDocumentId(tree)
        var currentName = currentId.substringAfterLast('/').substringAfterLast(':')
        for (step in listOf(GAME_PACKAGE, "files", "Saves")) {
            if (currentName == step) continue
            val next = children(tree, currentId).firstOrNull { it.isDir && it.name == step } ?: continue
            currentId = next.id
            currentName = next.name
        }

        fun saveIn(folder: Doc): Map<String, Any>? {
            val files = children(tree, folder.id)
            val main = files.firstOrNull { !it.isDir && it.name == folder.name } ?: return null
            val info = files.firstOrNull { !it.isDir && it.name == "SaveGameInfo" }
            val m = mutableMapOf<String, Any>(
                "folder" to folder.name,
                "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, main.id).toString(),
                "modified" to main.modified,
                "size" to main.size
            )
            if (info != null) m["infoUri"] = DocumentsContract.buildDocumentUriUsingTree(tree, info.id).toString()
            return m
        }

        val here = Doc(currentId, currentName, DocumentsContract.Document.MIME_TYPE_DIR, 0, 0)
        saveIn(here)?.let { return listOf(it) }
        return children(tree, currentId).filter { it.isDir }.mapNotNull { saveIn(it) }
            .sortedByDescending { it["modified"] as Long }
    }
}
