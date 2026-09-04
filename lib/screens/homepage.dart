import 'dart:io';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

// TODO: แก้ไข path ด้านล่างนี้ให้ตรงกับโปรเจกต์ของคุณ
import 'package:gpt_vision_leaf_detect/constants/constants.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cross_file/cross_file.dart';

// ----------------------------------------------------------------------
// Class สำหรับวาดสี่เหลี่ยม (Bounding Box) บนรูปภาพ
// ----------------------------------------------------------------------
class BoundingBoxPainter extends CustomPainter {
  final List<double>? box;

  BoundingBoxPainter(this.box);

  @override
  void paint(Canvas canvas, Size size) {
    if (box == null || box!.length < 4) return;

    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // AI ส่งมาเป็น [ymin, xmin, ymax, xmax] 
    final double yMin = box![0] * size.height;
    final double xMin = box![1] * size.width;
    final double yMax = box![2] * size.height;
    final double xMax = box![3] * size.width;

    final rect = Rect.fromLTRB(xMin, yMin, xMax, yMax);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ----------------------------------------------------------------------
// HomePage
// ----------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<HomePage> {
  final apiService = ApiService();
  XFile? _selectedImage;
  String diseaseName = '';
  String diseasePrecautions = '';
  List<double> boundingBox = []; // เก็บพิกัดสี่เหลี่ยม
  
  bool detecting = false;
  bool precautionLoading = false;
  bool isSaving = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile =
        await ImagePicker().pickImage(source: source, imageQuality: 50,maxWidth: 400,          // จำกัดความกว้างไม่เกิน 800 พิกเซล
      maxHeight: 400);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        // รีเซ็ตค่าทั้งหมดเมื่อเลือกภาพใหม่
        diseaseName = '';
        diseasePrecautions = '';
        boundingBox = []; 
      });
    }
  }

  detectDisease() async {
    setState(() { detecting = true; });
    try {
      // เรียกฟังก์ชันเพื่อขอข้อมูล JSON (ชื่อโรค + พิกัดสี่เหลี่ยม)
      final result = await apiService.sendImageToAPI(image: _selectedImage!);
      
      setState(() {
        diseaseName = result['disease']?.toString() ?? "I don't know";
        // ดึงพิกัด และแปลงให้เป็น List<double>
        final rawBox = result['box'] as List<dynamic>? ?? [];
        boundingBox = rawBox.map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
      });
    } catch (error) {
      _showErrorSnackBar(error);
    } finally {
      setState(() { detecting = false; });
    }
  }

  showPrecautions() async {
    setState(() { precautionLoading = true; });
    try {
      if (diseasePrecautions == '') {
        diseasePrecautions =
            await apiService.sendDiseaseAdvice(diseaseName: diseaseName);
      }
      _showSuccessDialog("Precautions", diseasePrecautions);
    } catch (error) {
      _showErrorSnackBar(error);
    } finally {
      setState(() { precautionLoading = false; });
    }
  }

  Future<void> _saveDataWithLocation() async {
    setState(() { isSaving = true; });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('กรุณาเปิด GPS (Location Services) บนอุปกรณ์ของคุณ');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('สิทธิ์ถูกปฏิเสธอย่างถาวร กรุณาไปตั้งค่าในเครื่อง');
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      String latitude = position.latitude.toString();
      String longitude = position.longitude.toString();

      // TODO: บันทึกลง Database
      print("Saved: $diseaseName at $latitude, $longitude");
      
      _showSuccessDialog(
        "บันทึกข้อมูลสำเร็จ",
        "ชื่อโรค: $diseaseName\nพิกัด: $latitude, $longitude",
      );

    } catch (error) {
      _showErrorSnackBar(error);
    } finally {
      setState(() { isSaving = false; });
    }
  }

  void _showErrorSnackBar(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error.toString()),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showSuccessDialog(String title, String content) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.rightSlide,
      title: title,
      desc: content,
      btnOkText: 'ตกลง',
      btnOkColor: themeColor,
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        title: const Text('Plant Disease AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 28),
            tooltip: 'ประวัติการตรวจ',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('หน้าประวัติ...'))
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          Stack(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.20,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(50.0),
                  ),
                ),
              ),
              Container(
                height: MediaQuery.of(context).size.height * 0.18,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(50.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('OPEN GALLERY', style: TextStyle(color: textColor)),
                          const SizedBox(width: 10),
                          Icon(Icons.image, color: textColor)
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('START CAMERA', style: TextStyle(color: textColor)),
                          const SizedBox(width: 10),
                          Icon(Icons.camera_alt, color: textColor)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // -------------------------------------------------------------
          // พื้นที่แสดงภาพและวาดกรอบ
          // -------------------------------------------------------------
          _selectedImage == null
              ? Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Image.asset(
                        'assets/images/pick1.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                )
              : Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ]
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand, // วาง Stack เพื่อซ้อนรูปและเส้น
                        children: [
                          kIsWeb
                          ? Image.network(
                              _selectedImage!.path,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          if (boundingBox.isNotEmpty)
                            CustomPaint(
                              painter: BoundingBoxPainter(boundingBox),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
          // ปุ่ม DETECT 
          if (_selectedImage != null && diseaseName == '')
            detecting
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: SpinKitWave(color: themeColor, size: 30),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => detectDisease(),
                      child: const Text(
                        'DETECT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
          // ส่วนแสดงผลลัพธ์
          if (diseaseName != '')
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    child: AnimatedTextKit(
                      isRepeatingAnimation: false,
                      displayFullTextOnTap: true,
                      animatedTexts: [
                        TyperAnimatedText(
                          diseaseName.trim(),
                          textAlign: TextAlign.center,
                        ),
                      ]
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: precautionLoading
                            ? const SpinKitWave(color: Colors.blue, size: 30)
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => showPrecautions(),
                                icon: Icon(Icons.info_outline, color: textColor),
                                label: Text('PRECAUTION',
                                    style: TextStyle(color: textColor, fontSize: 13)),
                              ),
                      ),
                      
                      const SizedBox(width: 15),
                      
                      Expanded(
                        child: isSaving
                            ? SpinKitWave(color: themeColor, size: 30)
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green, 
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _saveDataWithLocation(),
                                icon: Icon(Icons.save, color: textColor),
                                label: Text('SAVE',
                                    style: TextStyle(color: textColor, fontSize: 13)),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}