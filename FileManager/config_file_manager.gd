extends FilesManager
class_name ConfigFileManager

#region -------- 工具方法 --------
## 安全读取cfg文件内容并返回ConfigFile对象，文件不存在时返回null
## @param path: cfg文件路径
## @param create_empty: cfg文件文件不存在是否创建空文件
## @return: ConfigFile对象实例
static func load_cfg(path: String, create_empty: bool = false) -> ConfigFile:
	if not path.is_absolute_path():
		push_warning("ConfigFileManager: load_cfg, path is not absolute: %s" % path)
		return null
	var cfg: ConfigFile = ConfigFile.new()
	if not FileAccess.file_exists(path) and create_empty:
		if not create_empty_file(path):
			return null
	var error = cfg.load(path)
	if error != OK:
		push_warning("ConfigFileManager: load_cfg, load cfg file [%s] error: %s " % [path, error])
		return null
	return cfg

## 储存数据到cfg文件
## @param cfg: ConfigFile
## @param path: cfg文件路径
static func _save_cfg(cfg: ConfigFile, file_path: String) -> bool:
	var error = cfg.save(file_path)
	if error != OK:
		push_error("Error saving config file: ", error)
		return false
	else:
		# print_debug("ConfigFileManager: load_cfg, load cfg file [%s] success" % file_path)
		return true
#endregion

#region -------- 整个文件操作方法 --------
## 获取cfg文件内容作为字典返回，主键为section名，value为section的key和value的键值对字典
## @param path: cfg文件路径
## @param create_empty: cfg文件文件不存在是否创建空文件
## @return: cfg文件内容
static func get_cfg(path: String, create_empty: bool = false) -> Dictionary:
	var cfg: ConfigFile = load_cfg(path, create_empty)
	var result: Dictionary
	if not cfg:
		return result
	var sections = cfg.get_sections()
	for section in sections:
		var keys = cfg.get_section_keys(section)
		var section_dict: Dictionary
		for key in keys:
			section_dict[key] = cfg.get_value(section, key)
		result[section] = section_dict

	return result

## 覆盖cfg文件，会将原来的内容清除
# @param path: cfg文件路径
## @param nested_dict: 包含section、key、value的嵌套字典
## @param backup: 是否备份
## @param backup_num: 备份数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func overwrite_cfg(path: String, nested_dict: Dictionary, backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	path = normalize_path(path)
	if not path.is_absolute_path():
		push_warning("ConfigFileManager: overwrite_cfg, path is not valid: %s" % path)
		return false
	
	var cfg: ConfigFile = ConfigFile.new()

	for section in nested_dict.keys():
		var dict: Dictionary
		if nested_dict[section] is Dictionary:
			dict = nested_dict[section]
		else:
			continue
		for key in dict.keys():
			cfg.set_value(section, key, dict[key])

	if backup and not backup_and_rotate(path, backup_num, backup_by_copy):
		return false
	return _save_cfg(cfg, path)

## 将包含section的嵌套字典保存到cfg文件，主键名为section，值为section对应的字典
## @param path: cfg文件路径
## @param nested_dict: 包含section、key、value的嵌套字典
## @param backup: 是否备份
## @param backup_num: 备份数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func save_nested_dict(path: String, nested_dict: Dictionary, backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var create_empty: bool
	#get_stack()
	#print_stack()
	#print_debug("save_nested_dict-> nested_dict:",nested_dict)
	if not FileAccess.file_exists(path):
		if create_empty_file(path):
			create_empty = true
		else:
			return false
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false
	
	var is_changed: bool
	for section in nested_dict.keys():
		var dict: Dictionary
		if nested_dict[section] is Dictionary:
			dict = nested_dict[section]
		else:
			continue

		for key in dict.keys():
			if cfg.has_section_key(section, key):
				var old_value = cfg.get_value(section, key)
				if is_equal(old_value, dict[key]):
					continue
				cfg.set_value(section, key, dict[key])
				is_changed = true
			else:
				cfg.set_value(section, key, dict[key])
				is_changed = true
	if not is_changed:
		return true

	if not create_empty and backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)
#endregion
#region -------- 写入类方法 --------
## 覆盖cfg文件的某个section的所有键值对，如果section不存在会自动新建；如果只是对某些键值对进行修改，使用save_cfg_value。
## @param path: cfg文件路径
## @param section: section名
## @param dict: 键值对
## @param backup: 是否备份
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func overwrite_section(path: String, section: String, dict: Dictionary, backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var create_empty: bool
	if not FileAccess.file_exists(path):
		if create_empty_file(path):
			create_empty = true
		else:
			return false
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false
	if cfg.has_section(section):
		cfg.erase_section(section)

	for key in dict.keys():
		cfg.set_value(section, key, dict[key])
	
	if not create_empty and backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)

## 将section对应的字典中的键值对依次保存到cfg文件，不会改变字典中没有的键值对
## @param path: cfg文件路径
## @param section: section名
## @param dict: 键值对字典
## @param backup: 是否备份
## @param backup_num: 备份数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func save_section_dict(path: String, section: String, dict: Dictionary, backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var create_empty: bool
	if not FileAccess.file_exists(path):
		if create_empty_file(path):
			create_empty = true
		else:
			return false
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false

	var is_changed: bool
	for key in dict.keys():
		if cfg.has_section_key(section, key):
			var old_value = cfg.get_value(section, key)
			if is_equal(old_value, dict[key]):
				continue
		cfg.set_value(section, key, dict[key])
		is_changed = true

	if not is_changed:
		return true

	if not create_empty and backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false

	return _save_cfg(cfg, path)

## 储存数据到cfg文件
## @param path: cfg文件路径
## @param section: section名
## @param key: key名
## @param value: 值
## @param backup: 是否备份
## @param backup_num: 备份数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func save_value(path: String, section: String, key: StringName, value: Variant, backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var create_empty: bool
	if not FileAccess.file_exists(path):
		if create_empty_file(path):
			create_empty = true
		else:
			return false
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false
	if cfg.has_section_key(section, key):
		var old_value = cfg.get_value(section, key)
		if is_equal(old_value, value):
			return true
	cfg.set_value(section, key, value)
	if not create_empty and backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)

#endregion
#region -------- 获取类方法 --------
## 获取cfg某个section的所有key
## @param path: cfg文件路径
## @param section: section名
## @return: section的所有key
static func get_section_keys(path: String, section: String) -> PackedStringArray:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return []
	if not cfg.has_section(section):
		return []
	return cfg.get_section_keys(section)

## 获取cfg某个section的所有键值对，返回字典
## @param path: cfg文件路径
## @param section: section名
## @return: section的所有键值对
static func get_section_dict(path: String, section: String) -> Dictionary:
	var cfg: ConfigFile = load_cfg(path)
	var result: Dictionary = {}
	if not cfg:
		return result

	if not cfg.has_section(section):
		return result
	var keys: PackedStringArray = cfg.get_section_keys(section)
	
	for key in keys:
		result[key] = cfg.get_value(section, key)
	
	return result

## 获取cfg某个section的所有key的value数组
## @param path: cfg文件路径
## @param section: section名
## @return: Array section的所有key的value
static func get_section_values(path: String, section: String) -> Array:
	var cfg: ConfigFile = load_cfg(path)
	var result: Array
	if not cfg:
		return result
	if not cfg.has_section(section):
		return result

	var keys: PackedStringArray = cfg.get_section_keys(section)
	for key in keys:
		result.append(cfg.get_value(section, key))
	
	return result

## 获取cfg所有section名
## @param path: cfg文件路径
## @return: cfg所有section的数组
static func get_section_list(path: String) -> PackedStringArray:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return []
		
	return cfg.get_sections()

## 获取cfg某个section的某个key的值
## @param path: cfg文件路径
## @param section: section名
## @param key: key名
## @return: section的某个key的值,失败时返回null
static func get_value(path: String, section: String, key: StringName) -> Variant:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return null
	if not cfg.has_section_key(section, key):
		return null
	
	return cfg.get_value(section, key)

#endregion
#region -------- 复制类方法 --------
## 复制cfg某个section的某个key
## @param path: cfg文件路径
## @param section: section名
## @param key: key名
## @param key_in_value: 可选，如果value为字典，key_in_value为value中key的键名，则将value[key_in_value]修改为new_key
## @param backup: 是否备份文件
## @param backup_num: 备份文件数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func copy_section_key(path: String, section: String, sorce_key: String, target_key: String, key_in_value: String = "", backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false
	if not cfg.has_section_key(section, sorce_key):
		return false
	if sorce_key == target_key:
		return true

	var value = cfg.get_value(section, sorce_key)
	if not key_in_value.is_empty() and value is Dictionary:
		value[key_in_value] = target_key
	
	cfg.set_value(section, target_key, value)
	if backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)

## 复制section全部内容,new_section为空时按照旧section名复制但只能复制到新的文件中
## @param old_section: 旧section名
## @param new_section: 新section名
## @param path: cfg文件路径
## @param target_path: 目标文件路径
## @return: 是否成功
static func copy_section(old_section: String, new_section: String, path: String, target_path: String = "") -> bool:
	if old_section.is_empty():
		push_warning("ConfigFileManager: copy_section, old_section cannot be empty")
		return false
	if not FileAccess.file_exists(path):
		push_warning("ConfigFileManager: copy_section, source file does not exist: %s" % path)
		return false
	# 确定目标section名
	if new_section.is_empty():
		new_section = old_section
	
	# 确定目标文件路径
	if target_path.is_empty():
		target_path = path
	# 处理源文件和目标文件相同的情况
	if check_path_equal(path, target_path):
		# 如果新旧section名相同，无需操作
		if old_section == new_section:
			return true
		
		# 在同一文件内复制section
		return copy_section_in_same_file(path, old_section, new_section)
	else:
		# 复制到不同文件
		return copy_section_to_different_file(path, target_path, old_section, new_section)

## 在同一文件内复制section
## @param path: cfg文件路径
## @param old_section: 旧section名
## @param new_section: 新section名
## @return: 是否成功
static func copy_section_in_same_file(file_path: String, old_section: String, new_section: String) -> bool:
	var cfg: ConfigFile = load_cfg(file_path)
	if not cfg:
		return false
	if old_section == new_section:
		return true
	var source_keys: PackedStringArray = cfg.get_section_keys(old_section)
	if source_keys.is_empty():
		return true
	# 复制数据
	for key in source_keys:
		var value = cfg.get_value(old_section, key)
		cfg.set_value(new_section, key, value)
	
	# 保存文件
	# print_debug("ConfigFileManager: 已将 %s 复制为 %s 在同一文件中" % [old_section, new_section])
	return _save_cfg(cfg, file_path)

## 复制section到不同文件
## @param source_path: 源文件路径
## @param target_path: 目标文件路径
## @param old_section: 旧section名
## @param new_section: 新section名
static func copy_section_to_different_file(source_path: String, target_path: String, old_section: String, new_section: String) -> bool:
	## 检查源文件和目标文件是否相同，如果相同则调用copy_section_in_same_file
	if check_path_equal(source_path, target_path):
		return copy_section_in_same_file(source_path, old_section, new_section)
	## 源文件的ConfigFile对象
	var source_cfg: ConfigFile = load_cfg(source_path)
	if not source_cfg:
		return false
	## 检查目标文件是否存在，如果不存在则尝试创建空文件
	if not FileAccess.file_exists(target_path):
		if not create_empty_file(target_path):
			return false
	## 目标文件的ConfigFile对象
	var target_cfg: ConfigFile = load_cfg(target_path)
	if not target_cfg:
		return false
	var source_keys: PackedStringArray = source_cfg.get_section_keys(old_section)
	if source_keys.is_empty():
		return true
	# 复制数据到目标文件
	for key in source_keys:
		var value = source_cfg.get_value(old_section, key)
		target_cfg.set_value(new_section, key, value)
	
	# 保存目标文件
	# print_debug("ConfigFileManager: 已将 %s 从 %s 复制为 %s 到 %s" % [old_section, source_path, new_section, target_path])
	return _save_cfg(target_cfg, target_path)

#endregion
#region -------- 删除类方法 --------
## 删除cfg某个section的某个key
## @param path: cfg文件路径
## @param section: section名
## @param key: key名
## @param backup: 是否备份文件
## @param backup_num: 备份文件数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func delete_section_key(path: String, section: String, key: StringName, backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false

	if cfg.has_section_key(section, key):
		cfg.erase_section_key(section, key)
	else:
		return true

	if backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)

## 批量删除cfg某个section的keys
## @param path: cfg文件路径
## @param section: section名
## @param key_list: key列表
## @param backup: 是否备份文件
## @param backup_num: 备份文件数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func delete_section_keys(path: String, section: String, key_list: PackedStringArray, backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false

	var is_changed: bool
	for key in key_list:
		if cfg.has_section_key(section, key):
			is_changed = true
			cfg.erase_section_key(section, key)
	
	if not is_changed:
		return true
	if backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)

## 删除cfg某个section
## @param path: cfg文件路径
## @param section: section名
## @param backup: 是否备份文件
## @param backup_num: 备份文件数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func delete_section(path: String, section: String, backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false

	var is_changed: bool
	if cfg.has_section(section):
		cfg.erase_section(section)
		is_changed = true
	if not is_changed:
		return true
	if backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)

## 批量删除cfg的section
## @param path: cfg文件路径
## @param section_list: section列表
## @param backup: 是否备份文件
## @param backup_num: 备份文件数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func delete_section_list(path: String, section_list: PackedStringArray, backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false
	
	var is_changed: bool
	for section in section_list:
		if cfg.has_section(section):
			is_changed = true
			cfg.erase_section(section)
	if not is_changed:
		return true
	if backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)

#endregion
#region -------- 修改类方法 --------
## 修改cfg某个section名
## @param path: cfg文件路径
## @param old_section: 旧section名
## @param new_section: 新section名
## @param key: 如果section里面的key的值和section名相同，则会同步修改该key的值为new_section，默认为空表示不同步修改
## @param backup: 是否备份文件
## @param backup_num: 备份文件数量
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func modify_section_name(path: String, old_section: String, new_section: String, key: StringName = "", backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false
	if not cfg.has_section(old_section):
		push_warning("cfg section [%s] not exists in file: %s" % [old_section, path])
		return false
	if old_section == new_section:
		return true
	
	var keys: PackedStringArray = cfg.get_section_keys(old_section)
	
	for _key in keys:
		var value
		if not key.is_empty() and _key == key:
			value = new_section
		else:
			value = cfg.get_value(old_section, _key)
		cfg.set_value(new_section, _key, value)
	cfg.erase_section(old_section)

	if backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)
	
## 修改某个section的key
## @param path: cfg文件路径
## @param section: section名
## @param old_key: 旧key名
## @param new_key: 新key名
## @param value: 可选，如果为null则使用旧key的value
## @param key_in_value: 可选，如果value为字典，key_in_value为在自动中key的键名，则将value[key_in_value]修改为new_key
## @param backup: 是否备份
## @param backup_by_copy: 是否使用copy进行备份，从安全性考虑默认为true，如果追求性能可以改为false从而使用重命名方式备份
## @return: 是否成功
static func modify_key_name(path: String, section: String, old_key: String, new_key: StringName, value: Variant = null, key_in_value: String = "", backup: bool = false, backup_num: int = 5, backup_by_copy: bool = true) -> bool:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false
	if not cfg.has_section_key(section, old_key):
		return false
	if old_key == new_key:
		return true
	if value == null:
		value = cfg.get_value(section, old_key)
	if not key_in_value.is_empty() and value is Dictionary:
		value[key_in_value] = new_key
	cfg.set_value(section, new_key, value)
	cfg.erase_section_key(section, old_key)
	if backup:
		if not backup_and_rotate(path, backup_num, backup_by_copy):
			return false
	return _save_cfg(cfg, path)

#endregion
#region -------- 检查类方法 --------
## 判定某个key是否存在于section中
## @param path: cfg文件路径
## @param section: section名
## @param key: key名
## @return: 是否存在
static func has_section_key(path: String, section: String, key: StringName) -> bool:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false
	return cfg.has_section_key(section, key)

## 判定某个section是否存在
## @param path: cfg文件路径
## @param section: section名
## @return: 是否存在
static func has_section(path: String, section: String) -> bool:
	var cfg: ConfigFile = load_cfg(path)
	if not cfg:
		return false
	
	return cfg.has_section(section)

## 判断两个值是否相等
## @param a: 第一个值
## @param b: 第二个值
## @return: bool 两个值是否相等
static func is_equal(a, b) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a == b

#endregion
