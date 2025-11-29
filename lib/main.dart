import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// 後端伺服器網址（你的 Mac IP）
const String backendBaseUrl = 'http://219.70.123.30:8001';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

// ================== 使用者個人資料 Model ==================
class UserProfile {
  final int? age;
  final String? gender; // 'male' / 'female' / 'other'
  final double? heightCm;
  final double? weightKg;
  final double? bodyFat;
  final double? targetWeightKg;
  final String? activityLevel; // 'low' / 'medium' / 'high'
  final String? dietaryNeeds; // 乳糖不耐、素食等

  UserProfile({
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.bodyFat,
    this.targetWeightKg,
    this.activityLevel,
    this.dietaryNeeds,
  });

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'body_fat': bodyFat,
      'target_weight_kg': targetWeightKg,
      'activity_level': activityLevel,
      'dietary_needs': dietaryNeeds,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) {
        return double.tryParse(v);
      }
      return null;
    }

    int? _toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        return int.tryParse(v);
      }
      return null;
    }

    return UserProfile(
      age: _toInt(json['age']),
      gender: json['gender'] as String?,
      heightCm: _toDouble(json['height_cm']),
      weightKg: _toDouble(json['weight_kg']),
      bodyFat: _toDouble(json['body_fat']),
      targetWeightKg: _toDouble(json['target_weight_kg']),
      activityLevel: json['activity_level'] as String?,
      dietaryNeeds: json['dietary_needs'] as String?,
    );
  }
}

// ================== 首頁：個人資料 + 目標 + 歷史紀錄入口 ==================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void goToGoalPage(BuildContext context, String goal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GoalPage(goal: goal),
      ),
    );
  }

  void goToProfilePage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserProfilePage(),
      ),
    );
  }

  void goToHistoryPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HistoryPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 飲食教練')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => goToProfilePage(context),
              child: const Text('設定 / 編輯個人資料'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => goToHistoryPage(context),
              child: const Text('查看歷史紀錄'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            const Text(
              '選擇你的目標',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => goToGoalPage(context, '增肌'),
              child: const Text('增肌'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => goToGoalPage(context, '瘦身'),
              child: const Text('瘦身'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => goToGoalPage(context, '維持體態'),
              child: const Text('維持體態'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== 個人資料設定頁 ==================
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  static const _profileKey = 'user_profile';

  final TextEditingController _ageController = TextEditingController();
  String _gender = 'male';
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _bodyFatController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  String _activityLevel = 'medium';
  final TextEditingController _dietaryNeedsController = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    _targetWeightController.dispose();
    _dietaryNeedsController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final profile = UserProfile.fromJson(map);
        _ageController.text = profile.age?.toString() ?? '';
        _gender = profile.gender ?? 'male';
        _heightController.text = profile.heightCm?.toString() ?? '';
        _weightController.text = profile.weightKg?.toString() ?? '';
        _bodyFatController.text = profile.bodyFat?.toString() ?? '';
        _targetWeightController.text = profile.targetWeightKg?.toString() ?? '';
        _activityLevel = profile.activityLevel ?? 'medium';
        _dietaryNeedsController.text = profile.dietaryNeeds ?? '';
      } catch (_) {
        // ignore invalid saved data
      }
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    int? _toInt(String value) {
      final v = value.trim();
      if (v.isEmpty) return null;
      return int.tryParse(v);
    }

    double? _toDouble(String value) {
      final v = value.trim();
      if (v.isEmpty) return null;
      return double.tryParse(v);
    }

    final profile = UserProfile(
      age: _toInt(_ageController.text),
      gender: _gender,
      heightCm: _toDouble(_heightController.text),
      weightKg: _toDouble(_weightController.text),
      bodyFat: _toDouble(_bodyFatController.text),
      targetWeightKg: _toDouble(_targetWeightController.text),
      activityLevel: _activityLevel,
      dietaryNeeds: _dietaryNeedsController.text.trim().isEmpty
          ? null
          : _dietaryNeedsController.text.trim(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存個人資料')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('個人資料設定'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('個人資料設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '年齡（歲）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: '性別',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('男')),
                DropdownMenuItem(value: 'female', child: Text('女')),
                DropdownMenuItem(value: 'other', child: Text('其他 / 不方便透露')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _gender = v;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '身高（公分）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '體重（公斤）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyFatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '體脂率（%，可不填）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetWeightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '目標體重（公斤，可不填）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _activityLevel,
              decoration: const InputDecoration(
                labelText: '活動量',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('久坐 / 幾乎不運動')),
                DropdownMenuItem(value: 'medium', child: Text('普通活動量（學生、走動）')),
                DropdownMenuItem(value: 'high', child: Text('高活動量（常運動、體育訓練）')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _activityLevel = v;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dietaryNeedsController,
              decoration: const InputDecoration(
                labelText: '特殊飲食需求（例如：乳糖不耐、蛋奶素、海鮮過敏，可不填）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('儲存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== 目標頁 ==================
class GoalPage extends StatelessWidget {
  final String goal;

  const GoalPage({super.key, required this.goal});

  void goToFoodLogPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodLogPage(goal: goal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('你的目標')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            Text(
              '你選擇的目標是：\n\n$goal',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => goToFoodLogPage(context),
              child: const Text('開始記錄今天的飲食'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== 飲食紀錄頁（每天分開顯示） ==================
class FoodLogPage extends StatefulWidget {
  final String goal;

  const FoodLogPage({super.key, required this.goal});

  @override
  State<FoodLogPage> createState() => _FoodLogPageState();
}

class _FoodLogPageState extends State<FoodLogPage> {
  final TextEditingController _foodController = TextEditingController();
  String _selectedMeal = '早餐';

  final List<_FoodRecord> _allRecords = [];
  String _suggestion = '';

  static const _prefsKey = 'food_records';
  static const _profileKey = 'user_profile';

  UserProfile? _userProfile;

  DateTime get _todayDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  List<_FoodRecord> get _todayRecords {
    final t = _todayDate;
    final list = _allRecords.where((r) {
      final d = r.time;
      return d.year == t.year && d.month == t.month && d.day == t.day;
    }).toList();
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _foodController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _userProfile = UserProfile.fromJson(map);
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;

      final List<dynamic> decoded = jsonDecode(raw);
      final loaded = decoded.map((e) {
        if (e is Map<String, dynamic>) {
          return _FoodRecord(
            meal: e['meal'] as String,
            food: e['food'] as String,
            time: DateTime.parse(e['time'] as String),
          );
        } else if (e is Map) {
          return _FoodRecord(
            meal: e['meal'] as String,
            food: e['food'] as String,
            time: DateTime.parse(e['time'] as String),
          );
        } else {
          return _FoodRecord(
            meal: '未知',
            food: '未知',
            time: DateTime.now(),
          );
        }
      }).toList();

      setState(() {
        _allRecords.clear();
        _allRecords.addAll(loaded);
      });
    } catch (e) {
      // ignore invalid data
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _allRecords
        .map((r) => {
              'meal': r.meal,
              'food': r.food,
              'time': r.time.toIso8601String(),
            })
        .toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
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
        _FoodRecord(
          meal: _selectedMeal,
          food: text,
          time: DateTime.now(),
        ),
      );
      _foodController.clear();
    });

    _saveRecords();
  }

  void _deleteRecord(int index) {
    final todayList = _todayRecords;
    if (index < 0 || index >= todayList.length) return;
    final target = todayList[index];

    setState(() {
      _allRecords.removeWhere((r) =>
          r.meal == target.meal &&
          r.food == target.food &&
          r.time == target.time);
    });
    _saveRecords();
  }

  void _generateSuggestion() {
    final todayList = _todayRecords;
    if (todayList.isEmpty) {
      setState(() {
        _suggestion =
            '你今天還沒有任何紀錄，先記錄至少 1 餐，我才能幫你判斷下一餐喔。';
      });
      return;
    }

    final goal = widget.goal;
    final count = todayList.length;

    String result;

    if (goal == '增肌') {
      if (count <= 2) {
        result =
            '目標是增肌，但你今天吃得還不多。下一餐可以再補一份高蛋白主餐（例如：雞胸肉、牛肉、豆腐、蛋），搭配主食與一些蔬菜。';
      } else {
        result =
            '你今天的餐數已經不算少了。下一餐可以選高蛋白但不要太油膩的組合，例如：烤雞沙拉飯、牛肉飯＋無糖飲料。記得睡前可以再補一點蛋白質。';
      }
    } else if (goal == '瘦身') {
      if (count >= 3) {
        result =
            '今天吃的餐數已經夠了，下一餐建議走「清爽＋高纖維」路線，例如：沙拉、湯品、燙青菜，避免油炸與含糖飲料。';
      } else {
        result =
            '你正在瘦身，下一餐可以選擇「高纖＋有蛋白質但澱粉適中」的餐，例如：雞胸沙拉、燙青菜＋少量飯，飲料選無糖或微糖。';
      }
    } else {
      result =
          '你目前是維持體態為主。下一餐可以選擇「有主食、有蛋白質、有蔬菜」的均衡餐，例如：便當類（少炸物）、和風丼飯＋青菜，飲料盡量減糖。';
    }

    setState(() {
      _suggestion = result;
    });
  }

  void _goToSummary() {
    final todayList = _todayRecords;
    if (todayList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('先記錄至少 1 餐，再看今天總結會比較有意義喔。')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SummaryPage(
          goal: widget.goal,
          records: List<_FoodRecord>.from(todayList),
        ),
      ),
    );
  }

  String _goalToBackendKey() {
    if (widget.goal == '增肌') return 'muscle_gain';
    if (widget.goal == '瘦身') return 'fat_loss';
    return 'maintenance';
  }

  Map<String, dynamic> _buildUserProfileJson() {
    if (_userProfile == null) return {};
    return _userProfile!.toJson();
  }

  // ====== 組出「今天」的 AI JSON（給預覽用） ======
  String _buildAiRequestJsonForToday() {
    final now = DateTime.now();
    final today = _todayDate;
    final todayList = _todayRecords;

    final data = {
      "date":
          "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}",
      "goal": _goalToBackendKey(),
      "records": todayList.map((r) {
        final timeStr =
            "${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}";
        return {
          "time": timeStr,
          "mealType": r.meal,
          "description": r.food,
        };
      }).toList(),
      "user_profile": _buildUserProfileJson(),
      "meta": {
        "generated_at": now.toIso8601String(),
        "timezone": "Asia/Taipei",
      }
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  void _previewAiJson() {
    final todayList = _todayRecords;
    if (todayList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少先記錄 1 餐，才有資料可以給 AI。')),
      );
      return;
    }

    final jsonText = _buildAiRequestJsonForToday();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiRequestPreviewPage(jsonText: jsonText),
      ),
    );
  }

  void _goToWeeklyPlan() {
    if (_allRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先記錄幾餐，才有東西可以做一週建議。')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeeklyPlanPage(
          goal: widget.goal,
          allRecords: List<_FoodRecord>.from(_allRecords),
          userProfile: _userProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayList = _todayRecords;

    return Scaffold(
      appBar: AppBar(title: const Text('記錄今日飲食')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '目前目標：${widget.goal}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (_userProfile == null)
              const Text(
                '尚未設定個人資料，建議回首頁先填寫，AI 才能更個人化。',
                style: TextStyle(fontSize: 12, color: Colors.redAccent),
              )
            else
              const Text(
                '已載入個人資料，AI 建議會依照你的狀態調整。',
                style: TextStyle(fontSize: 12, color: Colors.green),
              ),
            const SizedBox(height: 8),
            Text(
              '日期：${_todayDate.year}-${_todayDate.month.toString().padLeft(2, '0')}-${_todayDate.day.toString().padLeft(2, '0')}（只顯示今天）',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedMeal,
              decoration: const InputDecoration(
                labelText: '餐別',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '早餐', child: Text('早餐')),
                DropdownMenuItem(value: '午餐', child: Text('午餐')),
                DropdownMenuItem(value: '晚餐', child: Text('晚餐')),
                DropdownMenuItem(value: '點心', child: Text('點心')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedMeal = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _foodController,
              decoration: const InputDecoration(
                labelText: '你吃了什麼？（例如：雞胸肉便當、珍奶半糖去冰）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addRecord,
              child: const Text('加入紀錄'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              '今天的飲食紀錄：',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: todayList.isEmpty
                  ? const Center(child: Text('今天還沒有紀錄'))
                  : ListView.builder(
                      itemCount: todayList.length,
                      itemBuilder: (context, index) {
                        final r = todayList[index];
                        final timeStr =
                            '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}';
                        return Card(
                          child: ListTile(
                            title: Text('${r.meal}：${r.food}'),
                            subtitle: Text('記錄時間：$timeStr'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteRecord(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _generateSuggestion,
              child: const Text('產生下一餐建議（前端模擬）'),
            ),
            const SizedBox(height: 8),
            if (_suggestion.isNotEmpty)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _suggestion,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _goToSummary,
              child: const Text('查看今天總結'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _previewAiJson,
              child: const Text('預覽要給 AI 的資料（含個人資料）'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _goToWeeklyPlan,
              child: const Text('查看本週飲食建議（AI 後端）'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== 今天總結頁 ==================
class SummaryPage extends StatelessWidget {
  final String goal;
  final List<_FoodRecord> records;

  const SummaryPage({
    super.key,
    required this.goal,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final total = records.length;
    final breakfastCount = records.where((r) => r.meal == '早餐').length;
    final lunchCount = records.where((r) => r.meal == '午餐').length;
    final dinnerCount = records.where((r) => r.meal == '晚餐').length;
    final snackCount = records.where((r) => r.meal == '點心').length;

    final String summaryText;
    if (goal == '增肌') {
      summaryText =
          '你的目標是「增肌」。\n\n今天總共記錄了 $total 餐，記得每一餐都要有足夠蛋白質和主食。'
          '如果有一兩餐比較隨便，下一餐可以加強一些高蛋白和好的碳水，例如：雞胸、牛肉、蛋、豆腐配飯或地瓜。';
    } else if (goal == '瘦身') {
      summaryText =
          '你的目標是「瘦身」。\n\n今天總共記錄了 $total 餐。'
          '如果點心（$snackCount 次）偏多，之後可以把點心改成水果、優格或無糖飲品，主餐盡量少炸物、少含糖飲料。';
    } else {
      summaryText =
          '你的目標是「維持體態」。\n\n今天總共記錄了 $total 餐。'
          '只要大部分餐點是有主食、蛋白質和蔬菜的均衡搭配，就可以慢慢維持現在的狀態，偶爾放鬆一餐也沒關係。';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('今天總結')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('目標：$goal',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 16),
            Text('今天總共記錄了 $total 餐：',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('・早餐：$breakfastCount 次'),
            Text('・午餐：$lunchCount 次'),
            Text('・晚餐：$dinnerCount 次'),
            Text('・點心：$snackCount 次'),
            const SizedBox(height: 24),
            const Text(
              '系統總結建議：',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  summaryText,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== AI 請求預覽頁 ==================
class AiRequestPreviewPage extends StatelessWidget {
  final String jsonText;

  const AiRequestPreviewPage({
    super.key,
    required this.jsonText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('給 AI 的資料預覽')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            jsonText,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}

// ================== 每週建議頁（呼叫真正後端 AI） ==================
class WeeklyPlanPage extends StatefulWidget {
  final String goal;
  final List<_FoodRecord> allRecords;
  final UserProfile? userProfile;

  const WeeklyPlanPage({
    super.key,
    required this.goal,
    required this.allRecords,
    required this.userProfile,
  });

  @override
  State<WeeklyPlanPage> createState() => _WeeklyPlanPageState();
}

class _WeeklyPlanPageState extends State<WeeklyPlanPage> {
  String _planText = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _callBackend();
  }

  String _goalToBackendKey() {
    if (widget.goal == '增肌') return 'muscle_gain';
    if (widget.goal == '瘦身') return 'fat_loss';
    return 'maintenance';
  }

  Future<void> _callBackend() async {
    setState(() {
      _loading = true;
      _planText = '';
    });

    try {
      final today = DateTime.now();
      final recordsJson = widget.allRecords.map((r) {
        final timeStr =
            "${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}";
        return {
          "time": timeStr,
          "mealType": r.meal,
          "description": r.food,
        };
      }).toList();

      final body = {
        "date":
            "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}",
        "goal": _goalToBackendKey(),
        "records": recordsJson,
        "user_profile": widget.userProfile?.toJson() ?? {},
      };

      final uri = Uri.parse('$backendBaseUrl/analyze-day');
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final score = data['score'];
        final summary = data['summary'] ?? '';
        final suggestions = (data['suggestions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        final buffer = StringBuffer();
        buffer.writeln('【AI 分析結果】');
        buffer.writeln();
        buffer.writeln('分數：$score');
        buffer.writeln();
        buffer.writeln('總結：');
        buffer.writeln(summary);
        buffer.writeln();
        if (suggestions.isNotEmpty) {
          buffer.writeln('建議：');
          for (final s in suggestions) {
            buffer.writeln('- $s');
          }
        }

        setState(() {
          _planText = buffer.toString();
          _loading = false;
        });
      } else {
        setState(() {
          _planText =
              '後端回傳錯誤（HTTP ${resp.statusCode}）。\n請稍後再試。';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _planText = '呼叫後端時發生錯誤：$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本週飲食建議（AI 後端）')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: SelectableText(
                  _planText,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
      ),
    );
  }
}

// ================== 歷史紀錄頁：列出有紀錄的日期 ==================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _prefsKey = 'food_records';

  bool _loading = true;
  List<_FoodRecord> _allRecords = [];
  late List<_DaySummary> _days; // 每天的總覽

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        setState(() {
          _allRecords = [];
          _days = [];
          _loading = false;
        });
        return;
      }

      final List<dynamic> decoded = jsonDecode(raw);
      final loaded = decoded.map((e) {
        if (e is Map<String, dynamic>) {
          return _FoodRecord(
            meal: e['meal'] as String,
            food: e['food'] as String,
            time: DateTime.parse(e['time'] as String),
          );
        } else if (e is Map) {
          return _FoodRecord(
            meal: e['meal'] as String,
            food: e['food'] as String,
            time: DateTime.parse(e['time'] as String),
          );
        } else {
          return _FoodRecord(
            meal: '未知',
            food: '未知',
            time: DateTime.now(),
          );
        }
      }).toList();

      // 依日期分組
      final Map<DateTime, List<_FoodRecord>> byDate = {};
      for (final r in loaded) {
        final d = DateTime(r.time.year, r.time.month, r.time.day);
        byDate.putIfAbsent(d, () => []);
        byDate[d]!.add(r);
      }

      final days = byDate.entries.map((e) {
        e.value.sort((a, b) => a.time.compareTo(b.time));
        return _DaySummary(
          date: e.key,
          records: e.value,
        );
      }).toList();

      // 依日期由新到舊排序
      days.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _allRecords = loaded;
        _days = days;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _allRecords = [];
        _days = [];
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('歷史飲食紀錄')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _days.isEmpty
              ? const Center(
                  child: Text('目前沒有任何歷史紀錄。\n先去記錄幾天的飲食再回來看吧！'),
                )
              : ListView.builder(
                  itemCount: _days.length,
                  itemBuilder: (context, index) {
                    final day = _days[index];
                    final dateStr = _formatDate(day.date);
                    final count = day.records.length;

                    // 大略算一下當天早餐 / 午餐 / 晚餐數量，展示給評審看
                    final breakfastCount =
                        day.records.where((r) => r.meal == '早餐').length;
                    final lunchCount =
                        day.records.where((r) => r.meal == '午餐').length;
                    final dinnerCount =
                        day.records.where((r) => r.meal == '晚餐').length;

                    return Card(
                      child: ListTile(
                        title: Text('$dateStr  （共 $count 餐）'),
                        subtitle: Text(
                            '早餐：$breakfastCount，午餐：$lunchCount，晚餐：$dinnerCount'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DayDetailPage(
                                date: day.date,
                                records: day.records,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// 每一天的簡單總結資料
class _DaySummary {
  final DateTime date;
  final List<_FoodRecord> records;

  _DaySummary({
    required this.date,
    required this.records,
  });
}

// ================== 某一天的詳細紀錄頁 ==================
class DayDetailPage extends StatelessWidget {
  final DateTime date;
  final List<_FoodRecord> records;

  const DayDetailPage({
    super.key,
    required this.date,
    required this.records,
  });

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...records]..sort((a, b) => a.time.compareTo(b.time));

    return Scaffold(
      appBar: AppBar(
        title: Text('${_formatDate(date)} 的紀錄'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: sorted.isEmpty
            ? const Center(child: Text('這一天沒有任何紀錄'))
            : ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final r = sorted[index];
                  final timeStr =
                      '${r.time.hour.toString().padLeft(2, '0')}:${r.time.minute.toString().padLeft(2, '0')}';
                  return Card(
                    child: ListTile(
                      title: Text('${r.meal}：${r.food}'),
                      subtitle: Text('時間：$timeStr'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ================== 紀錄模型 ==================
class _FoodRecord {
  final String meal;
  final String food;
  final DateTime time;

  _FoodRecord({
    required this.meal,
    required this.food,
    required this.time,
  });
}
