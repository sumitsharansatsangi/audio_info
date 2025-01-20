import 'dart:async';
import 'package:flutter/services.dart';

/// The `AudioInfo` class is responsible for retrieving audio metadata and embedded images 
/// from audio files using method channels.
class AudioInfo {
  // Method channel used for communication between Flutter and native code
  static const MethodChannel _channel = MethodChannel('audio_info');

  /// Retrieves audio information for a given file path.
  ///
  /// The [filePath] parameter specifies the path to the audio file.
  /// Returns an `AudioData` object containing the metadata, or `null` if the information could not be retrieved.
  static Future<AudioData?> getAudioInfo(String filePath) async {
    final audioInfoMap = await _channel.invokeMethod('getInfo', {'filePath': filePath});
    return audioInfoMap != null
        ? AudioData.fromMap(Map<String, dynamic>.from(audioInfoMap))
        : null;
  }

  /// Retrieves the embedded picture from the audio file, if available.
  ///
  /// The [filePath] parameter specifies the path to the audio file.
  /// Returns a `Uint8List` containing the image data, or `null` if no embedded picture is found.
  static Future<Uint8List?> getAudioImage(String filePath) async {
    final audioEmbeddedPicture = await _channel.invokeMethod('getEmbeddedPicture', {'filePath': filePath});
    return audioEmbeddedPicture.isNotEmpty
        ? Uint8List.fromList(audioEmbeddedPicture)
        : null;
  }
}

/// The `AudioData` class represents the metadata information of an audio file.
class AudioData {
  /// Constructs an `AudioData` object with the specified metadata fields. ///
  /// 
  /// The [title] field represents the title of the audio track.
  final String title;
   /// The [album] field represents the album name. ///
  final String album;
  /// The [author] field represents the author of the track. ///
  final String author;
  /// The [artist] field represents the performing artist. ///
  final String artist;
  /// The [albumArtist] field represents the album artist. ///
  final String albumArtist;
  /// The [composer] field represents the composer of the track. ///
  final String composer;
  /// The [genre] field represents the genre of the track. ///
  final String genre;
  /// The [year] field represents the year of release. ///
  final String year;
  /// The [track] field represents the track number. ///
  final String track;
  /// The [duration] field represents the duration of the track in seconds. ///
  final String duration;
  /// The [bitRate] field represents the bitrate of the audio file. ///
  final String bitRate;
  /// The [compilation] field represents whether the track is part of a compilation. ///
  final String compilation;
  /// The [date] field represents the release date. ///
  final String date;
  /// The [discNumber] field represents the disc number. ///
  final String discNumber;

  /// Constructs an `AudioData` object with the specified metadata fields.
  AudioData({
    required this.title,
    required this.album,
    required this.author,
    required this.artist,
    required this.albumArtist,
    required this.composer,
    required this.genre,
    required this.year,
    required this.track,
    required this.duration,
    required this.bitRate,
    required this.compilation,
    required this.date,
    required this.discNumber,
  });

  /// Creates an `AudioData` object from a map of key-value pairs.
  ///
  /// The [map] parameter is a map containing the metadata fields and their corresponding values.
  factory AudioData.fromMap(Map<String, dynamic> map) {
    return AudioData(
      title: map['title'] ?? "",
      album: map['album'] ?? "",
      author: map['author'] ?? "",
      artist: map['artist'] ?? "",
      albumArtist: map['albumArtist'] ?? "",
      composer: map['composer'] ?? "",
      genre: map['genre'] ?? "",
      year: map['year'] ?? "",
      track: map['track'] ?? "",
      duration: map['duration'] ?? "",
      bitRate: map['bitRate'] ?? "",
      compilation: map['compilation'] ?? "",
      date: map['date'] ?? "",
      discNumber: map['discNumber'] ?? "",
    );
  }
}
