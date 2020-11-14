import 'dart:async';
import 'dart:io';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:barcode_scan/gen/protos/protos.pbenum.dart';
import 'package:camera/camera.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:modelingobject/scanner_utils.dart';
import 'package:path_provider/path_provider.dart';

class ReadCamera extends StatefulWidget {
  ReadCamera({Key key}) : super(key: key);

  @override
  _ReadCameraState createState() => _ReadCameraState();
}

class _ReadCameraState extends State<ReadCamera> {
  CameraLensDirection _direction = CameraLensDirection.back;
  CameraController _camera;
  String _text;
  File _picture;
  String _urlFirestore;
  String _codeBarr = '';

  @override
  Widget build(BuildContext context) {
    return starCamera();
  }

  Widget starCamera() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Read Product'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _camera == null
                  ? Container(
                      color: Theme.of(context).primaryColor,
                      child: Center(
                        child: Text(
                          'Error init camera...',
                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  : Container(
                      height: MediaQuery.of(context).size.height - 100,
                      child: CameraPreview(
                        _camera,
                      ),
                    ),
            ],
          ),
          Positioned(
            bottom: (MediaQuery.of(context).size.height / 2) - 40,
            left: (MediaQuery.of(context).size.width / 2) - 40,
            child: Column(
              children: [
                Container(
                  height: 80.0,
                  width: 80.0,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: IconButton(
                    onPressed: () {
                      seekTextinPicture();
                    },
                    icon: Icon(
                      Icons.camera,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  height: 15.0,
                ),
                Container(
                  child: Text(
                    'Press seek text',
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _camera?.dispose();
  }

  void initCamera() async {
    _text = '';
    final CameraDescription _description = await ScannerUtils.getCamera(_direction);
    setState(() {
      _camera = CameraController(
        _description,
        ResolutionPreset.medium,
      );
    });

    await _camera.initialize();
    print('Camara ready');
  }

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<String> scan() async {
    try {
      var options = ScanOptions(
        strings: {
          "cancel": "Cancel",
          "flash_on": "Flash on",
          "flash_off": "Flash off",
        },
        // restrictFormat: selectedFormats,
        useCamera: -1,
        autoEnableFlash: true,
        android: AndroidOptions(
          aspectTolerance: 0.0,
          useAutoFocus: true,
        ),
      );

      var result = await BarcodeScanner.scan(options: options);

      print('BarCode: ${result.rawContent}');

      return result.rawContent.toString();
    } on PlatformException catch (e) {
      var result = ScanResult(
        type: ResultType.Error,
      );

      if (e.code == BarcodeScanner.cameraAccessDenied) {
        setState(() {
          result.rawContent = 'The user did not grant the camera permission!';
        });
      } else {
        result.rawContent = 'Unknown error: $e';
      }
      return result.rawContent.toString();
    }
  }

  void seekTextinPicture() async {
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path + "/" + DateTime.now().millisecond.toString();
    await _camera.initialize();
    await _camera.takePicture(tempPath);

    final TextRecognizer textRecognizer = FirebaseVision.instance.textRecognizer();
    FirebaseVisionImage preProcessImage = new FirebaseVisionImage.fromFilePath(tempPath);

    VisionText textRecognized = await textRecognizer.processImage(preProcessImage);
    String text = textRecognized.text;

    setState(() {
      _text = text;
    });

    if (_text.length > 0) {
      _picture = await ImagePicker.pickImage(source: ImageSource.camera);
      if (_picture != null) {
        _codeBarr = await scan();
        uploadPictures();
        setState(() {
          _text = '';
        });
      }
    }
  }

  void uploadPictures() async {
    final StorageReference postImageRef = FirebaseStorage.instance.ref().child("Product");
    var timeKey = DateTime.now();
    final StorageUploadTask uploadTask = postImageRef.child("product_" + timeKey.toString() + ".jpg").putFile(_picture);
    var imageUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
    _urlFirestore = imageUrl.toString();
    print('url firestore $_urlFirestore');
    saveToDatabase(_urlFirestore);
  }

  void saveToDatabase(String url) {
    var dbTimeKey = DateTime.now();
    var formatDate = DateFormat('MMM, d, yyyy');
    var formatTime = DateFormat('EEEE, hh:mm aaa');
    String date = formatDate.format(dbTimeKey);
    String time = formatTime.format(dbTimeKey);

    DatabaseReference ref = FirebaseDatabase.instance.reference();
    var data = {
      "image": url,
      "codbarra": _codeBarr,
      "date": date,
      "time": time,
    };
    ref.child("ProductImage").push().set(data);
  }
}
