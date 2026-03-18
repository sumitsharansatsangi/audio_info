import AVFoundation
import CoreMedia
import Flutter
import Foundation
import UIKit
import UniformTypeIdentifiers

public class AudioInfoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "audio_info", binaryMessenger: registrar.messenger())
    let instance = AudioInfoPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInfo":
      guard let filePath = argument(named: "filePath", from: call) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "File path is required", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let info = self.getInfo(filePath: filePath)
        DispatchQueue.main.async { result(info) }
      }
    case "getEmbeddedPicture":
      guard let filePath = argument(named: "filePath", from: call) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "File path is required", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let picture = self.getEmbeddedPicture(filePath: filePath)
        DispatchQueue.main.async { result(picture) }
      }
    case "getWaveform":
      guard let filePath = argument(named: "filePath", from: call) else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "File path is required", details: nil))
        return
      }
      let arguments = call.arguments as? [String: Any]
      let sampleCount = arguments?["samples"] as? Int ?? 100
      DispatchQueue.global(qos: .userInitiated).async {
        let waveform = self.getWaveform(filePath: filePath, sampleCount: sampleCount)
        DispatchQueue.main.async { result(waveform) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func argument(named key: String, from call: FlutterMethodCall) -> String? {
    (call.arguments as? [String: Any])?[key] as? String
  }

  private func getInfo(filePath: String) -> [String: Any] {
    let url = URL(fileURLWithPath: filePath)
    let asset = AVURLAsset(url: url)
    let metadata = metadataMap(from: asset)
    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    let durationSeconds = CMTimeGetSeconds(asset.duration)
    let durationMs = durationSeconds.isFinite ? Int(durationSeconds * 1000) : 0
    let bitrate = estimatedBitrate(from: asset)
    let mimeType = detectMimeType(for: url)
    let hasArtwork = embeddedArtworkData(from: asset) != nil

    let year = firstNonEmpty([
      metadata["year"],
      extractYear(from: metadata["date"])
    ])
    let title = inferDisplayTitle(fileURL: url, rawTitle: metadata["title"] ?? "")

    return [
      "title": title,
      "album": metadata["album"] ?? "",
      "author": metadata["author"] ?? "",
      "writer": metadata["writer"] ?? "",
      "artist": metadata["artist"] ?? "",
      "albumArtist": metadata["albumArtist"] ?? "",
      "composer": metadata["composer"] ?? "",
      "genre": metadata["genre"] ?? "",
      "year": year,
      "date": metadata["date"] ?? "",
      "compilation": metadata["compilation"] ?? "",
      "trackNumber": metadata["trackNumber"] ?? "",
      "discNumber": metadata["discNumber"] ?? "",
      "durationMs": durationMs,
      "durationSec": durationMs / 1000,
      "durationFormatted": formatDuration(ms: durationMs),
      "bitrate": bitrate,
      "bitrateKbps": bitrate / 1000,
      "mimeType": mimeType,
      "fileSizeBytes": fileSize,
      "fileSizeMB": Double(fileSize) / (1024.0 * 1024.0),
      "quality": qualityLabel(mimeType: mimeType, bitrate: bitrate),
      "hasArtwork": hasArtwork,
    ]
  }

  private func getEmbeddedPicture(filePath: String) -> FlutterStandardTypedData? {
    let asset = AVURLAsset(url: URL(fileURLWithPath: filePath))
    guard let imageData = embeddedArtworkData(from: asset) else {
      return nil
    }
    return FlutterStandardTypedData(bytes: imageData)
  }

  /// Seek-based waveform: seeks to [sampleCount] evenly-spaced positions and reads
  /// a small chunk at each one. Avoids loading the entire file into memory.
  private func getWaveform(filePath: String, sampleCount: Int) -> [Double] {
    guard sampleCount > 0 else { return [] }

    let url = URL(fileURLWithPath: filePath)

    do {
      let file = try AVAudioFile(forReading: url)
      let totalFrames = file.length
      guard totalFrames > 0 else { return [] }

      let format = file.processingFormat
      let channelCount = Int(format.channelCount)
      let framesPerSlot = max(1, totalFrames / Int64(sampleCount))
      // Read at most 4 096 frames per slot; use stride=4 to halve CPU further.
      let chunkFrames = AVAudioFrameCount(min(framesPerSlot, 4_096))

      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
        return []
      }

      var waveform = [Double]()
      waveform.reserveCapacity(sampleCount)

      for slot in 0..<sampleCount {
        file.framePosition = Int64(slot) * framesPerSlot
        buffer.frameLength = 0
        do { try file.read(into: buffer, frameCount: chunkFrames) } catch { waveform.append(0); continue }

        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else {
          waveform.append(0); continue
        }

        let frames = Int(buffer.frameLength)
        var peak: Float = 0
        var frameIndex = 0
        while frameIndex < frames {
          var mixed: Float = 0
          for ch in 0..<channelCount { mixed += channelData[ch][frameIndex] }
          mixed /= Float(channelCount)
          let a = mixed < 0 ? -mixed : mixed
          if a > peak { peak = a }
          frameIndex += 4  // stride — sample every 4th frame
        }
        waveform.append(Double(peak))
      }

      return waveform
    } catch {
      NSLog("AudioInfo waveform extraction error for \(filePath): \(error.localizedDescription)")
      return []
    }
  }

private func metadataMap(from asset: AVURLAsset) -> [String: String] {
    var values: [String: String] = [:]

    for item in asset.commonMetadata {
      guard let key = item.commonKey?.rawValue else {
        continue
      }

      switch key {
      case AVMetadataKey.commonKeyTitle.rawValue:
        values["title"] = metadataString(from: item)
      case AVMetadataKey.commonKeyAlbumName.rawValue:
        values["album"] = metadataString(from: item)
      case AVMetadataKey.commonKeyArtist.rawValue:
        values["artist"] = metadataString(from: item)
      case AVMetadataKey.commonKeyCreator.rawValue:
        values["author"] = metadataString(from: item)
      case AVMetadataKey.commonKeyContributor.rawValue:
        values["writer"] = metadataString(from: item)
      case AVMetadataKey.commonKeyType.rawValue:
        if values["compilation"]?.isEmpty ?? true {
          values["compilation"] = metadataString(from: item)
        }
      case AVMetadataKey.commonKeyCreationDate.rawValue:
        values["date"] = metadataString(from: item)
      case AVMetadataKey.commonKeySubject.rawValue:
        if values["genre"]?.isEmpty ?? true {
          values["genre"] = metadataString(from: item)
        }
      default:
        break
      }
    }

    for item in asset.metadata {
      let keySpace = item.keySpace?.rawValue ?? ""
      let key = metadataKeyString(from: item) ?? ""
      let lowercasedKey = key.lowercased()
      let value = metadataString(from: item)

      guard !value.isEmpty else {
        continue
      }

      if matches(lowercasedKey, rawKey: key, expected: ["albumartist", "album artist", "aART"]) {
        values["albumArtist"] = value
      } else if matches(lowercasedKey, rawKey: key, expected: ["composer", "©wrt"]) {
        values["composer"] = value
      } else if matches(lowercasedKey, rawKey: key, expected: ["genre", "©gen", "gnre"]) {
        values["genre"] = value
      } else if matches(lowercasedKey, rawKey: key, expected: ["writer", "©lyr", "lyricist"]) {
        values["writer"] = value
      } else if matches(lowercasedKey, rawKey: key, expected: ["author"]) {
        values["author"] = value
      } else if matches(lowercasedKey, rawKey: key, expected: ["date", "©day"]) {
        values["date"] = value
      } else if matches(lowercasedKey, rawKey: key, expected: ["year"]) {
        values["year"] = value
      } else if matches(lowercasedKey, rawKey: key, expected: ["tracknumber", "trkn"]) {
        values["trackNumber"] = decodeNumberPair(item) ?? value
      } else if matches(lowercasedKey, rawKey: key, expected: ["discnumber", "disk"]) {
        values["discNumber"] = decodeNumberPair(item) ?? value
      } else if matches(lowercasedKey, rawKey: key, expected: ["compilation", "cpil"]) {
        values["compilation"] = decodeCompilation(item) ?? value
      }

      if keySpace == AVMetadataKeySpace.id3.rawValue {
        if lowercasedKey.contains("band") || lowercasedKey.contains("albumsort") {
          values["albumArtist"] = values["albumArtist"] ?? value
        }
      }
    }

    return values
  }

  private func embeddedArtworkData(from asset: AVURLAsset) -> Data? {
    for item in asset.commonMetadata where item.commonKey == .commonKeyArtwork {
      if let dataValue = item.dataValue {
        return dataValue
      }
      if let value = item.value as? Data {
        return value
      }
    }

    for item in asset.metadata {
      if let dataValue = item.dataValue {
        let key = metadataKeyString(from: item)?.lowercased() ?? ""
        if key.contains("covr") || key.contains("apic") || key.contains("artwork") {
          return dataValue
        }
      }
    }

    return nil
  }

  private func estimatedBitrate(from asset: AVURLAsset) -> Int {
    if let track = asset.tracks(withMediaType: .audio).first {
      return Int(track.estimatedDataRate)
    }
    return 0
  }

  private func detectMimeType(for url: URL) -> String {
    let fileExtension = url.pathExtension

    if #available(iOS 14.0, *),
       let type = UTType(filenameExtension: fileExtension),
       let mimeType = type.preferredMIMEType {
      return mimeType
    }

    switch fileExtension.lowercased() {
    case "mp3":
      return "audio/mpeg"
    case "m4a", "mp4", "aac":
      return "audio/mp4"
    case "wav":
      return "audio/wav"
    case "flac":
      return "audio/flac"
    case "ogg":
      return "audio/ogg"
    default:
      return ""
    }
  }

  private func qualityLabel(mimeType: String, bitrate: Int) -> String {
    if mimeType.localizedCaseInsensitiveContains("flac") {
      return "lossless"
    }
    if bitrate >= 320_000 {
      return "high"
    }
    if bitrate >= 192_000 {
      return "medium"
    }
    if bitrate > 0 {
      return "low"
    }
    return "unknown"
  }

  private func inferDisplayTitle(fileURL: URL, rawTitle: String) -> String {
    if !rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return rawTitle
    }

    let baseName = fileURL.deletingPathExtension().lastPathComponent
    guard !baseName.isEmpty else {
      return ""
    }

    let path = fileURL.path.lowercased()
    let isWhatsApp = path.contains("whatsapp")
      || baseName.uppercased().hasPrefix("PTT-")
      || baseName.uppercased().hasPrefix("AUD-")
      || baseName.uppercased().contains("-WA")

    if isWhatsApp {
      if baseName.uppercased().hasPrefix("PTT-") || path.contains("voice notes") {
        return "WhatsApp Voice Note"
      }
      return "WhatsApp Audio"
    }

    return baseName
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func formatDuration(ms: Int) -> String {
    let totalSeconds = ms / 1000
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
      return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
  }

  private func metadataString(from item: AVMetadataItem) -> String {
    if let stringValue = item.stringValue {
      return stringValue
    }
    if let numberValue = item.numberValue {
      return numberValue.stringValue
    }
    if let dataValue = item.dataValue, let stringValue = String(data: dataValue, encoding: .utf8) {
      return stringValue
    }
    return ""
  }

  private func metadataKeyString(from item: AVMetadataItem) -> String? {
    if let key = item.key as? String {
      return key
    }
    if let number = item.key as? NSNumber {
      if let fourChar = fourCharCode(from: number.uint32Value) {
        return fourChar
      }
      return number.stringValue
    }
    return nil
  }

  private func fourCharCode(from value: UInt32) -> String? {
    let bytes: [CChar] = [
      CChar((value >> 24) & 0xff),
      CChar((value >> 16) & 0xff),
      CChar((value >> 8) & 0xff),
      CChar(value & 0xff),
      0,
    ]

    let string = String(cString: bytes)
    return string.trimmingCharacters(in: .controlCharacters)
  }

  private func decodeNumberPair(_ item: AVMetadataItem) -> String? {
    if let value = item.value as? Data {
      let bytes = [UInt8](value)
      guard bytes.count >= 6 else {
        return nil
      }

      let current = Int(bytes[3])
      let total = Int(bytes[5])
      if total > 0 {
        return "\(current)/\(total)"
      }
      return "\(current)"
    }

    return item.numberValue?.stringValue
  }

  private func decodeCompilation(_ item: AVMetadataItem) -> String? {
    if let number = item.numberValue {
      return number.intValue == 0 ? "false" : "true"
    }

    if let dataValue = item.dataValue?.first {
      return dataValue == 0 ? "false" : "true"
    }

    return nil
  }

  private func matches(_ lowercasedKey: String, rawKey: String, expected: [String]) -> Bool {
    expected.contains { candidate in
      lowercasedKey == candidate.lowercased() || rawKey == candidate
    }
  }

  private func firstNonEmpty(_ values: [String?]) -> String {
    for value in values {
      if let value, !value.isEmpty {
        return value
      }
    }
    return ""
  }

  private func extractYear(from dateString: String?) -> String {
    guard let dateString, dateString.count >= 4 else {
      return ""
    }
    return String(dateString.prefix(4))
  }
}
