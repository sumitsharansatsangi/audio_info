import 'dart:typed_data';

import 'package:audio_info/audio_info.dart';
import 'package:audio_info/waveform_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const AudioInfoScreen(),
    );
  }
}

class AudioInfoScreen extends StatelessWidget {
  const AudioInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Audio Info Plugin')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Audio Info Plugin'),
            ElevatedButton(
              onPressed: () => pickFile(context),
              child: const Text('Choose Audio file'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickFile(BuildContext context) async {
    final FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      final String filePath = result.files.single.path!;
      final AudioData? audioInfo = await AudioInfo.getAudioInfo(filePath);
      final Uint8List? embeddedPicture = await AudioInfo.getAudioImage(filePath);
      final List<double> waveform = await AudioInfo.getWaveform(
        filePath,
        samples: 120,
      );
      if (audioInfo != null && context.mounted) {
        showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Audio Info'),
                content: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (embeddedPicture != null)
                          Image.memory(embeddedPicture),
                        if (waveform.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Waveform'),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 320,
                            height: 100,
                            child: WaveformWidget(waveform: waveform),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text('Title: ${audioInfo.title}'),
                        Text('Album: ${audioInfo.album}'),
                        Text('Author: ${audioInfo.author}'),
                        Text('Writer: ${audioInfo.writer}'),
                        Text('Artist: ${audioInfo.artist}'),
                        Text('Album Artist: ${audioInfo.albumArtist}'),
                        Text('Composer: ${audioInfo.composer}'),
                        Text('Genre: ${audioInfo.genre}'),
                        Text('Year: ${audioInfo.year}'),
                        Text('Date: ${audioInfo.date}'),
                        Text('Compilation: ${audioInfo.compilation}'),
                        Text('Track: ${audioInfo.trackNumber}'),
                        Text('Duration: ${audioInfo.durationFormatted}'),
                        Text('Bitrate: ${audioInfo.bitrateKbps} kbps'),
                        Text('Quality: ${audioInfo.quality}'),
                        Text('Disc Number: ${audioInfo.discNumber}'),
                        Text('Mime Type: ${audioInfo.mimeType}'),
                        Text(
                          'File Size: ${audioInfo.fileSizeMB.toStringAsFixed(2)} MB',
                        ),
                        Text('Has Artwork: ${audioInfo.hasArtwork}'),
                      ],
                    ),
                  ),
                ),
              );
            });
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('No audio file selected')));
        }
      }
    }
  }
}
