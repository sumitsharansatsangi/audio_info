import 'dart:async';
import 'package:flutter/services.dart';

class AudioInfo {
  static const MethodChannel _channel = MethodChannel('audio_info');

  static Future<AudioData?> getAudioInfo(String filePath) async {
    final audioInfoMap =
        await _channel.invokeMethod('getInfo', {'filePath': filePath});
    return audioInfoMap != null
        ? AudioData.fromMap(Map<String, dynamic>.from(audioInfoMap))
        : null;
  }

  static Future<Uint8List?> getAudioImage(String filePath) async {
    final audioEmbeddedPicture = await _channel
        .invokeMethod('getEmbeddedPicture', {'filePath': filePath});
    return audioEmbeddedPicture != null
        ? Uint8List.fromList(audioEmbeddedPicture)
        : null;
  }
}

class AudioData {
  final String title;
  final String album;
  final String author;
  final String artist;
  final String albumArtist;
  final String composer;
  final String genre;
  final String year;
  final String track;
  final String duration;
  final String bitRate;
  final String compilation;
  final String date;
  final String discNumber;

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
