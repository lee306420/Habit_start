import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import '../services/storage_service.dart';

abstract class FileViewer {
  Widget buildViewer(String filePath);
}

class HTMLViewer implements FileViewer {
  @override
  Widget buildViewer(String filePath) {
    final WebViewController controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFile(filePath);

    return WebViewWidget(controller: controller);
  }
}

class PDFViewer implements FileViewer {
  @override
  Widget buildViewer(String filePath) {
    return PDFView(
      filePath: filePath,
      enableSwipe: true,
      swipeHorizontal: true,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      fitPolicy: FitPolicy.BOTH,
    );
  }
}

class ViewerService {
  static final ViewerService _instance = ViewerService._internal();
  factory ViewerService() => _instance;
  ViewerService._internal();

  final StorageService _storageService = StorageService();

  Widget getViewerForFile(FileInfo fileInfo) {
    // 将相对路径转换为绝对路径
    final String relativePath = fileInfo.path;
    final String absolutePath = _storageService.getFullPath(relativePath);

    if (fileInfo.isHTML) {
      return HTMLViewer().buildViewer(absolutePath);
    } else if (fileInfo.isPDF) {
      return PDFViewer().buildViewer(absolutePath);
    }

    // 默认情况下尝试使用HTML查看器
    return HTMLViewer().buildViewer(absolutePath);
  }

  Future<void> openFile(BuildContext context, FileInfo fileInfo) async {
    // 更新文件的最后访问时间
    FileInfo updatedInfo = FileInfo(
      path: fileInfo.path,
      name: fileInfo.name,
      type: fileInfo.type,
      lastOpened: DateTime.now(),
      tags: fileInfo.tags,
      category: fileInfo.category,
      isFavorite: fileInfo.isFavorite,
    );

    await _storageService.updateFileInfo(updatedInfo);

    // 导航到查看器页面，并在返回时接收可能的更新标志
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FileViewerPage(fileInfo: updatedInfo),
      ),
    );

    // 如果返回了true，表示文件已更新，需要刷新界面
    if (result == true) {
      // 关闭页面时自动返回上一级，上一级页面会自动刷新
      // 不需要额外操作
    }
  }
}

class FileViewerPage extends StatefulWidget {
  final FileInfo fileInfo;

  const FileViewerPage({super.key, required this.fileInfo});

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  final ViewerService _viewerService = ViewerService();
  final StorageService _storageService = StorageService();
  bool _hasUpdates = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // 当页面即将关闭时，返回是否有更新的标志
      onWillPop: () async {
        Navigator.pop(context, _hasUpdates);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileInfo.name),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                  widget.fileInfo.isFavorite ? Icons.star : Icons.star_border),
              color: widget.fileInfo.isFavorite ? Colors.amber : null,
              onPressed: () async {
                FileInfo updatedInfo = FileInfo(
                  path: widget.fileInfo.path,
                  name: widget.fileInfo.name,
                  type: widget.fileInfo.type,
                  lastOpened: widget.fileInfo.lastOpened,
                  tags: widget.fileInfo.tags,
                  category: widget.fileInfo.category,
                  isFavorite: !widget.fileInfo.isFavorite,
                );

                await StorageService().updateFileInfo(updatedInfo);

                // 标记有更新
                setState(() {
                  _hasUpdates = true;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(updatedInfo.isFavorite ? '已添加到收藏' : '已从收藏中移除'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'change_category') {
                  _showCategoryDialog(context);
                } else if (value == 'share') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('分享功能即将推出'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'change_category',
                  child: Row(
                    children: [
                      Icon(Icons.folder, size: 20),
                      SizedBox(width: 8),
                      Text('更改分类'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 8),
                      Text('分享'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.fileInfo.isHTML
                        ? Icons.html
                        : (widget.fileInfo.isPDF
                            ? Icons.picture_as_pdf
                            : Icons.insert_drive_file),
                    color: widget.fileInfo.isHTML
                        ? Colors.blue
                        : (widget.fileInfo.isPDF ? Colors.red : Colors.grey),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<String>(
                        future: _getDisplayPath(),
                        builder: (context, snapshot) {
                          String displayPath =
                              snapshot.data ?? widget.fileInfo.path;
                          return Text(
                            '${widget.fileInfo.name} (${widget.fileInfo.type.toUpperCase()})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _viewerService.getViewerForFile(widget.fileInfo),
            ),
          ],
        ),
      ),
    );
  }

  // 获取展示用的路径（用于界面显示）
  Future<String> _getDisplayPath() async {
    String storagePath = await _storageService.getStoragePath();

    if (widget.fileInfo.path.startsWith('files/')) {
      return '存储: ${widget.fileInfo.path}';
    } else if (widget.fileInfo.path.startsWith('/')) {
      // 外部文件
      return '外部: ${widget.fileInfo.path}';
    }

    return widget.fileInfo.path;
  }

  // 显示分类编辑对话框
  Future<void> _showCategoryDialog(BuildContext context) async {
    List<String> categories = await StorageService().getAllCategories();
    String selectedCategory = widget.fileInfo.category;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('选择分类'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('新建分类'),
                      onPressed: () {
                        final TextEditingController categoryController =
                            TextEditingController();
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('新建分类'),
                            content: TextField(
                              controller: categoryController,
                              decoration: const InputDecoration(
                                labelText: '分类名称',
                                hintText: '输入分类名称',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (categoryController.text.isNotEmpty) {
                                    setState(() {
                                      categories.add(categoryController.text);
                                      selectedCategory =
                                          categoryController.text;
                                    });
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text('添加'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return RadioListTile<String>(
                            title: Text(category),
                            value: category,
                            groupValue: selectedCategory,
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() {
                                  selectedCategory = value;
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    // 保存分类
                    FileInfo updatedInfo = FileInfo(
                      path: widget.fileInfo.path,
                      name: widget.fileInfo.name,
                      type: widget.fileInfo.type,
                      lastOpened: widget.fileInfo.lastOpened,
                      tags: widget.fileInfo.tags,
                      category: selectedCategory,
                      isFavorite: widget.fileInfo.isFavorite,
                    );

                    await StorageService().updateFileInfo(updatedInfo);

                    // 标记有更新
                    this.setState(() {
                      _hasUpdates = true;
                    });

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('分类已更新'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
