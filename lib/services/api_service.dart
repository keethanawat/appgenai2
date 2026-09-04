import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:cross_file/cross_file.dart';

// TODO: นำเข้าไฟล์ constants ของคุณ ถ้ามี
// import '../constants/api_constants.dart';

class ApiService {
  late final Dio _dio;
  
  // ⚠️ ใส่ API Key ของคุณที่นี่ (แนะนำให้ใช้ .env ในแอปจริง)
  final String _apiKey = 'sk_IEPultVWP2jNOvKyaNijkhX0hojpqcoW43eIpCTKAiLUo3J8HWld73sCioBzcPnV'; 

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://gen.ai.kku.ac.th/upacth/api/v1', 
        connectTimeout: const Duration(seconds: 30), // เผื่อเวลาให้ AI วิเคราะห์ภาพ
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
          HttpHeaders.contentTypeHeader: 'application/json',
        },
      ),
    );
  }

  Future<String> encodeImage(XFile image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  Future<String> _postToAPI(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post("/chat/completions", data: data);
      final jsonResponse = response.data;
      print(jsonResponse);
      if (jsonResponse == null) {
        throw const HttpException('Empty response from API');
      }

      if (jsonResponse['error'] != null) {
        throw HttpException(
          jsonResponse['error']['message']?.toString() ?? 'Unknown API error',
        );
      }

      final choices = jsonResponse['choices'];
      if (choices == null || choices.isEmpty) {
        throw const HttpException('No response choices returned');
      }

      final content = choices[0]['message']?['content']?.toString();
      if (content == null || content.trim().isEmpty) {
        throw const HttpException('Empty AI response');
      }

      return content.trim();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error']?['message'] ?? e.message;
      print("DioException: $errorMsg");
      throw Exception('API request failed: $errorMsg');
    } catch (e) {
      print("General Exception: $e");
      throw Exception('Error: $e');
    }
  }

  Future<String> sendDiseaseAdvice({
    required String diseaseName,
    String model = "gemini-3.1-pro-preview",
  }) async {
    final data = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': "For the plant health condition '$diseaseName', "
              "provide exactly three concise precautionary or management measures IN eng LANGUAGE. "
              "Each measure must be one short sentence. "
              "Return only three bullet points and no additional explanation.",
        }
      ],
      'max_tokens': 200,
    };

    return _postToAPI(data);
  }

  // แก้ไขให้ส่งกลับเป็น Map เพื่อรับค่า JSON (ชื่อโรค + กรอบพิกัด)
  Future<Map<String, dynamic>> sendImageToAPI({
    required XFile image,
    int maxTokens = 150,
    String model = "gemini-3.1-pro-preview",
  }) async {
    final String base64Image = await encodeImage(image);

    final data = {
      'model': model,
      'messages': [
        {
          'role': 'system',
          'content': 'You are a plant health image analysis assistant.',
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': 'Analyze this image of a plant or leaf. Identify the most likely abnormal condition and provide its name in Thai language. '
                  'Also, provide the bounding box of the damaged area as normalized coordinates (between 0.0 and 1.0). '
                  'Respond STRICTLY in valid JSON format like this: {"disease": "ชื่อโรคภาษาไทย", "box": [ymin, xmin, ymax, xmax]}. '
                  'If no disease is found, set "disease" to "ไม่ทราบ" and "box" to []. '
                  'Do not use markdown blocks like ```json.',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
              },
            },
          ],
        },
      ],
      'max_tokens': maxTokens,
    };

    final responseText = await _postToAPI(data);
    
    try {
      // ทำความสะอาดข้อความ เผื่อ AI ตอบกลับมามี ```json ติดมาด้วย
      String cleanedText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> jsonMap = jsonDecode(cleanedText);
      return jsonMap;
    } catch (e) {
      // หากเกิดข้อผิดพลาดในการแปลง JSON ให้คืนค่าปกติและกล่องเปล่า
      return {'disease': responseText, 'box': []};
    }
  }
}