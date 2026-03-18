package com.kumpali.audio_info

import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.nio.ByteBuffer
import kotlin.collections.set

class AudioInfoPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "audio_info")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getInfo" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    result.success(getInfo(filePath))
                } else {
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                }
            }

            "getEmbeddedPicture" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    result.success(getEmbeddedPicture(filePath))
                } else {
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                }
            }

            "getWaveform" -> {
                val filePath = call.argument<String>("filePath")
                val samples = call.argument<Int>("samples") ?: 100

                if (filePath != null) {
                    result.success(getWaveform(filePath, samples))
                } else {
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun getEmbeddedPicture(filePath: String): ByteArray {
        val metaRetriever = MediaMetadataRetriever()
        return try {
            metaRetriever.setDataSource(filePath)
            metaRetriever.embeddedPicture ?: ByteArray(0)
        } catch (e: Exception) {
            Log.e("AudioInfo", "Embedded picture error for $filePath", e)
            ByteArray(0)
        } finally {
            metaRetriever.release()
        }
    }

    fun getWaveform(filePath: String, sampleCount: Int = 100): List<Float> {
        if (sampleCount <= 0) {
            return emptyList()
        }

        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(filePath)
            val audioTrackIndex = findAudioTrackIndex(extractor)
            if (audioTrackIndex == -1) {
                emptyList()
            } else {
                extractor.selectTrack(audioTrackIndex)

                val waveform = mutableListOf<Float>()
                val buffer = ByteBuffer.allocate(2048)

                while (true) {
                    buffer.clear()
                    val sampleSize = extractor.readSampleData(buffer, 0)
                    if (sampleSize <= 0) {
                        break
                    }

                    waveform.add(readPeak(buffer.array(), sampleSize))
                    extractor.advance()
                }

                downsample(waveform, sampleCount)
            }
        } catch (e: Exception) {
            Log.e("AudioInfo", "Waveform extraction error for $filePath", e)
            emptyList()
        } finally {
            extractor.release()
        }
    }

    private fun findAudioTrackIndex(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                return i
            }
        }
        return -1
    }

    private fun readPeak(bytes: ByteArray, sampleSize: Int): Float {
        var peak = 0f
        val lastIndex = if (sampleSize % 2 == 0) sampleSize else sampleSize - 1

        for (i in 0 until lastIndex step 2) {
            val sample =
                ((bytes[i + 1].toInt() shl 8) or (bytes[i].toInt() and 0xff)).toShort()
            val normalized = kotlin.math.abs(sample / 32768f)
            if (normalized > peak) {
                peak = normalized
            }
        }

        return peak
    }

    private fun downsample(input: List<Float>, targetSize: Int): List<Float> {
        if (input.isEmpty() || targetSize <= 0) {
            return emptyList()
        }

        if (input.size <= targetSize) {
            return input
        }

        val result = mutableListOf<Float>()
        val bucketSize = input.size.toDouble() / targetSize

        for (i in 0 until targetSize) {
            val start = (i * bucketSize).toInt()
            val end = minOf(((i + 1) * bucketSize).toInt(), input.size).coerceAtLeast(start + 1)
            val max = input.subList(start, end).maxOrNull() ?: 0f
            result.add(max)
        }

        return result
    }

    private fun getInfo(filePath: String): Map<String, Any> {
        val metaRetriever = MediaMetadataRetriever()
        val audioInfoMap = mutableMapOf<String, Any>()

        try {
            metaRetriever.setDataSource(filePath)

            // Basic metadata
            audioInfoMap["title"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""
            audioInfoMap["album"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM) ?: ""
            audioInfoMap["artist"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST) ?: ""
            audioInfoMap["albumArtist"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST) ?: ""
            audioInfoMap["composer"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_COMPOSER) ?: ""
            audioInfoMap["genre"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_GENRE) ?: ""

            // Extended tags
            audioInfoMap["author"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_AUTHOR) ?: ""
            audioInfoMap["writer"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_WRITER) ?: ""
            audioInfoMap["year"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR) ?: ""
            audioInfoMap["date"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE) ?: ""
            audioInfoMap["compilation"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_COMPILATION) ?: ""

            // Track info
            audioInfoMap["trackNumber"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER)
                    ?: ""
            audioInfoMap["discNumber"] =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DISC_NUMBER) ?: ""

            // Technical
            val durationStr =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION) ?: "0"
            val bitrateStr =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE) ?: "0"
            val mime =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE) ?: ""

            val durationMs = durationStr.toLongOrNull() ?: 0L
            val bitrate = bitrateStr.toIntOrNull() ?: 0

            audioInfoMap["durationMs"] = durationMs
            audioInfoMap["durationSec"] = durationMs / 1000
            audioInfoMap["durationFormatted"] = formatDuration(durationMs)

            audioInfoMap["bitrate"] = bitrate
            audioInfoMap["bitrateKbps"] = bitrate / 1000

            audioInfoMap["mimeType"] = mime

            // File size
            val file = File(filePath)
            val fileSize = file.length()

            audioInfoMap["fileSizeBytes"] = fileSize
            audioInfoMap["fileSizeMB"] = fileSize / (1024.0 * 1024.0)

            // Quality classification
            audioInfoMap["quality"] = when {
                mime.contains("flac", ignoreCase = true) -> "lossless"
                bitrate >= 320000 -> "high"
                bitrate >= 192000 -> "medium"
                bitrate > 0 -> "low"
                else -> "unknown"
            }

            // Album art presence
            audioInfoMap["hasArtwork"] = metaRetriever.embeddedPicture != null
        } catch (e: Exception) {
            Log.e("AudioInfo", "Metadata error for $filePath", e)
        } finally {
            metaRetriever.release()
        }

        return audioInfoMap
    }

    private fun formatDuration(ms: Long): String {
        val totalSeconds = ms / 1000
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60

        return if (hours > 0) {
            String.format("%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }
    }
}
