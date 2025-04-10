import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/viewer_service.dart';
import '../services/theme_service.dart';
import './search_page.dart';
import 'dart:math' as math;

class FileManagerPage extends StatefulWidget {
  const FileManagerPage({super.key});

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final ViewerService _viewerService = ViewerService();
  final ThemeService _themeService = ThemeService();
  late TabController _tabController;

  List<FileInfo> _allFiles = [];
  List<FileInfo> _favoriteFiles = [];
  List<FileInfo> _recentFiles = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  // 为列表添加滚动控制器
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadFiles();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      // 添加触觉反馈
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    if (_isRefreshing) return;

    setState(() {
      _isLoading = _allFiles.isEmpty;
      _isRefreshing = true;
    });

    try {
      // 获取所有文件
      List<FileInfo> allFiles =
          await _storageService.getRecentFiles(limit: 100);

      // 获取收藏文件
      List<FileInfo> favoriteFiles = await _storageService.getFavoriteFiles();

      // 获取最近文件（限制20个）
      List<FileInfo> recentFiles =
          await _storageService.getRecentFiles(limit: 20);

      // 按时间排序（最近的在前）
      allFiles.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));

      if (mounted) {
        setState(() {
          _allFiles = allFiles;
          _favoriteFiles = favoriteFiles;
          _recentFiles = recentFiles;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载文件时出错: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteFile(
      FileInfo fileInfo, int index, bool isFavoriteTab) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${fileInfo.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _storageService.deleteFileInfo(fileInfo.path);

        if (mounted) {
          setState(() {
            if (isFavoriteTab) {
              _favoriteFiles.removeAt(index);
            } else if (_tabController.index == 1) {
              // 如果当前在"最近"标签页
              _recentFiles.removeAt(index);
            } else {
              // 如果当前在"全部"标签页
              _allFiles.removeAt(index);
            }

            // 从其他列表中移除
            if (!isFavoriteTab) {
              _favoriteFiles.removeWhere((file) => file.path == fileInfo.path);
            }

            if (_tabController.index != 0) {
              _allFiles.removeWhere((file) => file.path == fileInfo.path);
            }

            if (_tabController.index != 1) {
              _recentFiles.removeWhere((file) => file.path == fileInfo.path);
            }
          });

          // 添加触觉反馈
          HapticFeedback.mediumImpact();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文件已删除'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除文件时出错: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _toggleFavorite(FileInfo fileInfo, int index, bool isFavoriteTab) async {
    FileInfo updatedInfo = FileInfo(
      path: fileInfo.path,
      name: fileInfo.name,
      type: fileInfo.type,
      lastOpened: fileInfo.lastOpened,
      isFavorite: !fileInfo.isFavorite,
      tags: fileInfo.tags,
      category: fileInfo.category,
    );

    try {
      await _storageService.updateFileInfo(updatedInfo);

      // 更新状态
      if (mounted) {
        setState(() {
          if (isFavoriteTab) {
            _favoriteFiles.removeAt(index);
          } else {
            if (_tabController.index == 0) {
              // 全部文件标签
              _allFiles[index] = updatedInfo;
            } else if (_tabController.index == 1) {
              // 最近文件标签
              _recentFiles[index] = updatedInfo;
            }
          }
        });

        // 添加触觉反馈
        HapticFeedback.lightImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updatedInfo.isFavorite ? '已添加到收藏' : '已从收藏中移除'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_themeService.borderRadius),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_themeService.borderRadius),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '文件管理器',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchPage(),
                  ),
                ).then((_) => _loadFiles());
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "全部"),
              Tab(text: "最近"),
              Tab(text: "收藏"),
            ],
            indicatorWeight: 3,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurface.withOpacity(0.7),
            indicatorColor: colorScheme.primary,
            dividerColor: Colors.transparent,
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFileList(_allFiles, false),
                  _buildFileList(_recentFiles, false),
                  _buildFileList(_favoriteFiles, true),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // 滚动到顶部
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          },
          tooltip: '返回顶部',
          child: const Icon(Icons.arrow_upward),
        ),
      ),
    );
  }

  Widget _buildFileList(List<FileInfo> files, bool isFavoriteTab) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '加载中...',
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (files.isEmpty) {
      final emptyMessage = isFavoriteTab ? '没有收藏的文件' : '没有最近的文件';
      final actionText = isFavoriteTab ? '收藏一些文件吧' : '打开一些文件吧';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFavoriteTab ? Icons.star_border : Icons.folder_open,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              actionText,
              style: TextStyle(
                fontSize: 14,
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadFiles();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final fileInfo = files[index];
          final isFirst = index == 0;
          final isLast = index == files.length - 1;

          return _buildFileCard(
            fileInfo,
            index,
            isFavoriteTab,
            isFirst: isFirst,
            isLast: isLast,
          );
        },
      ),
    );
  }

  Widget _buildFileCard(FileInfo fileInfo, int index, bool isFavoriteTab,
      {bool isFirst = false, bool isLast = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double borderRadius = _themeService.borderRadius;
    final Color cardColor = theme.brightness == Brightness.dark
        ? colorScheme.surface.withOpacity(0.8)
        : colorScheme.surface;

    final String subtitle =
        '${fileInfo.type.toUpperCase()} · ${_formatDateTime(fileInfo.lastOpened)}';
    final Color typeColor = _getFileTypeColor(fileInfo.type);

    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 8 : 4,
        bottom: isLast ? 8 : 4,
      ),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: () => _openFile(fileInfo),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              children: [
                // 文件图标
                Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(borderRadius * 0.8),
                  ),
                  child: Center(
                    child:
                        _getFileIcon(fileInfo.type, size: 32, color: typeColor),
                  ),
                ),

                // 文件信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileInfo.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      if (fileInfo.category != '未分类' ||
                          fileInfo.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            children: [
                              if (fileInfo.category != '未分类')
                                _buildCategoryChip(fileInfo.category),
                              ...fileInfo.tags
                                  .take(2)
                                  .map((tag) => _buildTagChip(tag)),
                              if (fileInfo.tags.length > 2)
                                _buildMoreTagsChip(fileInfo.tags.length - 2),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 操作按钮
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                              scale: animation, child: child);
                        },
                        child: Icon(
                          fileInfo.isFavorite ? Icons.star : Icons.star_border,
                          key: ValueKey<bool>(fileInfo.isFavorite),
                          color: fileInfo.isFavorite ? Colors.amber : null,
                        ),
                      ),
                      onPressed: () =>
                          _toggleFavorite(fileInfo, index, isFavoriteTab),
                      tooltip: fileInfo.isFavorite ? '取消收藏' : '添加到收藏',
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () =>
                          _showFileOptionsMenu(fileInfo, index, isFavoriteTab),
                      tooltip: '更多选项',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '#$tag',
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _buildMoreTagsChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  // 显示文件操作菜单
  void _showFileOptionsMenu(FileInfo fileInfo, int index, bool isFavoriteTab) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 文件信息标题
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileInfo.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fileInfo.type.toUpperCase()} · ${_formatDateTime(fileInfo.lastOpened)}',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 操作选项
              ListTile(
                leading: Icon(Icons.open_in_new, color: colorScheme.primary),
                title: const Text('打开文件'),
                onTap: () {
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
                onTap: () {
                  Navigator.pop(context);
                  _toggleFavorite(fileInfo, index, isFavoriteTab);
                },
              ),
              if (fileInfo.category != '未分类')
                ListTile(
                  leading: Icon(Icons.folder, color: colorScheme.primary),
                  title: Text('分类: ${fileInfo.category}'),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    Navigator.pop(context);
                    // 处理修改分类
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteFile(fileInfo, index, isFavoriteTab);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _getFileIcon(String type, {double size = 24, Color? color}) {
    final iconColor = color ?? Theme.of(context).colorScheme.primary;

    switch (type) {
      case 'html':
        return Icon(Icons.html, size: size, color: iconColor);
      case 'pdf':
        return Icon(Icons.picture_as_pdf, size: size, color: iconColor);
      default:
        return Icon(Icons.insert_drive_file, size: size, color: iconColor);
    }
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
}
