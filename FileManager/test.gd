extends Node


func _ready() -> void:
	cfg_demo()

func get_path_name_demo() -> void:
	var path_A: String = "J:\\GodotProject\\System"
	print("name A: ", FilesManager.get_path_name(path_A))
	var path_B: String = "res://abc/dasd/dasda/gugugaga.json"
	print("name B: ", FilesManager.get_path_name(path_B))
	var path_C: String = "43423/54354-54543gugugaga.cfg"
	print("name C: ", FilesManager.get_path_name(path_C))

func get_target_file_path_demo() -> void:
	## 源文件路径
	var source_path: String = "res://abc/gugugaga.cfg"
	## 目标文件完整路径
	var target_a: String = "res://abc/xyz/gugugaga.cfg"
	## 目标文件参数为带有扩展名的文件名
	var target_b: String = "Henry.json"
	## 目标文件参数为不带扩展名文件名
	var target_c: String = "Hans"
	## 目标文件参数为子路径
	var target_d: String = "Henry/Hans.json"
	print("目标参数为完整路径的返回结果: %s,\n------------" % FilesManager.get_target_file_path(target_a, source_path))
	print("目标参数为带扩展名的返回结果: %s,\n------------" % FilesManager.get_target_file_path(target_b, source_path))
	print("目标参数为不带扩展名的返回结果: %s,\n------------" % FilesManager.get_target_file_path(target_c, source_path))
	print("目标参数为子路径的返回结果: %s,\n------------" % FilesManager.get_target_file_path(target_d, source_path))
	
func cfg_demo() -> void:
	var dict: Dictionary = {
		"gugu": {
			name = "gugu",
			age = 16,
			weapon = "long_sword2"
		}
	}
	var path: String = "res://FileManager/演示文件.cfg"
	ConfigFileManager.overwrite_cfg(path,dict)
	#ConfigFileManager.save_nested_dict(path, dict)
