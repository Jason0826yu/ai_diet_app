import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 你現在用雲端後端（Render）就填這個
/// 例：'https://ai-diet-backend-q493.onrender.com'
const String backendBaseUrl = 'https://ai-diet-backend-q493.onrender.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/* ===========================
   App / Theme
=========================== */
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF2E7D32),
      scaffoldBackgroundColor: const Color(0xFFF7F7FA),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const HomePage(),
    );
  }
}

/* ===========================
   Models
=========================== */
class FoodRecord {
  final String meal; // 早餐/午餐/晚餐/點心
  final String food; // 文字描述
  final DateTime time;

  FoodRecord({
    required this.meal,
    required this.food,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'meal': meal,
        'food': food,
        'time': time.toIso8601String(),
      };

  static FoodRecord fromJson(Map<String, dynamic> m) => FoodRecord(
        meal: (m['meal'] ?? '') as String,
        food: (m['food'] ?? '') as String,
        time: DateTime.tryParse((m['time'] ?? '') as String) ?? DateTime.now(),
      );
}

class UserProfile {
  int? age;
  String? gender; // 男/女/其他
  int? heightCm;
  double? weightKg;
  String? activityLevel; // 久坐/普通/高度活動
  String country; // 台灣/日本/韓國/美國/其他
  String? dietaryNotes;

  UserProfile({
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.country = '台灣',
    this.dietaryNotes,
  });

  Map<String, dynamic> toJson() => {
        'age': age,
        'gender': gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'activity_level': activityLevel,
        'country': country,
        'dietary_notes': dietaryNotes,
      };

  static UserProfile fromJson(Map<String, dynamic> m) => UserProfile(
        age: (m['age'] is int) ? m['age'] as int : int.tryParse('${m['age']}'),
        gender: (m['gender'] as String?)?.trim(),
        heightCm: (m['height_cm'] is int)
            ? m['height_cm'] as int
            : int.tryParse('${m['height_cm']}'),
        weightKg: (m['weight_kg'] is num)
            ? (m['weight_kg'] as num).toDouble()
            : double.tryParse('${m['weight_kg']}'),
        activityLevel: (m['activity_level'] as String?)?.trim(),
        country: ((m['country'] as String?)?.trim().isNotEmpty ?? false)
            ? (m['country'] as String).trim()
            : '台灣',
        dietaryNotes: (m['dietary_notes'] as String?)?.trim(),
      );
}

/* ===========================
   SharedPreferences Keys
=========================== */
const String _prefsFoodKey = 'food_records'; // List<FoodRecord>
const String _prefsProfileKey = 'user_profile'; // UserProfile
const String _prefsGoalKey = 'goal_selected'; // String

/* ===========================
   Helpers
=========================== */
DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

String _fmtDate(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

String _fmtTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String _goalToType(String goal) {
  if (goal == '增肌') return 'muscle_gain';
  if (goal == '瘦身') return 'fat_loss';
  return 'maintenance';
}

/* ===========================
   UI Widgets (Small)
=========================== */
class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/* ===========================
   HomePage (Goal + Quick Entry)
=========================== */
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _goal = '維持體態';
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadGoalAndProfile();
  }

  Future<void> _loadGoalAndProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final g = prefs.getString(_prefsGoalKey);
    final rawProfile = prefs.getString(_prefsProfileKey);

    setState(() {
      _goal = g ?? '維持體態';
      _profile = rawProfile == null
          ? null
          : UserProfile.fromJson(jsonDecode(rawProfile) as Map<String, dynamic>);
    });
  }

  Future<void> _saveGoal(String goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsGoalKey, goal);
    setState(() => _goal = goal);
  }

  void _goToFoodLog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FoodLogPage(goal: _goal)),
    );
  }

  void _goToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
    // 回來後刷新
    _loadGoalAndProfile();
  }

  @override
  Widget build(BuildContext context) {
    final profileHint = (_profile == null)
        ? '尚未設定（建議先填，AI 會更準）'
        : '${_profile!.country}｜${_profile!.activityLevel ?? '活動量未填'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('專屬貼身 AI 營養師'),
        actions: [
          IconButton(
            onPressed: _goToProfile,
            icon: const Icon(Icons.person_outline),
            tooltip: '個人資料',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今天目標',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ChoiceChip(
                        label: const Text('增肌'),
                        selected: _goal == '增肌',
                        onSelected: (_) => _saveGoal('增肌'),
                      ),
                      ChoiceChip(
                        label: const Text('瘦身'),
                        selected: _goal == '瘦身',
                        onSelected: (_) => _saveGoal('瘦身'),
                      ),
                      ChoiceChip(
                        label: const Text('維持體態'),
                        selected: _goal == '維持體態',
                        onSelected: (_) => _saveGoal('維持體態'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '個人資料：$profileHint',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: _goToProfile,
                        child: const Text('去設定'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '開始記錄',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '你記越多天，AI 就越像「懂你」的教練，不會每次講一樣。',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  _PrimaryButton(
                    text: '進入記錄頁（今天）',
                    onPressed: _goToFoodLog,
                  ),
                ],
              ),
            ),
            
            
          ],
        ),
      ),
    );
  }
}

/* ===========================
   ProfilePage (User data + country)
=========================== */
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _gender = '男';
  String _activity = '普通';
  String _country = '台灣';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsProfileKey);
    if (raw == null) {
      setState(() => _loading = false);
      return;
    }

    final p = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _ageCtrl.text = p.age?.toString() ?? '';
    _heightCtrl.text = p.heightCm?.toString() ?? '';
    _weightCtrl.text = p.weightKg?.toString() ?? '';
    _notesCtrl.text = p.dietaryNotes ?? '';

    setState(() {
      _gender = (p.gender?.isNotEmpty ?? false) ? p.gender! : '男';
      _activity = (p.activityLevel?.isNotEmpty ?? false) ? p.activityLevel! : '普通';
      _country = p.country;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final p = UserProfile(
      age: int.tryParse(_ageCtrl.text.trim()),
      gender: _gender,
      heightCm: int.tryParse(_heightCtrl.text.trim()),
      weightKg: double.tryParse(_weightCtrl.text.trim()),
      activityLevel: _activity,
      country: _country,
      dietaryNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    await prefs.setString(_prefsProfileKey, jsonEncode(p.toJson()));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存個人資料')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('個人資料設定')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('基本資料', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: deco('年齡', hint: '例如：16'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: deco('性別'),
                    items: const [
                      DropdownMenuItem(value: '男', child: Text('男')),
                      DropdownMenuItem(value: '女', child: Text('女')),
                      DropdownMenuItem(value: '其他', child: Text('其他')),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? '男'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: deco('身高（cm）', hint: '例如：170'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: deco('體重（kg）', hint: '例如：55'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('情境設定', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _activity,
                    decoration: deco('活動量'),
                    items: const [
                      DropdownMenuItem(value: '久坐', child: Text('久坐')),
                      DropdownMenuItem(value: '普通', child: Text('普通')),
                      DropdownMenuItem(value: '高度活動', child: Text('高度活動')),
                    ],
                    onChanged: (v) => setState(() => _activity = v ?? '普通'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _country,
                    decoration: deco('所在國家（影響推薦）'),
                    items: const [
                      DropdownMenuItem(value: '台灣', child: Text('台灣')),
                      DropdownMenuItem(value: '日本', child: Text('日本')),
                      DropdownMenuItem(value: '韓國', child: Text('韓國')),
                      DropdownMenuItem(value: '美國', child: Text('美國')),
                      DropdownMenuItem(value: '其他', child: Text('其他')),
                    ],
                    onChanged: (v) => setState(() => _country = v ?? '台灣'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: deco('特殊飲食需求/備註', hint: '例如：乳糖不耐、素食、過敏'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _PrimaryButton(text: '儲存', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

/* ===========================
   FoodLogPage (Daily + AI plan)
=========================== */
class FoodLogPage extends StatefulWidget {
  final String goal;
  const FoodLogPage({super.key, required this.goal});

  @override
  State<FoodLogPage> createState() => _FoodLogPageState();
}

class _FoodLogPageState extends State<FoodLogPage> {
  final TextEditingController _foodController = TextEditingController();
  String _selectedMeal = '早餐';

  final List<FoodRecord> _allRecords = [];
  bool _loading = true;

  bool _aiLoading = false;
  String _aiText = '';

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  DateTime get _today => _dateOnly(DateTime.now());

  List<FoodRecord> get _todayRecords {
    final t = _today;
    final list = _allRecords.where((r) {
      final d = _dateOnly(r.time);
      return d.year == t.year && d.month == t.month && d.day == t.day;
    }).toList();
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  List<FoodRecord> get _last7DaysRecords {
    final now = DateTime.now();
    final from = _dateOnly(now.subtract(const Duration(days: 6))); // 含今天共7天
    final list = _allRecords.where((r) => _dateOnly(r.time).isAfter(from.subtract(const Duration(days: 1)))).toList();
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsFoodKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final loaded = decoded
            .whereType<Map>()
            .map((e) => FoodRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _allRecords.clear();
        _allRecords.addAll(loaded);
      } catch (_) {
        // 忽略壞資料
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _allRecords.map((e) => e.toJson()).toList();
    await prefs.setString(_prefsFoodKey, jsonEncode(list));
  }

  void _addRecord() {
    final text = _foodController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先輸入你吃了什麼')),
      );
      return;
    }

    setState(() {
      _allRecords.add(
        FoodRecord(meal: _selectedMeal, food: text, time: DateTime.now()),
      );
      _foodController.clear();
    });
    _saveRecords();
  }

  void _deleteTodayRecord(int index) {
    final todayList = _todayRecords;
    if (index < 0 || index >= todayList.length) return;
    final target = todayList[index];

    setState(() {
      _allRecords.removeWhere((r) =>
          r.meal == target.meal && r.food == target.food && r.time == target.time);
    });
    _saveRecords();
  }

  Future<UserProfile?> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsProfileKey);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 組給後端：把「最近 7 天」一起送，AI 才會開始像真的
  Future<Map<String, dynamic>> _buildAnalyzePayload() async {
    final profile = await _loadProfile();
    final logs = _last7DaysRecords.map((r) {
      return {
        "date": _fmtDate(r.time),
        "meal_type": r.meal,
        "description": r.food,
      };
    }).toList();

    return {
      "context": {
        "goal_type": _goalToType(widget.goal),
      },
      "food_logs": logs,
      "user_profile": profile?.toJson(),
    };
  }

  Future<String> _postJson(String url, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      req.add(utf8.encode(jsonEncode(body)));

      final resp = await req.close();
      final respBody = await resp.transform(utf8.decoder).join();

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw HttpException('HTTP ${resp.statusCode}: $respBody');
      }
      return respBody;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _runAiAnalyze() async {
    if (_allRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先記錄幾餐（至少今天 1–2 餐），AI 才會準')),
      );
      return;
    }

    setState(() {
      _aiLoading = true;
      _aiText = '';
    });

    try {
      final payload = await _buildAnalyzePayload();
      final raw = await _postJson('$backendBaseUrl/analyze-day', payload);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final text = (decoded['analysis_text'] ?? '').toString();
      final score = (decoded['score'] ?? '').toString();

      setState(() {
        _aiText = text.isNotEmpty ? text : '（後端回傳空白）';
        if (score.isNotEmpty && !_aiText.contains('分')) {
          _aiText = '【AI 分析結果｜$score 分】\n\n$_aiText';
        }
      });
    } catch (e) {
      setState(() {
        _aiText = '呼叫後端時發生錯誤：\n$e';
      });
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  void _goProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已回到記錄頁（個人資料已更新）')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final todayList = _todayRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('記錄今日飲食'),
        actions: [
          IconButton(
            onPressed: _goProfile,
            icon: const Icon(Icons.person_outline),
            tooltip: '個人資料',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '目標：${widget.goal}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '今天：${_fmtDate(DateTime.now())}（只顯示今天紀錄）',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedMeal,
                    decoration: InputDecoration(
                      labelText: '餐別',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: const [
                      DropdownMenuItem(value: '早餐', child: Text('早餐')),
                      DropdownMenuItem(value: '午餐', child: Text('午餐')),
                      DropdownMenuItem(value: '晚餐', child: Text('晚餐')),
                      DropdownMenuItem(value: '點心', child: Text('點心')),
                    ],
                    onChanged: (v) => setState(() => _selectedMeal = v ?? '早餐'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _foodController,
                    decoration: InputDecoration(
                      labelText: '你吃了什麼？',
                      hintText: '例如：雞胸便當、茶葉蛋+地瓜、珍奶半糖',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PrimaryButton(text: '加入紀錄', onPressed: _addRecord),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _runAiAnalyze,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('AI 分析'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI 會使用「最近 7 天」的紀錄來抓你的偏好，越記越像真人。',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: [
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('今天的飲食紀錄', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        if (todayList.isEmpty)
                          const Text('今天還沒有紀錄', style: TextStyle(fontSize: 13))
                        else
                          ...List.generate(todayList.length, (i) {
                            final r = todayList[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F6F3),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  title: Text('${r.meal}：${r.food}'),
                                  subtitle: Text('時間：${_fmtTime(r.time)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteTodayRecord(i),
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI 分析結果', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        if (_aiLoading)
                          Row(
                            children: const [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Expanded(child: Text('AI 分析中...')),
                            ],
                          )
                        else if (_aiText.isEmpty)
                          Text(
                            '按「AI 分析」後會在這裡顯示。\n\n'
                            '如果你覺得內容很像，通常是因為紀錄太少；至少連續記 3–7 天會差很多。',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                          )
                        else
                          SelectableText(
                            _aiText,
                            style: const TextStyle(fontSize: 13, height: 1.35),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('後端網址（你現在用雲端）', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        SelectableText(
                          backendBaseUrl,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
