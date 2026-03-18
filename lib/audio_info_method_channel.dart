import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_info.dart';
import 'audio_info_platform_interface.dart';

/// An implementation of [AudioInfoPlatform] that uses method channels.
class MethodChannelAudioInfo extends AudioInfoPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audio_info');

  @override
  Future<AudioData?> getAudioInfo(String filePath) async {
    final audioInfoMap = await methodChannel.invokeMapMethod<String, dynamic>(
      'getInfo',
      {'filePath': filePath},
    );
    return audioInfoMap == null ? null : AudioData.fromMap(audioInfoMap);
  }

  @override
  Future<Uint8List?> getAudioImage(String filePath) async {
    final result = await methodChannel.invokeMethod<List<Object?>>(
      'getEmbeddedPicture',
      {'filePath': filePath},
    );
    if (result == null || result.isEmpty) {
      return null;
    }

    return Uint8List.fromList(result.cast<int>());
  }

  @override
  Future<List<double>> getWaveform(String filePath, {int samples = 100}) async {
    final result = await methodChannel.invokeListMethod<Object?>(
      'getWaveform',
      {
        'filePath': filePath,
        'samples': samples,
      },
    );
    if (result == null) {
      return const <double>[];
    }

    return result.map((value) => (value as num).toDouble()).toList();
  }
}
