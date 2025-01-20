import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:audio_info/audio_info.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AudioInfoScreen(),
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
            Text('Audio Info Plugin'),
            ElevatedButton(
              onPressed:()=> pickFile(context),
              child: Text('Choose Audio file'),
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
       AudioData? audioInfo = await AudioInfo.getAudioInfo(result.files.single.path!);
       Uint8List?  embeddedPicture = await AudioInfo.getAudioImage(result.files.single.path!);
       if(audioInfo != null && context.mounted){
      showDialog(context: context, builder: (context){
        return AlertDialog(
          title: Text('Audio Info'),
          content: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if(embeddedPicture != null)
                Image.memory(embeddedPicture),  
                Text('Title: ${audioInfo.title}'),
                Text('Album: ${audioInfo.album}'),
                Text('Author: ${audioInfo.author}'),
                Text('Artist: ${audioInfo.artist}'),
                Text('Album Artist: ${audioInfo.albumArtist}'),
                Text('Composer: ${audioInfo.composer}'),
                Text('Genre: ${audioInfo.genre}'),
                Text('Year: ${audioInfo.year}'),
                Text('Track: ${audioInfo.track}'),
                Text('Duration: ${ int.parse(audioInfo.duration) / 1000}s'),
                Text('BitRate: ${audioInfo.bitRate} kbps'),
                Text('Compilation: ${audioInfo.compilation}'),
                Text('Disc Number: ${audioInfo.discNumber}'),
                Text('Date: ${audioInfo.date}'),
              ],
            ),
          ),
        );
      });
      }else{
        if(context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No audio file selected')));
        }
      }
    }
  }
}


