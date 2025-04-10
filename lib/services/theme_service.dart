import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  final String name;
  final Color primary;
  final Color secondary;
  final bool useDarkerColors;
  final double borderRadius;

  const AppTheme({
    required this.name,
    required this.primary,
    required this.secondary,
    this.useDarkerColors = false,
    this.borderRadius = 12.0,
  });
}

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // 存储键
  final String _themeKey = 'themeMode';
  final String _themeIndexKey = 'themeIndex';
  final String _borderRadiusKey = 'borderRadius';
  final String _useDenseKey = 'useDense';

  // 主题设置
  ThemeMode _themeMode = ThemeMode.system;
  int _currentThemeIndex = 0;
  double _borderRadius = 12.0;
  bool _useDenseUi = false;

  // 预设主题列表
  final List<AppTheme> _themes = [
    const AppTheme(
      name: '默认蓝',
      primary: Colors.blue,
      secondary: Colors.lightBlue,
    ),
    const AppTheme(
      name: '翡翠绿',
      primary: Color(0xFF00897B),
      secondary: Color(0xFF4DB6AC),
    ),
    const AppTheme(
      name: '珊瑚红',
      primary: Color(0xFFE57373),
      secondary: Color(0xFFFFCDD2),
    ),
    const AppTheme(
      name: '深紫',
      primary: Color(0xFF673AB7),
      secondary: Color(0xFFB39DDB),
      useDarkerColors: true,
    ),
    const AppTheme(
      name: '午夜蓝',
      primary: Color(0xFF1A237E),
      secondary: Color(0xFF3949AB),
      useDarkerColors: true,
    ),
  ];

  // Getters
  ThemeMode get themeMode => _themeMode;
  List<AppTheme> get themes => _themes;
  AppTheme get currentTheme => _themes[_currentThemeIndex];
  Color get primaryColor => currentTheme.primary;
  Color get secondaryColor => currentTheme.secondary;
  double get borderRadius => _borderRadius;
  bool get useDenseUi => _useDenseUi;

  Future<void> init() async {
    await loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeKey) ?? 0;
    final themeIndex = prefs.getInt(_themeIndexKey) ?? 0;
    final borderRadius = prefs.getDouble(_borderRadiusKey) ?? 12.0;
    final useDense = prefs.getBool(_useDenseKey) ?? false;

    _themeMode = ThemeMode.values[themeModeIndex];
    _currentThemeIndex = themeIndex < _themes.length ? themeIndex : 0;
    _borderRadius = borderRadius;
    _useDenseUi = useDense;

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);

    notifyListeners();
  }

  Future<void> setThemeByIndex(int index) async {
    if (_currentThemeIndex == index || index >= _themes.length) return;

    _currentThemeIndex = index;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeIndexKey, index);

    notifyListeners();
  }

  Future<void> setBorderRadius(double radius) async {
    if (_borderRadius == radius) return;

    _borderRadius = radius;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_borderRadiusKey, radius);

    notifyListeners();
  }

  Future<void> setUseDenseUi(bool useDense) async {
    if (_useDenseUi == useDense) return;

    _useDenseUi = useDense;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDenseKey, useDense);

    notifyListeners();
  }

  ThemeData getTheme(bool isDark) {
    final theme = currentTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: theme.primary,
        secondary: theme.secondary,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      brightness: isDark ? Brightness.dark : Brightness.light,
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: ListTileThemeData(
        dense: _useDenseUi,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      tabBarTheme: TabBarTheme(
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius * 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: _useDenseUi ? 8.0 : 16.0,
        ),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 20.0,
            vertical: _useDenseUi ? 10.0 : 15.0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: _useDenseUi ? 8.0 : 12.0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: _useDenseUi ? 8.0 : 12.0,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        space: 20,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(_borderRadius * 2),
          ),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
        ),
      ),
    );
  }
}
