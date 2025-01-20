import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_info_method_channel.dart';

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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
