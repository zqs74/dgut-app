package cn.edu.dgut.dgut_app

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "dgut/install"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("bad_arg", "path 为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message ?: "唤起安装失败", null)
                        }
                    }
                    // 是否已授权"安装未知来源应用"，用于提前引导用户去开启
                    "canInstall" -> {
                        val ok = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(ok)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 把私有目录里的 apk 通过 FileProvider 交给系统安装器（用户仍需在系统弹窗点一次"安装"） */
    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) throw IllegalStateException("安装包不存在：$path")

        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileProvider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
