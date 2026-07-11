extends RefCounted
class_name FilesManager

#region -------- 枚举 & 常量 --------
## 路径类型枚举
enum PathType {
	## 目录绝对路径
	DIR,
	## 文件绝对路径
	FILE,
	## 其他，包括无效路径，相对路径，文件名或目录名等
	OTHER,
}

## 类 Unix 操作系统集合（macOS、Linux），用于O(1)哈希查找
const _UNIX_OS_SET: Dictionary = {
	"macOS": true,
	"Linux": true,
}
#endregion
#region -------- 文件操作 --------
## 按路径创建新的空文件，仅支持绝对路径
## 注意：当文件已存在时不会进行覆盖并会返回true
## @param file_path: 文件绝对路径
## @return: 是否创建成功
static func create_empty_file(file_path: String) -> bool:
	file_path = normalize_path(file_path)
	if not file_path.is_absolute_path():
		push_warning("file path is not an absolute path: ", file_path)
		return false
	if FileAccess.file_exists(file_path):
		return true
	var dir_path: String = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		if not DirAccess.make_dir_recursive_absolute(dir_path) == OK:
			push_error("create_empty_file: Can't create directory: " + dir_path)
			return false
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)

	if not file:
		push_error("create empty file failed: ", file_path)
		return false
	file.close()
	return true

## 文件改名，新路径可以为完整路径，也可以为相对路径或者新的文件名
## @param old_path: 旧文件路径
## @param new_path: 新文件路径或新文件名，如果新文件名不带后缀则使用旧文件后缀
## @param override: 是否覆盖已存在的目标文件，默认为false
## @return: 是否改名成功
static func file_rename(old_path: String, new_path: String, override: bool = false) -> bool:
	old_path = normalize_path(old_path)
	if not FileAccess.file_exists(old_path):
		push_warning("file does not exist: ", old_path)
		return false

	new_path = get_target_file_path(new_path, old_path)
	if FileAccess.file_exists(new_path) and not override:
		push_warning("file already exists: ", new_path)
		return false
	if DirAccess.rename_absolute(old_path, new_path) == OK:
		return true
	push_error("file rename failed: ", old_path, " -> ", new_path)
	return false

## 复制文件
## @param source_path: 源文件绝对路径
## @param target_path: 目标文件路径或目标文件名，如果目标路径不带扩展名，则使用源文件的扩展名
## @param override: 是否覆盖已存在的目标文件，默认为false
## @return: 是否复制成功
static func copy_file(source_path: String, target_path: String, override: bool = false) -> bool:
	source_path = normalize_path(source_path)
	var origin_target_path: String = target_path
	target_path = get_target_file_path(target_path, source_path)

	if target_path.is_empty():
		push_warning("Invalid path: " + origin_target_path)
		return false

	if FileAccess.file_exists(target_path) and not override: # 如果目标文件已存在且不允许覆盖则返回false
		push_warning("Target path is existed: " + target_path)
		return false
	var target_dir_path: String = target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(target_dir_path):
		if not DirAccess.make_dir_recursive_absolute(target_dir_path) == OK:
			push_warning("Failed to create directory: " + target_dir_path)
			return false

	return DirAccess.copy_absolute(source_path, target_path) == OK

## 删除文件或目录，将其移动到回收站
## @param path: 文件路径
## @return: 是否删除成功
static func move_to_trash(path: String) -> bool:
	return OS.move_to_trash(ProjectSettings.globalize_path(path)) is int

#endregion
#region -------- 目录操作 --------
## 按路径创建新的文件夹
## @param dir_path: 目录路径
## @return: 是否创建成功
static func create_dir(dir_path: String) -> bool:
	dir_path = normalize_path(dir_path)
	if not dir_path.is_absolute_path():
		push_warning("directory path is not an absolute path: ", dir_path)
		return false
	if DirAccess.make_dir_recursive_absolute(dir_path) != OK:
		push_error("create_dir: Can't create directory: " + dir_path)
		return false
	return true

## 目录改名，新路径可以为完整路径，也可以为相对路径或者新的目录名
## @param old_path: 旧目录路径
## @param new_path: 新目录路径或同根目录下的新目录名
## @return: 是否改名成功
static func dir_rename(old_path: String, new_path: String) -> bool:
	old_path = normalize_path(old_path)
	new_path = normalize_path(new_path)
	var dir_path: String = old_path.get_base_dir()
	if not dir_path.is_absolute_path():
		push_warning("directory path is not an absolute path: ", old_path)
		return false
	var dir: DirAccess = DirAccess.open(dir_path)
	var new_path_type: PathType = check_path_type(new_path)
	if new_path_type == PathType.FILE:
		push_warning("target path is a file path: ", new_path)
		return false
	elif new_path_type == PathType.OTHER:
		new_path = fix_path(new_path)
	if dir.rename(old_path, new_path) == OK:
		return true
	push_error("directory rename failed: ", old_path, " -> ", new_path)
	return false

## 复制文件夹（递归复制所有子文件和子文件夹）
## @param source_path: 源文件夹绝对路径
## @param target_path: 目标文件夹绝对路径
## @return: 是否复制成功
static func copy_folder(source_path: String, target_path: String) -> bool:
	if check_path_type(source_path) != PathType.DIR:
		push_warning("Invalid source path: " + source_path)
		return false
	if check_path_type(target_path) != PathType.DIR:
		push_warning("Invalid target path: " + target_path)
		return false
	var dir: DirAccess = DirAccess.open(source_path)
	if not dir:
		push_error("failed to open source folder: " + source_path)
		return false

	# 创建目标文件夹
	DirAccess.make_dir_recursive_absolute(target_path)

	# 遍历源文件夹内容
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var source_item: String = source_path.path_join(file_name)
		var target_item: String = target_path.path_join(file_name)

		if dir.current_is_dir():
			# 递归复制子文件夹
			if not copy_folder(source_item, target_item):
				return false
		else:
			# 复制文件
			if DirAccess.copy_absolute(source_item, target_item) != OK:
				push_error("failed to copy file: " + source_item)
				return false

		file_name = dir.get_next()

	dir.list_dir_end()
	return true

## 获取目录下的文件夹列表
## @param dir_path: 目录路径
## @return: 文件夹列表
static func get_dir_list(dir_path: String) -> PackedStringArray:
	dir_path = normalize_path(dir_path)
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir:
		return dir.get_directories()
	return PackedStringArray()

## 获取目录下以指定前缀开头且后缀为数字编号的文件夹列表（如 "Chapter001", "Chapter002"）
## @param dir_path: 目录路径
## @param default_name: 文件夹前缀名称（如 "Chapter"）
## @return: 匹配的文件夹名列表（按字母排序）
static func get_dir_list_by_default_name(dir_path: String, default_name: String) -> PackedStringArray:
	dir_path = normalize_path(dir_path)
	var dir: DirAccess = DirAccess.open(dir_path)
	var result: PackedStringArray = PackedStringArray()
	if dir:
		var dirs: PackedStringArray = dir.get_directories()

		for _dir in dirs:
			if _dir.begins_with(default_name) and _dir.replace(default_name, "").is_valid_int():
				result.append(_dir)
		result.sort()

	return result

## 获取目标目录在父目录下的索引
## @param dir_path: 目录路径
## @param dir_name: 目录名称
## @return: 目录索引
static func get_index_in_parent_dir(dir_path: String, dir_name: String) -> int:
	dir_path = normalize_path(dir_path)
	var dir_names: PackedStringArray = get_dir_list(dir_path)
	var index: int = dir_names.find(dir_name)
	if index == -1:
		push_warning("Directory not found: " + dir_name)
		return -1
	return index

#endregion
#region -------- 文件列表获取 --------
## 通过后缀名获取指定目录下的文件列表
## @param dir_path: 目录路径
## @param suffix_name: 后缀名称（如 ".json"）
## @param whole: 是否包含后缀名，true返回带后缀的文件名，false只返回纯文件名，默认为false
## @return: 文件名列表
static func get_file_list_by_suffix(dir_path: String, suffix_name: String = "", whole: bool = false) -> PackedStringArray:
	dir_path = normalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(dir_path):
		return []
	var dir_access: DirAccess = DirAccess.open(dir_path)
	var file_name_list: PackedStringArray = PackedStringArray()
	var pure_file_names: PackedStringArray = PackedStringArray()

	var count: int = 0
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		count += 1
		if not dir_access.current_is_dir() and file_name.ends_with(suffix_name):
			file_name_list.append(file_name)
			pure_file_names.append(file_name.get_basename())
		file_name = dir_access.get_next()
		if count > 1000:
			push_warning("Too many files in directory or in dead cycle: " + dir_path)
			break
	dir_access.list_dir_end()
	if whole:
		return file_name_list
	else:
		return pure_file_names

## 通过前缀(默认)名称获取文件名列表
## @param dir_path: 目录路径
## @param prefix_name: 前缀名称
## @param whole: 是否包含后缀名，true返回带后缀的文件名，false只返回纯文件名，默认为true
## @return: 文件名列表
static func get_files_list_by_prefix(dir_path: String, prefix_name: String, whole: bool = true) -> PackedStringArray:
	dir_path = normalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(dir_path):
		return PackedStringArray()
	var file_name_list: PackedStringArray = PackedStringArray()
	var pure_file_names: PackedStringArray = PackedStringArray()
	var dir_access: DirAccess = DirAccess.open(dir_path)
	var count: int = 0
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		count += 1
		if not dir_access.current_is_dir() and file_name.begins_with(prefix_name):
			file_name_list.append(file_name)
			pure_file_names.append(file_name.get_basename())
		file_name = dir_access.get_next()
		if count > 100:
			push_warning("Too many files in directory or in dead cycle: " + dir_path)
			break
	dir_access.list_dir_end()
	if whole:
		return file_name_list
	else:
		return pure_file_names

## 通过前缀(默认)名称以及后缀名称获取文件列表
## @param dir_path: 目录路径
## @param prefix_name: 前缀名称
## @param suffix_name: 后缀名称
## @param whole: 是否包含后缀名，true返回带后缀的文件名，false只返回纯文件名，默认为true
## @return: 文件名列表
static func get_files_list_by_prefix_and_suffix(dir_path: String, prefix_name: String, suffix_name: String, whole: bool = true) -> PackedStringArray:
	dir_path = normalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(dir_path):
		return PackedStringArray()
	var file_name_list: PackedStringArray = PackedStringArray()
	var pure_file_names: PackedStringArray = PackedStringArray()
	var dir_access: DirAccess = DirAccess.open(dir_path)
	var count: int = 0
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		count += 1
		if not dir_access.current_is_dir() and file_name.begins_with(prefix_name) and file_name.ends_with(suffix_name):
			file_name_list.append(file_name)
			pure_file_names.append(file_name.get_basename())
		file_name = dir_access.get_next()
		if count > 100:
			push_warning("Too many files in directory or in dead cycle: " + dir_path)
			break
	dir_access.list_dir_end()
	if whole:
		return file_name_list
	else:
		return pure_file_names

#endregion

#region -------- 备份管理 --------
## 通过改名或拷贝来备份文件（在文件名后添加时间戳和.bak后缀）
## @param file_path: 文件路径
## @param backup_by_copy: 是否通过拷贝备份，默认为false（改名备份，原文件保留为空文件）
## @return: 是否备份成功
static func file_backup(file_path: String, backup_by_copy: bool = false) -> bool:
	file_path = normalize_path(file_path)
	if not FileAccess.file_exists(file_path):
		push_warning("file does not exist: ", file_path)
		return false
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var backup_path: String = file_path.get_basename() + "__" + timestamp + ".bak"
	match backup_by_copy:
		true:
			# 原文件安全，但文件较大时速度较慢且占用双倍磁盘空间
			if copy_file(file_path, backup_path, true):
				return true
		false:
			# 性能极好，瞬间完成，但存在风险窗口，如果改名失败则可能丢失原文件
			if file_rename(file_path, backup_path, true):
				create_empty_file(file_path)
				return true
	return false

## 备份文件并清理超出保留数量的旧备份
## @param path: 文件路径
## @param backup_by_copy: 是否通过拷贝备份，默认为false（重命名备份，原文件保留为空文件）
## @param backup_num: 保留的最新备份数量，超过此数量的旧备份会被删除，默认为5
## @return: 是否备份成功
static func backup_and_rotate(path: String, backup_num: int = 5, backup_by_copy: bool = false) -> bool:
	path = normalize_path(path)
	if not FileAccess.file_exists(path):
		push_warning("file does not exist: ", path)
		return false
	if file_backup(path, backup_by_copy):
		clean_old_backup(path, backup_num)
		return true
	return false

## 清理超出保留数量的旧备份文件（按文件名排序，保留最新的N个）
## @param file_path: 文件路径
## @param backup_num: 保留的最新备份数量
static func clean_old_backup(file_path: String, backup_num: int) -> void:
	file_path = normalize_path(file_path)
	var file_dir: String = file_path.get_base_dir()
	if not file_dir.is_absolute_path():
		return

	var dir_access: DirAccess = DirAccess.open(file_dir)
	var prefix_name: String = file_path.get_file().get_slice(".", 0)
	var backups: Array = []
	dir_access.list_dir_begin()
	var file_name: String = dir_access.get_next()
	while file_name != "":
		if not dir_access.current_is_dir() and file_name.begins_with(prefix_name) and file_name.ends_with(".bak"):
			backups.append(file_name)
		file_name = dir_access.get_next()

	backups.sort()
	var delete_num: int = backups.size() - backup_num
	if delete_num > 0:
		for i in range(delete_num):
			dir_access.remove(backups[i])

## 用备份文件恢复为当前文件（如果目标文件已存在则先备份再覆盖）
## @param dir_path: 目录路径
## @param backup_file_name: 备份文件名（不含后缀，函数会自动添加.bak）
## @param file_name: 要恢复的目标文件名
## @return: 是否成功
static func backup_to_file(dir_path: String, backup_file_name: String, file_name: String) -> bool:
	dir_path = normalize_path(dir_path)
	var dir: DirAccess = DirAccess.open("user://")
	var backup_path: String = dir_path + backup_file_name + ".bak"
	var file_path: String = dir_path + file_name

	if FileAccess.file_exists(file_path):
		file_backup(file_path)

	if not dir.file_exists(backup_path):
		push_warning("File not found: " + backup_path)
		return false

	if file_rename(backup_path, file_path) == false:
		push_warning("Can't rename file: " + backup_path)
		return false
	return true

## 获取文件的备份文件列表
## @param file_path: 文件路径
## @return: 备份文件列表
static func get_backup_file_list(file_path: String) -> PackedStringArray:
	file_path = normalize_path(file_path)
	var file_name: String = get_path_name(file_path)
	var files: PackedStringArray = get_files_list_by_prefix_and_suffix(file_path.get_base_dir(), file_name, ".bak")
	var backup_file_list: PackedStringArray = PackedStringArray()
	for file in files:
		if file.get_slice("__", 0) == file_name and file.get_extension() == "bak":
			backup_file_list.append(file)

	return backup_file_list

## 重命名备份文件名
## @param file_path: 文件路径
## @param new_name: 新名称
## @return: 是否成功
static func rename_backup_file(file_path: String, new_name: String) -> bool:
	file_path = normalize_path(file_path)
	var backup_file_list: PackedStringArray = get_backup_file_list(file_path)
	var file_name: String = get_path_name(file_path)
	if backup_file_list.is_empty():
		return true
	var dir: DirAccess = DirAccess.open(file_path.get_base_dir())
	var old_name: String
	for backup_file in backup_file_list:
		old_name = backup_file.get_file()
		if not dir.rename(old_name, old_name.replace(file_name, new_name)):
			push_warning("Can't rename file: " + backup_file)
	return true

## 文件改名时同步更新关联备份文件的文件名（将备份文件名中的旧名称替换为新名称）
## @param file_path: 文件路径
## @param new_name: 新的文件名
## @return: 是否成功
static func sync_backup_file(file_path: String, new_name: String) -> bool:
	file_path = normalize_path(file_path)
	var file_name: String = get_path_name(file_path)
	var backup_file_list: PackedStringArray = get_backup_file_list(file_path)
	if backup_file_list.is_empty():
		return true
	var dir: DirAccess = DirAccess.open(file_path.get_base_dir())
	for backup_file in backup_file_list:
		if not dir.rename(backup_file, backup_file.replace(file_name, new_name)):
			push_warning("Can't rename file: " + backup_file)
	return true

#endregion

#region -------- 顺序命名工具 --------

## 获取目录下匹配前缀的文件/文件夹的数字编号数组（从名称中提取前缀后的纯数字部分）
## @param dir_path: 目录路径
## @param default_name: 前缀名称（如 "Chapter"）
## @param suffix_name: 后缀名称（仅 flag=true 时有效）
## @param flag: true=文件类型（用后缀过滤），false=文件夹类型
## @return: 去重后的数字编号数组
static func get_code_from_default_name(dir_path: String, default_name: String, suffix_name: String, flag: bool) -> PackedInt32Array:
	dir_path = normalize_path(dir_path)
	var file_names: Variant
	if flag:
		file_names = get_files_list_by_prefix_and_suffix(dir_path, default_name, suffix_name)
	else:
		file_names = get_dir_list_by_default_name(dir_path, default_name)
	var file_code: PackedInt32Array = PackedInt32Array()
	for i in file_names.size():
		file_code.append(int(file_names[i].replace(default_name, "")))
	#去重复
	var unique_dict: Dictionary = {}
	var code_list: PackedInt32Array = PackedInt32Array()
	for num in file_code:
		if not unique_dict.has(num):
			unique_dict[num] = 1
			code_list.append(num)
	return code_list

## 获取目录下可用的最小空缺编号（从0开始递增，跳跃已有编号）
## @param dir_path: 目录路径
## @param default_name: 前缀名称（如 "Chapter"）
## @param suffix_name: 后缀名称（仅 flag=true 时有效）
## @param flag: true=文件类型，false=文件夹类型
## @return: 可用最小空缺编号
static func get_latest_code_from_default_name(dir_path: String, default_name: String, suffix_name: String, flag: bool) -> int:
	dir_path = normalize_path(dir_path)
	var default_name_code: PackedInt32Array = get_code_from_default_name(dir_path, default_name, suffix_name, flag)
	var code: int = 0
	for num in default_name_code:
		if code < num:
			break
		else:
			code += 1
	return code

## 获取目录下最新默认文件名，不包括后缀名
## @param dir_path: 目录路径
## @param default_name: 默认名称
## @param suffix_name: 后缀名称
## @param flag: true=文件类型，false=文件夹类型
## @return: 最新默认文件名
static func get_latest_default_name(dir_path: String, default_name: String = "", suffix_name: String = "", flag: bool = false) -> String:
	dir_path = normalize_path(dir_path)
	var code: int = get_latest_code_from_default_name(dir_path, default_name, suffix_name, flag)
	if code > 99:
		return default_name + str(code)
	if code > 9:
		return default_name + "0" + str(code)
	return default_name + "00" + str(code)

#endregion
#region -------- 路径工具 --------
## 规范路径
## @param path: 路径
## @return: 规范后的路径（反斜杠转正斜杠，去除首尾空白）
static func normalize_path(path: String) -> String:
	return path.replace("\\", "/").strip_edges()

## 文件路径禁止符修正，根据当前操作系统移除路径中的非法字符
## @param text: 输入文本
## @return: 修正后的文本
static func fix_path(text: String) -> String:
	var fixed_account: String = text

	# 定义不同系统的禁用字符
	var invalid_chars: String = ""

	if OS.get_name() == "Windows":
		# Windows 禁用字符: < > : " / \ | ? *
		invalid_chars = r'[<>:"/\\|?*]'
	elif _UNIX_OS_SET.has(OS.get_name()):
		# macOS/Linux 禁用字符: / （根目录分隔符）
		invalid_chars = r'[/]'
	else:
		# 其他系统（如Android、iOS），默认不处理
		return fixed_account

	# 使用正则表达式替换禁用字符
	var regex: RegEx = RegEx.new()
	if regex.compile(invalid_chars) == OK:
		fixed_account = regex.sub(fixed_account, "", true)

	# 额外处理：移除开头/结尾的点或空格（Windows不允许）
	if OS.get_name() == "Windows":
		fixed_account = fixed_account.strip_edges().trim_suffix(".").trim_suffix(" ")

	# 检查是否为Windows保留名称（如CON, PRN, AUX等）
	if OS.get_name() == "Windows" and is_windows_reserved_name(fixed_account):
		fixed_account = "_" + fixed_account # 添加前缀避免冲突

	# 为避免和备份名冲突，禁止使用双下划线
	fixed_account = fixed_account.replace("__", "_")

	return fixed_account

## 检查是否是Windows保留名称（如CON, PRN, AUX等）
## @param text: 输入文本
## @return: 是否是Windows保留名称
const RESERVED_NAMES: Dictionary = {
	"CON": true, "PRN": true, "AUX": true, "NUL": true,
	"COM1": true, "COM2": true, "COM3": true, "COM4": true,
	"COM5": true, "COM6": true, "COM7": true, "COM8": true, "COM9": true,
	"LPT1": true, "LPT2": true, "LPT3": true, "LPT4": true,
	"LPT5": true, "LPT6": true, "LPT7": true, "LPT8": true, "LPT9": true,
}

static func is_windows_reserved_name(text: String) -> bool:
	return RESERVED_NAMES.has(text.to_upper())

## 根据路径获取文件名或者目录名
## @param path: 路径
## @return: 文件名或者目录名
static func get_path_name(path: String) -> String:
	path = normalize_path(path)
	var path_type: PathType = check_path_type(path)
	match path_type:
		PathType.DIR:
			return path.rstrip("/").get_file()
		PathType.FILE, PathType.OTHER:
			return path.get_file().get_basename()
		_:
			return ""

## 获取文件在文件系统中的全局路径
## @param path: 文件路径（支持相对路径或完整路径）
## @return: 文件的绝对路径，文件不存在则返回空字符串
static func get_global_file_path(path: String) -> String:
	path = normalize_path(path)
	if not path.is_absolute_path():
		return ""
	return ProjectSettings.globalize_path(path)

## 获取目标文件绝对路径
## @param target_path: 目标文件路径，如果目标路径不带扩展名，则使用参考路径的扩展名
## @param source_path: 参考路径，当 target_path 为文件名或子路径时，用于提供默认目录和扩展名
## @return: 目标文件绝对路径
static func get_target_file_path(target_path: String, source_path: String = "") -> String:
	target_path = normalize_path(target_path).trim_suffix("/")
	if target_path.is_empty():
		push_warning("target_path is empty")
		return ""

	# 如果 target_path 已经是完整文件路径，直接返回
	var target_path_type: PathType = check_path_type(target_path)
	if target_path_type == PathType.DIR:
		push_warning("target_path[%s] is a dir path" % [target_path])
		return ""
	if target_path_type == PathType.FILE:
		return target_path

	# target_path 不是完整路径，需要 source_path 来补全
	if source_path.is_empty():
		push_warning("source_path is empty, can't resolve target path: " + target_path)
		return ""
	source_path = normalize_path(source_path)
	var source_path_type: PathType = check_path_type(source_path)
	if not source_path_type == PathType.FILE:
		push_warning("source_path[%s] is not a file path" % [source_path])
		return ""

	var source_extension: String = source_path.get_extension()
	var target_file_name: String = target_path.get_basename()
	var extension: String
	if target_path.get_extension().is_empty():
		extension = source_extension
	else:
		extension = target_path.get_extension()
	var dir_path: String = source_path.get_base_dir()

	target_path = dir_path.path_join(target_file_name + "." + extension)
	return target_path

#endregion

#region -------- 路径判断 --------
## 检查路径类型
## @param path: 路径（支持绝对路径或相对路径）
## @return: PathType.DIR（目录绝对路径）/ PathType.FILE（文件绝对路径）/ PathType.OTHER（相对路径或无效路径）
static func check_path_type(path: String) -> PathType:
	path = normalize_path(path)
	if not path.is_absolute_path():
		return PathType.OTHER
	if path.ends_with("/"):
		return PathType.DIR

	var extension: String = path.get_extension()
	if extension.is_empty(): # 项目文件命名规范，文件名必须带后缀否则视为目录
		return PathType.DIR
	else:
		return PathType.FILE

## 检查路径是否为系统资源路径（res://目录下）
## @param path: 路径
## @return: 是否为系统资源路径
static func check_is_res_path(path: String) -> bool:
	path = normalize_path(path)
	var project_root: String = ProjectSettings.globalize_path("res://")
	var normalized_root: String = project_root.replace("\\", "/").rstrip("/") + "/"
	var normalized_path: String = path.replace("\\", "/")
	return normalized_path.begins_with(normalized_root)

## 检查路径是否为用户文件夹路径（user://目录下）
## @param path: 路径
## @return: 是否为用户路径
static func check_is_user_path(path: String) -> bool:
	path = normalize_path(path)
	var user_root: String = ProjectSettings.globalize_path("user://")
	var normalized_root: String = user_root.replace("\\", "/").rstrip("/") + "/"
	var normalized_path: String = path.replace("\\", "/")
	return normalized_path.begins_with(normalized_root)

## 判定两个路径是否相同
## @param path1: 路径1
## @param path2: 路径2
## @return: 是否相同
static func check_path_equal(path1: String, path2: String) -> bool:
	return ProjectSettings.globalize_path(path1) == ProjectSettings.globalize_path(path2)

## 将系统完整路径转化为游戏根目录下完整路径（res://），如果不是则返回空字符串
## @param path: 路径
## @return: 游戏根目录下完整路径
static func reslize_path(path: String) -> String:
	path = normalize_path(path)
	var project_root: String = ProjectSettings.globalize_path("res://")
	var normalized_root: String = project_root.replace("\\", "/").rstrip("/") + "/"
	var normalized_path: String = path.replace("\\", "/")

	if normalized_path.begins_with(normalized_root):
		return normalized_path.replace(normalized_root, "res://")
	else:
		return ""

## 将系统完整路径转化为用户文件夹下完整路径（user://），如果不是则返回空字符串
## @param path: 路径
## @return: 用户文件夹下完整路径
static func userlize_path(path: String) -> String:
	var user_root: String = ProjectSettings.globalize_path("user://")
	var normalized_root: String = user_root.replace("\\", "/").rstrip("/") + "/"
	var normalized_path: String = normalize_path(path)
	if normalized_path.begins_with(normalized_root):
		return normalized_path.replace(normalized_root, "user://")
	else:
		return ""

#endregion
