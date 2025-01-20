import 'package:flutter_test/flutter_test.dart';
import 'package:audio_info/audio_info.dart';
import 'package:audio_info/audio_info_platform_interface.dart';
import 'package:audio_info/audio_info_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAudioInfoPlatform
    with MockPlatformInterfaceMixin
    implements AudioInfoPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AudioInfoPlatform initialPlatform = AudioInfoPlatform.instance;

  test('$MethodChannelAudioInfo is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAudioInfo>());
  });

  test('getPlatformVersion', () async {
    MockAudioInfoPlatform fakePlatform = MockAudioInfoPlatform();
    AudioInfoPlatform.instance = fakePlatform;

    expect(await AudioInfo.getAudioInfo(""), '42');
  });
}
