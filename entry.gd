extends RefCounted

const _SDK_PACKAGED_REL_PATH: String = "lib/fu_sdk/v1.gd"
const _SDK_DEV_REL_PATH: String = "../../shared/sdk/fu_sdk/v1.gd"
const _SHARED_ASSET_STORE_PATH: String = "res://services/storage/SharedAssetStore.cs"


func _get_base_dir() -> String:
	var self_script := get_script() as Script
	if self_script == null or self_script.resource_path.is_empty():
		return ""
	return self_script.resource_path.split("::")[0].get_base_dir()


func _load_sdk_script() -> Script:
	var base_dir: String = _get_base_dir()
	if base_dir.is_empty():
		return null
	var packaged_path: String = base_dir.path_join(_SDK_PACKAGED_REL_PATH)
	if FileAccess.file_exists(packaged_path) or ResourceLoader.exists(packaged_path):
		return load(packaged_path) as Script
	var dev_path: String = base_dir.path_join(_SDK_DEV_REL_PATH).simplify_path()
	if FileAccess.file_exists(dev_path) or ResourceLoader.exists(dev_path):
		return load(dev_path) as Script
	return null


func _load_src_script(filename: String) -> Script:
	var base_dir: String = _get_base_dir()
	if base_dir.is_empty():
		return null
	var mod_path: String = base_dir.path_join("src").path_join(filename)
	if FileAccess.file_exists(mod_path) or ResourceLoader.exists(mod_path):
		return load(mod_path) as Script
	return null


func _load_modules() -> Dictionary:
	var sdk_script: Script = _load_sdk_script()
	if sdk_script == null:
		return {"ok": false, "reason": "fu_sdk_not_found"}
	var names: Array[String] = [
		"fvtt_source.gd",
		"fvtt_nedb.gd",
		"snappy.gd",
		"fvtt_leveldb.gd",
		"fvtt_normalizer.gd",
		"fuvtt_assets.gd",
		"fuvtt_mapper.gd",
	]
	var scripts: Dictionary = {"sdk": sdk_script}
	for fname: String in names:
		var scr: Script = _load_src_script(fname)
		if scr == null:
			return {"ok": false, "reason": "missing_module:" + fname}
		scripts[fname] = scr
	return {"ok": true, "scripts": scripts}


func _read_file_length(path: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return -1
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var length: int = int(file.get_length())
	file.close()
	return maxi(0, length)


func _coerce_bool(value: Variant, fallback: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value == true
		TYPE_INT:
			return int(value) != 0
		TYPE_FLOAT:
			var num: float = float(value)
			if is_nan(num):
				return fallback
			return num != 0.0
		TYPE_STRING:
			var normalized: String = str(value).strip_edges().to_lower()
			match normalized:
				"true", "1", "yes", "on":
					return true
				"false", "0", "no", "off":
					return false
				_:
					return fallback
		_:
			return fallback


func _coerce_string(value: Variant, fallback: String = "") -> String:
	if typeof(value) == TYPE_STRING:
		return str(value)
	return fallback


func _sanitize_options(raw_options: Variant) -> Dictionary:
	var opts: Dictionary = raw_options if (raw_options is Dictionary) else {}
	return {
		"proxy": _coerce_string(opts.get("proxy", ""), "").strip_edges(),
		"import_scenes": _coerce_bool(opts.get("import_scenes", true), true),
		"import_characters": _coerce_bool(opts.get("import_characters", true), true),
		"import_monsters": _coerce_bool(opts.get("import_monsters", true), true),
		"include_hidden": _coerce_bool(opts.get("include_hidden", true), true),
		"skip_missing_assets": _coerce_bool(opts.get("skip_missing_assets", true), true),
		"register_entity_library": _coerce_bool(opts.get("register_entity_library", true), true),
		"download_remote_assets": _coerce_bool(opts.get("download_remote_assets", true), true),
	}


func _parse_core_major(world_json: Dictionary) -> int:
	var ver_str: String = ""
	for k: String in ["coreVersion", "version", "compatibleCoreVersion"]:
		var v: Variant = world_json.get(k, null)
		if v is String and not (v as String).strip_edges().is_empty():
			ver_str = (v as String).strip_edges()
			break
	if ver_str.is_empty():
		return 0
	var dot_idx: int = ver_str.find(".")
	var head: String = ver_str if dot_idx < 0 else ver_str.substr(0, dot_idx)
	if head.is_valid_int():
		return int(head)
	return 0


func _is_hard_collection_error(reason: String) -> bool:
	if reason.is_empty():
		return false
	if (
		reason.begins_with("zip_")
		or reason.begins_with("sstable_")
		or reason.contains(":sstable_")
		or reason.begins_with("snappy_")
		or reason.contains(":snappy_")
		or reason.begins_with("block_")
		or reason.contains(":block_")
	):
		return true
	return false


func _read_all_collections(
	source: RefCounted,
	nedb: RefCounted,
	leveldb: RefCounted,
	snappy: RefCounted,
	world_json: Dictionary,
	session: RefCounted
) -> Dictionary:
	var core_major: int = _parse_core_major(world_json)
	var out: Dictionary = {}
	for coll_name: String in ["scenes", "actors", "folders"]:
		if session != null and session.is_cancelled():
			return {"ok": false, "reason": "cancelled"}
		# Always pass session = null to read_collection so warnings are emitted only once by normalizer.
		if leveldb.has_collection(source, coll_name):
			var ldb_res: Dictionary = leveldb.read_collection(source, coll_name, snappy, null)
			if bool(ldb_res.get("ok", false)):
				out[coll_name] = ldb_res
				continue
			var ldb_reason: String = str(ldb_res.get("reason", ""))
			if _is_hard_collection_error(ldb_reason):
				return {"ok": false, "reason": ldb_reason}
			if core_major > 0 and core_major < 11 and source.has_file("data/%s.db" % coll_name):
				var nedb_fb: Dictionary = nedb.read_collection(source, coll_name, null)
				if not bool(nedb_fb.get("ok", false)) and _is_hard_collection_error(str(nedb_fb.get("reason", ""))):
					return {"ok": false, "reason": str(nedb_fb.get("reason", ""))}
				out[coll_name] = nedb_fb
				continue
			out[coll_name] = ldb_res
		elif source.has_file("data/%s.db" % coll_name):
			var nedb_res: Dictionary = nedb.read_collection(source, coll_name, null)
			if not bool(nedb_res.get("ok", false)) and _is_hard_collection_error(str(nedb_res.get("reason", ""))):
				return {"ok": false, "reason": str(nedb_res.get("reason", ""))}
			out[coll_name] = nedb_res
		else:
			out[coll_name] = {"ok": false, "docs": [], "warnings": []}
	return {"ok": true, "collections": out}


func _u16_le(buf: PackedByteArray, off: int) -> int:
	return int(buf[off]) | (int(buf[off + 1]) << 8)


func _u32_le(buf: PackedByteArray, off: int) -> int:
	return (
		int(buf[off])
		| (int(buf[off + 1]) << 8)
		| (int(buf[off + 2]) << 16)
		| (int(buf[off + 3]) << 24)
	)


func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var n: int = bytes.size()
	var i: int = 0
	while i < n:
		var b0: int = bytes[i]
		if b0 <= 0x7F:
			i += 1
		elif (b0 & 0xE0) == 0xC0:
			if i + 1 >= n:
				return false
			var b1: int = bytes[i + 1]
			if (b1 & 0xC0) != 0x80:
				return false
			var cp2: int = ((b0 & 0x1F) << 6) | (b1 & 0x3F)
			if cp2 < 0x80:
				return false
			i += 2
		elif (b0 & 0xF0) == 0xE0:
			if i + 2 >= n:
				return false
			var b1e: int = bytes[i + 1]
			var b2e: int = bytes[i + 2]
			if (b1e & 0xC0) != 0x80 or (b2e & 0xC0) != 0x80:
				return false
			var cp3: int = ((b0 & 0x0F) << 12) | ((b1e & 0x3F) << 6) | (b2e & 0x3F)
			if cp3 < 0x800 or (cp3 >= 0xD800 and cp3 <= 0xDFFF):
				return false
			i += 3
		elif (b0 & 0xF8) == 0xF0:
			if i + 3 >= n:
				return false
			var b1f: int = bytes[i + 1]
			var b2f: int = bytes[i + 2]
			var b3f: int = bytes[i + 3]
			if (b1f & 0xC0) != 0x80 or (b2f & 0xC0) != 0x80 or (b3f & 0xC0) != 0x80:
				return false
			var cp4: int = ((b0 & 0x07) << 18) | ((b1f & 0x3F) << 12) | ((b2f & 0x3F) << 6) | (b3f & 0x3F)
			if cp4 < 0x10000 or cp4 > 0x10FFFF:
				return false
			i += 4
		else:
			return false
	return true


func _decode_zip_cd_name(fn_bytes: PackedByteArray) -> String:
	if fn_bytes.is_empty():
		return ""
	if _is_valid_utf8(fn_bytes):
		return fn_bytes.get_string_from_utf8()
	var out: String = ""
	for b: int in fn_bytes:
		out += char(b)
	return out


func _sum_zip_cd_uncompressed(zip_path: String) -> int:
	var f: FileAccess = FileAccess.open(zip_path, FileAccess.READ)
	if f == null:
		return -1
	var flen: int = int(f.get_length())
	if flen < 22:
		f.close()
		return -1
	var tail_len: int = mini(flen, 65557)
	f.seek(flen - tail_len)
	var tail: PackedByteArray = f.get_buffer(tail_len)
	var eocd_pos: int = -1
	for i: int in range(tail.size() - 22, -1, -1):
		if tail[i] == 0x50 and tail[i + 1] == 0x4B and tail[i + 2] == 0x05 and tail[i + 3] == 0x06:
			var comment_len: int = _u16_le(tail, i + 20)
			if i + 22 + comment_len == tail.size():
				eocd_pos = i
				break
	if eocd_pos < 0:
		f.close()
		return -1
	var cd_size: int = _u32_le(tail, eocd_pos + 12)
	var cd_offset: int = _u32_le(tail, eocd_pos + 16)
	if cd_size <= 0 or cd_offset < 0 or cd_offset + cd_size > flen or cd_size > 67108864:
		f.close()
		return -1
	f.seek(cd_offset)
	var cd: PackedByteArray = f.get_buffer(cd_size)
	f.close()
	if cd.size() != cd_size:
		return -1
	var total: int = 0
	var seen_norm_sizes: Dictionary = {}
	var seen_raw_sizes: Dictionary = {}
	var p: int = 0
	while p + 46 <= cd_size:
		if cd[p] != 0x50 or cd[p + 1] != 0x4B or cd[p + 2] != 0x01 or cd[p + 3] != 0x02:
			break
		var uncomp_sz: int = _u32_le(cd, p + 24)
		var fn_len: int = _u16_le(cd, p + 28)
		var ex_len: int = _u16_le(cd, p + 30)
		var cm_len: int = _u16_le(cd, p + 32)
		if p + 46 + fn_len + ex_len + cm_len > cd_size:
			break
		if uncomp_sz == 4294967295:
			return -1
		var raw_name: String = _decode_zip_cd_name(cd.slice(p + 46, p + 46 + fn_len))
		var fname: String = raw_name.replace("\\", "/")
		var is_junk: bool = fname.is_empty() or fname.ends_with("/")
		if not is_junk:
			var junk_parts: PackedStringArray = fname.split("/", false)
			for seg: String in junk_parts:
				if seg == "__MACOSX" or seg == ".DS_Store" or seg.begins_with("._"):
					is_junk = true
					break
		if not is_junk:
			var is_clean_valid: bool = false
			var norm_key: String = ""
			if not fname.begins_with("/") and not fname.contains(":"):
				var raw_parts: PackedStringArray = fname.split("/", false)
				var clean_parts: PackedStringArray = PackedStringArray()
				var has_unsafe: bool = false
				for seg: String in raw_parts:
					if seg == ".":
						continue
					if seg.is_empty() or seg == ".." or seg.contains(":"):
						has_unsafe = true
						break
					clean_parts.append(seg)
				if not has_unsafe and not clean_parts.is_empty():
					is_clean_valid = true
					norm_key = "/".join(clean_parts)
			if is_clean_valid:
				if seen_norm_sizes.has(norm_key):
					total -= int(seen_norm_sizes[norm_key])
				seen_norm_sizes[norm_key] = uncomp_sz
			else:
				if seen_raw_sizes.has(raw_name):
					total -= int(seen_raw_sizes[raw_name])
				seen_raw_sizes[raw_name] = uncomp_sz
			total += uncomp_sz
		p += 46 + fn_len + ex_len + cm_len
	return total


func _compute_zip_decoded_bytes(zip_path: String, source: RefCounted, open_res: Dictionary, session: RefCounted) -> Dictionary:
	var wj_bytes_v: Variant = open_res.get("world_json_bytes", PackedByteArray())
	var wj_len: int = (wj_bytes_v as PackedByteArray).size() if (wj_bytes_v is PackedByteArray) else 0
	var open_decoded: int = int(open_res.get("decoded_bytes", 0))
	if open_decoded > 0:
		return {"ok": true, "decoded_bytes": maxi(open_decoded, wj_len)}
	var fast_total: int = _sum_zip_cd_uncompressed(zip_path)
	if fast_total > 0:
		return {"ok": true, "decoded_bytes": maxi(fast_total, wj_len)}
	var total: int = 0
	var files: PackedStringArray = source.list_files("")
	for i: int in range(files.size()):
		if (i % 64) == 0 and session != null and session.is_cancelled():
			return {"ok": false, "reason": "cancelled"}
		var data: PackedByteArray = source.read_bytes(files[i])
		if source.has_method("get_last_read_error"):
			var read_err: String = str(source.get_last_read_error())
			if not read_err.is_empty():
				return {"ok": false, "reason": read_err}
		total += data.size()
	return {"ok": true, "decoded_bytes": maxi(total, wj_len)}


func _instantiate_shared_asset_store() -> Variant:
	if not ResourceLoader.exists(_SHARED_ASSET_STORE_PATH):
		return null
	var store_res: Variant = load(_SHARED_ASSET_STORE_PATH)
	if store_res is Script and (store_res as Script).can_instantiate():
		return (store_res as Script).new()
	return null


func inspect_import(path: String, options: Dictionary, host: RefCounted) -> Dictionary:
	var mod_load: Dictionary = _load_modules()
	if not bool(mod_load.get("ok", false)):
		return {"ok": false, "reason": str(mod_load.get("reason", "module_load_failed"))}
	var scripts: Dictionary = mod_load["scripts"]
	var sdk: RefCounted = (scripts["sdk"] as Script).new()

	var clean_options: Dictionary = _sanitize_options(options)
	var session = sdk.create_session(host, clean_options)
	if session.is_cancelled():
		return session.err_cancelled()

	var source_bytes: int = _read_file_length(path)
	if source_bytes < 0:
		return session.err_failed("source_file_not_found")

	session.report_progress("正在检查 FVTT 世界包……")
	if session.is_cancelled():
		return session.err_cancelled()

	var source: RefCounted = (scripts["fvtt_source.gd"] as Script).new()
	var open_res: Dictionary = source.open(path)
	if not bool(open_res.get("ok", false)):
		var open_err: String = str(open_res.get("reason", "source_open_failed"))
		source.close()
		return session.err_failed(open_err)
	if session.is_cancelled():
		source.close()
		return session.err_cancelled()

	var nedb: RefCounted = (scripts["fvtt_nedb.gd"] as Script).new()
	var snappy: RefCounted = (scripts["snappy.gd"] as Script).new()
	var leveldb: RefCounted = (scripts["fvtt_leveldb.gd"] as Script).new()
	var normalizer: RefCounted = (scripts["fvtt_normalizer.gd"] as Script).new()

	var world_json: Dictionary = open_res.get("world_json", {}) if open_res.get("world_json", null) is Dictionary else {}
	var col_wrap: Dictionary = _read_all_collections(source, nedb, leveldb, snappy, world_json, session)
	if not bool(col_wrap.get("ok", false)):
		source.close()
		var col_err: String = str(col_wrap.get("reason", "cancelled"))
		if col_err == "cancelled" or session.is_cancelled():
			return session.err_cancelled()
		return session.err_failed(col_err)
	var collections: Dictionary = col_wrap["collections"]

	var norm_res: Dictionary = normalizer.normalize(world_json, collections, source, clean_options, null)
	if not bool(norm_res.get("ok", false)):
		var norm_err: String = str(norm_res.get("reason", "normalize_failed"))
		source.close()
		return session.err_failed(norm_err)
	if session.is_cancelled():
		source.close()
		return session.err_cancelled()

	var decoded_bytes: int = 0
	if source.get_source_kind() == "dir":
		decoded_bytes = maxi(source_bytes, int(open_res.get("decoded_bytes", source_bytes)))
	else:
		var zip_sz_res: Dictionary = _compute_zip_decoded_bytes(path, source, open_res, session)
		if not bool(zip_sz_res.get("ok", false)):
			source.close()
			var sz_err: String = str(zip_sz_res.get("reason", "cancelled"))
			if sz_err == "cancelled" or session.is_cancelled():
				return session.err_cancelled()
			return session.err_failed(sz_err)
		decoded_bytes = int(zip_sz_res.get("decoded_bytes", 0))

	source.close()
	if session.is_cancelled():
		return session.err_cancelled()

	var model: Dictionary = norm_res["model"]
	var world_meta: Dictionary = model.get("world_meta", {}) if model.get("world_meta", null) is Dictionary else {}
	var counts_override: Dictionary = model.get("inspect_counts", {}) if model.get("inspect_counts", null) is Dictionary else {}
	var download_remote: bool = bool(clean_options.get("download_remote_assets", true))
	var remote_assets: Dictionary = {}
	if download_remote and model.get("remote_assets", null) is Dictionary:
		remote_assets = model["remote_assets"]

	var result: Dictionary = session.ok_inspect(path, counts_override, remote_assets)
	var world_title: String = str(world_meta.get("title", "")).strip_edges()
	var base_name: String = path.get_file().get_basename().strip_edges()
	var final_name: String = world_title if not world_title.is_empty() else (base_name if not base_name.is_empty() else "fvtt-world")
	result["name"] = final_name
	result["source_bytes"] = source_bytes
	result["decoded_bytes"] = decoded_bytes
	result["unique_images"] = int(counts_override.get("images", 0))
	return result


func prepare_import(path: String, options: Dictionary, host: RefCounted) -> Dictionary:
	var mod_load: Dictionary = _load_modules()
	if not bool(mod_load.get("ok", false)):
		return {"ok": false, "reason": str(mod_load.get("reason", "module_load_failed"))}
	var scripts: Dictionary = mod_load["scripts"]
	var sdk: RefCounted = (scripts["sdk"] as Script).new()

	var clean_options: Dictionary = _sanitize_options(options)
	var session = sdk.create_session(host, clean_options)
	if session.is_cancelled():
		return session.err_cancelled()
	if path.is_empty() or not FileAccess.file_exists(path):
		return session.err_failed("source_file_not_found")

	session.report_progress("正在解析 FVTT 世界包……")
	if session.is_cancelled():
		return session.err_cancelled()

	var source: RefCounted = (scripts["fvtt_source.gd"] as Script).new()
	var open_res: Dictionary = source.open(path)
	if not bool(open_res.get("ok", false)):
		var open_err: String = str(open_res.get("reason", "source_open_failed"))
		source.close()
		return session.err_failed(open_err)
	if session.is_cancelled():
		source.close()
		return session.err_cancelled()

	if source.get_source_kind() == "dir":
		session.add_warning("已从解压目录 world.json 导入（宿主导入桥默认会将活动名显示为 world，真实世界标题已保留在世界模块与楼层中）")

	var nedb: RefCounted = (scripts["fvtt_nedb.gd"] as Script).new()
	var snappy: RefCounted = (scripts["snappy.gd"] as Script).new()
	var leveldb: RefCounted = (scripts["fvtt_leveldb.gd"] as Script).new()
	var normalizer: RefCounted = (scripts["fvtt_normalizer.gd"] as Script).new()
	var assets_helper: RefCounted = (scripts["fuvtt_assets.gd"] as Script).new()
	var mapper: RefCounted = (scripts["fuvtt_mapper.gd"] as Script).new()

	var store_inst: Variant = _instantiate_shared_asset_store()
	if store_inst != null:
		assets_helper.set_shared_asset_store(store_inst, false)
		mapper.set_shared_asset_store(store_inst, false)

	var world_json: Dictionary = open_res.get("world_json", {}) if open_res.get("world_json", null) is Dictionary else {}
	var col_wrap: Dictionary = _read_all_collections(source, nedb, leveldb, snappy, world_json, session)
	if not bool(col_wrap.get("ok", false)):
		source.close()
		var col_err2: String = str(col_wrap.get("reason", "cancelled"))
		if col_err2 == "cancelled" or session.is_cancelled():
			return session.err_cancelled()
		return session.err_failed(col_err2)
	var collections: Dictionary = col_wrap["collections"]

	var norm_res: Dictionary = normalizer.normalize(world_json, collections, source, clean_options, session)
	if not bool(norm_res.get("ok", false)):
		var norm_err: String = str(norm_res.get("reason", "normalize_failed"))
		source.close()
		return session.err_failed(norm_err)
	if session.is_cancelled():
		source.close()
		return session.err_cancelled()

	session.report_progress("正在构建 Fu VTT 场景与资源……")
	if session.is_cancelled():
		source.close()
		return session.err_cancelled()

	var builder = sdk.create_world_builder(null, 150.0)
	var map_res: Dictionary = mapper.map_to_world(
		norm_res["model"],
		builder,
		assets_helper,
		source,
		host,
		session,
		clean_options
	)
	if not bool(map_res.get("ok", false)):
		if mapper.has_method("rollback_entity_library"):
			mapper.rollback_entity_library()
		assets_helper.cleanup_published()
		source.close()
		var map_err: String = str(map_res.get("reason", "map_to_world_failed"))
		if map_err == "cancelled" or session.is_cancelled():
			return session.err_cancelled()
		return session.err_failed(map_err)

	if session.is_cancelled():
		if mapper.has_method("rollback_entity_library"):
			mapper.rollback_entity_library()
		assets_helper.cleanup_published()
		source.close()
		return session.err_cancelled()

	source.close()
	return builder.build_result(
		int(map_res.get("source_records", 0)),
		int(map_res.get("merged_walls", 0))
	)
