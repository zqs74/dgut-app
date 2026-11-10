package cn.edu.dgut.dgut_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
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
                        if (!canInstall()) {
                            result.error("permission_denied", "系统还不允许本应用安装 APK", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message ?: "唤起安装失败", null)
                        }
                    }
                    // 是否已授权"安装未知来源应用"
                    "canInstall" -> result.success(canInstall())
                    // 直接跳到本应用的「安装未知应用」开关页
                    "openInstallPermission" -> result.success(openInstallPermission())
                    else -> result.notImplemented()
                }
            }
    }

    private fun canInstall(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    /**
     * 打开「安装未知应用」授权页。
     * Android 8+ 有专门页面（ACTION_MANAGE_UNKNOWN_APP_SOURCES），低版本退回应用详情页。
     */
    private fun openInstallPermission(): Boolean {
        val data = Uri.parse("package:$packageName")
        val candidates = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                add(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, data))
            } else {
                add(Intent(Settings.ACTION_SECURITY_SETTINGS))
            }
            add(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, data))
        }
        for (intent in candidates) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // 换下一个候选页
            }
        }
        return false
    }

    /** 把私有目录里的 apk 通过 FileProvider 交给系统安装器（用户仍需在系统弹窗点一次"安装"） */
    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) throw IllegalStateException("安装包不存在")

        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.fileProvider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}
