import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '外观'),
            Tab(text: '文件'),
            Tab(text: '关于'),
          ],
          indicatorWeight: 3,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurface.withOpacity(0.7),
          indicatorColor: colorScheme.primary,
          dividerColor: Colors.transparent,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAppearanceTab(themeService),
          _buildFileManagementTab(),
          _buildAboutTab(),
        ],
      ),
    );
  }

  // 外观标签页
  Widget _buildAppearanceTab(ThemeService themeService) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      children: [
        const SizedBox(height: 16),

        // 主题模式选择
        _buildSettingSection(
          title: '主题模式',
          icon: Icons.brightness_4,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildThemeModeOption(
                    title: '跟随系统',
                    subtitle: '根据系统设置自动调整',
                    icon: Icons.brightness_auto,
                    selected: themeService.themeMode == ThemeMode.system,
                    onTap: () => themeService.setThemeMode(ThemeMode.system),
                  ),
                  const Divider(),
                  _buildThemeModeOption(
                    title: '浅色模式',
                    subtitle: '始终使用浅色主题',
                    icon: Icons.brightness_5,
                    selected: themeService.themeMode == ThemeMode.light,
                    onTap: () => themeService.setThemeMode(ThemeMode.light),
                  ),
                  const Divider(),
                  _buildThemeModeOption(
                    title: '深色模式',
                    subtitle: '始终使用深色主题',
                    icon: Icons.brightness_2,
                    selected: themeService.themeMode == ThemeMode.dark,
                    onTap: () => themeService.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 主题颜色选择
        _buildSettingSection(
          title: '主题颜色',
          icon: Icons.color_lens,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '预设主题',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(
                      themeService.themes.length,
                      (index) => _buildThemeOption(themeService, index),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 界面设置
        _buildSettingSection(
          title: '界面设置',
          icon: Icons.tune,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // 圆角大小
                ListTile(
                  title: const Text('界面圆角'),
                  subtitle: Text('${themeService.borderRadius.toInt()}px'),
                  leading: const Icon(Icons.rounded_corner),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: themeService.borderRadius,
                      min: 0,
                      max: 24,
                      divisions: 12,
                      label: themeService.borderRadius.toInt().toString(),
                      onChanged: (value) {
                        themeService.setBorderRadius(value);
                      },
                    ),
                  ),
                ),

                // 紧凑界面
                SwitchListTile(
                  title: const Text('紧凑界面'),
                  subtitle: const Text('减少内容间距，显示更多信息'),
                  value: themeService.useDenseUi,
                  onChanged: (value) {
                    themeService.setUseDenseUi(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        onTap();
        HapticFeedback.lightImpact();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.6),
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? colorScheme.primary : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(ThemeService themeService, int index) {
    final appTheme = themeService.themes[index];
    final bool isSelected = themeService.currentTheme.name == appTheme.name;

    return GestureDetector(
      onTap: () {
        themeService.setThemeByIndex(index);
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isSelected
              ? appTheme.primary.withOpacity(0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? appTheme.primary : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: appTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: appTheme.primary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              appTheme.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? appTheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 文件管理标签页
  Widget _buildFileManagementTab() {
    return ListView(
      children: [
        const SizedBox(height: 16),
        _buildSettingSection(
          title: '文件分类',
          icon: Icons.folder,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  title: const Text('管理分类'),
                  subtitle: const Text('编辑或删除文件分类'),
                  leading: const Icon(Icons.category),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCategoriesDialog(),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('管理标签'),
                  subtitle: const Text('编辑或删除文件标签'),
                  leading: const Icon(Icons.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTagsDialog(),
                ),
              ],
            ),
          ),
        ),
        _buildSettingSection(
          title: '文件管理',
          icon: Icons.storage,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                FutureBuilder<String>(
                    future: _storageService.getStoragePath(),
                    builder: (context, snapshot) {
                      String path = snapshot.data ?? '加载中...';
                      return ListTile(
                        title: const Text('存储位置'),
                        subtitle: Text(path,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        leading: const Icon(Icons.folder_open),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _showSetStoragePathDialog(),
                      );
                    }),
                const Divider(height: 1),
                ListTile(
                  title: const Text('支持的文件类型'),
                  subtitle: const Text('HTML, PDF'),
                  leading: const Icon(Icons.description),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('清除缓存'),
                  subtitle: const Text('删除临时文件'),
                  leading: const Icon(Icons.cleaning_services),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showClearCacheDialog(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 关于标签页
  Widget _buildAboutTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      children: [
        const SizedBox(height: 16),

        // 应用图标和名称
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.html,
                  size: 60,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'HTML 启动器',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '版本 1.0.0',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        // 关于信息
        ListTile(
          title: const Text('检查更新'),
          leading: const Icon(Icons.system_update),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('当前已是最新版本'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        ListTile(
          title: const Text('隐私政策'),
          leading: const Icon(Icons.privacy_tip),
          onTap: () {
            // 显示隐私政策
          },
        ),
        ListTile(
          title: const Text('意见反馈'),
          leading: const Icon(Icons.feedback),
          onTap: () {
            // 提供反馈
          },
        ),
        ListTile(
          title: const Text('关于'),
          leading: const Icon(Icons.info),
          onTap: () => _showAboutDialog(),
        ),

        // 底部版权信息
        const SizedBox(height: 24),
        Center(
          child: Text(
            '© 2023 HTML Launcher',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSettingSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        child,
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _showCategoriesDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<String> categories = await _storageService.getAllCategories();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('管理分类'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_off,
                        size: 48,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text('没有创建任何分类'),
                      const SizedBox(height: 8),
                      Text(
                        '在文件页面添加文件到分类',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(categories[index]),
                      leading: Icon(
                        Icons.folder,
                        color: colorScheme.primary.withOpacity(0.7),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTagsDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<String> tags = await _storageService.getAllTags();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.label, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('管理标签'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: tags.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.label_off,
                        size: 48,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text('没有创建任何标签'),
                      const SizedBox(height: 8),
                      Text(
                        '在文件页面为文件添加标签',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 标签搜索框
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '搜索标签...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    // 标签列表
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            deleteIcon: const Icon(Icons.clear, size: 16),
                            onDeleted: () {
                              // 删除标签
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          tags.isNotEmpty
              ? TextButton.icon(
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text('清除所有'),
                  onPressed: () {
                    // 清除所有标签
                    Navigator.pop(context);
                  },
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Future<void> _showClearCacheDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存文件吗？这不会删除您的文件信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 执行清除缓存操作
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('缓存已清除'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAboutDialog() async {
    showAboutDialog(
      context: context,
      applicationName: 'HTML 启动器',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.html,
          size: 30,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      children: [
        const SizedBox(height: 16),
        const Text('HTML 启动器是一个轻量级的 HTML 和 PDF 文件查看器，支持收藏、分类和标签功能。'),
        const SizedBox(height: 16),
        const Text('© 2023 HTML Launcher'),
      ],
    );
  }

  // 显示设置存储路径对话框
  Future<void> _showSetStoragePathDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final TextEditingController pathController = TextEditingController();
    String currentPath = await _storageService.getStoragePath();
    pathController.text = currentPath;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder_open, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text('设置存储位置'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('当前存储位置:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              width: double.infinity,
              child: Text(
                currentPath,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('设置新的存储位置:'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pathController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '输入路径或选择文件夹',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.folder),
                  tooltip: '选择文件夹',
                  onPressed: () async {
                    try {
                      String? selectedDirectory =
                          await FilePicker.platform.getDirectoryPath();
                      if (selectedDirectory != null) {
                        pathController.text = selectedDirectory;
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('选择文件夹失败: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '默认使用应用的文档目录',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              bool success = await _storageService.resetToDefaultStoragePath();
              if (mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '已重置为默认存储位置' : '重置失败'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );

                setState(() {});
              }
            },
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: () async {
              final path = pathController.text.trim();
              if (path.isNotEmpty) {
                bool success = await _storageService.setCustomStoragePath(path);
                if (mounted) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '存储位置已更新' : '设置失败，请确保路径有效且可写'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );

                  setState(() {});
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
