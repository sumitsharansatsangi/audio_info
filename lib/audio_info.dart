import 'dart:async';

import 'dart:typed_data';

import 'audio_info_platform_interface.dart';

/// The `AudioInfo` class is responsible for retrieving audio metadata and embedded images 
/// from audio files using method channels.
class AudioInfo {
  /// Retrieves audio information for a given file path.
  ///
  /// The [filePath] parameter specifies the path to the audio file.
  /// Returns an `AudioData` object containing the metadata, or `null` if the information could not be retrieved.
  static Future<AudioData?> getAudioInfo(String filePath) async {
    return AudioInfoPlatform.instance.getAudioInfo(filePath);
  }

  /// Retrieves the embedded picture from the audio file, if available.
  ///
  /// The [filePath] parameter specifies the path to the audio file.
  /// Returns a `Uint8List` containing the image data, or `null` if no embedded picture is found.
  static Future<Uint8List?> getAudioImage(String filePath) async {
    return AudioInfoPlatform.instance.getAudioImage(filePath);
  }

  static Future<List<double>> getWaveform(String filePath, {int samples = 100}) {
    return AudioInfoPlatform.instance.getWaveform(filePath, samples: samples);
  }
}

/// The `AudioData` class represents the metadata information of an audio file.
class AudioData {
  final String title;
  final String album;
  final String author;
  final String writer;
  final String artist;
  final String albumArtist;
  final String composer;
  final String genre;
  final String year;
  final String date;
  final String compilation;

  final String trackNumber;
  final String discNumber;

  // 🔥 Proper typed fields
  final int durationMs;
  final int durationSec;
  final String durationFormatted;

  final int bitrate;
  final int bitrateKbps;

  final String mimeType;

  final int fileSizeBytes;
  final double fileSizeMB;

  final String quality;

  final bool hasArtwork;

  AudioData({
    required this.title,
    required this.album,
    required this.author,
    required this.writer,
    required this.artist,
    required this.albumArtist,
    required this.composer,
    required this.genre,
    required this.year,
    required this.date,
    required this.compilation,
    required this.trackNumber,
    required this.discNumber,
    required this.durationMs,
    required this.durationSec,
    required this.durationFormatted,
    required this.bitrate,
    required this.bitrateKbps,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.fileSizeMB,
    required this.quality,
    required this.hasArtwork,
  });

  factory AudioData.fromMap(Map<String, dynamic> map) {
    return AudioData(
      title: map['title'] ?? "",
      album: map['album'] ?? "",
      author: map['author'] ?? "",
      writer: map['writer'] ?? "",
      artist: map['artist'] ?? "",
      albumArtist: map['albumArtist'] ?? "",
      composer: map['composer'] ?? "",
      genre: map['genre'] ?? "",
      year: map['year'] ?? "",
      date: map['date'] ?? "",
      compilation: map['compilation'] ?? "",
      trackNumber: map['trackNumber'] ?? "",
      discNumber: map['discNumber'] ?? "",
      durationMs: map['durationMs'] ?? 0,
      durationSec: map['durationSec'] ?? 0,
      durationFormatted: map['durationFormatted'] ?? "00:00",
      bitrate: map['bitrate'] ?? 0,
      bitrateKbps: map['bitrateKbps'] ?? 0,
      mimeType: map['mimeType'] ?? "",
      fileSizeBytes: map['fileSizeBytes'] ?? 0,
      fileSizeMB: (map['fileSizeMB'] ?? 0).toDouble(),
      quality: map['quality'] ?? "unknown",
      hasArtwork: map['hasArtwork'] ?? false,
    );
  }
}
