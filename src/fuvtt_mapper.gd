extends RefCounted

const _MAX_FLOORS: int = 512
const _MAX_ENTITIES: int = 10000
const _MAX_NAME_LENGTH: int = 96
const _MAX_BIOGRAPHY_CHARS: int = 2048
const _MAX_MODULE_ENTRY_BYTES: int = 6 * 1024 * 1024
const _MAX_MODULE_TOTAL_BYTES: int = 8 * 1024 * 1024
const _MAX_WORLD_BUDGET_BYTES: int = 30 * 1024 * 1024
const _SHARED_ASSET_STORE_PATH: String = "res://services/storage/SharedAssetStore.cs"

var _shared_asset_store: Variant = null
var _allow_mock_store: bool = false
var _last_lib_rollback: Dictionary = {}


func set_shared_asset_store(store: Variant, allow_mock: bool = false) -> void:
	_shared_asset_store = store
	_allow_mock_store = allow_mock


func _to_float(v: Variant, fallback: float = 0.0) -> float:
	if v == null:
		return fallback
	var t: int = typeof(v)
	if t == TYPE_INT:
		return float(v)
	if t == TYPE_FLOAT:
		var f: float = float(v)
		return f if is_finite(f) else fallback
	if t == TYPE_STRING:
		var s: String = str(v).strip_edges()
		if s.is_valid_float():
			var fs: float = s.to_float()
			if is_finite(fs):
				return fs
	return fallback


static func _parse_int64_str(s: String) -> Variant:
	var t: String = s.strip_edges()
	if t.is_empty():
		return null
	var negative: bool = false
	var idx: int = 0
	var first_ch: int = t.unicode_at(0)
	if first_ch == 45:
		negative = true
		idx = 1
	elif first_ch == 43:
		idx = 1
	var n: int = t.length()
	if idx >= n:
		return null
	for i: int in range(idx, n):
		var c: int = t.unicode_at(i)
		if c < 48 or c > 57:
			return null
	while idx < n and t.unicode_at(idx) == 48:
		idx += 1
	if idx == n:
		return 0
	var digits: String = t.substr(idx)
	var dlen: int = digits.length()
	if dlen > 19:
		return null
	if dlen == 19:
		var limit: String = "9223372036854775808" if negative else "9223372036854775807"
		if digits > limit:
			return null
		if negative and digits == "9223372036854775808":
			return -9223372036854775807 - 1
	var mag: int = int(digits)
	return -mag if negative else mag


func _to_int(v: Variant, fallback: int = 0) -> int:
	if v == null:
		return fallback
	var t: int = typeof(v)
	if t == TYPE_INT:
		return int(v)
	if t == TYPE_FLOAT:
		var f: float = float(v)
		if is_finite(f) and f >= -9223372036854775808.0 and f < 9223372036854775808.0:
			return int(f)
		return fallback
	if t == TYPE_STRING:
		var s: String = str(v).strip_edges()
		var parsed_i64: Variant = _parse_int64_str(s)
		if parsed_i64 != null:
			return int(parsed_i64)
		if s.is_valid_int():
			return fallback
		if s.is_valid_float():
			var fs: float = s.to_float()
			if is_finite(fs) and fs >= -9223372036854775808.0 and fs < 9223372036854775808.0:
				return int(fs)
	return fallback


func _sanitize_module_value(v: Variant, depth: int = 0) -> Variant:
	if depth > 32:
		return null
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return v
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(v)
		TYPE_FLOAT:
			var f: float = float(v)
			return f if is_finite(f) else 0.0
		TYPE_ARRAY:
			var out_arr: Array = []
			for item: Variant in v as Array:
				out_arr.append(_sanitize_module_value(item, depth + 1))
			return out_arr
		TYPE_DICTIONARY:
			var out_dict: Dictionary = {}
			var d: Dictionary = v as Dictionary
			for k: Variant in d.keys():
				var ks: String = k if (k is String) else str(k)
				out_dict[ks] = _sanitize_module_value(d[k], depth + 1)
			return out_dict
		_:
			return null


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


func _is_cancelled(session: RefCounted) -> bool:
	return session != null and session.has_method("is_cancelled") and bool(session.is_cancelled())


func _warn(session: RefCounted, message: String) -> void:
	if session != null and session.has_method("add_warning"):
		session.add_warning(message)


func _sanitize_catalog_name(value: String, fallback: String = "1F") -> String:
	var cleaned: String = value
	while cleaned.begins_with(char(0xFEFF)):
		cleaned = cleaned.substr(1)
	var out: String = ""
	for index: int in cleaned.length():
		var code: int = cleaned.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159):
			continue
		out += cleaned.substr(index, 1)
	out = out.strip_edges().left(_MAX_NAME_LENGTH).strip_edges()
	return out if not out.is_empty() else fallback


func _rename_floor_safe(builder: RefCounted, floor_uid: String, new_name: String, fallback: String = "1F") -> void:
	var clean_name: String = _sanitize_catalog_name(new_name, fallback)
	if builder.has_method("rename_floor"):
		builder.call("rename_floor", floor_uid, clean_name)
		return
	var world_var: Variant = builder.get_world()
	if not (world_var is Dictionary):
		return
	var world: Dictionary = world_var as Dictionary
	var catalog_var: Variant = world.get("catalog", null)
	if not (catalog_var is Dictionary):
		return
	var floors_var: Variant = (catalog_var as Dictionary).get("floors", null)
	if not (floors_var is Array):
		return
	var floors: Array = floors_var as Array
	for raw_f: Variant in floors:
		if raw_f is Dictionary:
			var fd: Dictionary = raw_f as Dictionary
			if str(fd.get("floor_uid", "")) == floor_uid:
				fd["name"] = clean_name
				return


func _scene_scale_for(scene: Dictionary, world_source_units_per_cell: float) -> float:
	var grid_type: int = _to_int(scene.get("grid_type", 1), 1)
	var grid_size: float = _to_float(scene.get("grid_size", 0.0), 0.0)
	if grid_type == 0 or not is_finite(grid_size) or grid_size <= 0.0:
		return 1.0
	var clamped_grid: float = clampf(grid_size, 1.0, 1e6)
	var base_units: float = clampf(world_source_units_per_cell, 1.0, 1e6)
	return clampf(base_units / clamped_grid, 1e-4, 1e4)


func _sort_tiles_stable(tiles: Array) -> Array:
	var indexed: Array = []
	for i: int in range(tiles.size()):
		if tiles[i] is Dictionary:
			indexed.append({"idx": i, "tile": tiles[i]})
	indexed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var za: int = _to_int((a["tile"] as Dictionary).get("z_order", 0), 0)
		var zb: int = _to_int((b["tile"] as Dictionary).get("z_order", 0), 0)
		if za != zb:
			return za < zb
		return int(a["idx"]) < int(b["idx"])
	)
	var out: Array = []
	for item: Dictionary in indexed:
		out.append(item["tile"])
	return out


func _find_entity_dict(builder: RefCounted, entity_id: String) -> Dictionary:
	var world_var: Variant = builder.get_world()
	if not (world_var is Dictionary):
		return {}
	var es_var: Variant = (world_var as Dictionary).get("entity_state", null)
	if not (es_var is Dictionary):
		return {}
	var ents_var: Variant = (es_var as Dictionary).get("entities", null)
	if not (ents_var is Array):
		return {}
	var ents: Array = ents_var as Array
	for i: int in range(ents.size() - 1, -1, -1):
		if ents[i] is Dictionary and str((ents[i] as Dictionary).get("id", "")) == entity_id:
			return ents[i] as Dictionary
	return {}


func _suppress_light_fallback_box(builder: RefCounted, light_eid: String) -> void:
	var ent: Dictionary = _find_entity_dict(builder, light_eid)
	if ent.is_empty():
		return
	ent["fallback_color"] = Color(1.0, 1.0, 1.0, 0.0)
	var comps_var: Variant = ent.get("components", null)
	if comps_var is Array and not (comps_var as Array).is_empty():
		var c0_var: Variant = (comps_var as Array)[0]
		if c0_var is Dictionary:
			var state_var: Variant = (c0_var as Dictionary).get("state", null)
			if state_var is Dictionary:
				var st: Dictionary = state_var as Dictionary
				st["fallback_color"] = Color(1.0, 1.0, 1.0, 0.0)
				st["show_fallback"] = false


func _bounded_size_estimate(val: Variant, depth: int = 0) -> int:
	if depth > 32:
		return -1
	match typeof(val):
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return 16 + str(val).length() * 4
		TYPE_PACKED_BYTE_ARRAY:
			return 16 + (val as PackedByteArray).size()
		TYPE_PACKED_INT32_ARRAY:
			return 16 + (val as PackedInt32Array).size() * 4
		TYPE_PACKED_FLOAT32_ARRAY:
			return 16 + (val as PackedFloat32Array).size() * 4
		TYPE_PACKED_INT64_ARRAY:
			return 16 + (val as PackedInt64Array).size() * 8
		TYPE_PACKED_FLOAT64_ARRAY:
			return 16 + (val as PackedFloat64Array).size() * 8
		TYPE_PACKED_VECTOR2_ARRAY:
			return 16 + (val as PackedVector2Array).size() * 16
		TYPE_PACKED_VECTOR3_ARRAY:
			return 16 + (val as PackedVector3Array).size() * 24
		TYPE_PACKED_VECTOR4_ARRAY:
			return 16 + (val as PackedVector4Array).size() * 32
		TYPE_PACKED_COLOR_ARRAY:
			return 16 + (val as PackedColorArray).size() * 32
		TYPE_PACKED_STRING_ARRAY:
			if depth + 1 > 32:
				return -1
			var total_ps: int = 16
			for s: String in val as PackedStringArray:
				total_ps += 16 + s.length() * 4
			return total_ps
		TYPE_DICTIONARY:
			var total_d: int = 16
			var d: Dictionary = val as Dictionary
			for k: Variant in d.keys():
				var kc: int = _bounded_size_estimate(k, depth + 1)
				if kc < 0:
					return -1
				var vc: int = _bounded_size_estimate(d[k], depth + 1)
				if vc < 0:
					return -1
				total_d += kc + vc
			return total_d
		TYPE_ARRAY:
			var total_a: int = 16
			for item: Variant in val as Array:
				var ic: int = _bounded_size_estimate(item, depth + 1)
				if ic < 0:
					return -1
				total_a += ic
			return total_a
		_:
			return 256


func _build_actor_archive_list(actors: Array, actor_keys: Array[String], actor_sprite_refs: Dictionary, trim_level: int) -> Array:
	# trim_level 0: full (biography <= 2048)
	# trim_level 1: clear biography
	# trim_level 2: clear raw_summary, abilities, speed, senses
	var out: Array = []
	for i: int in range(actors.size()):
		if not (actors[i] is Dictionary):
			continue
		var act: Dictionary = actors[i] as Dictionary
		var aid: String = str(act.get("id", ""))
		var key: String = actor_keys[i] if i < actor_keys.size() else (aid if not aid.is_empty() else ("_idx_%d" % i))
		var sprite_ref: String = str(actor_sprite_refs.get(key, ""))
		var row: Dictionary = {
			"id": aid,
			"name": str(act.get("name", "")),
			"actor_type": str(act.get("actor_type", "npc")),
			"sub_type": str(act.get("sub_type", "")),
			"folder_name": str(act.get("folder_name", "")),
			"ac": _to_int(act.get("ac", 10), 10),
			"hp_value": _to_int(act.get("hp_value", 0), 0),
			"hp_max": _to_int(act.get("hp_max", 0), 0),
			"cr_or_level": _to_float(act.get("cr_or_level", 0.0), 0.0),
			"sprite_ref": sprite_ref,
		}
		if trim_level <= 1:
			var ab_clean: Variant = _sanitize_module_value(act.get("abilities", {}))
			row["abilities"] = ab_clean if (ab_clean is Dictionary) else {}
			var sp_clean: Variant = _sanitize_module_value(act.get("speed", {}))
			row["speed"] = sp_clean if (sp_clean is Dictionary) else {}
			var sn_clean: Variant = _sanitize_module_value(act.get("senses", {}))
			row["senses"] = sn_clean if (sn_clean is Dictionary) else {}
			var rs_clean: Variant = _sanitize_module_value(act.get("raw_summary", {}))
			row["raw_summary"] = rs_clean if (rs_clean is Dictionary) else {}
		if trim_level == 0:
			row["biography"] = str(act.get("biography", "")).left(_MAX_BIOGRAPHY_CHARS)
		else:
			row["biography"] = ""
		out.append(row)
	return out


func _modules_within_budget(builder: RefCounted, mod_state: Dictionary) -> bool:
	var entry_var_bytes: int = var_to_bytes(mod_state).size()
	if entry_var_bytes > _MAX_MODULE_ENTRY_BYTES:
		return false
	var entry_bounded: int = _bounded_size_estimate(mod_state)
	if entry_bounded < 0 or entry_bounded > _MAX_MODULE_ENTRY_BYTES:
		return false
	var world_var: Variant = builder.get_world()
	if not (world_var is Dictionary):
		return false
	var world: Dictionary = world_var as Dictionary
	var mods_var: Variant = world.get("modules", {})
	var mods_copy: Dictionary = (mods_var as Dictionary).duplicate(false) if (mods_var is Dictionary) else {"version": 2, "entries": {}}
	if not mods_copy.has("version"):
		mods_copy["version"] = 2
	var raw_entries_copy: Variant = mods_copy.get("entries", {})
	var entries_copy: Dictionary = (raw_entries_copy as Dictionary).duplicate(false) if (raw_entries_copy is Dictionary) else {}
	var new_entry: Dictionary = {"version": 1, "state": mod_state}
	entries_copy["fvtt_world_importer"] = new_entry
	mods_copy["entries"] = entries_copy

	if var_to_bytes(mods_copy).size() > _MAX_MODULE_TOTAL_BYTES:
		return false
	var total_bounded: int = _bounded_size_estimate(mods_copy)
	if total_bounded < 0 or total_bounded > _MAX_MODULE_TOTAL_BYTES:
		return false

	# Check total world size estimate (current world bytes + module delta)
	var cur_world_bytes: int = var_to_bytes(world).size()
	var prev_entry_bytes: int = 0
	var real_entries: Variant = (mods_var as Dictionary).get("entries", {}) if (mods_var is Dictionary) else {}
	if real_entries is Dictionary and (real_entries as Dictionary).has("fvtt_world_importer"):
		prev_entry_bytes = var_to_bytes((real_entries as Dictionary)["fvtt_world_importer"]).size()
	var new_entry_bytes: int = var_to_bytes(new_entry).size()
	if cur_world_bytes - prev_entry_bytes + new_entry_bytes > _MAX_WORLD_BUDGET_BYTES:
		return false
	return true


func _parse_json_dict(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return raw as Dictionary
	if raw is String:
		var j := JSON.new()
		if j.parse(raw as String) == OK and j.data is Dictionary:
			return j.data as Dictionary
	return {}


func _normalize_abs_dir(raw_path: String) -> String:
	var p: String = raw_path.strip_edges().replace("\\", "/").simplify_path()
	while p.length() > 1 and p.ends_with("/"):
		if p.length() == 3 and p.substr(1, 2) == ":/":
			break
		p = p.left(p.length() - 1)
	return p


func _validate_session_destination(global_root: String, global_dest: String) -> bool:
	var root_norm: String = _normalize_abs_dir(global_root)
	var dest_norm: String = _normalize_abs_dir(global_dest)
	if root_norm.is_empty() or dest_norm.is_empty():
		return false
	var dest_leaf: String = dest_norm.get_file()
	var parent_dir: String = _normalize_abs_dir(dest_norm.get_base_dir())
	var parent_name: String = parent_dir.get_file()
	if parent_name != "sessions" and parent_name != "recycle":
		return false
	var rx := RegEx.new()
	if rx.compile("^桌面 [0-9-]{10} [0-9]{6}_[0-9a-f]{32}$") != OK:
		return false
	if rx.search(dest_leaf) == null:
		return false
	var grandparent_dir: String = _normalize_abs_dir(parent_dir.get_base_dir())
	if grandparent_dir.is_empty():
		return false
	if OS.get_name() == "Windows":
		return grandparent_dir.to_lower() == root_norm.to_lower()
	return grandparent_dir == root_norm


func _rollback_library_mutations(global_root: String, mutations: Array[Dictionary], initial_rev: String) -> void:
	if _shared_asset_store == null or mutations.is_empty():
		return
	var rev: String = initial_rev
	if rev.is_empty() and _shared_asset_store.has_method("ReadLibraryRecords"):
		var r_var: Variant = _shared_asset_store.ReadLibraryRecords(global_root)
		if r_var is Dictionary and bool((r_var as Dictionary).get("ok", false)):
			rev = str((r_var as Dictionary).get("revision", ""))
	for idx: int in range(mutations.size() - 1, -1, -1):
		var mut: Dictionary = mutations[idx]
		var rec_id: String = str(mut.get("id", ""))
		var written_b: PackedByteArray = mut.get("written_bytes", PackedByteArray())
		var prev_b: PackedByteArray = mut.get("prev_bytes", PackedByteArray())
		var rb_res: Dictionary = _parse_json_dict(
			_shared_asset_store.WriteLibraryRecord(global_root, rec_id, written_b, prev_b, rev)
		)
		if bool(rb_res.get("ok", false)):
			rev = str(rb_res.get("revision", rev))
		elif _shared_asset_store.has_method("ReadLibraryRecords"):
			var r2_var: Variant = _shared_asset_store.ReadLibraryRecords(global_root)
			if r2_var is Dictionary and bool((r2_var as Dictionary).get("ok", false)):
				var r2: Dictionary = r2_var as Dictionary
				rev = str(r2.get("revision", rev))
				var cur_recs: Dictionary = r2.get("records", {}) if r2.get("records", null) is Dictionary else {}
				var cur_b: PackedByteArray = cur_recs.get(rec_id, PackedByteArray())
				var rb2: Dictionary = _parse_json_dict(
					_shared_asset_store.WriteLibraryRecord(global_root, rec_id, cur_b, prev_b, rev)
				)
				if bool(rb2.get("ok", false)):
					rev = str(rb2.get("revision", rev))


func rollback_entity_library() -> void:
	if _last_lib_rollback.is_empty():
		return
	var gr: String = str(_last_lib_rollback.get("global_root", ""))
	var muts_raw: Variant = _last_lib_rollback.get("mutations", [])
	var rev: String = str(_last_lib_rollback.get("rev", ""))
	_last_lib_rollback = {}
	if gr.is_empty() or not (muts_raw is Array):
		return
	var muts: Array[Dictionary] = []
	for m: Variant in muts_raw as Array:
		if m is Dictionary:
			muts.append(m as Dictionary)
	_rollback_library_mutations(gr, muts, rev)


func _register_entity_library(
	world_id: String,
	actors: Array,
	actor_keys: Array[String],
	actor_sprite_refs: Dictionary,
	host: RefCounted,
	session: RefCounted,
	register_enabled: bool
) -> Dictionary:
	_last_lib_rollback = {}
	# 4-gate check
	if not register_enabled:
		return {"ok": true, "count": 0}
	if _shared_asset_store == null:
		return {"ok": true, "count": 0}
	if not (ResourceLoader.exists(_SHARED_ASSET_STORE_PATH) or _allow_mock_store):
		return {"ok": true, "count": 0}
	if host == null:
		return {"ok": true, "count": 0}
	var root_var: Variant = host.get("root")
	var dest_var: Variant = host.get("destination")
	if not (root_var is String) or not (dest_var is String):
		return {"ok": true, "count": 0}
	var raw_root: String = (root_var as String).strip_edges()
	var raw_dest: String = (dest_var as String).strip_edges()
	if raw_root.is_empty() or raw_dest.is_empty():
		return {"ok": true, "count": 0}
	var global_root: String = ProjectSettings.globalize_path(raw_root)
	var global_dest: String = ProjectSettings.globalize_path(raw_dest)
	if not _validate_session_destination(global_root, global_dest):
		return {"ok": true, "count": 0}
	if _is_cancelled(session):
		return {"ok": false, "reason": "cancelled", "count": 0}
	if actors.is_empty():
		return {"ok": true, "count": 0}

	var open_res: Dictionary = _parse_json_dict(_shared_asset_store.OpenLibrary(global_root))
	if not bool(open_res.get("ok", false)):
		_warn(session, "打开素材库失败，已跳过角色/怪物素材库注册：" + str(open_res.get("reason", "unknown")))
		return {"ok": true, "count": 0}

	# ReadLibraryRecords returns Godot Dictionary directly (NOT JSON string)
	var read_var: Variant = _shared_asset_store.ReadLibraryRecords(global_root)
	if not (read_var is Dictionary):
		_warn(session, "读取素材库记录失败，已跳过注册")
		return {"ok": true, "count": 0}
	var read_res: Dictionary = read_var as Dictionary
	if not bool(read_res.get("ok", false)):
		_warn(session, "读取素材库记录失败，已跳过注册：" + str(read_res.get("reason", "unknown")))
		return {"ok": true, "count": 0}

	var records: Dictionary = read_res.get("records", {}) if read_res.get("records", null) is Dictionary else {}
	var current_rev: String = str(read_res.get("revision", ""))
	var registered_count: int = 0
	var mutations: Array[Dictionary] = []

	# Register folder hierarchy deterministically (no cycles)
	var folder_ids: Dictionary = {}
	for act_var: Variant in actors:
		if _is_cancelled(session):
			_rollback_library_mutations(global_root, mutations, current_rev)
			return {"ok": false, "reason": "cancelled", "count": 0}
		if not (act_var is Dictionary):
			continue
		var fname_path: String = str((act_var as Dictionary).get("folder_name", "")).strip_edges()
		if fname_path.is_empty():
			continue
		var parts: PackedStringArray = fname_path.split("/", false)
		var parent_id: String = ""
		var prefix_path: String = ""
		for seg: String in parts:
			if _is_cancelled(session):
				_rollback_library_mutations(global_root, mutations, current_rev)
				return {"ok": false, "reason": "cancelled", "count": 0}
			var clean_seg: String = _sanitize_catalog_name(seg, "")
			if clean_seg.is_empty():
				continue
			prefix_path = clean_seg if prefix_path.is_empty() else (prefix_path + "/" + clean_seg)
			if folder_ids.has(prefix_path):
				parent_id = str(folder_ids[prefix_path])
				continue
			var fid: String = ("fvtt:lib:folder:%s:%s" % [world_id, prefix_path]).sha256_text().left(32)
			if fid == parent_id:
				continue
			var folder_row: Dictionary = {
				"version": 1,
				"id": fid,
				"name": clean_seg.left(256),
				"kind": "folder",
				"folder_id": parent_id,
			}
			var desired_f: PackedByteArray = var_to_bytes(folder_row)
			var expected_f: PackedByteArray = records.get(fid, PackedByteArray())
			var folder_ok: bool = false
			if desired_f == expected_f:
				folder_ok = true
			else:
				var wf_res: Dictionary = _parse_json_dict(
					_shared_asset_store.WriteLibraryRecord(global_root, fid, expected_f, desired_f, current_rev)
				)
				if bool(wf_res.get("ok", false)):
					current_rev = str(wf_res.get("revision", current_rev))
					mutations.append({
						"id": fid,
						"prev_bytes": expected_f,
						"written_bytes": desired_f,
					})
					records[fid] = desired_f
					folder_ok = true
				else:
					_warn(session, "写入素材库目录失败（%s）：%s" % [clean_seg, str(wf_res.get("reason", "unknown"))])
					if records.has(fid):
						folder_ok = true
			if folder_ok:
				folder_ids[prefix_path] = fid
				parent_id = fid
			else:
				break

	# Register actors as kind="unit"
	for i: int in range(actors.size()):
		if _is_cancelled(session):
			_rollback_library_mutations(global_root, mutations, current_rev)
			return {"ok": false, "reason": "cancelled", "count": 0}
		if not (actors[i] is Dictionary):
			continue
		var act: Dictionary = actors[i] as Dictionary
		var aid: String = str(act.get("id", ""))
		var key: String = actor_keys[i] if i < actor_keys.size() else (aid if not aid.is_empty() else ("_idx_%d" % i))
		var sprite_ref: String = str(actor_sprite_refs.get(key, ""))
		if sprite_ref.begins_with("asset://"):
			var adopt_res: Dictionary = _parse_json_dict(_shared_asset_store.AdoptLibraryAsset(global_root, global_dest, sprite_ref))
			if bool(adopt_res.get("ok", false)):
				var share_res: Dictionary = _parse_json_dict(_shared_asset_store.ShareLibraryAsset(global_root, sprite_ref))
				if not bool(share_res.get("ok", false)):
					_warn(session, "素材库共享贴图失败（%s）：%s" % [sprite_ref, str(share_res.get("reason", "unknown"))])
			else:
				_warn(session, "素材库归档贴图失败（%s）：%s" % [sprite_ref, str(adopt_res.get("reason", "unknown"))])
				sprite_ref = ""

		var folder_path: String = str(act.get("folder_name", "")).strip_edges()
		var target_folder_id: String = ""
		if not folder_path.is_empty():
			var clean_segs: Array[String] = []
			for seg2: String in folder_path.split("/", false):
				var cs: String = _sanitize_catalog_name(seg2, "")
				if not cs.is_empty():
					clean_segs.append(cs)
			var clean_key: String = "/".join(clean_segs)
			target_folder_id = str(folder_ids.get(clean_key, ""))

		var row_id: String = ("fvtt:lib:unit:%s:%s" % [world_id, key]).sha256_text().left(32)
		var raw_name: String = str(act.get("name", "")).strip_edges()
		var row_name: String = raw_name.left(256) if not raw_name.is_empty() else "Unnamed Unit"
		var tok_w: float = clampf(_to_float(act.get("token_width", 1.0), 1.0), 0.1, 16384.0)
		var tok_h: float = clampf(_to_float(act.get("token_height", 1.0), 1.0), 0.1, 16384.0)
		var row_size := Vector2(maxf(4.0, tok_w * 64.0), maxf(4.0, tok_h * 64.0))

		var unit_row: Dictionary = {
			"version": 1,
			"id": row_id,
			"name": row_name,
			"kind": "unit",
			"folder_id": target_folder_id,
			"reference": sprite_ref,
			"size": row_size,
			"record": {
				"data": {
					"id": row_id,
					"name": row_name,
					"type": "generic",
					"category": "library",
					"size": row_size,
					"color": Color.WHITE,
					"sprite": sprite_ref,
					"components": {"unit": {}},
					"selectable_in_select_mode": false,
				},
				"source_info": {},
				"kind": "unit",
			},
		}
		var desired_u: PackedByteArray = var_to_bytes(unit_row)
		var expected_u: PackedByteArray = records.get(row_id, PackedByteArray())
		if desired_u == expected_u:
			registered_count += 1
			continue
		var wu_res: Dictionary = _parse_json_dict(
			_shared_asset_store.WriteLibraryRecord(global_root, row_id, expected_u, desired_u, current_rev)
		)
		if bool(wu_res.get("ok", false)):
			current_rev = str(wu_res.get("revision", current_rev))
			mutations.append({
				"id": row_id,
				"prev_bytes": expected_u,
				"written_bytes": desired_u,
			})
			records[row_id] = desired_u
			registered_count += 1
		else:
			_warn(session, "写入素材库单位失败（%s）：%s" % [row_name, str(wu_res.get("reason", "unknown"))])

	if _is_cancelled(session):
		_rollback_library_mutations(global_root, mutations, current_rev)
		return {"ok": false, "reason": "cancelled", "count": 0}

	_last_lib_rollback = {
		"global_root": global_root,
		"mutations": mutations,
		"rev": current_rev,
	}
	return {"ok": true, "count": registered_count}


func map_to_world(
	model: Dictionary,
	builder: RefCounted,
	assets_helper: RefCounted,
	source: RefCounted,
	host: RefCounted,
	session: RefCounted,
	options: Dictionary
) -> Dictionary:
	_last_lib_rollback = {}
	if _is_cancelled(session):
		return {"ok": false, "reason": "cancelled"}
	if builder == null or assets_helper == null:
		return {"ok": false, "reason": "invalid_mapper_dependencies"}

	var world_meta: Dictionary = model.get("world_meta", {}) if model.get("world_meta", null) is Dictionary else {}
	var raw_scenes: Array = model.get("scenes", []) if model.get("scenes", null) is Array else []
	var raw_actors: Array = model.get("actors", []) if model.get("actors", null) is Array else []
	var assets_map: Dictionary = model.get("assets", {}) if model.get("assets", null) is Dictionary else {}
	var source_records: int = _to_int(model.get("source_records", 0), 0)

	var import_scenes: bool = _coerce_bool(options.get("import_scenes", true), true)
	var import_characters: bool = _coerce_bool(options.get("import_characters", true), true)
	var import_monsters: bool = _coerce_bool(options.get("import_monsters", true), true)
	var include_hidden: bool = _coerce_bool(options.get("include_hidden", true), true)
	var register_entity_library: bool = _coerce_bool(options.get("register_entity_library", true), true)

	# Filter actors if caller passed an unfiltered model directly
	var actors: Array = []
	var actor_keys: Array[String] = []
	var seen_actor_keys: Dictionary = {}
	var actor_by_id: Dictionary = {}
	for act_v: Variant in raw_actors:
		if not (act_v is Dictionary):
			continue
		var act_d: Dictionary = act_v as Dictionary
		var atype: String = str(act_d.get("actor_type", "npc"))
		if atype == "character" and not import_characters:
			continue
		if atype != "character" and not import_monsters:
			continue
		var a_idx: int = actors.size()
		actors.append(act_d)
		var aid: String = str(act_d.get("id", ""))
		if not aid.is_empty():
			actor_by_id[aid] = act_d
		var unique_akey: String = aid if not aid.is_empty() else ("_idx_%d" % a_idx)
		if seen_actor_keys.has(unique_akey):
			unique_akey = "%s_%d" % [unique_akey, a_idx]
		while seen_actor_keys.has(unique_akey):
			unique_akey = "%s_x" % unique_akey
		seen_actor_keys[unique_akey] = true
		actor_keys.append(unique_akey)

	var effective_scenes: Array = []
	if import_scenes and not raw_scenes.is_empty():
		var valid_scenes: Array = []
		for sc_v: Variant in raw_scenes:
			if sc_v is Dictionary:
				var sc_d: Dictionary = sc_v as Dictionary
				if not include_hidden and bool(sc_d.get("hidden", false)):
					continue
				valid_scenes.append(sc_d)
		if valid_scenes.size() > _MAX_FLOORS:
			_warn(session, "场景数量（%d）超过宿主上限 %d，已截断至前 %d 个场景" % [valid_scenes.size(), _MAX_FLOORS, _MAX_FLOORS])
			effective_scenes = valid_scenes.slice(0, _MAX_FLOORS)
		else:
			effective_scenes = valid_scenes

	# Determine world_source_units_per_cell from first gridded scene (grid_type == 1 && grid_size > 0)
	var world_source_units_per_cell: float = 150.0
	for sc_g: Dictionary in effective_scenes:
		var gt: int = _to_int(sc_g.get("grid_type", 1), 1)
		var gs: float = _to_float(sc_g.get("grid_size", 0.0), 0.0)
		if gt == 1 and is_finite(gs) and gs > 0.0:
			world_source_units_per_cell = clampf(gs, 1.0, 1e6)
			break
	world_source_units_per_cell = clampf(world_source_units_per_cell, 1.0, 1e6)
	var source_to_world: float = 64.0 / world_source_units_per_cell

	# Phase A: setup + bounds preview + floors + walls/doors/windows
	var setup_res: Dictionary = builder.setup(session, world_source_units_per_cell)
	if not bool(setup_res.get("ok", false)):
		return {"ok": false, "reason": str(setup_res.get("reason", "world_builder_setup_failed"))}

	var total_preview_items: int = 0
	var has_bounds: bool = false
	var bounds_min := Vector2.ZERO
	var bounds_max := Vector2.ZERO
	for sc_b: Dictionary in effective_scenes:
		var sc_scale_b: float = _scene_scale_for(sc_b, world_source_units_per_cell)
		var sx: float = clampf(clampf(_to_float(sc_b.get("scene_x", 0.0), 0.0), -1e15, 1e15) * sc_scale_b, -1e15, 1e15)
		var sy: float = clampf(clampf(_to_float(sc_b.get("scene_y", 0.0), 0.0), -1e15, 1e15) * sc_scale_b, -1e15, 1e15)
		var sw: float = clampf(clampf(maxf(1.0, _to_float(sc_b.get("width", 3000.0), 3000.0)), 1.0, 1e15) * sc_scale_b, 1.0, 1e15)
		var sh: float = clampf(clampf(maxf(1.0, _to_float(sc_b.get("height", 2100.0), 2100.0)), 1.0, 1e15) * sc_scale_b, 1.0, 1e15)
		if not has_bounds:
			bounds_min = Vector2(sx, sy)
			bounds_max = Vector2(sx + sw, sy + sh)
			has_bounds = true
		else:
			bounds_min = bounds_min.min(Vector2(sx, sy))
			bounds_max = bounds_max.max(Vector2(sx + sw, sy + sh))
		total_preview_items += 1
		var walls_b: Variant = sc_b.get("walls", null)
		if walls_b is Array:
			total_preview_items += (walls_b as Array).size()
		var tiles_b: Variant = sc_b.get("tiles", null)
		if tiles_b is Array:
			total_preview_items += (tiles_b as Array).size()
		var tokens_b: Variant = sc_b.get("tokens", null)
		if tokens_b is Array:
			total_preview_items += (tokens_b as Array).size()
		var lights_b: Variant = sc_b.get("lights", null)
		if lights_b is Array:
			total_preview_items += (lights_b as Array).size()
	if not has_bounds:
		bounds_max = Vector2(3000.0, 2100.0)
	if effective_scenes.is_empty():
		total_preview_items += actors.size()
	builder.begin_bounds_preview(total_preview_items, Rect2(bounds_min, bounds_max - bounds_min))

	var floor0_uid: String = builder.get_active_floor_uid()
	var scene_floor_uids: Array[String] = []
	var active_floor_uid: String = floor0_uid
	var found_active: bool = false

	if not effective_scenes.is_empty():
		var sc0: Dictionary = effective_scenes[0] as Dictionary
		_rename_floor_safe(builder, floor0_uid, str(sc0.get("name", "")), "1F")
		scene_floor_uids.append(floor0_uid)
		if bool(sc0.get("active", false)):
			active_floor_uid = floor0_uid
			found_active = true
		for i: int in range(1, effective_scenes.size()):
			var sc_i: Dictionary = effective_scenes[i] as Dictionary
			var fl_name: String = _sanitize_catalog_name(str(sc_i.get("name", "")), "%dF" % (i + 1))
			var new_fuid: String = builder.add_floor(fl_name, Color(0.28, 0.65, 0.40), false)
			if new_fuid.is_empty():
				return {"ok": false, "reason": "add_floor_failed"}
			scene_floor_uids.append(new_fuid)
			if not found_active and bool(sc_i.get("active", false)):
				active_floor_uid = new_fuid
				found_active = true
	else:
		_rename_floor_safe(builder, floor0_uid, "1F", "1F")

	var scene_ids: Array[String] = []
	var seen_scene_ids: Dictionary = {}
	for s_i: int in range(effective_scenes.size()):
		var sc_id_src: Dictionary = effective_scenes[s_i] as Dictionary
		var raw_sc_id: String = str(sc_id_src.get("id", "")).strip_edges()
		var unique_sc_id: String = raw_sc_id if not raw_sc_id.is_empty() else ("idx_%d" % s_i)
		if seen_scene_ids.has(unique_sc_id):
			unique_sc_id = "%s_%d" % [unique_sc_id, s_i]
		while seen_scene_ids.has(unique_sc_id):
			unique_sc_id = "%s_x" % unique_sc_id
		seen_scene_ids[unique_sc_id] = true
		scene_ids.append(unique_sc_id)

	var entity_count: int = 0
	var merged_walls: int = 0
	var entity_cap_warned: bool = false

	for s_idx: int in range(effective_scenes.size()):
		if _is_cancelled(session):
			return {"ok": false, "reason": "cancelled"}
		var sc: Dictionary = effective_scenes[s_idx] as Dictionary
		var floor_uid: String = scene_floor_uids[s_idx]
		builder.set_active_floor(floor_uid)

		var sc_id: String = scene_ids[s_idx]
		var scene_scale: float = _scene_scale_for(sc, world_source_units_per_cell)
		var raw_gs: float = _to_float(sc.get("grid_size", 0.0), 0.0)
		var effective_grid: float = clampf(raw_gs, 1.0, 1e6) if (is_finite(raw_gs) and raw_gs > 0.0) else world_source_units_per_cell
		var half_w: float = clampf(maxf(4.0, effective_grid * 0.06 * scene_scale), 4.0, 1e6)

		var walls: Array = sc.get("walls", []) if sc.get("walls", null) is Array else []
		for w_idx: int in range(walls.size()):
			if entity_count >= _MAX_ENTITIES:
				if not entity_cap_warned:
					entity_cap_warned = true
					_warn(session, "世界实体总数达到宿主上限 %d，后续实体已截断" % _MAX_ENTITIES)
				break
			if not (walls[w_idx] is Dictionary):
				continue
			var w: Dictionary = walls[w_idx] as Dictionary
			var door: int = _to_int(w.get("door", 0), 0)
			if not include_hidden and door == 2:
				continue
			var ds: int = _to_int(w.get("ds", 0), 0)
			var move_v: int = _to_int(w.get("move", 20), 20)
			var sight_v: int = _to_int(w.get("sight", 20), 20)
			var light_v: int = _to_int(w.get("light", 20), 20)

			# Skip ethereal lines (T2-F7-03)
			if door == 0 and move_v <= 0 and sight_v <= 0 and light_v <= 0:
				continue

			var c_var: Variant = w.get("c", null)
			if not (c_var is Array) or (c_var as Array).size() < 4:
				continue
			var ca: Array = c_var as Array
			var p0_s := Vector2(_to_float(ca[0], NAN), _to_float(ca[1], NAN)) * scene_scale
			var p1_s := Vector2(_to_float(ca[2], NAN), _to_float(ca[3], NAN)) * scene_scale
			if (
				not is_finite(p0_s.x)
				or not is_finite(p0_s.y)
				or not is_finite(p1_s.x)
				or not is_finite(p1_s.y)
			):
				_warn(session, "跳过包含非有限坐标的墙体：" + str(w.get("id", "")))
				continue

			var p0_w: Vector2 = p0_s * source_to_world
			var p1_w: Vector2 = p1_s * source_to_world
			if (
				absf(p0_s.x) > 1e7
				or absf(p0_s.y) > 1e7
				or absf(p1_s.x) > 1e7
				or absf(p1_s.y) > 1e7
				or not is_finite(p0_w.x)
				or not is_finite(p0_w.y)
				or not is_finite(p1_w.x)
				or not is_finite(p1_w.y)
				or absf(p0_w.x) > 1e7
				or absf(p0_w.y) > 1e7
				or absf(p1_w.x) > 1e7
				or absf(p1_w.y) > 1e7
			):
				_warn(session, "跳过退化零长度或超长溢出墙体或门：" + str(w.get("id", "")))
				continue

			var seg: Vector2 = p1_s - p0_s
			var seg_len: float = seg.length()
			if not is_finite(seg_len) or seg_len < maxf(0.5, 1e-3):
				_warn(session, "跳过退化零长度或超长溢出墙体或门：" + str(w.get("id", "")))
				continue

			var dir: Vector2 = seg / seg_len
			if not is_finite(dir.x) or not is_finite(dir.y) or dir.length_squared() < 0.5:
				_warn(session, "跳过方向退化或溢出的墙体或门：" + str(w.get("id", "")))
				continue
			var n := Vector2(-dir.y, dir.x)
			var center_src: Vector2 = (p0_s + p1_s) * 0.5
			var center_w: Vector2 = center_src * source_to_world
			if (
				not is_finite(center_src.x)
				or not is_finite(center_src.y)
				or absf(center_src.x) > 1e7
				or absf(center_src.y) > 1e7
				or not is_finite(center_w.x)
				or not is_finite(center_w.y)
				or absf(center_w.x) > 1e7
				or absf(center_w.y) > 1e7
			):
				_warn(session, "跳过中心点溢出的墙体或门：" + str(w.get("id", "")))
				continue
			var ring: Array = [
				p0_s - center_src - n * half_w,
				p1_s - center_src - n * half_w,
				p1_s - center_src + n * half_w,
				p0_s - center_src + n * half_w,
			]
			var r0: Vector2 = ring[0]
			var r1: Vector2 = ring[1]
			var r2: Vector2 = ring[2]
			var r3: Vector2 = ring[3]
			var ring_oob: bool = false
			for r_pt: Vector2 in [r0, r1, r2, r3]:
				var r_w: Vector2 = r_pt * source_to_world
				var abs_w: Vector2 = (center_src + r_pt) * source_to_world
				if (
					not is_finite(r_pt.x)
					or not is_finite(r_pt.y)
					or absf(r_pt.x) > 1e7
					or absf(r_pt.y) > 1e7
					or not is_finite(r_w.x)
					or not is_finite(r_w.y)
					or absf(r_w.x) > 1e7
					or absf(r_w.y) > 1e7
					or not is_finite(abs_w.x)
					or not is_finite(abs_w.y)
					or absf(abs_w.x) > 1e8
					or absf(abs_w.y) > 1e8
				):
					ring_oob = true
					break
			var ring_area2: float = absf((r1 - r0).cross(r2 - r0))
			if (
				ring_oob
				or r0 == r3
				or r1 == r2
				or r0 == r1
				or r2 == r3
				or not is_finite(ring_area2)
				or ring_area2 <= 1e-3
			):
				_warn(session, "跳过退化零长度或超长溢出墙体或门：" + str(w.get("id", "")))
				continue
			var wid: String = str(w.get("id", ""))
			var src_id: String = "scene:%s:wall:%s:%d" % [sc_id, wid, w_idx]
			var eid: String = ""
			if door == 1 or door == 2:
				eid = builder.add_door(src_id, "", center_src, [ring], ds == 1, true)
			elif door == 0 and sight_v == 0 and move_v > 0:
				eid = builder.add_window(src_id, "", center_src, [ring], false, true)
			else:
				eid = builder.add_wall(src_id, "", center_src, [ring], true)
			if not eid.is_empty():
				entity_count += 1
				merged_walls += 1

	if _is_cancelled(session):
		return {"ok": false, "reason": "cancelled"}
	if not builder.finish_geometry_preview():
		if _is_cancelled(session):
			return {"ok": false, "reason": "cancelled"}
		return {"ok": false, "reason": "geometry_preview_failed"}

	# Pre-validate unique local images across worker threads before sequential Phase B resolution
	if assets_helper.has_method("prevalidate_local_refs"):
		var pre_refs: Array[String] = []
		if entity_count < _MAX_ENTITIES:
			for sc_p: Dictionary in effective_scenes:
				var p_bg_ref: String = str(sc_p.get("background_ref", ""))
				if not p_bg_ref.is_empty():
					pre_refs.append(p_bg_ref)
				var p_raw_tiles: Array = sc_p.get("tiles", []) if sc_p.get("tiles", null) is Array else []
				for p_tile_v: Variant in _sort_tiles_stable(p_raw_tiles):
					if not (p_tile_v is Dictionary):
						continue
					var p_tile: Dictionary = p_tile_v as Dictionary
					if not include_hidden and bool(p_tile.get("hidden", false)):
						continue
					var p_t_ref: String = str(p_tile.get("img_ref", ""))
					if not p_t_ref.is_empty():
						pre_refs.append(p_t_ref)
				var p_fg_ref: String = str(sc_p.get("foreground_ref", ""))
				if not p_fg_ref.is_empty():
					pre_refs.append(p_fg_ref)
				var p_tokens: Array = sc_p.get("tokens", []) if sc_p.get("tokens", null) is Array else []
				for p_tok_v: Variant in p_tokens:
					if not (p_tok_v is Dictionary):
						continue
					var p_tok: Dictionary = p_tok_v as Dictionary
					if not include_hidden and bool(p_tok.get("hidden", false)):
						continue
					var p_tok_atype: String = str(p_tok.get("actor_type", "npc"))
					if p_tok_atype == "character" and not import_characters:
						continue
					if p_tok_atype != "character" and not import_monsters:
						continue
					var p_tok_ref: String = str(p_tok.get("img_ref", ""))
					if not p_tok_ref.is_empty():
						pre_refs.append(p_tok_ref)
		for p_act_v: Variant in actors:
			if not (p_act_v is Dictionary):
				continue
			var p_act: Dictionary = p_act_v as Dictionary
			var p_act_ref: String = str(p_act.get("token_img_ref", ""))
			if p_act_ref.is_empty():
				p_act_ref = str(p_act.get("img_ref", ""))
			if not p_act_ref.is_empty():
				pre_refs.append(p_act_ref)
		assets_helper.prevalidate_local_refs(pre_refs, assets_map, source, session)
		if _is_cancelled(session):
			return {"ok": false, "reason": "cancelled"}

	# Phase B: scene backgrounds, tiles, foreground, tokens, lights + standalone actors
	for s_idx: int in range(effective_scenes.size()):
		if _is_cancelled(session):
			return {"ok": false, "reason": "cancelled"}
		var sc: Dictionary = effective_scenes[s_idx] as Dictionary
		var floor_uid: String = scene_floor_uids[s_idx]
		builder.set_active_floor(floor_uid)

		var sc_id: String = scene_ids[s_idx]
		var sc_name: String = str(sc.get("name", "Map"))
		var sc_hidden: bool = _coerce_bool(sc.get("hidden", false), false)
		var scene_scale: float = _scene_scale_for(sc, world_source_units_per_cell)
		var raw_gs: float = _to_float(sc.get("grid_size", 0.0), 0.0)
		var effective_grid: float = clampf(raw_gs, 1.0, 1e6) if (is_finite(raw_gs) and raw_gs > 0.0) else world_source_units_per_cell
		var grid_dist: float = maxf(0.01, _to_float(sc.get("grid_distance", 5.0), 5.0))

		var sc_w: float = clampf(maxf(1.0, _to_float(sc.get("width", 3000.0), 3000.0)), 1.0, 1e15)
		var sc_h: float = clampf(maxf(1.0, _to_float(sc.get("height", 2100.0), 2100.0)), 1.0, 1e15)
		var sc_x: float = clampf(_to_float(sc.get("scene_x", 0.0), 0.0), -1e15, 1e15)
		var sc_y: float = clampf(_to_float(sc.get("scene_y", 0.0), 0.0), -1e15, 1e15)
		var bg_center := Vector2(
			clampf((sc_x + sc_w * 0.5) * scene_scale, -1e15, 1e15),
			clampf((sc_y + sc_h * 0.5) * scene_scale, -1e15, 1e15)
		)
		var bg_size := Vector2(
			clampf(maxf(4.0, sc_w * scene_scale), 4.0, 1e15),
			clampf(maxf(4.0, sc_h * scene_scale), 4.0, 1e15)
		)

		# Background
		var bg_ref: String = str(sc.get("background_ref", ""))
		if not bg_ref.is_empty() and entity_count < _MAX_ENTITIES:
			var bg_res: Dictionary = assets_helper.resolve_sprite_ref(
				bg_ref,
				assets_map.get(bg_ref, {}),
				source,
				host,
				session,
				options
			)
			if not bool(bg_res.get("ok", false)):
				return bg_res
			var bg_eid: String = builder.add_map_tile(
				"scene:%s:bg" % sc_id,
				sc_name,
				bg_center,
				bg_size,
				str(bg_res.get("sprite_path", "")),
				0.0,
				Vector2.ONE,
				sc_hidden,
				"",
				false
			)
			if not bg_eid.is_empty():
				entity_count += 1
		elif not bg_ref.is_empty() and entity_count >= _MAX_ENTITIES and not entity_cap_warned:
			entity_cap_warned = true
			_warn(session, "世界实体总数达到宿主上限 %d，后续实体已截断" % _MAX_ENTITIES)

		# Sorted tiles
		var raw_tiles: Array = sc.get("tiles", []) if sc.get("tiles", null) is Array else []
		var sorted_tiles: Array = _sort_tiles_stable(raw_tiles)
		for t_idx: int in range(sorted_tiles.size()):
			if _is_cancelled(session):
				return {"ok": false, "reason": "cancelled"}
			if entity_count >= _MAX_ENTITIES:
				if not entity_cap_warned:
					entity_cap_warned = true
					_warn(session, "世界实体总数达到宿主上限 %d，后续实体已截断" % _MAX_ENTITIES)
				break
			var tile: Dictionary = sorted_tiles[t_idx] as Dictionary
			var t_hidden: bool = bool(tile.get("hidden", false))
			if not include_hidden and t_hidden:
				continue
			var t_ref: String = str(tile.get("img_ref", ""))
			var t_sprite: String = ""
			if not t_ref.is_empty():
				var t_res: Dictionary = assets_helper.resolve_sprite_ref(
					t_ref,
					assets_map.get(t_ref, {}),
					source,
					host,
					session,
					options
				)
				if not bool(t_res.get("ok", false)):
					return t_res
				t_sprite = str(t_res.get("sprite_path", ""))
			var tw: float = clampf(maxf(1.0, _to_float(tile.get("width", 100.0), 100.0)), 1.0, 1e15)
			var th: float = clampf(maxf(1.0, _to_float(tile.get("height", 100.0), 100.0)), 1.0, 1e15)
			var tx: float = clampf(_to_float(tile.get("x", 0.0), 0.0), -1e15, 1e15)
			var ty: float = clampf(_to_float(tile.get("y", 0.0), 0.0), -1e15, 1e15)
			var t_center := Vector2(
				clampf((tx + tw * 0.5) * scene_scale, -1e15, 1e15),
				clampf((ty + th * 0.5) * scene_scale, -1e15, 1e15)
			)
			var t_size := Vector2(
				clampf(maxf(4.0, tw * scene_scale), 4.0, 1e15),
				clampf(maxf(4.0, th * scene_scale), 4.0, 1e15)
			)
			var t_rot: float = deg_to_rad(_to_float(tile.get("rotation", 0.0), 0.0))
			var t_eid: String = builder.add_map_tile(
				"scene:%s:tile:%s:%d" % [sc_id, str(tile.get("id", "")), t_idx],
				"%s Tile" % sc_name,
				t_center,
				t_size,
				t_sprite,
				t_rot,
				Vector2.ONE,
				t_hidden,
				"",
				false
			)
			if not t_eid.is_empty():
				entity_count += 1

		# Foreground (drawn after background & tiles on map layer)
		var fg_ref: String = str(sc.get("foreground_ref", ""))
		if not fg_ref.is_empty():
			if entity_count >= _MAX_ENTITIES:
				if not entity_cap_warned:
					entity_cap_warned = true
					_warn(session, "世界实体总数达到宿主上限 %d，后续实体已截断" % _MAX_ENTITIES)
			else:
				var fg_res: Dictionary = assets_helper.resolve_sprite_ref(
					fg_ref,
					assets_map.get(fg_ref, {}),
					source,
					host,
					session,
					options
				)
				if not bool(fg_res.get("ok", false)):
					return fg_res
				var fg_eid: String = builder.add_map_tile(
					"scene:%s:fg" % sc_id,
					"%s (Foreground)" % sc_name,
					bg_center,
					bg_size,
					str(fg_res.get("sprite_path", "")),
					0.0,
					Vector2.ONE,
					sc_hidden,
					"",
					false
				)
				if not fg_eid.is_empty():
					entity_count += 1

		# Tokens
		var tokens: Array = sc.get("tokens", []) if sc.get("tokens", null) is Array else []
		for tok_idx: int in range(tokens.size()):
			if _is_cancelled(session):
				return {"ok": false, "reason": "cancelled"}
			if entity_count >= _MAX_ENTITIES:
				if not entity_cap_warned:
					entity_cap_warned = true
					_warn(session, "世界实体总数达到宿主上限 %d，后续实体已截断" % _MAX_ENTITIES)
				break
			if not (tokens[tok_idx] is Dictionary):
				continue
			var tok: Dictionary = tokens[tok_idx] as Dictionary
			var tok_hidden: bool = bool(tok.get("hidden", false))
			if not include_hidden and tok_hidden:
				continue
			var tok_atype: String = str(tok.get("actor_type", "npc"))
			if tok_atype == "character" and not import_characters:
				continue
			if tok_atype != "character" and not import_monsters:
				continue

			var tok_ref: String = str(tok.get("img_ref", ""))
			var tok_sprite: String = ""
			if not tok_ref.is_empty():
				var tok_res: Dictionary = assets_helper.resolve_sprite_ref(
					tok_ref,
					assets_map.get(tok_ref, {}),
					source,
					host,
					session,
					options
				)
				if not bool(tok_res.get("ok", false)):
					return tok_res
				tok_sprite = str(tok_res.get("sprite_path", ""))

			var tok_w_px: float = clampf(maxf(0.1, _to_float(tok.get("width", 1.0), 1.0)), 0.1, 16384.0) * effective_grid
			var tok_h_px: float = clampf(maxf(0.1, _to_float(tok.get("height", 1.0), 1.0)), 0.1, 16384.0) * effective_grid
			var tok_x_pre: float = clampf(_to_float(tok.get("x", 0.0), 0.0), -1e15, 1e15) + tok_w_px * 0.5
			var tok_y_pre: float = clampf(_to_float(tok.get("y", 0.0), 0.0), -1e15, 1e15) + tok_h_px * 0.5
			var tok_center := Vector2(
				clampf(tok_x_pre * scene_scale, -1e15, 1e15),
				clampf(tok_y_pre * scene_scale, -1e15, 1e15)
			)
			var tok_size := Vector2(
				clampf(maxf(4.0, tok_w_px * scene_scale), 4.0, 1e15),
				clampf(maxf(4.0, tok_h_px * scene_scale), 4.0, 1e15)
			)
			var tok_sval: float = clampf(maxf(0.1, _to_float(tok.get("scale", 1.0), 1.0)), 0.1, 1000.0)
			var tok_scale := Vector2(tok_sval, tok_sval)
			var tok_rot: float = deg_to_rad(_to_float(tok.get("rotation", 0.0), 0.0))
			var size_world: Vector2 = tok_size * tok_scale * source_to_world
			var footprint_r: float = clampf(minf(size_world.x, size_world.y) * 0.5, 0.5, 4096.0)

			var player_operable: bool = (
				tok_atype == "character"
				or _coerce_bool(tok.get("actor_link", false), false)
				or _to_int(tok.get("disposition", -1), -1) == 1
			)
			var perm_state: Dictionary = {
				"owners_csv": "",
				"gm_can_operate": true,
				"all_players_can_operate": player_operable,
				"owner_peers": PackedInt32Array(),
				"owner_player_ids": PackedStringArray(),
			}
			var tok_name: String = str(tok.get("name", "")).strip_edges()
			if tok_name.is_empty():
				tok_name = "Token"
			var tok_eid: String = builder.add_token(
				"scene:%s:token:%s:%d" % [sc_id, str(tok.get("id", "")), tok_idx],
				tok_name,
				tok_center,
				tok_size,
				tok_sprite,
				tok_rot,
				tok_scale,
				tok_hidden,
				footprint_r,
				false,
				perm_state
			)
			if not tok_eid.is_empty():
				entity_count += 1
				builder.attach_unit_marker(tok_eid)
				var sight_enabled: bool = _coerce_bool(tok.get("sight_enabled", false), false)
				var sight_range: float = maxf(0.0, _to_float(tok.get("sight_range", 0.0), 0.0))
				var raw_sight_angle: float = _to_float(tok.get("sight_angle", 360.0), 360.0)
				var sight_angle: float = 360.0 if (not is_finite(raw_sight_angle) or raw_sight_angle <= 0.0 or raw_sight_angle >= 360.0) else raw_sight_angle
				if not sight_enabled:
					var aid: String = str(tok.get("actor_id", ""))
					var linked_act: Dictionary = actor_by_id.get(aid, {})
					if not linked_act.is_empty():
						var senses_d: Dictionary = linked_act.get("senses", {}) if linked_act.get("senses", null) is Dictionary else {}
						var dv: float = maxf(0.0, _to_float(senses_d.get("darkvision", 0.0), 0.0))
						if dv > 0.0:
							sight_enabled = true
							sight_range = dv
							sight_angle = 360.0
				if sight_enabled:
					var vision_radius_world: float = (maxf(0.0, sight_range) / grid_dist) * 64.0
					builder.attach_simple_vision(tok_eid, vision_radius_world, sight_angle, false, true)

		# Lights (never clipped in padding/negative region)
		var lights: Array = sc.get("lights", []) if sc.get("lights", null) is Array else []
		for lt_idx: int in range(lights.size()):
			if _is_cancelled(session):
				return {"ok": false, "reason": "cancelled"}
			if entity_count >= _MAX_ENTITIES:
				if not entity_cap_warned:
					entity_cap_warned = true
					_warn(session, "世界实体总数达到宿主上限 %d，后续实体已截断" % _MAX_ENTITIES)
				break
			if not (lights[lt_idx] is Dictionary):
				continue
			var lt: Dictionary = lights[lt_idx] as Dictionary
			var lt_hidden: bool = _coerce_bool(lt.get("hidden", false), false)
			if not include_hidden and lt_hidden:
				continue
			var lt_center := Vector2(
				clampf(clampf(_to_float(lt.get("x", 0.0), 0.0), -1e15, 1e15) * scene_scale, -1e15, 1e15),
				clampf(clampf(_to_float(lt.get("y", 0.0), 0.0), -1e15, 1e15) * scene_scale, -1e15, 1e15)
			)
			var lt_size := Vector2(
				clampf(maxf(4.0, 32.0 * scene_scale), 4.0, 1e15),
				clampf(maxf(4.0, 32.0 * scene_scale), 4.0, 1e15)
			)
			var lt_eid: String = builder.add_object_sprite(
				"scene:%s:light:%s:%d" % [sc_id, str(lt.get("id", "")), lt_idx],
				"Light",
				lt_center,
				lt_size,
				"",
				0.0,
				Vector2.ONE,
				lt_hidden,
				"",
				false
			)
			if not lt_eid.is_empty():
				entity_count += 1
				_suppress_light_fallback_box(builder, lt_eid)
				var max_range: float = maxf(0.0, maxf(_to_float(lt.get("bright", 0.0), 0.0), _to_float(lt.get("dim", 0.0), 0.0)))
				var lt_radius_world: float = (max_range / grid_dist) * 64.0
				var raw_lt_angle: float = _to_float(lt.get("angle", 360.0), 360.0)
				var lt_angle: float = 360.0 if (not is_finite(raw_lt_angle) or raw_lt_angle <= 0.0 or raw_lt_angle >= 360.0) else raw_lt_angle
				builder.attach_simple_light(lt_eid, lt_radius_world, lt_angle, not lt_hidden)

	# Resolve sprite refs for all imported actors
	var actor_sprite_refs: Dictionary = {}
	for i: int in range(actors.size()):
		if _is_cancelled(session):
			return {"ok": false, "reason": "cancelled"}
		var act: Dictionary = actors[i] as Dictionary
		var key: String = actor_keys[i]
		var primary_ref: String = str(act.get("token_img_ref", ""))
		if primary_ref.is_empty():
			primary_ref = str(act.get("img_ref", ""))
		var sprite_path: String = ""
		if not primary_ref.is_empty():
			var a_res: Dictionary = assets_helper.resolve_sprite_ref(
				primary_ref,
				assets_map.get(primary_ref, {}),
				source,
				host,
				session,
				options
			)
			if not bool(a_res.get("ok", false)):
				return a_res
			sprite_path = str(a_res.get("sprite_path", ""))
		actor_sprite_refs[key] = sprite_path

	# If no scenes imported (0 scenes or import_scenes == false) and actors non-empty, lay out cleanly on Floor 0 "1F"
	if effective_scenes.is_empty() and not actors.is_empty():
		builder.set_active_floor(floor0_uid)
		var cols: int = maxi(1, int(ceil(sqrt(float(actors.size())))))
		var spacing: float = world_source_units_per_cell * 1.5
		for i: int in range(actors.size()):
			if _is_cancelled(session):
				return {"ok": false, "reason": "cancelled"}
			if entity_count >= _MAX_ENTITIES:
				if not entity_cap_warned:
					entity_cap_warned = true
					_warn(session, "世界实体总数达到宿主上限 %d，后续实体已截断" % _MAX_ENTITIES)
				break
			var act: Dictionary = actors[i] as Dictionary
			var key: String = actor_keys[i]
			var sprite_path: String = str(actor_sprite_refs.get(key, ""))
			var col_idx: int = i % cols
			var row_idx: int = i / cols
			var pos_src := Vector2(float(col_idx) * spacing + spacing * 0.5, float(row_idx) * spacing + spacing * 0.5)
			var tok_w: float = clampf(maxf(0.1, _to_float(act.get("token_width", 1.0), 1.0)), 0.1, 16384.0) * world_source_units_per_cell
			var tok_h: float = clampf(maxf(0.1, _to_float(act.get("token_height", 1.0), 1.0)), 0.1, 16384.0) * world_source_units_per_cell
			var size_src := Vector2(maxf(4.0, tok_w), maxf(4.0, tok_h))
			var sval: float = clampf(maxf(0.1, _to_float(act.get("token_scale", 1.0), 1.0)), 0.1, 1000.0)
			var tscale := Vector2(sval, sval)
			var size_world: Vector2 = size_src * tscale * source_to_world
			var fp_r: float = clampf(minf(size_world.x, size_world.y) * 0.5, 0.5, 4096.0)
			var is_pc: bool = str(act.get("actor_type", "npc")) == "character" or _coerce_bool(act.get("actor_link", false), false) or _to_int(act.get("disposition", -1), -1) == 1
			var perm_state: Dictionary = {
				"owners_csv": "",
				"gm_can_operate": true,
				"all_players_can_operate": is_pc,
				"owner_peers": PackedInt32Array(),
				"owner_player_ids": PackedStringArray(),
			}
			var aname: String = str(act.get("name", "")).strip_edges()
			if aname.is_empty():
				aname = "Unit"
			var eid: String = builder.add_token(
				"actor:%s" % key,
				aname,
				pos_src,
				size_src,
				sprite_path,
				0.0,
				tscale,
				false,
				fp_r,
				false,
				perm_state
			)
			if not eid.is_empty():
				entity_count += 1
				builder.attach_unit_marker(eid)
				var senses_d: Dictionary = act.get("senses", {}) if act.get("senses", null) is Dictionary else {}
				var dv: float = maxf(0.0, _to_float(senses_d.get("darkvision", 0.0), 0.0))
				if dv > 0.0:
					builder.attach_simple_vision(eid, (dv / 5.0) * 64.0, 360.0, false, true)

	# Restore active floor before writing modules
	builder.set_active_floor(active_floor_uid)

	# Write world.modules: grid_alignment (8 exact keys)
	if not effective_scenes.is_empty():
		var has_square: bool = false
		for sc_sq: Dictionary in effective_scenes:
			if _to_int(sc_sq.get("grid_type", 1), 1) == 1:
				has_square = true
				break
		var ga_state: Dictionary = {
			"schema": "fus.grid_alignment.config",
			"version": 1,
			"cell_size": clampf(64.0, 8.0, 4096.0),
			"offset": [0.0, 0.0],
			"color": [0.5, 0.55, 0.65, 0.7],
			"line_width": 1.0,
			"snap_enabled": has_square,
			"snap_strength": 0.1,
		}
		builder.set_module_state("grid_alignment", 1, ga_state)

	# Write world.modules: fvtt_world_importer with progressive 6/8/30 MiB budget trimming
	var world_meta_clean: Dictionary = {
		"id": str(world_meta.get("id", "")),
		"title": str(world_meta.get("title", "")),
		"core_version": str(world_meta.get("core_version", "")),
		"system": str(world_meta.get("system", "")),
		"system_version": str(world_meta.get("system_version", "")),
		"source_kind": str(world_meta.get("source_kind", "")),
	}
	var written_module: bool = false
	for trim_level: int in range(3):
		var archive_actors: Array = _build_actor_archive_list(actors, actor_keys, actor_sprite_refs, trim_level)
		var mod_state: Dictionary = {
			"world": world_meta_clean,
			"actors": archive_actors,
		}
		if _modules_within_budget(builder, mod_state):
			if trim_level == 1:
				_warn(session, "world.modules 体积超出预算，已裁剪角色/怪物传记文本")
			elif trim_level == 2:
				_warn(session, "world.modules 体积超出预算，已裁剪角色/怪物扩展属性摘要")
			written_module = builder.set_module_state("fvtt_world_importer", 1, mod_state)
			break
	if not written_module:
		_warn(session, "世界或模块体积接近上限，已省略可选 fvtt_world_importer 档案模块")

	# 4-gate entity-library registration
	var world_id_str: String = str(world_meta.get("id", "fvtt_world"))
	var lib_res: Dictionary = _register_entity_library(
		world_id_str,
		actors,
		actor_keys,
		actor_sprite_refs,
		host,
		session,
		register_entity_library
	)
	if not bool(lib_res.get("ok", false)):
		return {"ok": false, "reason": str(lib_res.get("reason", "cancelled"))}

	return {
		"ok": true,
		"source_records": source_records,
		"merged_walls": merged_walls,
		"registered_library_count": int(lib_res.get("count", 0)),
	}
