import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_info_method_channel.dart';
import 'audio_info.dart';

abstract class AudioInfoPlatform extends PlatformInterface {
  /// Constructs a AudioInfoPlatform.
  AudioInfoPlatform() : super(token: _token);

  static final Object _token = Object();

  static AudioInfoPlatform _instance = MethodChannelAudioInfo();

  /// The default instance of [AudioInfoPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioInfo].
  static AudioInfoPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudioInfoPlatform] when
  /// they register themselves.
  static set instance(AudioInfoPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<AudioData?> getAudioInfo(String filePath) {
    throw UnimplementedError('getAudioInfo() has not been implemented.');
  }

  Future<Uint8List?> getAudioImage(String filePath) {
    throw UnimplementedError('getAudioImage() has not been implemented.');
  }

  Future<List<double>> getWaveform(String filePath, {int samples = 100}) {
    throw UnimplementedError('getWaveform() has not been implemented.');
  }
}
