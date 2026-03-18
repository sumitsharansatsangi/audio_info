import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_info/audio_info.dart';
import 'package:audio_info/audio_info_platform_interface.dart';
import 'package:audio_info/audio_info_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAudioInfoPlatform
    with MockPlatformInterfaceMixin
    implements AudioInfoPlatform {
  @override
  Future<AudioData?> getAudioInfo(String filePath) => Future.value(
        AudioData.fromMap({
          'title': 'Test Title',
          'writer': 'Test Writer',
          'date': '2026-03-18',
          'compilation': 'true',
          'durationMs': 42000,
          'durationSec': 42,
          'durationFormatted': '00:42',
          'bitrate': 128000,
          'bitrateKbps': 128,
          'mimeType': 'audio/mpeg',
          'fileSizeBytes': 1024,
          'fileSizeMB': 0.001,
          'quality': 'low',
          'hasArtwork': true,
        }),
      );

  @override
  Future<Uint8List?> getAudioImage(String filePath) async =>
      Uint8List.fromList(<int>[1, 2, 3]);

  @override
  Future<List<double>> getWaveform(String filePath, {int samples = 100}) async =>
      <double>[0.1, 0.5, 0.9];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final AudioInfoPlatform initialPlatform = AudioInfoPlatform.instance;

  test('$MethodChannelAudioInfo is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAudioInfo>());
  });

  test('getAudioInfo delegates through the platform interface', () async {
    final MockAudioInfoPlatform fakePlatform = MockAudioInfoPlatform();
    AudioInfoPlatform.instance = fakePlatform;

    final info = await AudioInfo.getAudioInfo('/tmp/audio.mp3');

    expect(info, isNotNull);
    expect(info!.title, 'Test Title');
    expect(info.writer, 'Test Writer');
    expect(info.date, '2026-03-18');
    expect(info.compilation, 'true');
    expect(info.durationFormatted, '00:42');
  });

  test('getAudioImage delegates through the platform interface', () async {
    AudioInfoPlatform.instance = MockAudioInfoPlatform();

    final image = await AudioInfo.getAudioImage('/tmp/audio.mp3');

    expect(image, isNotNull);
    expect(image, hasLength(3));
  });

  test('getWaveform delegates through the platform interface', () async {
    AudioInfoPlatform.instance = MockAudioInfoPlatform();

    final waveform = await AudioInfo.getWaveform('/tmp/audio.mp3', samples: 3);

    expect(waveform, <double>[0.1, 0.5, 0.9]);
  });

  tearDown(() {
    AudioInfoPlatform.instance = initialPlatform;
  });
}
