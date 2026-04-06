import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AlternativeCard extends StatefulWidget {
  final String productName;
  final String nutriScore;
  final List<String> userAllergies;
  final String dietaryPreference;

  const AlternativeCard({
    super.key,
    required this.productName,
    required this.nutriScore,
    this.userAllergies = const [],
    this.dietaryPreference = '',
  });

  @override
  State<AlternativeCard> createState() => _AlternativeCardState();
}

class _AlternativeCardState extends State<AlternativeCard> {
  String? _suggestion;
  bool _isLoading = false;
  bool _fetched = false;

  // Only show for C, D, E scores — no point suggesting alternative for A/B
  bool get _needsAlternative =>
      ['C', 'D', 'E'].contains(widget.nutriScore.toUpperCase());

  Future<void> _fetchAlternative() async {
    if (_fetched || !_needsAlternative) return;
    setState(() => _isLoading = true);

    final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    final model =
        dotenv.env['GROQ_MODEL'] ?? 'llama-3.3-70b-versatile';

    final allergiesText = widget.userAllergies.isNotEmpty
        ? 'User allergies: ${widget.userAllergies.join(', ')}.'
        : '';
    final dietText = widget.dietaryPreference.isNotEmpty
        ? 'Dietary preference: ${widget.dietaryPreference}.'
        : '';

    final prompt = '''
The user just scanned "${widget.productName}" which has a NutriScore of ${widget.nutriScore} (not ideal).
$allergiesText
$dietText

In 2-3 sentences maximum, suggest ONE specific healthier alternative product or food category the user could choose instead.
Be direct and practical. Do not use bullet points or markdown.
Start with: "Instead of [product], try..."
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 120,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['choices']?[0]?['message']?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          setState(() {
            _suggestion = content.trim();
            _fetched = true;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    setState(() {
      _isLoading = false;
      _fetched = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchAlternative();
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsAlternative) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded,
                  color: Colors.green[700], size: 20),
              const SizedBox(width: 6),
              Text(
                'Healthier Alternative',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green[600],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Finding a better option for you...',
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            )
          else if (_suggestion != null)
            Text(
              _suggestion!,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[900],
                  height: 1.5),
            )
          else
            Text(
              'Look for products with NutriScore A or B as healthier alternatives.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }
}