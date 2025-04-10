import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../services/viewer_service.dart';
import '../services/theme_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
  final ViewerService _viewerService = ViewerService();
  final ThemeService _themeService = ThemeService();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<FileInfo> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  // 过滤器
  String? _selectedType;
  String? _selectedCategory;
  String? _selectedTag;

  List<String> _availableCategories = ['未分类'];
  List<String> _availableTags = [];
  List<String> _availableTypes = ['html', 'pdf'];

  @override
  void initState() {
    super.initState();
    _loadFilters();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();

    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final categories = await _storageService.getAllCategories();
      final tags = await _storageService.getAllTags();

      setState(() {
        _availableCategories = categories;
        _availableTags = tags;
      });
    } catch (e) {
      // 处理错误
    }
  }

  // 执行搜索
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty &&
        _selectedType == null &&
        _selectedCategory == null &&
        _selectedTag == null) {
      // 没有搜索条件
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _storageService.searchFiles(
        query: query.isEmpty ? null : query,
        fileType: _selectedType,
        category: _selectedCategory,
        tag: _selectedTag,
      );

      // 触觉反馈
      HapticFeedback.lightImpact();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索时出错: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 清除搜索条件
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _selectedType = null;
      _selectedCategory = null;
      _selectedTag = null;
      _searchResults = [];
      _hasSearched = false;
    });
  }

  // 打开文件
  void _openFile(FileInfo fileInfo) {
    _viewerService.openFile(context, fileInfo);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '搜索文件',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_hasSearched && _searchResults.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  '${_searchResults.length}个结果',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '筛选',
            onPressed: _showFilterDialog,
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
            decoration: BoxDecoration(
              color: theme.appBarTheme.backgroundColor ?? colorScheme.surface,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(_themeService.borderRadius),
                bottomRight: Radius.circular(_themeService.borderRadius),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: '搜索文件名...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(_themeService.borderRadius),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 16.0),
              ),
              onChanged: (value) {
                // 当文本变化时自动搜索
                _performSearch();
              },
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _performSearch();
              },
            ),
          ),

          // 过滤器标签显示
          if (_selectedType != null ||
              _selectedCategory != null ||
              _selectedTag != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: theme.brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '已选筛选条件',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all, size: 16),
                        label:
                            const Text('清除全部', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _selectedType = null;
                            _selectedCategory = null;
                            _selectedTag = null;
                          });
                          _performSearch();
                          HapticFeedback.lightImpact();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      if (_selectedType != null)
                        _buildFilterChip(
                          label: '类型: ${_selectedType!.toUpperCase()}',
                          onDeleted: () {
                            setState(() {
                              _selectedType = null;
                            });
                            _performSearch();
                          },
                          color: Colors.blue,
                        ),
                      if (_selectedCategory != null)
                        _buildFilterChip(
                          label: '分类: $_selectedCategory',
                          onDeleted: () {
                            setState(() {
                              _selectedCategory = null;
                            });
                            _performSearch();
                          },
                          color: Colors.green,
                        ),
                      if (_selectedTag != null)
                        _buildFilterChip(
                          label: '标签: $_selectedTag',
                          onDeleted: () {
                            setState(() {
                              _selectedTag = null;
                            });
                            _performSearch();
                          },
                          color: Colors.purple,
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // 搜索结果
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildSearchResults(),
            ),
          ),
        ],
      ),
      floatingActionButton: _searchResults.isNotEmpty
          ? FloatingActionButton(
              mini: true,
              child: const Icon(Icons.keyboard_arrow_up),
              tooltip: '返回顶部',
              onPressed: () {
                // 回到顶部的功能
              },
            )
          : null,
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
    required Color color,
  }) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      deleteIcon: const Icon(Icons.cancel, size: 16),
      onDeleted: onDeleted,
      backgroundColor: color.withOpacity(0.1),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  // 显示过滤对话框
  void _showFilterDialog() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_themeService.borderRadius * 2),
        ),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    // 拖动条指示器
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '筛选条件',
                            style: TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              this.setState(() {
                                _selectedType = null;
                                _selectedCategory = null;
                                _selectedTag = null;
                              });
                              Navigator.pop(context);
                              _performSearch();
                            },
                            child: const Text('重置'),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),

                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        children: [
                          // 文件类型筛选
                          _buildFilterSection(
                            title: '文件类型',
                            children: [
                              Wrap(
                                spacing: 8.0,
                                children: [
                                  _buildChoiceChip(
                                    label: '全部',
                                    selected: _selectedType == null,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedType = null;
                                        });
                                      }
                                    },
                                  ),
                                  ..._availableTypes.map((type) {
                                    return _buildChoiceChip(
                                      label: type.toUpperCase(),
                                      selected: _selectedType == type,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedType =
                                              selected ? type : null;
                                        });
                                      },
                                      color: type == 'html'
                                          ? Colors.blue
                                          : Colors.red,
                                    );
                                  }).toList(),
                                ],
                              ),
                            ],
                          ),

                          // 分类筛选
                          _buildFilterSection(
                            title: '文件分类',
                            children: [
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: [
                                  _buildChoiceChip(
                                    label: '全部',
                                    selected: _selectedCategory == null,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedCategory = null;
                                        });
                                      }
                                    },
                                  ),
                                  ..._availableCategories.map((category) {
                                    return _buildChoiceChip(
                                      label: category,
                                      selected: _selectedCategory == category,
                                      onSelected: (selected) {
                                        setState(() {
                                          _selectedCategory =
                                              selected ? category : null;
                                        });
                                      },
                                      color: Colors.green,
                                    );
                                  }).toList(),
                                ],
                              ),
                            ],
                          ),

                          // 标签筛选
                          if (_availableTags.isNotEmpty)
                            _buildFilterSection(
                              title: '文件标签',
                              children: [
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: [
                                    _buildChoiceChip(
                                      label: '全部',
                                      selected: _selectedTag == null,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedTag = null;
                                          });
                                        }
                                      },
                                    ),
                                    ..._availableTags.map((tag) {
                                      return _buildChoiceChip(
                                        label: tag,
                                        selected: _selectedTag == tag,
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedTag =
                                                selected ? tag : null;
                                          });
                                        },
                                        color: Colors.purple,
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // 底部操作按钮
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 8.0),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _performSearch();
                            },
                            child: const Text('应用筛选'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chipColor = color ?? colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: chipColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? chipColor : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在搜索...'),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              '搜索您的文件',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '输入关键词或使用筛选条件',
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              '未找到匹配的文件',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试不同的关键词或筛选条件',
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final fileInfo = _searchResults[index];
        return _buildSearchResultCard(fileInfo, index);
      },
    );
  }

  Widget _buildSearchResultCard(FileInfo fileInfo, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color typeColor = _getFileTypeColor(fileInfo.type);

    final bool isFirst = index == 0;
    final bool isLast = index == _searchResults.length - 1;

    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 4 : 2,
        bottom: isLast ? 4 : 2,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_themeService.borderRadius),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(_themeService.borderRadius),
          onTap: () => _openFile(fileInfo),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文件图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(_themeService.borderRadius * 0.6),
                  ),
                  child: Center(
                    child: _getFileIcon(fileInfo.type, color: typeColor),
                  ),
                ),
                const SizedBox(width: 12),

                // 文件信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fileInfo.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (fileInfo.isFavorite)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fileInfo.type.toUpperCase()} · ${_formatDateTime(fileInfo.lastOpened)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      if (fileInfo.category != '未分类' ||
                          fileInfo.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (fileInfo.category != '未分类')
                                _buildSmallChip(
                                  fileInfo.category,
                                  Colors.green.withOpacity(0.1),
                                  Colors.green.shade700,
                                ),
                              ...fileInfo.tags.map((tag) => _buildSmallChip(
                                    '#$tag',
                                    Colors.purple.withOpacity(0.1),
                                    Colors.purple.shade700,
                                  )),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallChip(String label, Color backgroundColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _getFileIcon(String type, {Color? color}) {
    switch (type) {
      case 'html':
        return Icon(Icons.html, color: color ?? Colors.blue);
      case 'pdf':
        return Icon(Icons.picture_as_pdf, color: color ?? Colors.red);
      default:
        return Icon(Icons.insert_drive_file, color: color ?? Colors.grey);
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
}
