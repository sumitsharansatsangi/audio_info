import 'package:flutter/services.dart';
import 'package:audio_info/audio_info_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelAudioInfo platform = MethodChannelAudioInfo();
  const MethodChannel channel = MethodChannel('audio_info');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getInfo':
            return <String, Object?>{
              'title': '42',
              'writer': 'Writer 42',
              'date': '2026-03-18',
              'compilation': 'false',
              'durationMs': 42000,
              'durationSec': 42,
              'durationFormatted': '00:42',
              'bitrate': 128000,
              'bitrateKbps': 128,
              'mimeType': 'audio/mpeg',
              'fileSizeBytes': 1024,
              'fileSizeMB': 0.001,
              'quality': 'low',
              'hasArtwork': false,
            };
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getAudioInfo', () async {
    final info = await platform.getAudioInfo('/tmp/audio.mp3');

    expect(info, isNotNull);
    expect(info!.title, '42');
    expect(info.writer, 'Writer 42');
    expect(info.date, '2026-03-18');
    expect(info.compilation, 'false');
  });
}
