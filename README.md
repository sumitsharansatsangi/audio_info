# audio_info

`audio_info` is a Flutter plugin for reading audio metadata, embedded artwork, and lightweight waveform samples from a local audio file.

Current platform support:
- Android

## Features

- Read common metadata such as title, album, artist, composer, genre, year, track, and disc number
- Read extended metadata including author, writer, date, and compilation
- Read technical information such as duration, bitrate, mime type, file size, and quality classification
- Extract embedded album artwork
- Generate waveform sample data for simple visualizations

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  audio_info: ^0.0.4
```

## Import

```dart
import 'package:audio_info/audio_info.dart';
import 'package:audio_info/waveform_widget.dart';
```

## API

### Read metadata

```dart
final AudioData? info = await AudioInfo.getAudioInfo(filePath);
```

### Read embedded artwork

```dart
final Uint8List? artwork = await AudioInfo.getAudioImage(filePath);
```

### Read waveform data

```dart
final List<double> waveform = await AudioInfo.getWaveform(
  filePath,
  samples: 120,
);
```

## AudioData fields

`AudioData` currently exposes:

- `title`
- `album`
- `author`
- `writer`
- `artist`
- `albumArtist`
- `composer`
- `genre`
- `year`
- `date`
- `compilation`
- `trackNumber`
- `discNumber`
- `durationMs`
- `durationSec`
- `durationFormatted`
- `bitrate`
- `bitrateKbps`
- `mimeType`
- `fileSizeBytes`
- `fileSizeMB`
- `quality`
- `hasArtwork`

## Example

```dart
import 'dart:typed_data';

import 'package:audio_info/audio_info.dart';
import 'package:audio_info/waveform_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: AudioInfoScreen(),
    );
  }
}

class AudioInfoScreen extends StatelessWidget {
  const AudioInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Info Plugin')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => pickFile(context),
          child: const Text('Choose Audio file'),
        ),
      ),
    );
  }

  Future<void> pickFile(BuildContext context) async {
    final FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.audio);

    if (result == null || result.files.single.path == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio file selected')),
        );
      }
      return;
    }

    final String filePath = result.files.single.path!;
    final AudioData? audioInfo = await AudioInfo.getAudioInfo(filePath);
    final Uint8List? embeddedPicture = await AudioInfo.getAudioImage(filePath);
    final List<double> waveform = await AudioInfo.getWaveform(
      filePath,
      samples: 120,
    );

    if (audioInfo == null || !context.mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Audio Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (embeddedPicture != null) Image.memory(embeddedPicture),
                if (waveform.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Waveform'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 320,
                    height: 100,
                    child: WaveformWidget(waveform: waveform),
                  ),
                ],
                const SizedBox(height: 16),
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
                Text('Disc Number: ${audioInfo.discNumber}'),
                Text('Duration: ${audioInfo.durationFormatted}'),
                Text('Bitrate: ${audioInfo.bitrateKbps} kbps'),
                Text('Mime Type: ${audioInfo.mimeType}'),
                Text('Quality: ${audioInfo.quality}'),
                Text(
                  'File Size: ${audioInfo.fileSizeMB.toStringAsFixed(2)} MB',
                ),
                Text('Has Artwork: ${audioInfo.hasArtwork}'),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

## Notes

- `getWaveform` returns sampled amplitude values intended for lightweight UI rendering.
- The waveform output is approximate and depends on the source format and Android media stack behavior.
- Metadata availability varies by audio file format and embedded tags.

## Contributing

Issues and pull requests are welcome on the repository:

`https://github.com/sumitsharansatsangi/audio_info/`

## License

This project is licensed under the MIT License. See `LICENSE`.
