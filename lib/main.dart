import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:math';

import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'services/viewer_service.dart';
import 'pages/settings_page.dart';
import 'pages/file_manager_page.dart';
import 'pages/search_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化服务
  final storageService = StorageService();
  await storageService.init();

  final themeService = ThemeService();
  await themeService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final bool isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    return MaterialApp(
      title: 'HTML启动器',
      theme: themeService.getTheme(false),
      darkTheme: themeService.getTheme(true),
      themeMode: themeService.themeMode,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final ViewerService _viewerService = ViewerService();
  final ThemeService _themeService = ThemeService();
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  List<FileInfo> recentFiles = [];
  List<FileInfo> favoriteFiles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadRecentFiles();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    if (Platform.isAndroid &&
        await Permission.manageExternalStorage.isGranted == false) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _loadRecentFiles() async {
    setState(() => _isLoading = true);

    try {
      final allFiles = await _storageService.getRecentFiles(limit: 10);
      final favorites = await _storageService.getFavoriteFiles();

      setState(() {
        recentFiles = allFiles;
        favoriteFiles = favorites.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickHTMLFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;

      // 检查文件是否支持
      if (!_storageService.isFileSupported(filePath)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('不支持的文件类型，请选择HTML或PDF文件'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 显示加载指示器
      setState(() => _isLoading = true);

      try {
        // 获取存储路径
        String storagePath = await _storageService.getStoragePath();

        // 创建文件信息并保存（会复制文件到存储位置）
        FileInfo fileInfo = await _storageService.createFileInfo(filePath);
        await _storageService.saveFileInfo(fileInfo);

        // 检查是否成功移动到自定义目录
        bool isMoved = fileInfo.path != filePath;

        // 更新最近文件列表
        setState(() {
          recentFiles = [
            fileInfo,
            ...recentFiles.where((f) => f.path != fileInfo.path)
          ];
          if (recentFiles.length > 10) {
            recentFiles = recentFiles.sublist(0, 10);
          }
          _isLoading = false;
        });

        // 显示成功提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMoved ? '文件已添加并保存到: $storagePath' : '文件已添加但保存失败'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );

          // 打开文件
          _viewerService.openFile(context, fileInfo);
        }
      } catch (e) {
        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('添加文件失败: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _loadSampleHTML() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取存储路径
      String storagePath = await _storageService.getStoragePath();

      // 先创建一个临时文件
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/sample.html');

      // 这里我们创建一个简单的HTML样本文件
      const htmlContent = '''
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>样本HTML页面</title>
    <style>
        body {
            font-family: 'Microsoft YaHei', Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f0f8ff;
            color: #333;
        }
        h1 {
            color: #4285f4;
            text-align: center;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .feature {
            margin: 20px 0;
            padding: 10px;
            border-left: 4px solid #4285f4;
            background-color: #e8f0fe;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>HTML文件启动器</h1>
        <p>欢迎使用HTML文件启动器应用！此应用允许你在安卓设备上查看HTML和PDF文件。</p>
        
        <div class="feature">
            <h3>主要功能：</h3>
            <ul>
                <li>选择并打开任意HTML或PDF文件</li>
                <li>支持JavaScript交互</li>
                <li>文件收藏和分类管理</li>
                <li>支持标签和搜索</li>
                <li>自定义主题和外观</li>
                <li>持久化保存历史记录</li>
            </ul>
        </div>
        
        <p>点击应用底部的"选择文件"按钮开始使用。</p>
        <p>开发者：您的名字</p>
    </div>
</body>
</html>
''';

      await file.writeAsString(htmlContent);

      // 创建并保存文件信息（会复制到存储目录）
      FileInfo fileInfo = await _storageService.createFileInfo(file.path);
      await _storageService.saveFileInfo(fileInfo);

      // 检查是否成功移动到自定义目录
      bool isMoved = fileInfo.path != file.path;

      setState(() {
        recentFiles = [
          fileInfo,
          ...recentFiles.where((f) => f.path != fileInfo.path)
        ];
        if (recentFiles.length > 10) {
          recentFiles = recentFiles.sublist(0, 10);
        }
        _isLoading = false;
      });

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMoved ? '样本文件已保存到: $storagePath' : '样本文件已添加但保存失败'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // 打开文件
        _viewerService.openFile(context, fileInfo);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载样本文件失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 应用栏
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              title: ScaleTransition(
                scale: _scaleAnimation,
                child: Text(
                  'HTML 启动器',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 渐变背景
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          colorScheme.primary,
                          colorScheme.primaryContainer,
                        ],
                      ),
                    ),
                  ),
                  // 装饰图案
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.onPrimary.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.onPrimary.withOpacity(0.1),
                      ),
                    ),
                  ),
                  // HTML图标
                  Positioned(
                    right: 20,
                    bottom: 70,
                    child: Opacity(
                      opacity: 0.15,
                      child: Transform.rotate(
                        angle: pi / 12,
                        child: const Icon(
                          Icons.html,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: '加载样本HTML',
                onPressed: _loadSampleHTML,
              ),
            ],
          ),

          // 主体内容
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 快捷操作卡片
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_themeService.borderRadius),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '快捷操作',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildActionButton(
                                icon: Icons.file_open,
                                label: '打开文件',
                                onTap: _pickHTMLFile,
                                color: colorScheme.primary,
                              ),
                              _buildActionButton(
                                icon: Icons.folder,
                                label: '文件管理',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const FileManagerPage(),
                                    ),
                                  ).then((_) => _loadRecentFiles());
                                },
                                color: Colors.orange,
                              ),
                              _buildActionButton(
                                icon: Icons.search,
                                label: '搜索',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SearchPage(),
                                    ),
                                  );
                                },
                                color: Colors.green,
                              ),
                              _buildActionButton(
                                icon: Icons.settings,
                                label: '设置',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SettingsPage(),
                                    ),
                                  );
                                },
                                color: Colors.purple,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 收藏文件部分
                  if (favoriteFiles.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '收藏文件',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onBackground,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FileManagerPage(),
                              ),
                            ).then((_) => _loadRecentFiles());
                          },
                          child: const Text('查看全部'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: favoriteFiles.length,
                        itemBuilder: (context, index) {
                          final file = favoriteFiles[index];
                          return _buildFavoriteFileCard(file);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 最近文件部分
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '最近打开',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onBackground,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FileManagerPage(),
                            ),
                          ).then((_) => _loadRecentFiles());
                        },
                        child: const Text('查看全部'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // 最近文件列表
          _isLoading
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              : recentFiles.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 80,
                                color:
                                    colorScheme.onBackground.withOpacity(0.2),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '没有最近文件',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '点击"打开文件"按钮开始使用',
                                style: TextStyle(
                                  color:
                                      colorScheme.onBackground.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final file = recentFiles[index];
                          return _buildRecentFileCard(file);
                        },
                        childCount: recentFiles.length,
                      ),
                    ),

          // 底部空间
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteFileCard(FileInfo fileInfo) {
    final Color typeColor = _getFileTypeColor(fileInfo.type);

    return Card(
      margin: const EdgeInsets.only(right: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_themeService.borderRadius),
      ),
      child: InkWell(
        onTap: () => _openFile(fileInfo),
        onLongPress: () => _renameFile(fileInfo),
        borderRadius: BorderRadius.circular(_themeService.borderRadius),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileTypeIcon(fileInfo.type),
                      color: typeColor,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                fileInfo.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(fileInfo.lastOpened),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFileCard(FileInfo fileInfo) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color typeColor = _getFileTypeColor(fileInfo.type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_themeService.borderRadius),
        ),
        child: InkWell(
          onTap: () => _openFile(fileInfo),
          onLongPress: () => _renameFile(fileInfo),
          borderRadius: BorderRadius.circular(_themeService.borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // 文件图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getFileTypeIcon(fileInfo.type),
                    color: typeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // 文件信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileInfo.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              fileInfo.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: typeColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(fileInfo.lastOpened),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          if (fileInfo.isFavorite) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // 右侧图标
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptionsMenu(fileInfo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsMenu(FileInfo fileInfo) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_themeService.borderRadius * 2),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 文件信息头部
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_themeService.borderRadius * 2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileInfo.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fileInfo.type.toUpperCase()} · ${_formatDateTime(fileInfo.lastOpened)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              ListTile(
                leading: Icon(Icons.open_in_new, color: colorScheme.primary),
                title: const Text('打开文件'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  _openFile(fileInfo);
                },
              ),
              ListTile(
                leading: Icon(
                  fileInfo.isFavorite ? Icons.star : Icons.star_border,
                  color:
                      fileInfo.isFavorite ? Colors.amber : colorScheme.primary,
                ),
                title: Text(fileInfo.isFavorite ? '取消收藏' : '添加到收藏'),
                onTap: () async {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  FileInfo updatedInfo = FileInfo(
                    path: fileInfo.path,
                    name: fileInfo.name,
                    type: fileInfo.type,
                    lastOpened: fileInfo.lastOpened,
                    isFavorite: !fileInfo.isFavorite,
                    tags: fileInfo.tags,
                    category: fileInfo.category,
                  );

                  await _storageService.updateFileInfo(updatedInfo);
                  _loadRecentFiles();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(updatedInfo.isFavorite ? '已添加到收藏' : '已从收藏中移除'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(_themeService.borderRadius),
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.edit, color: colorScheme.primary),
                title: const Text('重命名'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  _renameFile(fileInfo);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getFileTypeColor(String type) {
    switch (type) {
      case 'html':
        return Colors.blue;
      case 'pdf':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getFileTypeIcon(String type) {
    switch (type) {
      case 'html':
        return Icons.html;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}年前';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}月前';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  void _openFile(FileInfo fileInfo) {
    _viewerService.openFile(context, fileInfo);
  }

  // 文件重命名功能
  void _renameFile(FileInfo fileInfo) {
    final TextEditingController nameController =
        TextEditingController(text: fileInfo.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名文件'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '文件名称',
              hintText: '输入新的文件名',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '文件名不能为空';
              }
              return null;
            },
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);

                // 获取文件信息
                final String path = fileInfo.path;
                final String type = fileInfo.type;
                final String oldName = fileInfo.name;
                final String newName = nameController.text;

                // 构建更新后的文件信息
                FileInfo updatedInfo = FileInfo(
                  path: path,
                  name: newName,
                  type: type,
                  lastOpened: fileInfo.lastOpened,
                  isFavorite: fileInfo.isFavorite,
                  tags: fileInfo.tags,
                  category: fileInfo.category,
                );

                // 保存更新
                await _storageService.updateFileInfo(updatedInfo);

                // 重新加载文件列表
                _loadRecentFiles();

                // 显示提示
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('文件已重命名: $oldName → $newName'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(_themeService.borderRadius),
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
