import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileInfo {
  final String path;
  final String name;
  final String type;
  final DateTime lastOpened;
  bool isFavorite;
  final String category;
  final List<String> tags;

  FileInfo({
    required this.path,
    required this.name,
    required this.type,
    required this.lastOpened,
    this.isFavorite = false,
    this.category = '未分类',
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'type': type,
      'lastOpened': lastOpened.toIso8601String(),
      'isFavorite': isFavorite ? 1 : 0,
      'category': category,
      'tags': jsonEncode(tags),
    };
  }

  factory FileInfo.fromMap(Map<String, dynamic> map) {
    return FileInfo(
      path: map['path'],
      name: map['name'],
      type: map['type'],
      lastOpened: DateTime.parse(map['lastOpened']),
      isFavorite: map['isFavorite'] == 1,
      category: map['category'] ?? '未分类',
      tags:
          map['tags'] != null ? List<String>.from(jsonDecode(map['tags'])) : [],
    );
  }

  String get extension => path.split('.').last.toLowerCase();

  bool get isHTML => type == 'html';
  bool get isPDF => type == 'pdf';
}

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late Database _database;
  final List<String> _supportedTypes = ['html', 'htm', 'pdf'];
  late String _storagePath;
  static const String _storagePathKey = 'custom_storage_path';
  static const String _dbName = 'html_launcher.db';

  // 初始化存储服务
  Future<void> init() async {
    // 初始化存储路径
    await _initStoragePath();

    // 确保数据库目录存在
    final dbDir = Directory('$_storagePath/database');
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // 初始化数据库
    final dbPath = '${dbDir.path}/$_dbName';
    _database = await openDatabase(
      dbPath,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE files(id INTEGER PRIMARY KEY, path TEXT, name TEXT, type TEXT, lastOpened TEXT, isFavorite INTEGER, category TEXT, tags TEXT)',
        );
      },
      version: 1,
    );
  }

  // 初始化存储路径
  Future<void> _initStoragePath() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(_storagePathKey);

    if (customPath != null && customPath.isNotEmpty) {
      final directory = Directory(customPath);
      final exists = await directory.exists();

      if (exists) {
        _storagePath = customPath;
        return;
      }
    }

    // 如果没有自定义路径或目录不存在，使用默认路径
    _storagePath = (await getApplicationDocumentsDirectory()).path;
  }

  // 获取当前存储路径
  Future<String> getStoragePath() async {
    return _storagePath;
  }

  // 设置自定义存储路径
  Future<bool> setCustomStoragePath(String path) async {
    try {
      final directory = Directory(path);

      // 检查目录是否存在，不存在则创建
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 检查目录是否可写
      final testFile = File('${directory.path}/test_write.tmp');
      await testFile.writeAsString('test');
      await testFile.delete();

      // 保存路径到SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storagePathKey, path);

      // 关闭当前数据库连接
      await _database.close();

      // 更新存储路径
      _storagePath = path;

      // 确保新路径的目录结构存在
      await _ensureDirectories();

      // 重新初始化数据库
      final dbDir = Directory('$_storagePath/database');
      final dbPath = '${dbDir.path}/$_dbName';
      _database = await openDatabase(
        dbPath,
        onCreate: (db, version) {
          return db.execute(
            'CREATE TABLE files(id INTEGER PRIMARY KEY, path TEXT, name TEXT, type TEXT, lastOpened TEXT, isFavorite INTEGER, category TEXT, tags TEXT)',
          );
        },
        version: 1,
      );

      return true;
    } catch (e) {
      print('设置存储路径失败: $e');
      return false;
    }
  }

  // 确保目录结构存在
  Future<void> _ensureDirectories() async {
    // 确保数据库目录存在
    final dbDir = Directory('$_storagePath/database');
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // 确保文件存储目录存在
    final filesDir = Directory('$_storagePath/files');
    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }
  }

  // 重置为默认存储路径
  Future<bool> resetToDefaultStoragePath() async {
    try {
      final defaultPath = (await getApplicationDocumentsDirectory()).path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storagePathKey);

      // 关闭当前数据库连接
      await _database.close();

      // 更新存储路径
      _storagePath = defaultPath;

      // 确保目录结构存在
      await _ensureDirectories();

      // 重新初始化数据库
      final dbDir = Directory('$_storagePath/database');
      final dbPath = '${dbDir.path}/$_dbName';
      _database = await openDatabase(
        dbPath,
        onCreate: (db, version) {
          return db.execute(
            'CREATE TABLE files(id INTEGER PRIMARY KEY, path TEXT, name TEXT, type TEXT, lastOpened TEXT, isFavorite INTEGER, category TEXT, tags TEXT)',
          );
        },
        version: 1,
      );

      return true;
    } catch (e) {
      print('重置存储路径失败: $e');
      return false;
    }
  }

  Future<void> saveFileInfo(FileInfo fileInfo) async {
    await _database.insert(
      'files',
      fileInfo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateFileInfo(FileInfo fileInfo) async {
    await _database.update(
      'files',
      fileInfo.toMap(),
      where: 'path = ?',
      whereArgs: [fileInfo.path],
    );
  }

  Future<void> deleteFileInfo(String path) async {
    await _database.delete(
      'files',
      where: 'path = ?',
      whereArgs: [path],
    );

    // 如果是相对路径，删除实际文件
    if (!path.startsWith('/')) {
      try {
        final fullPath = '$_storagePath/$path';
        final file = File(fullPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('删除文件失败: $e');
      }
    }
  }

  // 获取文件的完整路径
  String getFullPath(String relativePath) {
    if (relativePath.startsWith('/')) {
      return relativePath; // 已经是绝对路径
    }
    return '$_storagePath/$relativePath';
  }

  // 将文件复制到存储目录
  Future<String> _copyFileToStorage(File file, String fileName) async {
    try {
      // 确保文件目录存在
      final directory = Directory('$_storagePath/files');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 生成目标路径
      final targetPath = '${directory.path}/$fileName';

      // 检查文件是否已存在
      if (await File(targetPath).exists()) {
        // 生成带时间戳的唯一文件名
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileNameWithoutExt =
            fileName.substring(0, fileName.lastIndexOf('.'));
        final ext = fileName.substring(fileName.lastIndexOf('.'));
        final newFileName = '${fileNameWithoutExt}_$timestamp$ext';
        return await _copyFileToStorage(file, newFileName);
      }

      // 复制文件
      await file.copy(targetPath);

      // 返回相对路径而不是绝对路径
      return 'files/$fileName';
    } catch (e) {
      print('复制文件到存储目录失败: $e');
      // 如果复制失败，返回原始路径
      return file.path;
    }
  }

  Future<FileInfo> createFileInfo(String path) async {
    File file = File(path);
    String name = path.split('/').last;
    String type = getFileType(path);

    // 复制文件到存储目录，获取相对路径
    String relativePath = await _copyFileToStorage(file, name);

    return FileInfo(
      path: relativePath,
      name: name,
      type: type,
      lastOpened: DateTime.now(),
    );
  }

  Future<List<FileInfo>> getRecentFiles({int limit = 20}) async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'files',
      orderBy: 'lastOpened DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return FileInfo.fromMap(maps[i]);
    });
  }

  Future<List<FileInfo>> getFavoriteFiles() async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'files',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'lastOpened DESC',
    );

    return List.generate(maps.length, (i) {
      return FileInfo.fromMap(maps[i]);
    });
  }

  bool isFileSupported(String path) {
    String ext = path.split('.').last.toLowerCase();
    return _supportedTypes.contains(ext);
  }

  String getFileType(String path) {
    String ext = path.split('.').last.toLowerCase();
    if (['html', 'htm'].contains(ext)) {
      return 'html';
    } else if (ext == 'pdf') {
      return 'pdf';
    }
    return 'unknown';
  }

  // 获取所有分类
  Future<List<String>> getAllCategories() async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'files',
      columns: ['category'],
      distinct: true,
    );

    List<String> categories = ['未分类'];
    for (var item in maps) {
      if (item['category'] != null &&
          item['category'].toString().isNotEmpty &&
          !categories.contains(item['category'])) {
        categories.add(item['category'].toString());
      }
    }

    return categories;
  }

  // 获取所有标签
  Future<List<String>> getAllTags() async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'files',
      columns: ['tags'],
      distinct: true,
    );

    Set<String> uniqueTags = {};

    for (var item in maps) {
      if (item['tags'] != null && item['tags'].toString().isNotEmpty) {
        try {
          List<String> fileTags = List<String>.from(jsonDecode(item['tags']));
          uniqueTags.addAll(fileTags);
        } catch (e) {
          // 解析错误时忽略该标签
        }
      }
    }

    return uniqueTags.toList();
  }

  // 搜索文件
  Future<List<FileInfo>> searchFiles({
    String? query,
    String? fileType,
    String? category,
    String? tag,
  }) async {
    if ((query == null || query.isEmpty) &&
        fileType == null &&
        category == null &&
        tag == null) {
      // 如果没有搜索条件，返回所有文件
      return getRecentFiles(limit: 100);
    }

    String whereClause = '';
    List<String> whereArgs = [];

    // 按文件名搜索
    if (query != null && query.isNotEmpty) {
      whereClause += 'name LIKE ? ';
      whereArgs.add('%$query%');
    }

    // 按文件类型搜索
    if (fileType != null) {
      if (whereClause.isNotEmpty) whereClause += 'AND ';
      whereClause += 'type = ? ';
      whereArgs.add(fileType);
    }

    // 按分类搜索
    if (category != null) {
      if (whereClause.isNotEmpty) whereClause += 'AND ';
      whereClause += 'category = ? ';
      whereArgs.add(category);
    }

    // 执行基本搜索
    final List<Map<String, dynamic>> maps = await _database.query(
      'files',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'lastOpened DESC',
    );

    // 将搜索结果转换为FileInfo对象列表
    List<FileInfo> results = List.generate(maps.length, (i) {
      return FileInfo.fromMap(maps[i]);
    });

    // 如果需要按标签搜索，需要额外处理
    if (tag != null) {
      results = results.where((file) {
        return file.tags.contains(tag);
      }).toList();
    }

    return results;
  }
}
