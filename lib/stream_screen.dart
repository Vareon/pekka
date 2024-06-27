import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/session_state.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:io';
import 'gallery_screen.dart';

class StreamScreen extends StatefulWidget {
  final String cameraUrl;

  const StreamScreen({Key? key, required this.cameraUrl}) : super(key: key);

  @override
  _StreamScreenState createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late VideoPlayerController _controller;
  late WebSocketChannel _channel;
  bool isRecording = false;
  late String _tempFilePath;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
    _initializeVideoPlayer();
    _checkConnectivityAndUpload();
  }

  void _initializeWebSocket() {
    _channel = WebSocketChannel.connect(Uri.parse(widget.cameraUrl));
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      final directory = await getTemporaryDirectory();
      _tempFilePath = '${directory.path}/temp_video.mp4';
      _controller = VideoPlayerController.file(File(_tempFilePath))
        ..initialize().then((_) {
          setState(() {});
          _controller.play();
        }).catchError((error) {
          print('Error initializing video player: $error');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load video stream: $error'),
          ));
        });
    } catch (e) {
      print('Exception initializing video player: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Exception occurred: $e'),
      ));
    }
  }

  Future<void> _checkConnectivityAndUpload() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi) {
      final directory = await getExternalStorageDirectory();
      final pekkaDir = Directory('${directory!.path}/Pekka');
      final files = pekkaDir.listSync().whereType<File>().toList();

      for (var file in files) {
        final fileName = file.path.split('/').last;
        final fileType = fileName.split('.').last;
        await uploadFileToFirebase(file.path, fileName.split('.').first, fileType);
      }
    }
  }

  Future<void> uploadFileToFirebase(String filePath, String fileName, String type) async {
    final File file = File(filePath);
    try {
      final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName.$type');
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();
      debugPrint("File uploaded to Firebase: $downloadUrl");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('File uploaded to Firebase: $downloadUrl'),
      ));
    } catch (e) {
      debugPrint("Failed to upload to Firebase: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to upload to Firebase: $e'),
      ));
    }
  }

  Future<void> saveFileToGallery(String filePath, String fileType) async {
    if (fileType == 'jpg' || fileType == 'jpeg' || fileType == 'png') {
      await GallerySaver.saveImage(filePath);
    } else if (fileType == 'mp4') {
      await GallerySaver.saveVideo(filePath);
    }
  }

  Future<String> getCustomFilePath(String fileName, String type) async {
    final directory = await getExternalStorageDirectory();
    final path = '${directory!.path}/Pekka';
    final pekkaDir = Directory(path);

    if (!(await pekkaDir.exists())) {
      await pekkaDir.create(recursive: true);
    }

    return '$path/$fileName.$type';
  }

  Future<void> _startRecording() async {
    final filePath = await getCustomFilePath('video_${DateTime.now().millisecondsSinceEpoch}', 'mp4');
    FFmpegKit.executeAsync(
      '-i ${widget.cameraUrl} -c:v copy -c:a copy $filePath',
          (session) async {
        final returnCode = await session.getReturnCode();
        final sessionState = await session.getState();
        if (returnCode == 0 && sessionState == SessionState.completed) {
          setState(() {
            isRecording = false;
          });
          await saveFileToGallery(filePath, 'mp4');
          await uploadFileToFirebase(filePath, 'video_${DateTime.now().millisecondsSinceEpoch}', 'mp4');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Video saved to $filePath'),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to record video'),
          ));
        }
      },
    );
    setState(() {
      isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    await FFmpegKit.cancel();
    setState(() {
      isRecording = false;
    });
  }

  Future<void> _takePicture() async {
    final filePath = await getCustomFilePath('image_${DateTime.now().millisecondsSinceEpoch}', 'jpg');
    FFmpegKit.executeAsync(
      '-i ${widget.cameraUrl} -vframes 1 $filePath',
          (session) async {
        final returnCode = await session.getReturnCode();
        final sessionState = await session.getState();
        if (returnCode == 0 && sessionState == SessionState.completed) {
          await saveFileToGallery(filePath, 'jpg');
          await uploadFileToFirebase(filePath, 'image_${DateTime.now().millisecondsSinceEpoch}', 'jpg');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Image saved to $filePath'),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to take picture'),
          ));
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pekka - Raspberry Pi Stream')),
      body: Center(
        child: StreamBuilder(
          stream: _channel.stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              return AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              );
            } else if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            } else {
              return CircularProgressIndicator();
            }
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              heroTag: 'take_picture', // Ensure unique hero tags
              onPressed: _takePicture,
              child: Icon(Icons.camera_alt),
            ),
            FloatingActionButton(
              heroTag: 'record_video', // Ensure unique hero tags
              onPressed: isRecording ? _stopRecording : _startRecording,
              child: Icon(isRecording ? Icons.stop : Icons.videocam),
            ),
            FloatingActionButton(
              heroTag: 'open_gallery', // Ensure unique hero tags
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GalleryScreen()), // Ensure GalleryScreen is imported correctly
                );
              },
              child: Icon(Icons.folder),
            ),
          ],
        ),
      ),
    );
  }
}
