import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:gpt_vision_leaf_detect/constants/constants.dart';

// ---------------------------------------------------
// 1. สร้าง Model สำหรับเก็บข้อมูลประวัติ (จำลอง)
// ---------------------------------------------------
class DiseaseRecord {
  final String diseaseName;
  final double latitude;
  final double longitude;
  final DateTime dateSaved;
  final String? imagePath; // เผื่ออนาคตคุณบันทึก path ของรูปไว้ด้วย

  DiseaseRecord({
    required this.diseaseName,
    required this.latitude,
    required this.longitude,
    required this.dateSaved,
    this.imagePath,
  });
}

// ---------------------------------------------------
// 2. หน้า History Page
// ---------------------------------------------------
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // TODO: แทนที่ Mock Data ด้วยการดึงข้อมูลจริงจาก SQLite หรือ Firebase
  final List<DiseaseRecord> _records = [
    DiseaseRecord(
      diseaseName: 'Apple Scab (โรคสแคปแอปเปิ้ล)',
      latitude: 19.0296,
      longitude: 99.8944,
      dateSaved: DateTime.now().subtract(const Duration(days: 1)),
    ),
    DiseaseRecord(
      diseaseName: 'Tomato Late Blight (โรคใบไหม้มะเขือเทศ)',
      latitude: 19.0305,
      longitude: 99.8950,
      dateSaved: DateTime.now().subtract(const Duration(days: 3)),
    ),
    DiseaseRecord(
      diseaseName: 'Corn Leaf Blight (โรคใบไหม้ข้าวโพด)',
      latitude: 19.0250,
      longitude: 99.8890,
      dateSaved: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        title: const Text(
          'ประวัติการตรวจ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // สีปุ่มย้อนกลับ
      ),
      body: _records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีประวัติการบันทึกข้อมูล',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final record = _records[index];
                
                // แปลงรูปแบบวันที่ให้อ่านง่าย
                final formattedDate =
                    DateFormat('dd MMM yyyy, HH:mm').format(record.dateSaved);

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // ไอคอนหรือรูปภาพด้านซ้าย
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.coronavirus, // ใช้ไอคอนโรคพืช
                            color: themeColor,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // ข้อมูลตรงกลาง
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.diseaseName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.red[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${record.latitude.toStringAsFixed(4)}, ${record.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        // ปุ่มเปิดแผนที่ด้านขวา
                        IconButton(
                          icon: const Icon(Icons.map, color: Colors.blue),
                          tooltip: 'ดูพิกัดบนแผนที่',
                          onPressed: () {
                            _openMap(record.latitude, record.longitude);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ฟังก์ชันจำลองสำหรับการเปิดแผนที่
  void _openMap(double lat, double lng) {
    // ในการใช้งานจริง แนะนำให้ใช้ package: url_launcher
    // เพื่อสั่งเปิด Google Maps: 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('เปิดแผนที่พิกัด: $lat, $lng'),
        action: SnackBarAction(
          label: 'ปิด',
          onPressed: () {},
        ),
      ),
    );
  }
}