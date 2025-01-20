import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_info_platform_interface.dart';

/// An implementation of [AudioInfoPlatform] that uses method channels.
class MethodChannelAudioInfo extends AudioInfoPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audio_info');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
