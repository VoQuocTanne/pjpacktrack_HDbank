import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:aws_storage_service/aws_storage_service.dart';
import 'package:pjpacktrack/modules/ui/aws_config.dart';
import 'package:pjpacktrack/modules/ui/delivery_option.dart';

class RecordingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const RecordingScreen({super.key, required this.cameras});

  @override
  _RecordingScreenState createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  CameraController? _cameraController;
  MobileScannerController? _scannerController;
  bool _isRecording = false;
  bool _isScanning = true;
  bool _isFlashOn = false;
  String? _lastScannedCode;
  String? _selectedDeliveryOption;
  final List<String> _videoPaths = [];

  final AwsCredentialsConfig credentialsConfig = AwsCredentialsConfig(
    accessKey: AwsConfig.accessKey,
    secretKey: AwsConfig.secretKey,
    bucketName: AwsConfig.bucketName,
    region: AwsConfig.region,
  );

  @override
  void initState() {
    super.initState();
    _initializeScannerController();
  }

  void _initializeScannerController() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.qrCode],
    );
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
        enableAudio: true,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  void _toggleFlash() async {
    if (_isScanning) {
      await _scannerController?.toggleTorch();
      setState(() => _isFlashOn = !_isFlashOn);
    } else if (_cameraController != null) {
      try {
        final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
        await _cameraController!.setFlashMode(newFlashMode);
        setState(() => _isFlashOn = !_isFlashOn);
      } catch (e) {
        print('Flash toggle error: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    await _scannerController?.stop();
    await _initializeCamera();

    if (_cameraController != null && !_isRecording) {
      try {
        await _cameraController!.startVideoRecording();
        setState(() => _isRecording = true);
      } catch (e) {
        print('Recording start error: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController != null && _isRecording) {
      try {
        final XFile videoFile = await _cameraController!.stopVideoRecording();
        setState(() {
          _isRecording = false;
          _videoPaths.add(videoFile.path);
        });

        await _uploadVideoToAWS(videoFile.path);

        _cameraController?.dispose();
        _cameraController = null;

        setState(() {
          _isScanning = true;
          _lastScannedCode = null;
        });

        _initializeScannerController();
      } catch (e) {
        print('Recording stop error: $e');
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét QR & Quay Video'),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isScanning && !_isRecording && _selectedDeliveryOption != null)
            MobileScanner(
              controller: _scannerController,
              onDetect: (BarcodeCapture capture) async {
                if (_lastScannedCode == null) {
                  final barcode = capture.barcodes.first;
                  final String? code = barcode.rawValue;

                  if (code != null) {
                    setState(() {
                      _isScanning = false;
                      _lastScannedCode = code;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Mã QR/Barcode: $code')),
                    );

                    await _startRecording();
                  }
                }
              },
            ),
          if (!_isScanning && _isRecording && _cameraController != null)
            CameraPreview(_cameraController!),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: DeliveryOptionsWidget(
                onOptionSelected: (String option) {
                  setState(() => _selectedDeliveryOption = option);
                  _saveDeliveryOption(option);
                },
              ),
            ),
          ),
          if (_selectedDeliveryOption == null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Vui lòng chọn loại giao hàng trước khi quét mã',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      // Previous bottomNavigationBar...
    );
  }

  Future<void> _saveDeliveryOption(String option) async {
    try {
      await FirebaseFirestore.instance.collection('delivery_options').add({
        'option': option,
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving delivery option: $e');
    }
  }

  Future<void> _uploadVideoToAWS(String filePath) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải video lên AWS...')),
      );

      final videoFileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(filePath)}';
      final videoKey = 'videos/$videoFileName';

      UploadTaskConfig uploadConfig = UploadTaskConfig(
        credentailsConfig: credentialsConfig,
        url: videoKey,
        uploadType: UploadType.file,
        file: File(filePath),
      );

      UploadFile uploadFile = UploadFile(config: uploadConfig);
      uploadFile.uploadProgress.listen((event) {
        print('Tiến trình tải: ${event[0]} / ${event[1]}');
      });

      await uploadFile.upload().then((value) async {
        final videoUrl =
            'https://${credentialsConfig.bucketName}.s3.${credentialsConfig.region}.amazonaws.com/$videoKey';

        await FirebaseFirestore.instance.collection('videos').add({
          'url': videoUrl,
          'fileName': videoFileName,
          'uploadDate': FieldValue.serverTimestamp(),
          'userId': FirebaseAuth.instance.currentUser?.uid,
          'qrCode': _lastScannedCode,
          'deliveryOption': _selectedDeliveryOption,
          'status': 'completed'
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Video đã được tải lên và lưu thành công')),
        );
        uploadFile.dispose();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi trong quá trình xử lý: $e')),
      );
    }
  }
}
