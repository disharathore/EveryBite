import 'dart:async';
import 'package:everybite/bottomnav.dart';
import 'package:everybite/analysispage1.dart';
import 'package:everybite/chatscreen.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:everybite/analysispage.dart';
import 'package:everybite/profilepage.dart';
import 'package:everybite/loginpage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:everybite/services/mongo_user_service.dart';
import 'package:everybite/services/scan_history_service.dart';
import 'package:everybite/services/session_service.dart';
import 'package:everybite/widgets/product_not_found_dialog.dart';
import 'package:everybite/comparepage.dart';
import 'package:everybite/historypage.dart';

class Homepage extends StatefulWidget {
  final String? userId;
  const Homepage({super.key, this.userId});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String scannedBarcode = "";
  bool _isLoading = false;
  Map<String, dynamic>? userData;

  int foodScanned = 0;
  int healthyFoodCount = 0;
  int typeStats = 0;

  Future<void> _loadStats() async {
    final history = await ScanHistoryService.instance.getHistory();
    final healthyScans = history.where((entry) {
      final score = (entry['nutri_score'] ?? '').toString().toUpperCase();
      return score == 'A' || score == 'B';
    }).length;
    final typeCount = history
        .map((entry) => (entry['source'] ?? 'unknown').toString())
        .toSet()
        .length;

    setState(() {
      foodScanned = history.length;
      healthyFoodCount = healthyScans;
      typeStats = typeCount;
    });
  }

  Future<String> _generateGroqResponse(String prompt) async {
    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    final model = dotenv.env['GROQ_MODEL'] ?? 'llama-3.3-70b-versatile';

    if (apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY is missing in .env');
    }

    final response = await http.post(
      Uri.parse('https://api.groqcloud.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Groq API request failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    final content = choices != null && choices.isNotEmpty
        ? (choices.first['message']?['content'] as String?)
        : null;

    if (content == null || content.trim().isEmpty) {
      throw Exception('Groq response was empty');
    }

    return content;
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadStats();
  }

  Future<void> _fetchUserData() async {
    try {
      final uid = SessionService.currentUserId ?? widget.userId;
      if (uid == null || uid.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        return;
      }

      final userSnapshot = await MongoUserService.instance.getUserById(uid);
      if (userSnapshot != null) {
        setState(() {
          userData = userSnapshot;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  Future<void> scanIngredients() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });

      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      String ingredientsText = recognizedText.text;

      await analyzeIngredients(ingredientsText);

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> analyzeIngredients(String ingredientsText) async {
    String userDetails = "";
    if (userData != null) {
      userDetails = """
User Details:
- Name: ${userData!['full_name']}
- Age: ${userData!['age']}
- Gender: ${userData!['gender']}
- Dietary Preference: ${userData!['dietary_preference']}
- Allergies: ${userData!['allergies']}
- Pregnancy Status: ${userData!['pregnancy_status']}
""";
    }

    final prompt = """
$userDetails

Analyze the following food ingredients:
$ingredientsText
give me a personalised feedback of the product with user details a conclusion in which discuss whether the product is fit for consumption . Give a direct answer in yes or a no. and give reasoning for the answer you wish to output. Considor all the parameters and the harms and benfits of each ingredient listed and then draw out a reliable result
give a separate paragraph for telling the user if the product is fit for consumption for the user
Write the whole response for an app page where the information is presented to the user. Write in a descriptive and informative tone. 
Also, give a personalized response based on the allergies and medical conditions inputted above. 
Adding to it, if there is a con in the product and if any ingredient is not adequate, give the possible health hazard related to it. 

If the product contains sodium and iron,  compare them with the adequate consumption of these minerals while stating if the values are fit or not. 
Furthermore, write about the cons and pros of the product by analyzing the information and the ingredients of the product. 


Then, in a separate paragraph, give the information about the environmental aspect of the product like give the meaning to the ecoscore and 
Please use markdown to format the response.

At last give me a conclusion in which discuss whether the product is fit for consumption . Give a direct answer in yes or a no. and give reasoning for the answer you wish to output. Considor all the parameters and the harms and benfits of each ingredient listed and then draw out a reliable result
Then, in a separate paragraph, give the information about the environmental aspect of the product like give the meaning to the ecoscore and nutriscore, describe what does the score stand for. 
Also, use the carbon footprint to give a conclusion if the product is environmentally friendly or not. 
Also, use the packaging material to draw out the results.
Please use markdown to format the response.

Generate the response in plain text without using any bold, bullets, or special symbols.
do not use special formats for heading
while generating the reposnse dont print the user details specifically in the beginning
""";

    try {
      final responseText = await _generateGroqResponse(prompt);

      if (responseText.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisPage1(
              productData: {"ingredients_text": ingredientsText},
              analysisResult: responseText,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error generating AI analysis: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate analysis. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> scanBarcode() async {
    try {
      final result = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => const SimpleBarcodeScannerPage(),
        ),
      );

      if (!mounted || result == null || result == '-1' || result.isEmpty) {
        return;
      }

      setState(() {
        scannedBarcode = result;
      });

      if (scannedBarcode.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });
        await fetchProductDetails(scannedBarcode);
      }
    } catch (e) {
      print("Error scanning barcode: $e");
    }
  }

  // BUG FIX: corrected bracket structure — was broken in your version
  Future<void> fetchProductDetails(String barcode) async {
    final url =
        "https://world.openfoodfacts.org/api/v0/product/$barcode.json";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data["status"] == 1) {
        final product = data["product"];
        await analyzeFood(product);
      } else {
        // Product not found — ask user for manual entry
        setState(() {
          _isLoading = false;
        });
        if (!mounted) return;
        final manualName = await showProductNotFoundDialog(
          context,
          barcode: barcode,
        );
        if (manualName != null && manualName.isNotEmpty) {
          setState(() {
            _isLoading = true;
          });
          await analyzeFood({'product_name': manualName, 'nutriments': {}});
        }
      }
    } else {
      print("Failed to fetch product data");
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> analyzeFood(Map<String, dynamic> product) async {
    String userDetails = "";
    if (userData != null) {
      userDetails = """
User Details:
- Name: ${userData!['full_name']}
- Age: ${userData!['age']}
- Gender: ${userData!['gender']}
- Dietary Preference: ${userData!['dietary_preference']}
- Allergies: ${userData!['allergies']}
- Pregnancy Status: ${userData!['pregnancy_status']}
""";
    }

    final prompt = """
$userDetails

Analyze the following food product:
Name: ${product["product_name"] ?? "Unknown"}
Ingredients: ${product["ingredients_text"] ?? "No ingredients listed"}
Nutritional Info: ${product["nutriments"] ?? "No data available"}

Main Components and Nutritional Values:
Here is a detailed breakdown of the nutritional values:
Sugar: ${product["nutriments"]?["sugars"] ?? "Not available"}
Proteins: ${product["nutriments"]?["proteins"] ?? "Not available"}
Fats: ${product["nutriments"]?["fat"] ?? "Not available"}
Sodium: ${product["nutriments"]?["sodium"] ?? "Not available"}
Iron: ${product["nutriments"]?["iron"] ?? "Not available"}

Is the Product Fit for Consumption?
Personalized Response Based on Allergies or Medical Conditions:
If the product contains allergens or medically relevant ingredients, provide advice, such as gluten or excessive sodium intake risks.
rite the whole response for an app page where the information is presented to the user. Write in a descriptive and informative tone. 
Also, give a personalized response based on the allergies and medical conditions inputted above. 
Adding to it, if there is a con Fin the product and if any ingredient is not adequate, give the possible health hazard related to it. 

Based on the nutritional values of the product, here is an assessment of its suitability for consumption:

Sodium and Iron Analysis:
Sodium: The recommended daily intake of sodium for an average adult is around 2,300 mg. If the product's sodium content exceeds this, it may contribute to high blood pressure or heart disease.
Iron: The recommended daily intake for iron is 8 mg for men and 18 mg for women. Check if the product meets the necessary requirement. If it's low, the product may not be ideal for individuals needing more iron in their diet.

Pros and Cons:
Pros: Provide health benefits based on the ingredients like high protein or antioxidants.
Cons: Mention potential risks like allergens or high sugar content.


Carbon Footprint and Packaging:
Discuss the carbon footprint and packaging sustainability.

Conclusion:
Summarize whether the product is a good choice based on its nutritional values, potential health risks, and environmental considerations.

Generate the response in plain text without using any bold, bullets, or special symbols.
do not use special formats for heading

Give me a detailed analysis by firstly showing the main components and nutritional values of the product, for example, state the values of sugar, proteins, etc. 
Then, give a separate paragraph for telling the user if the product is fit for consumption . 
Use the values of sodium and iron from the above information and compare them with the adequate consumption of these minerals while stating if the values are fit or not. 
Furthermore, write about the cons and pros of the product by analyzing the information and the ingredients of the product. 


Then, in a separate paragraph, give the information about the environmental aspect of the product like give the meaning to the ecoscore and nutriscore, describe what does the score stand for. 
Also, use the carbon footprint to give a conclusion if the product is environmentally friendly or not. 
Also, use the packaging material to draw out the results.
Please use markdown to format the response.
""";

    try {
      final responseText = await _generateGroqResponse(prompt);

      if (responseText.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisPage(
              productData: product,
              analysisResult: responseText,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error generating AI analysis: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate analysis. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void navigateToChatScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen()),
    );
  }

  void navigateToProfilePage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage()),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> actionButtons,
    Color backgroundColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: actionButtons,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  // ── Green header card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.green.shade200,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Hi, ${userData?['full_name'] ?? 'there'}",
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Track your scans, compare products, and stay on top of healthy choices.",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Image.asset(
                              'assets/image/wrap.png',
                              height: 96,
                              width: 96,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Nutrition summary',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Daily overview from your scanned items',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.all(10),
                                    child: const Icon(
                                      Icons.insights,
                                      color: Colors.green,
                                      size: 26,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final itemWidth = constraints.maxWidth >= 760
                                      ? (constraints.maxWidth - 24) / 3
                                      : double.infinity;
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: itemWidth,
                                        child: _buildStatCard(
                                          icon: Icons.local_fire_department,
                                          value: '$healthyFoodCount',
                                          label: 'Healthy foods',
                                          color: Colors.teal,
                                          backgroundColor: Colors.teal.shade50,
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _buildStatCard(
                                          icon: Icons.food_bank,
                                          value: '$foodScanned',
                                          label: 'Food scanned',
                                          color: Colors.green.shade700,
                                          backgroundColor: Colors.green.shade50,
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _buildStatCard(
                                          icon: Icons.bar_chart,
                                          value: '$typeStats',
                                          label: 'Scan types',
                                          color: Colors.amber.shade700,
                                          backgroundColor: Colors.amber.shade50,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        Image.asset(
                          'assets/image/corn.png',
                          width: 150,
                          height: 150,
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          "Scan, Discover, Nourish!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(221, 70, 3, 112),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Pick a tool below to start scanning, review history, compare products, or chat for support.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 28),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 760;
                            final itemWidth = isWide
                                ? (constraints.maxWidth - 24) / 2
                                : double.infinity;

                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                SizedBox(
                                  width: itemWidth,
                                  child: _buildSectionCard(
                                    title: 'Scanner',
                                    subtitle:
                                        'Scan barcodes or ingredients to get instant food insights.',
                                    backgroundColor: const Color(0xFFEAF5FF),
                                    actionButtons: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: scanBarcode,
                                          icon: const Icon(
                                            Icons.qr_code_scanner,
                                            size: 24,
                                          ),
                                          label: const Text('Scan Barcode'),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            backgroundColor:
                                                Colors.blue.shade700,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: scanIngredients,
                                          icon: const Icon(
                                            Icons.document_scanner,
                                            size: 24,
                                          ),
                                          label: const Text('Scan Ingredients'),
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            backgroundColor:
                                                Colors.purple.shade400,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: _buildSectionCard(
                                    title: 'Scan History',
                                    subtitle:
                                        'See your past scans and use them to make smarter choices.',
                                    backgroundColor: const Color(0xFFF2F9EA),
                                    actionButtons: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const HistoryPage(),
                                            ),
                                          ),
                                          icon: const Icon(Icons.history,
                                              size: 24),
                                          label: const Text('History'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.green.shade700,
                                            side: BorderSide(
                                                color: Colors.green.shade700),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: _buildSectionCard(
                                    title: 'Compare',
                                    subtitle:
                                        'Compare products side-by-side to choose the healthiest option.',
                                    backgroundColor: const Color(0xFFFFF7E5),
                                    actionButtons: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const ComparePage(),
                                            ),
                                          ),
                                          icon: const Icon(
                                              Icons.compare_arrows,
                                              size: 24),
                                          label: const Text('Compare'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.orange.shade700,
                                            side: BorderSide(
                                                color: Colors.orange.shade700),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: itemWidth,
                                  child: _buildSectionCard(
                                    title: 'Chat',
                                    subtitle:
                                        'Get instant guidance and help through chat support.',
                                    backgroundColor: const Color(0xFFF5E9FF),
                                    actionButtons: [
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              navigateToChatScreen(context),
                                          icon: const Icon(Icons.chat,
                                              size: 24),
                                          label: const Text('Chat'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.deepPurple.shade700,
                                            side: BorderSide(
                                                color:
                                                    Colors.deepPurple.shade700),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        'Generating your personalized response...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        navigateToHomePage: () {},
        navigateToProfilePage: () => navigateToProfilePage(context),
        navigateToScanPage: () => scanIngredients(),
      ),
    );
  }
}