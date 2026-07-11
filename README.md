# UnorthodoxHacks

![Godot](https://img.shields.io/badge/Godot-4.3+-478CBF?logo=godot-engine&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)

> 一个 Godot 4 脚本分享仓库，提供一些实用工具脚本和示例代码。  
> 欢迎 Star ⭐ 和 Fork，一起交流学习！

---

## 📦 目前已有脚本

| 脚本 | 说明 |
|:----|:----|
| `FileManager/files_manager.gd` | **文件管理器** — 提供路径解析、文件操作等实用工具方法，支持绝对路径/相对路径处理 |
| `FileManager/config_file_manager.gd` | **配置文件管理器** — 继承自 FilesManager，封装了 ConfigFile 的读写操作，支持安全加载、保存字典等 |
| `FileManager/test.gd` | **使用示例 / 演示脚本** — 展示了两个工具类的各种用法，方便快速上手 |

## 🚀 快速使用

将 `FileManager` 文件夹复制到你的项目中即可使用：

```gdscript
# 文件路径操作
FilesManager.get_path_name("res://abc/file.json")   # → "file.json"
FilesManager.get_target_file_path("backup/", 源路径) # → 生成目标路径

# 配置文件读写
ConfigFileManager.save_section_dict("res://config.cfg", "玩家", {"name": "gugu"})
var data = ConfigFileManager.load_section_dict("res://config.cfg", "玩家")
```

更多用法请参考 `test.gd` 中的示例代码。

---

## 📺 关于作者

**B站ID：[小爱孤辰](https://space.bilibili.com/30337799)** 🎮

不定期分享 Godot 开发相关的内容，欢迎关注！

---

## 📄 许可证

本项目采用 MIT 许可证 — 详见 [LICENSE](LICENSE) 文件（如有）。
