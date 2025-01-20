package com.kumpali.audio_info
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.util.Log
import android.media.MediaMetadataRetriever
import kotlin.collections.set


class AudioInfoPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel : MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "audio_info")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getInfo") {
            val filePath = call.argument<String>("filePath")
            if (filePath != null) {
                result.success(getInfo( filePath))
            } else {
                result.error("INVALID_ARGUMENT", "File path is required", null)
            }
        } else if (call.method == "getEmbeddedPicture") {
            val filePath = call.argument<String>("filePath")
            if (filePath != null) {
                result.success(getEmbeddedPicture( filePath))
            } else {
                result.error("INVALID_ARGUMENT", "File path is required", null)
            }
        }
        else {
            result.notImplemented()
        }
    }

    private fun getEmbeddedPicture(filePath: String): ByteArray?{
        val metaRetriever = MediaMetadataRetriever()
        metaRetriever.setDataSource(filePath)
        return metaRetriever.embeddedPicture
    }

    private fun getInfo(filePath: String): Map<String, Any> {
        val audioInfoMap = mutableMapOf<String, String>()
        val metaRetriever = MediaMetadataRetriever()
        metaRetriever.setDataSource(filePath)
        try {
            audioInfoMap["title"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""
            audioInfoMap["album"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM) ?: ""
            audioInfoMap["author"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_AUTHOR) ?: ""
            audioInfoMap["artist"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST) ?: ""
            audioInfoMap["albumArtist"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST) ?: ""
            audioInfoMap["composer"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_COMPOSER) ?: ""
            audioInfoMap["genre"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_GENRE) ?: ""
            audioInfoMap["year"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR) ?: ""
            audioInfoMap["track"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER) ?: ""
            audioInfoMap["duration"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION) ?: ""
            audioInfoMap["bitrate"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE) ?: ""
            audioInfoMap["compilation"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_COMPILATION) ?: ""
            audioInfoMap["date"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE) ?: ""
            audioInfoMap["discNumber"] = metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DISC_NUMBER) ?: ""
        } catch (e: Exception) {
          Log.d("Error", "Error: ${e.message}")
        }
        return audioInfoMap
    }
}
