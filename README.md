# Habit_start

这是一个名为"HTML启动器"的Flutter应用程序。主要功能包括：

1. **基本功能**：这是一个用于查看和管理HTML和PDF文件的应用程序，允许用户打开、管理和查看这些文件。

2. **核心组件**：
   - 文件选择和管理功能（使用file_picker和permission_handler）
   - HTML和PDF文件查看功能（使用webview_flutter和flutter_pdfview）
   - 文件存储和数据持久化（使用sqflite和path_provider）
   - 主题管理系统（支持亮色/暗色模式切换）

3. **项目结构**：
   - `lib/main.dart`：应用程序的入口点，包含主要的UI和初始化代码
   - `lib/pages/`：包含不同页面的实现，包括设置页面、文件管理器和搜索页面
   - `lib/services/`：包含业务逻辑和服务实现，负责存储、主题和文件查看等功能

4. **主要功能**：
   - 文件导入和管理
   - 最近使用文件列表
   - 收藏文件功能
   - 文件搜索
   - 主题设置
   - 移动设备权限管理

