import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:io';
import 'websocket.dart';
import 'gallery_screen.dart';

class VideoStream extends StatefulWidget {
  const VideoStream({Key? key}) : super(key: key);

  @override
  State<VideoStream> createState() => _VideoStreamState();
}

class _VideoStreamState extends State<VideoStream> {
  final WebSocket _socket = WebSocket("ws://192.168.231.87:5050");
  bool _isConnected = false;
  Uint8List? _currentFrame;
  bool isRecording = false;
  List<Uint8List> recordedFrames = [];
  late String videoFilePath;
  late String imageFilePath;

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndUpload();
  }

  @override
  void dispose() {
    _socket.close();
    super.dispose();
  }

  void connect(BuildContext context) async {
    _socket.connect();
    setState(() {
      _isConnected = true;
    });
  }

  void disconnect() {
    _socket.disconnect();
    setState(() {
      _isConnected = false;
    });
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

  void captureFrame(Uint8List frameData) async {
    imageFilePath = await getCustomFilePath('photo_${DateTime.now().millisecondsSinceEpoch}', 'jpg');
    final file = File(imageFilePath);
    await file.writeAsBytes(frameData);
    await saveFileToGallery(imageFilePath, 'jpg');
    await uploadFileToFirebase(imageFilePath, 'photo_${DateTime.now().millisecondsSinceEpoch}', 'jpg');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Frame captured and saved to $imageFilePath'),
    ));
  }

  void startRecording() {
    recordedFrames = [];
    isRecording = true;
    setState(() {});
  }

  void stopRecording() async {
    isRecording = false;
    videoFilePath = await getCustomFilePath('video_${DateTime.now().millisecondsSinceEpoch}', 'mp4');
    final file = File(videoFilePath);
    final videoData = recordedFrames.expand((x) => x).toList();
    await file.writeAsBytes(videoData);
    await saveFileToGallery(videoFilePath, 'mp4');
    await uploadFileToFirebase(videoFilePath, 'video_${DateTime.now().millisecondsSinceEpoch}', 'mp4');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Video saved to $videoFilePath'),
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Canlı Video"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => connect(context),
                    child: const Text("Bağlan"),
                  ),
                  ElevatedButton(
                    onPressed: disconnect,
                    child: const Text("Bağlantıyı kes"),
                  ),
                ],
              ),
              const SizedBox(
                height: 50.0,
              ),
              _isConnected
                  ? StreamBuilder(
                stream: _socket.stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  if (snapshot.connectionState == ConnectionState.done) {
                    return const Center(
                      child: Text("Bağlantı kapandı !"),
                    );
                  }
                  _currentFrame = Uint8List.fromList(base64Decode(snapshot.data.toString()));
                  if (isRecording && _currentFrame != null) {
                    recordedFrames.add(_currentFrame!);
                  }
                  return Image.memory(
                    _currentFrame!,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                  );
                },
              )
                  : const Text("Bağlantı Bekleniyor"),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      onPressed: () {
                        if (_currentFrame != null) {
                          captureFrame(_currentFrame!);
                        }
                      },
                      child: Icon(Icons.camera),
                    ),
                    FloatingActionButton(
                      onPressed: () {
                        if (isRecording) {
                          stopRecording();
                        } else {
                          startRecording();
                        }
                      },
                      child: Icon(isRecording ? Icons.stop : Icons.videocam),
                    ),
                    FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => GalleryScreen()),
                        );
                      },
                      child: Icon(Icons.folder),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
