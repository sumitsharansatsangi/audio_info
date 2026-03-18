package com.kumpali.audio_info

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors
import kotlin.collections.set

class AudioInfoPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val executor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "audio_info")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getInfo" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    executor.execute {
                        val info = getInfo(filePath)
                        mainHandler.post { result.success(info) }
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                }
            }

            "getEmbeddedPicture" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    executor.execute {
                        val picture = getEmbeddedPicture(filePath)
                        mainHandler.post { result.success(picture) }
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                }
            }

            "getWaveform" -> {
                val filePath = call.argument<String>("filePath")
                val samples = call.argument<Int>("samples") ?: 100

                if (filePath != null) {
                    executor.execute {
                        val waveform = getWaveform(filePath, samples)
                        mainHandler.post { result.success(waveform) }
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun getEmbeddedPicture(filePath: String): ByteArray? {
        val metaRetriever = MediaMetadataRetriever()
        return try {
            metaRetriever.setDataSource(filePath)
            metaRetriever.embeddedPicture // null when no artwork — Flutter receives null
        } catch (e: Exception) {
            Log.e("AudioInfo", "Embedded picture error for $filePath", e)
            null
        } finally {
            metaRetriever.release()
        }
    }

    fun getWaveform(filePath: String, sampleCount: Int = 100): List<Float> {
        if (sampleCount <= 0) return emptyList()

        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(filePath)
            val trackIndex = findAudioTrackIndex(extractor)
            if (trackIndex == -1) return emptyList()

            extractor.selectTrack(trackIndex)
            val format = extractor.getTrackFormat(trackIndex)
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION))
                format.getLong(MediaFormat.KEY_DURATION) else -1L

            if (durationUs > 0) {
                seekBasedWaveform(extractor, trackIndex, format, durationUs, sampleCount)
            } else {
                decodeWaveform(extractor, trackIndex, sampleCount)
            }
        } catch (e: Exception) {
            Log.e("AudioInfo", "Waveform extraction error for $filePath", e)
            emptyList()
        } finally {
            extractor.release()
        }
    }

    /**
     * Fast path: seeks to [sampleCount] evenly-spaced timestamps and decodes a tiny
     * chunk at each position. Avoids decoding the entire file.
     */
    private fun seekBasedWaveform(
        extractor: MediaExtractor,
        trackIndex: Int,
        format: MediaFormat,
        durationUs: Long,
        sampleCount: Int,
    ): List<Float> {
        val mimeType = format.getString(MediaFormat.KEY_MIME) ?: return emptyList()
        val codec = try {
            MediaCodec.createDecoderByType(mimeType)
        } catch (e: Exception) {
            Log.e("AudioInfo", "Codec creation failed, falling back to full decode", e)
            return decodeWaveform(extractor, trackIndex, sampleCount)
        }

        val bufferInfo = MediaCodec.BufferInfo()
        val peaks = ArrayList<Float>(sampleCount)
        val stepUs = durationUs / sampleCount
        var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT
        var bytesPerSample = 2

        return try {
            codec.configure(format, null, null, 0)
            codec.start()

            for (slot in 0 until sampleCount) {
                extractor.seekTo(slot * stepUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                codec.flush()

                var slotPeak = 0f
                var inputFed = 0
                var outputCollected = 0
                var inputDone = false

                // Feed up to MAX_INPUT_PER_SLOT compressed frames then collect
                // up to MAX_OUTPUT_PER_SLOT decoded frames.
                slot@ while (outputCollected < MAX_OUTPUT_PER_SLOT) {
                    if (!inputDone && inputFed < MAX_INPUT_PER_SLOT) {
                        val ibIdx = codec.dequeueInputBuffer(TIMEOUT_US)
                        if (ibIdx >= 0) {
                            val ib = codec.getInputBuffer(ibIdx)
                            if (ib == null) {
                                codec.queueInputBuffer(ibIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputDone = true
                            } else {
                                val sz = extractor.readSampleData(ib, 0)
                                if (sz < 0) {
                                    codec.queueInputBuffer(ibIdx, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                    inputDone = true
                                } else {
                                    codec.queueInputBuffer(ibIdx, 0, sz, extractor.sampleTime, 0)
                                    extractor.advance()
                                    inputFed++
                                }
                            }
                        }
                    }

                    when (val obIdx = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)) {
                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val outFmt = codec.outputFormat
                            pcmEncoding = outFmt.getIntegerSafely(
                                MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                            bytesPerSample = bytesPerSampleForEncoding(pcmEncoding)
                        }
                        MediaCodec.INFO_TRY_AGAIN_LATER,
                        MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED -> {
                            if (inputDone) break@slot
                        }
                        else -> if (obIdx >= 0) {
                            val ob = codec.getOutputBuffer(obIdx)
                            if (ob != null && bufferInfo.size > 0) {
                                // Skip the first decoded frame — codec warmup after flush
                                // can produce silence or artifacts.
                                if (outputCollected > 0) {
                                    val chunk = ByteArray(bufferInfo.size)
                                    ob.position(bufferInfo.offset)
                                    ob.limit(bufferInfo.offset + bufferInfo.size)
                                    ob.get(chunk)
                                    val p = readPeak(chunk, pcmEncoding, bytesPerSample)
                                    if (p > slotPeak) slotPeak = p
                                }
                            }
                            codec.releaseOutputBuffer(obIdx, false)
                            outputCollected++
                            if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                break@slot
                            }
                        }
                    }
                }

                peaks.add(slotPeak)
            }

            peaks
        } catch (e: Exception) {
            Log.e("AudioInfo", "Seek-based waveform error", e)
            emptyList()
        } finally {
            runCatching { codec.stop() }
            codec.release()
        }
    }

    /**
     * Fallback path used when file duration is unknown: decodes the whole file
     * sequentially and downsamples the resulting peak list.
     */
    private fun decodeWaveform(
        extractor: MediaExtractor,
        audioTrackIndex: Int,
        sampleCount: Int,
    ): List<Float> {
        val format = extractor.getTrackFormat(audioTrackIndex)
        val mimeType = format.getString(MediaFormat.KEY_MIME) ?: return emptyList()
        val codec = MediaCodec.createDecoderByType(mimeType)
        val waveform = mutableListOf<Float>()
        val bufferInfo = MediaCodec.BufferInfo()

        var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT
        var bytesPerSample = 2

        return try {
            codec.configure(format, null, null, 0)
            codec.start()

            var inputDone = false
            var outputDone = false

            while (!outputDone) {
                if (!inputDone) {
                    val inputBufferIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inputBufferIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputBufferIndex)
                        if (inputBuffer == null) {
                            codec.queueInputBuffer(inputBufferIndex, 0, 0, 0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inputBufferIndex, 0, 0, 0,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputDone = true
                            } else {
                                codec.queueInputBuffer(inputBufferIndex, 0, sampleSize,
                                    extractor.sampleTime, 0)
                                extractor.advance()
                            }
                        }
                    }
                }

                when (val obIdx = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val outputFormat = codec.outputFormat
                        pcmEncoding = outputFormat.getIntegerSafely(
                            MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                        bytesPerSample = bytesPerSampleForEncoding(pcmEncoding)
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER,
                    MediaCodec.INFO_OUTPUT_BUFFERS_CHANGED -> Unit
                    else -> if (obIdx >= 0) {
                        val outputBuffer = codec.getOutputBuffer(obIdx)
                        if (outputBuffer != null && bufferInfo.size > 0) {
                            val chunk = ByteArray(bufferInfo.size)
                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            outputBuffer.get(chunk)
                            waveform.add(readPeak(chunk, pcmEncoding, bytesPerSample))
                        }
                        codec.releaseOutputBuffer(obIdx, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }
                    }
                }
            }

            downsample(waveform, sampleCount)
        } catch (e: Exception) {
            Log.e("AudioInfo", "Waveform decode error", e)
            emptyList()
        } finally {
            codec.stop()
            codec.release()
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

    private fun readPeak(bytes: ByteArray, pcmEncoding: Int, bytesPerSample: Int): Float {
        var peak = 0f
        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        // Sample every PEAK_STRIDE-th value — 4× less CPU with negligible accuracy loss.
        val strideBytes = bytesPerSample * PEAK_STRIDE

        while (buffer.remaining() >= bytesPerSample) {
            val normalized = when (pcmEncoding) {
                AudioFormat.ENCODING_PCM_FLOAT -> kotlin.math.abs(buffer.float)
                AudioFormat.ENCODING_PCM_8BIT -> {
                    val sample = buffer.get().toInt() and 0xff
                    kotlin.math.abs((sample - 128) / 128f)
                }
                AudioFormat.ENCODING_PCM_24BIT_PACKED -> {
                    val b0 = buffer.get().toInt() and 0xff
                    val b1 = buffer.get().toInt() and 0xff
                    val b2 = buffer.get().toInt()
                    val sample = (b2 shl 24) or (b1 shl 16) or (b0 shl 8)
                    kotlin.math.abs((sample shr 8) / 8_388_608f)
                }
                AudioFormat.ENCODING_PCM_32BIT -> kotlin.math.abs(buffer.int / 2_147_483_648f)
                else -> kotlin.math.abs(buffer.short / 32768f)
            }

            if (normalized > peak) peak = normalized

            // Skip stride-1 additional samples
            val skip = (strideBytes - bytesPerSample).coerceAtMost(buffer.remaining())
            if (skip > 0) buffer.position(buffer.position() + skip)
        }

        return peak
    }

    private fun bytesPerSampleForEncoding(pcmEncoding: Int): Int = when (pcmEncoding) {
        AudioFormat.ENCODING_PCM_8BIT -> 1
        AudioFormat.ENCODING_PCM_24BIT_PACKED -> 3
        AudioFormat.ENCODING_PCM_32BIT,
        AudioFormat.ENCODING_PCM_FLOAT -> 4
        else -> 2
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
        val file = File(filePath)

        try {
            metaRetriever.setDataSource(filePath)

            // Basic metadata
            val rawTitle =
                metaRetriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""
            audioInfoMap["title"] = inferDisplayTitle(file, rawTitle)
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

    private fun inferDisplayTitle(file: File, rawTitle: String): String {
        if (rawTitle.isNotBlank()) {
            return rawTitle
        }

        val baseName = file.nameWithoutExtension
        if (baseName.isBlank()) {
            return ""
        }

        val path = file.absolutePath.lowercase()
        val isWhatsApp = path.contains("whatsapp") ||
            baseName.startsWith("PTT-", ignoreCase = true) ||
            baseName.startsWith("AUD-", ignoreCase = true) ||
            baseName.contains("-WA", ignoreCase = true)

        return if (isWhatsApp) {
            if (baseName.startsWith("PTT-", ignoreCase = true) || path.contains("voice notes")) {
                "WhatsApp Voice Note"
            } else {
                "WhatsApp Audio"
            }
        } else {
            prettifyFileName(baseName)
        }
    }

    private fun prettifyFileName(fileName: String): String {
        return fileName
            .replace('_', ' ')
            .replace('-', ' ')
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun MediaFormat.getIntegerSafely(key: String, fallback: Int): Int {
        return if (containsKey(key)) getInteger(key) else fallback
    }

    companion object {
        private const val TIMEOUT_US = 10_000L

        /** Max compressed frames fed to the codec per seek slot. */
        private const val MAX_INPUT_PER_SLOT = 8

        /** Max decoded frames collected per seek slot (1 skipped for warmup + this many used). */
        private const val MAX_OUTPUT_PER_SLOT = 3

        /** Sample every Nth PCM value in readPeak — 4× less CPU, negligible accuracy loss. */
        private const val PEAK_STRIDE = 4
    }
}
