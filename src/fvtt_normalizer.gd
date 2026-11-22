extends RefCounted


static func _coerce_bool(value: Variant, fallback: bool) -> bool:
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


static func _is_num(v: Variant) -> bool:
	if v == null:
		return false
	var t: int = typeof(v)
	if t == TYPE_INT:
		return true
	if t == TYPE_FLOAT:
		return is_finite(float(v))
	return false


static func _to_float(v: Variant, fallback: float = 0.0) -> float:
	if _is_num(v):
		return float(v)
	if v is String:
		var s: String = str(v).strip_edges()
		if s.is_valid_float():
			var f: float = s.to_float()
			if is_finite(f):
				return f
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


static func _try_num_to_int(v: Variant) -> Variant:
	if not _is_num(v):
		return null
	if v is int:
		return int(v)
	var fv: float = float(v)
	if fv >= -9223372036854775808.0 and fv < 9223372036854775808.0:
		return int(fv)
	return null


static func _to_int(v: Variant, fallback: int = 0) -> int:
	var num_int: Variant = _try_num_to_int(v)
	if num_int != null:
		return int(num_int)
	if _is_num(v):
		return fallback
	if v is String:
		var s: String = str(v).strip_edges()
		var parsed_i64: Variant = _parse_int64_str(s)
		if parsed_i64 != null:
			return int(parsed_i64)
		if s.is_valid_int():
			return fallback
		if s.is_valid_float():
			var f: float = s.to_float()
			if is_finite(f) and f >= -9223372036854775808.0 and f < 9223372036854775808.0:
				return int(f)
	return fallback


static func _parse_cr(v: Variant) -> float:
	if _is_num(v):
		return maxf(0.0, float(v))
	if v is String:
		var s: String = str(v).strip_edges()
		if s.is_empty():
			return 0.0
		if s.contains("/"):
			var parts: PackedStringArray = s.split("/", false)
			if parts.size() == 2 and parts[0].strip_edges().is_valid_float() and parts[1].strip_edges().is_valid_float():
				var denom: float = parts[1].strip_edges().to_float()
				if absf(denom) > 1e-9:
					var ratio: float = parts[0].strip_edges().to_float() / denom
					if is_finite(ratio):
						return maxf(0.0, ratio)
		if s.is_valid_float():
			var f: float = s.to_float()
			if is_finite(f):
				return maxf(0.0, f)
	return 0.0


static func _is_ascii_alpha(code: int) -> bool:
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


static func _strip_html(html_text: String) -> String:
	if html_text.is_empty():
		return ""
	var cleaned_html: String = html_text
	var rx_block := RegEx.new()
	if rx_block.compile("(?is)<(script|style)(?:\\s[^>]*)?>.*?</\\1\\s*>") == OK:
		cleaned_html = rx_block.sub(cleaned_html, " ", true)

	var out: String = ""
	var n: int = cleaned_html.length()
	var i: int = 0
	while i < n:
		var ch: String = cleaned_html[i]
		if ch == "<":
			if cleaned_html.substr(i, 4) == "<!--":
				var cend: int = cleaned_html.find("-->", i + 4)
				if cend >= 0:
					out += " "
					i = cend + 3
					continue
				out += "<"
				i += 1
				continue
			var is_tag_start: bool = false
			if i + 1 < n:
				var c1: int = cleaned_html.unicode_at(i + 1)
				if _is_ascii_alpha(c1) or c1 == 33 or c1 == 63:
					is_tag_start = true
				elif c1 == 47 and i + 2 < n and _is_ascii_alpha(cleaned_html.unicode_at(i + 2)):
					is_tag_start = true
			if is_tag_start:
				var j: int = i + 1
				var quote: String = ""
				var close_idx: int = -1
				var aborted: bool = false
				while j < n:
					var cj: String = cleaned_html[j]
					if quote.is_empty():
						if cj == "\"" or cj == "'":
							quote = cj
						elif cj == "<":
							aborted = true
							break
						elif cj == ">":
							close_idx = j
							break
					else:
						if cj == quote:
							quote = ""
					j += 1
				if not aborted and close_idx >= 0:
					out += " "
					i = close_idx + 1
					continue
			out += "<"
			i += 1
		else:
			out += ch
			i += 1

	out = out.replace("&amp;", "&")
	out = out.replace("&lt;", "<")
	out = out.replace("&gt;", ">")
	out = out.replace("&quot;", "\"")
	out = out.replace("&#39;", "'")
	out = out.replace("&apos;", "'")
	out = out.replace("&nbsp;", " ")
	out = out.replace("&rsquo;", "'")
	out = out.replace("&lsquo;", "'")
	out = out.replace("&ldquo;", "\"")
	out = out.replace("&rdquo;", "\"")
	out = out.replace("&mdash;", "-")
	out = out.replace("&ndash;", "-")

	var lines: PackedStringArray = out.replace("\r\n", "\n").replace("\r", "\n").split("\n", false)
	var clean_parts: Array[String] = []
	for line: String in lines:
		var words: PackedStringArray = line.split(" ", false)
		var joined: String = " ".join(words).strip_edges()
		if not joined.is_empty():
			clean_parts.append(joined)
	return " ".join(clean_parts).strip_edges()


static func _eval_simple_int_expr(expr: String) -> Variant:
	var compact: String = expr.replace(" ", "").replace("\t", "")
	if compact.is_empty():
		return null
	for i: int in range(compact.length()):
		var c: int = compact.unicode_at(i)
		if not ((c >= 48 and c <= 57) or c == 43 or c == 45):
			return null
	var total: int = 0
	var idx: int = 0
	var n: int = compact.length()
	while idx < n:
		var sign: int = 1
		while idx < n and (compact[idx] == "+" or compact[idx] == "-"):
			if compact[idx] == "-":
				sign = -sign
			idx += 1
		if idx >= n:
			return null
		var start_num: int = idx
		while idx < n:
			var cc: int = compact.unicode_at(idx)
			if cc >= 48 and cc <= 57:
				idx += 1
			else:
				break
		if idx == start_num:
			return null
		var num_str: String = compact.substr(start_num, idx - start_num)
		var signed_str: String = ("-" + num_str) if sign < 0 else num_str
		var parsed_term: Variant = _parse_int64_str(signed_str)
		if parsed_term == null:
			return null
		var term: int = int(parsed_term)
		if term > 0 and total > 9223372036854775807 - term:
			return null
		if term < 0 and total < (-9223372036854775807 - 1) - term:
			return null
		total += term
	return total


static func _extract_str(d: Dictionary, key: String, fallback: String = "") -> String:
	var v: Variant = d.get(key, null)
	if v is String:
		return str(v)
	return fallback


static func _pick_non_null(
	primary: Dictionary,
	primary_key: String,
	fallback: Dictionary,
	fallback_key: String,
	default_val: Variant
) -> Variant:
	var v1: Variant = primary.get(primary_key, null)
	if v1 != null:
		return v1
	var v2: Variant = fallback.get(fallback_key, null)
	if v2 != null:
		return v2
	return default_val


static func _extract_src_field(container: Dictionary, key: String) -> String:
	var v: Variant = container.get(key, null)
	if v is String:
		return str(v)
	if v is Dictionary:
		var src: Variant = (v as Dictionary).get("src", null)
		if src is String:
			return str(src)
	return ""


static func _resolve_folder_path(folder_id: Variant, raw_folders: Dictionary) -> String:
	if not (folder_id is String) or str(folder_id).is_empty():
		return ""
	var cur_id: String = str(folder_id)
	var visited: Dictionary = {}
	var parts: Array[String] = []
	while not cur_id.is_empty() and raw_folders.has(cur_id):
		if visited.has(cur_id):
			break
		visited[cur_id] = true
		var fdoc: Dictionary = raw_folders[cur_id]
		var fname: String = _extract_str(fdoc, "name", "").strip_edges()
		if not fname.is_empty():
			parts.append(fname)
		var next_id: String = _extract_str(fdoc, "folder", "").strip_edges()
		if next_id.is_empty():
			next_id = _extract_str(fdoc, "parent", "").strip_edges()
		cur_id = next_id
	parts.reverse()
	return "/".join(parts)


static func _compute_actor_ac(sys: Dictionary, items: Array, dex_mod: int) -> int:
	var attrs: Dictionary = sys.get("attributes", {}) if sys.get("attributes", null) is Dictionary else {}
	var ac: Dictionary = attrs.get("ac", {}) if attrs.get("ac", null) is Dictionary else {}

	var ov_var: Variant = _try_num_to_int(ac.get("override", null))
	if ov_var != null:
		return int(ov_var)

	var calc_raw: Variant = ac.get("calc", null)
	var calc_str: String = str(calc_raw).strip_edges().to_lower() if calc_raw is String else ""
	var calcs_arr: Array[String] = []
	var calcs_raw: Variant = ac.get("calcs", null)
	if calcs_raw is Array:
		for ce: Variant in calcs_raw:
			if ce is String:
				var cs: String = str(ce).strip_edges().to_lower()
				if not cs.is_empty():
					calcs_arr.append(cs)

	var flat_allowed: bool = false
	if not calc_str.is_empty():
		flat_allowed = (calc_str == "flat" or calc_str == "natural")
	else:
		flat_allowed = (
			calcs_arr.is_empty()
			or ("natural" in calcs_arr)
			or ("flat" in calcs_arr)
		)

	var flat_var: Variant = _try_num_to_int(ac.get("flat", null))
	if flat_allowed and flat_var != null:
		return int(flat_var)

	var has_armor: bool = false
	var armor_base: int = 0
	var best_eff_dex: int = dex_mod
	var best_armor_total: int = -999999
	var shield_bonus: int = 0

	for item_var: Variant in items:
		if not (item_var is Dictionary):
			continue
		var item: Dictionary = item_var
		if str(item.get("type", "")).strip_edges().to_lower() != "equipment":
			continue
		var isys: Dictionary = {}
		if item.get("system", null) is Dictionary:
			isys = item["system"]
		elif item.get("data", null) is Dictionary:
			isys = item["data"]

		var equipped: bool = _coerce_bool(_pick_non_null(isys, "equipped", item, "equipped", false), false)
		if not equipped:
			continue

		var armor_dict: Dictionary = isys.get("armor", {}) if isys.get("armor", null) is Dictionary else {}
		var atype: String = ""
		if isys.get("type", null) is Dictionary:
			atype = _extract_str(isys["type"], "value", "").strip_edges().to_lower()
		if atype.is_empty():
			atype = _extract_str(armor_dict, "type", "").strip_edges().to_lower()

		var aval: int = _to_int(armor_dict.get("value", 0), 0) + _to_int(armor_dict.get("magicalBonus", 0), 0)
		if atype == "shield":
			shield_bonus = maxi(shield_bonus, aval)
		elif atype in ["light", "medium", "heavy", "natural"]:
			var candidate_dex_cap: Variant = null
			var dex_raw: Variant = _try_num_to_int(armor_dict.get("dex", null))
			if dex_raw != null:
				candidate_dex_cap = int(dex_raw)
			elif atype == "medium":
				candidate_dex_cap = 2
			elif atype == "heavy":
				candidate_dex_cap = 0
			var candidate_eff_dex: int = dex_mod if candidate_dex_cap == null else mini(dex_mod, int(candidate_dex_cap))
			if (atype == "heavy" or (candidate_dex_cap != null and int(candidate_dex_cap) == 0)) and candidate_eff_dex < 0:
				candidate_eff_dex = 0
			var candidate_total: int = aval + candidate_eff_dex
			if not has_armor or candidate_total > best_armor_total:
				has_armor = true
				armor_base = aval
				best_eff_dex = candidate_eff_dex
				best_armor_total = candidate_total

	var eff_dex: int = best_eff_dex if has_armor else dex_mod
	var base_armor: int = armor_base if has_armor else 10
	var computed: int = base_armor + eff_dex + shield_bonus

	if calc_str == "custom" or ("custom" in calcs_arr):
		var candidate_formulas: Array[String] = []
		var f_single: Variant = ac.get("formula", null)
		if f_single is String and not str(f_single).strip_edges().is_empty():
			candidate_formulas.append(str(f_single).strip_edges())
		var f_list: Variant = ac.get("formulas", null)
		if f_list is Array:
			for f_item: Variant in f_list:
				if f_item is String and not str(f_item).strip_edges().is_empty():
					candidate_formulas.append(str(f_item).strip_edges())
		for formula: String in candidate_formulas:
			var sub_expr: String = formula
			sub_expr = sub_expr.replace("@attributes.ac.armor", str(base_armor))
			sub_expr = sub_expr.replace("@attributes.ac.dex", str(eff_dex))
			sub_expr = sub_expr.replace("@attributes.ac.shield", str(shield_bonus))
			var eval_res: Variant = _eval_simple_int_expr(sub_expr)
			if eval_res != null:
				return int(eval_res)

	return computed


static func _group_sublevel_by_parent(sublevel_container: Variant) -> Dictionary:
	var grouped: Dictionary = {}
	if sublevel_container is Dictionary:
		var sdict: Dictionary = sublevel_container
		for k_var: Variant in sdict.keys():
			var rec_key: String = str(k_var)
			var doc_var: Variant = sdict[k_var]
			if not (doc_var is Dictionary):
				continue
			var dot: int = rec_key.rfind(".")
			var parent_id: String = rec_key.substr(0, dot) if dot > 0 else ""
			if parent_id.is_empty():
				parent_id = _extract_str(doc_var as Dictionary, "parent", "")
			if parent_id.is_empty():
				continue
			if not grouped.has(parent_id):
				grouped[parent_id] = []
			(grouped[parent_id] as Array).append(doc_var)
	elif sublevel_container is Array:
		for doc_var2: Variant in sublevel_container:
			if not (doc_var2 is Dictionary):
				continue
			var p_id: String = _extract_str(doc_var2 as Dictionary, "parent", "")
			if p_id.is_empty():
				continue
			if not grouped.has(p_id):
				grouped[p_id] = []
			(grouped[p_id] as Array).append(doc_var2)
	return grouped


static func _pick_child_docs(parent_doc: Dictionary, field: String, sublevel_by_parent: Dictionary, parent_id: String) -> Array:
	var embedded: Variant = parent_doc.get(field, null)
	if embedded is Array:
		var dict_items: Array = []
		for el: Variant in (embedded as Array):
			if el is Dictionary:
				dict_items.append(el)
		if not dict_items.is_empty():
			return dict_items
	return sublevel_by_parent.get(parent_id, [])


static func _register_asset(
	raw_ref: String,
	world_id: String,
	source: RefCounted,
	assets: Dictionary,
	warnings: Array[String],
	unsupported_refs: Dictionary
) -> String:
	var trimmed: String = raw_ref.strip_edges()
	if trimmed.is_empty():
		return ""
	var resolved: Dictionary = {}
	if source != null and source.has_method("resolve_asset_ref"):
		var res_var: Variant = source.resolve_asset_ref(trimmed, world_id)
		if res_var is Dictionary:
			resolved = res_var
	else:
		var low: String = trimmed.to_lower()
		if low.begins_with("http://") or low.begins_with("https://"):
			resolved = {"kind": "remote", "rel_path": "", "url": trimmed, "exists": true, "unsafe": false, "ext": ""}
		else:
			resolved = {"kind": "local", "rel_path": trimmed, "url": "", "exists": false, "unsafe": false, "ext": trimmed.get_extension().to_lower()}

	var kind_var: Variant = resolved.get("kind", "empty")
	var kind: String = str(kind_var) if kind_var is String else "empty"
	if kind == "empty":
		return ""

	var sk_var: Variant = source.get_source_kind() if (source != null and source.has_method("get_source_kind")) else ""
	var source_kind: String = str(sk_var) if sk_var is String else ""
	var ext_var: Variant = resolved.get("ext", "")
	var ext: String = str(ext_var).to_lower() if ext_var is String else ""
	var is_unsafe: bool = (kind == "unsafe" or _coerce_bool(resolved.get("unsafe", false), false))
	var is_unsupported_ext: bool = (ext == "gif")

	var logical_ref: String = ""
	var resolved_path_or_url: String = ""
	var external_or_missing: bool = false

	if kind == "remote":
		var url_var: Variant = resolved.get("url", trimmed)
		logical_ref = str(url_var) if url_var is String else trimmed
		resolved_path_or_url = logical_ref
		source_kind = "remote"
		external_or_missing = true
	elif is_unsafe:
		logical_ref = trimmed
		resolved_path_or_url = ""
		external_or_missing = true
		if not unsupported_refs.has(logical_ref):
			unsupported_refs[logical_ref] = true
			warnings.append("已拦截不安全资源引用：" + logical_ref)
	else:
		var rel_var: Variant = resolved.get("rel_path", trimmed)
		logical_ref = str(rel_var) if rel_var is String else trimmed
		resolved_path_or_url = logical_ref
		external_or_missing = not _coerce_bool(resolved.get("exists", false), false)

	if is_unsupported_ext and not unsupported_refs.has(logical_ref):
		unsupported_refs[logical_ref] = true
		warnings.append("检测到不支持的 GIF 图片格式：" + logical_ref)

	if not assets.has(logical_ref):
		assets[logical_ref] = {
			"kind": kind,
			"source_kind": source_kind,
			"resolved_path_or_url": resolved_path_or_url,
			"external_or_missing": external_or_missing,
			"unsupported_ext": is_unsupported_ext,
			"unsafe": is_unsafe,
			"ext": ext,
		}
	return logical_ref


func normalize(
	world_json: Variant = {},
	collections: Variant = {},
	source: RefCounted = null,
	options: Variant = {},
	session: RefCounted = null
) -> Dictionary:
	if not (world_json is Dictionary):
		return {"ok": false, "reason": "invalid_world_json"}
	if not (collections is Dictionary):
		return {"ok": false, "reason": "missing_required_collections"}
	var wj: Dictionary = world_json
	var cols: Dictionary = collections
	var opts: Dictionary = options if (options is Dictionary) else {}

	var import_scenes: bool = _coerce_bool(opts.get("import_scenes", true), true)
	var import_characters: bool = _coerce_bool(opts.get("import_characters", true), true)
	var import_monsters: bool = _coerce_bool(opts.get("import_monsters", true), true)
	var include_hidden: bool = _coerce_bool(opts.get("include_hidden", true), true)
	var download_remote_assets: bool = _coerce_bool(opts.get("download_remote_assets", true), true)

	var scenes_col: Dictionary = cols.get("scenes", {}) if cols.get("scenes", null) is Dictionary else {}
	var actors_col: Dictionary = cols.get("actors", {}) if cols.get("actors", null) is Dictionary else {}
	var folders_col: Dictionary = cols.get("folders", {}) if cols.get("folders", null) is Dictionary else {}

	var scenes_ok: bool = _coerce_bool(scenes_col.get("ok", false), false)
	var actors_ok: bool = _coerce_bool(actors_col.get("ok", false), false)
	if not scenes_ok and not actors_ok:
		return {"ok": false, "reason": "missing_required_collections"}

	var warnings: Array[String] = []
	if source != null and source.has_method("get_warnings"):
		var src_warnings: Variant = source.get_warnings()
		if src_warnings is Array:
			for sw: Variant in src_warnings:
				warnings.append(str(sw))
	var col_parse_errors: int = 0
	for w_col: Variant in [scenes_col, actors_col, folders_col]:
		if w_col is Dictionary:
			var col_dict: Dictionary = w_col
			col_parse_errors += _to_int(col_dict.get("parse_errors", 0), 0)
			var col_warnings: Variant = col_dict.get("warnings", [])
			if col_warnings is Array:
				for wm: Variant in col_warnings:
					warnings.append(str(wm))

	if not scenes_ok:
		warnings.append("未找到 scenes 集合，将按空场景列表导入")
	if not actors_ok:
		warnings.append("未找到 actors 集合，将按空角色/怪物列表导入")

	var world_id: String = _extract_str(wj, "id", "").strip_edges()
	if world_id.is_empty():
		world_id = _extract_str(wj, "name", "").strip_edges()
	if world_id.is_empty():
		world_id = "fvtt_world"
	var world_title: String = _extract_str(wj, "title", "").strip_edges()
	if world_title.is_empty():
		world_title = world_id
	var core_version: String = _extract_str(wj, "coreVersion", "").strip_edges()
	if core_version.is_empty():
		core_version = _extract_str(wj, "version", "").strip_edges()
	if core_version.is_empty():
		core_version = _extract_str(wj, "compatibleCoreVersion", "").strip_edges()
	var system_id: String = _extract_str(wj, "system", "").strip_edges()
	var system_version: String = _extract_str(wj, "systemVersion", "").strip_edges()
	var sk_var: Variant = source.get_source_kind() if (source != null and source.has_method("get_source_kind")) else ""
	var source_kind: String = str(sk_var) if sk_var is String else ""

	var assets: Dictionary = {}
	var unsupported_refs: Dictionary = {}
	var world_bg_ref: String = _register_asset(
		_extract_str(wj, "background", ""),
		world_id,
		source,
		assets,
		warnings,
		unsupported_refs
	)

	var world_meta: Dictionary = {
		"id": world_id,
		"title": world_title,
		"core_version": core_version,
		"system": system_id,
		"system_version": system_version,
		"source_kind": source_kind,
		"background_ref": world_bg_ref,
	}

	# Folders
	var raw_folders: Dictionary = {}
	var folder_docs: Array = folders_col.get("docs", []) if folders_col.get("docs", null) is Array else []
	for f_var: Variant in folder_docs:
		if f_var is Dictionary:
			var fdoc: Dictionary = f_var
			var fid: String = _extract_str(fdoc, "_id", "")
			if not fid.is_empty():
				raw_folders[fid] = fdoc

	# Actors (MUST normalize ALL actors before import_characters / import_monsters filtering)
	var actor_docs: Array = actors_col.get("docs", []) if actors_col.get("docs", null) is Array else []
	var actors_sublevels: Dictionary = actors_col.get("sublevels", {}) if actors_col.get("sublevels", null) is Dictionary else {}
	var items_by_actor: Dictionary = _group_sublevel_by_parent(actors_sublevels.get("actors.items", {}))

	var all_actors: Array[Dictionary] = []
	var actor_by_id: Dictionary = {}
	var total_actor_items: int = 0

	for a_var: Variant in actor_docs:
		if not (a_var is Dictionary):
			continue
		var adoc: Dictionary = a_var
		var aid: String = _extract_str(adoc, "_id", "")
		var aname: String = _extract_str(adoc, "name", "").strip_edges()
		if aname.is_empty():
			aname = "Unnamed Actor"
		var raw_type: String = _extract_str(adoc, "type", "npc").strip_edges().to_lower()
		var actor_type: String = "character" if raw_type == "character" else "npc"

		var sys: Dictionary = {}
		if adoc.get("system", null) is Dictionary:
			sys = adoc["system"]
		elif adoc.get("data", null) is Dictionary:
			sys = adoc["data"]

		var actor_items: Array = _pick_child_docs(adoc, "items", items_by_actor, aid)
		total_actor_items += actor_items.size()

		var raw_abs: Dictionary = sys.get("abilities", {}) if sys.get("abilities", null) is Dictionary else {}
		var abilities: Dictionary = {}
		for ab_key: String in ["str", "dex", "con", "int", "wis", "cha"]:
			var ab_obj: Dictionary = raw_abs.get(ab_key, {}) if raw_abs.get(ab_key, null) is Dictionary else {}
			var ab_val: int = _to_int(ab_obj.get("value", 10), 10)
			var ab_mod_var: Variant = _try_num_to_int(ab_obj.get("mod", null))
			var ab_mod: int = int(ab_mod_var) if ab_mod_var != null else int(floor((float(ab_val) - 10.0) / 2.0))
			abilities[ab_key] = {"value": ab_val, "mod": ab_mod}

		var dex_mod: int = int((abilities["dex"] as Dictionary)["mod"])
		var ac: int = _compute_actor_ac(sys, actor_items, dex_mod)

		var attrs: Dictionary = sys.get("attributes", {}) if sys.get("attributes", null) is Dictionary else {}
		var hp_obj: Dictionary = attrs.get("hp", {}) if attrs.get("hp", null) is Dictionary else {}
		var hp_max: int = _to_int(hp_obj.get("max", 0), 0)
		var hp_val_var: Variant = _try_num_to_int(hp_obj.get("value", null))
		var hp_value: int = int(hp_val_var) if hp_val_var != null else hp_max
		var hp_temp: int = _to_int(hp_obj.get("temp", 0), 0)

		var details: Dictionary = sys.get("details", {}) if sys.get("details", null) is Dictionary else {}
		var cr_or_level: float = 0.0
		var class_summary_parts: Array[String] = []
		if actor_type == "character":
			var lvl_var: Variant = _try_num_to_int(details.get("level", null))
			if lvl_var != null:
				cr_or_level = float(int(lvl_var))
			else:
				var lvl_sum: int = 0
				for it_var: Variant in actor_items:
					if not (it_var is Dictionary):
						continue
					var it: Dictionary = it_var
					if str(it.get("type", "")).strip_edges().to_lower() == "class":
						var isys: Dictionary = it.get("system", {}) if it.get("system", null) is Dictionary else (it.get("data", {}) if it.get("data", null) is Dictionary else {})
						var clvl: int = _to_int(isys.get("levels", 0), 0)
						lvl_sum += clvl
						var cname: String = _extract_str(it, "name", "").strip_edges()
						if not cname.is_empty():
							class_summary_parts.append("%s %d" % [cname, clvl])
				cr_or_level = float(lvl_sum)
		else:
			cr_or_level = _parse_cr(details.get("cr", 0))

		var sub_type: String = ""
		var dtype_var: Variant = details.get("type", null)
		if dtype_var is Dictionary:
			var dtype: Dictionary = dtype_var
			var dval: String = _extract_str(dtype, "value", "").strip_edges().to_lower()
			var dcust: String = _extract_str(dtype, "custom", "").strip_edges().to_lower()
			if dval == "vehicle" or dcust.contains("vehicle"):
				sub_type = "vehicle"
			elif not dval.is_empty():
				sub_type = dval
		elif dtype_var is String:
			sub_type = str(dtype_var).strip_edges().to_lower()

		var mov: Dictionary = attrs.get("movement", {}) if attrs.get("movement", null) is Dictionary else {}
		var mov_src: Dictionary = mov.get("speeds", {}) if mov.get("speeds", null) is Dictionary else mov
		var speed: Dictionary = {
			"walk": _to_float(mov_src.get("walk", 0.0), 0.0),
			"fly": _to_float(mov_src.get("fly", 0.0), 0.0),
			"swim": _to_float(mov_src.get("swim", 0.0), 0.0),
			"climb": _to_float(mov_src.get("climb", 0.0), 0.0),
			"burrow": _to_float(mov_src.get("burrow", 0.0), 0.0),
			"units": _extract_str(mov, "units", "ft"),
		}
		if str(speed["units"]).is_empty():
			speed["units"] = "ft"

		var sen: Dictionary = attrs.get("senses", {}) if attrs.get("senses", null) is Dictionary else {}
		var sen_src: Dictionary = sen.get("ranges", {}) if sen.get("ranges", null) is Dictionary else sen
		var senses: Dictionary = {
			"darkvision": _to_float(sen_src.get("darkvision", 0.0), 0.0),
			"blindsight": _to_float(sen_src.get("blindsight", 0.0), 0.0),
			"tremorsense": _to_float(sen_src.get("tremorsense", 0.0), 0.0),
			"truesight": _to_float(sen_src.get("truesight", 0.0), 0.0),
			"units": _extract_str(sen, "units", "ft"),
		}
		if str(senses["units"]).is_empty():
			senses["units"] = "ft"

		var bio_raw: String = ""
		if details.get("biography", null) is Dictionary:
			bio_raw = _extract_str(details["biography"], "value", "")
		elif details.get("biography", null) is String:
			bio_raw = str(details["biography"])
		var biography: String = _strip_html(bio_raw)

		var folder_name: String = _resolve_folder_path(adoc.get("folder", null), raw_folders)

		var ptok: Dictionary = {}
		if adoc.get("prototypeToken", null) is Dictionary:
			ptok = adoc["prototypeToken"]
		elif adoc.get("token", null) is Dictionary:
			ptok = adoc["token"]

		var raw_actor_img: String = _extract_str(adoc, "img", "")
		var raw_tok_img: String = _extract_src_field(ptok, "texture")
		if raw_tok_img.is_empty():
			raw_tok_img = _extract_str(ptok, "img", "")
		if raw_tok_img.is_empty():
			raw_tok_img = raw_actor_img

		var img_ref: String = _register_asset(raw_actor_img, world_id, source, assets, warnings, unsupported_refs)
		var token_img_ref: String = _register_asset(raw_tok_img, world_id, source, assets, warnings, unsupported_refs)

		var token_width: float = maxf(0.1, _to_float(ptok.get("width", 1.0), 1.0))
		var token_height: float = maxf(0.1, _to_float(ptok.get("height", 1.0), 1.0))
		var token_scale: float = 1.0
		if ptok.get("texture", null) is Dictionary and _is_num((ptok["texture"] as Dictionary).get("scaleX", null)):
			token_scale = _to_float((ptok["texture"] as Dictionary).get("scaleX", 1.0), 1.0)
		elif _is_num(ptok.get("scale", null)):
			token_scale = _to_float(ptok.get("scale", 1.0), 1.0)
		if token_scale <= 0.0:
			token_scale = 1.0

		var disposition: int = _to_int(ptok.get("disposition", 1 if actor_type == "character" else -1), 1 if actor_type == "character" else -1)
		var actor_link: bool = _coerce_bool(ptok.get("actorLink", actor_type == "character"), actor_type == "character")

		var norm_actor: Dictionary = {
			"id": aid,
			"name": aname,
			"actor_type": actor_type,
			"sub_type": sub_type,
			"folder_name": folder_name,
			"img_ref": img_ref,
			"token_img_ref": token_img_ref,
			"token_width": token_width,
			"token_height": token_height,
			"token_scale": token_scale,
			"disposition": disposition,
			"actor_link": actor_link,
			"ac": ac,
			"hp_value": hp_value,
			"hp_max": hp_max,
			"hp_temp": hp_temp,
			"cr_or_level": cr_or_level,
			"abilities": abilities,
			"speed": speed,
			"senses": senses,
			"biography": biography,
			"raw_summary": {
				"classes": class_summary_parts,
				"sub_type": sub_type,
				"folder": folder_name,
			},
		}
		all_actors.append(norm_actor)
		if not aid.is_empty():
			actor_by_id[aid] = norm_actor

	# Scenes
	var scene_docs: Array = scenes_col.get("docs", []) if scenes_col.get("docs", null) is Array else []
	var scenes_sublevels: Dictionary = scenes_col.get("sublevels", {}) if scenes_col.get("sublevels", null) is Dictionary else {}
	var levels_by_scene: Dictionary = _group_sublevel_by_parent(scenes_sublevels.get("scenes.levels", {}))
	var walls_by_scene: Dictionary = _group_sublevel_by_parent(scenes_sublevels.get("scenes.walls", {}))
	var lights_by_scene: Dictionary = _group_sublevel_by_parent(scenes_sublevels.get("scenes.lights", {}))
	var tiles_by_scene: Dictionary = _group_sublevel_by_parent(scenes_sublevels.get("scenes.tiles", {}))
	var tokens_by_scene: Dictionary = _group_sublevel_by_parent(scenes_sublevels.get("scenes.tokens", {}))

	var all_scenes: Array[Dictionary] = []
	var inv_levels: int = 0
	var inv_walls: int = 0
	var inv_doors: int = 0
	var inv_lights: int = 0
	var inv_tiles: int = 0
	var inv_tokens: int = 0
	var inv_notes: int = 0
	var inv_drawings: int = 0
	var inv_hidden: int = 0

	for s_var: Variant in scene_docs:
		if not (s_var is Dictionary):
			continue
		var sdoc: Dictionary = s_var
		var sid: String = _extract_str(sdoc, "_id", "")
		var sname: String = _extract_str(sdoc, "name", "").strip_edges()
		if sname.is_empty():
			sname = "Unnamed Scene"
		var s_hidden: bool = _coerce_bool(sdoc.get("hidden", false), false)
		if s_hidden:
			inv_hidden += 1

		var width: float = maxf(1.0, _to_float(sdoc.get("width", 3000.0), 3000.0))
		var height: float = maxf(1.0, _to_float(sdoc.get("height", 2100.0), 2100.0))
		var padding: float = maxf(0.0, _to_float(sdoc.get("padding", 0.0), 0.0))
		var shift_x: float = _to_float(sdoc.get("shiftX", 0.0), 0.0)
		var shift_y: float = _to_float(sdoc.get("shiftY", 0.0), 0.0)

		var grid_size: float = 100.0
		var grid_type: int = 1
		var grid_distance: float = 5.0
		var grid_units: String = "ft"
		if sdoc.get("grid", null) is Dictionary:
			var gdict: Dictionary = sdoc["grid"]
			grid_size = _to_float(gdict.get("size", 100.0), 100.0)
			grid_type = _to_int(gdict.get("type", 1), 1)
			grid_distance = _to_float(gdict.get("distance", 5.0), 5.0)
			grid_units = _extract_str(gdict, "units", "ft")
		else:
			grid_size = _to_float(sdoc.get("grid", 100.0), 100.0)
			grid_type = _to_int(sdoc.get("gridType", 1), 1)
			grid_distance = _to_float(sdoc.get("gridDistance", 5.0), 5.0)
			grid_units = _extract_str(sdoc, "gridUnits", "ft")
		if grid_size <= 0.0 or not is_finite(grid_size):
			grid_size = 0.0
		else:
			grid_size = clampf(grid_size, 1.0, 1e6)
		if grid_distance <= 0.0:
			grid_distance = 5.0
		if grid_units.is_empty():
			grid_units = "ft"

		var raw_pad_w: float = width * padding
		var pad_w: float = (ceil(raw_pad_w / grid_size) * grid_size) if (padding > 0.0 and grid_size > 0.0) else round(raw_pad_w)
		if not is_finite(pad_w):
			pad_w = 0.0
		var raw_pad_h: float = height * padding
		var pad_h: float = (ceil(raw_pad_h / grid_size) * grid_size) if (padding > 0.0 and grid_size > 0.0) else round(raw_pad_h)
		if not is_finite(pad_h):
			pad_h = 0.0
		var scene_x: float = pad_w + shift_x
		if not is_finite(scene_x):
			scene_x = shift_x if is_finite(shift_x) else 0.0
		var scene_y: float = pad_h + shift_y
		if not is_finite(scene_y):
			scene_y = shift_y if is_finite(shift_y) else 0.0

		# Level selection for v14 background / foreground
		var scene_levels: Array = _pick_child_docs(sdoc, "levels", levels_by_scene, sid)
		inv_levels += scene_levels.size()
		var chosen_level: Dictionary = {}
		if not scene_levels.is_empty():
			var init_id: String = _extract_str(sdoc, "initialLevel", "")
			if init_id.is_empty() and sdoc.get("levels", null) is Array and not (sdoc["levels"] as Array).is_empty():
				var first_l: Variant = (sdoc["levels"] as Array)[0]
				if first_l is String:
					init_id = str(first_l)
				elif first_l is Dictionary:
					init_id = _extract_str(first_l as Dictionary, "_id", "")
			for lv_var: Variant in scene_levels:
				if lv_var is Dictionary and _extract_str(lv_var as Dictionary, "_id", "") == init_id:
					chosen_level = lv_var
					break
			if chosen_level.is_empty() and scene_levels[0] is Dictionary:
				chosen_level = scene_levels[0]

		var raw_bg: String = ""
		if not chosen_level.is_empty():
			raw_bg = _extract_src_field(chosen_level, "background")
		if raw_bg.is_empty():
			raw_bg = _extract_src_field(sdoc, "background")
		if raw_bg.is_empty():
			raw_bg = _extract_str(sdoc, "img", "")
		var background_ref: String = _register_asset(raw_bg, world_id, source, assets, warnings, unsupported_refs)

		var raw_fg: String = ""
		if not chosen_level.is_empty():
			raw_fg = _extract_src_field(chosen_level, "foreground")
		if raw_fg.is_empty():
			raw_fg = _extract_src_field(sdoc, "foreground")
		var foreground_ref: String = _register_asset(raw_fg, world_id, source, assets, warnings, unsupported_refs)

		# Walls
		var raw_walls: Array = _pick_child_docs(sdoc, "walls", walls_by_scene, sid)
		var norm_walls: Array[Dictionary] = []
		for w_var: Variant in raw_walls:
			if not (w_var is Dictionary):
				continue
			var wdoc: Dictionary = w_var
			var c_var: Variant = wdoc.get("c", null)
			if not (c_var is Array) or (c_var as Array).size() < 4:
				continue
			var ca: Array = c_var
			var x0: float = _to_float(ca[0], NAN)
			var y0: float = _to_float(ca[1], NAN)
			var x1: float = _to_float(ca[2], NAN)
			var y1: float = _to_float(ca[3], NAN)
			if (
				not is_finite(x0)
				or not is_finite(y0)
				or not is_finite(x1)
				or not is_finite(y1)
			):
				warnings.append("跳过包含非有限坐标的墙体：" + _extract_str(wdoc, "_id", ""))
				continue
			var door: int = _to_int(wdoc.get("door", 0), 0)
			var ds: int = _to_int(wdoc.get("ds", 0), 0)
			var move_v: int = _to_int(wdoc.get("move", 20), 20)
			var sight_v: int = _to_int(wdoc.get("sight", 20), 20)
			var light_v: int = _to_int(wdoc.get("light", 20), 20)
			var sense_v: int = _to_int(_pick_non_null(wdoc, "sense", wdoc, "sound", 20), 20)
			if door == 1 or door == 2:
				inv_doors += 1
				if door == 2:
					inv_hidden += 1
			else:
				inv_walls += 1
			norm_walls.append({
				"id": _extract_str(wdoc, "_id", ""),
				"c": [x0, y0, x1, y1],
				"door": door,
				"ds": ds,
				"move": move_v,
				"sight": sight_v,
				"light": light_v,
				"sense": sense_v,
			})

		# Lights
		var raw_lights: Array = _pick_child_docs(sdoc, "lights", lights_by_scene, sid)
		var norm_lights: Array[Dictionary] = []
		for lt_var: Variant in raw_lights:
			if not (lt_var is Dictionary):
				continue
			var ltdoc: Dictionary = lt_var
			var lcfg: Dictionary = ltdoc.get("config", {}) if ltdoc.get("config", null) is Dictionary else {}
			var bright: float = maxf(0.0, _to_float(_pick_non_null(lcfg, "bright", ltdoc, "bright", 0.0), 0.0))
			var dim: float = maxf(0.0, _to_float(_pick_non_null(lcfg, "dim", ltdoc, "dim", 0.0), 0.0))
			var angle: float = _to_float(_pick_non_null(lcfg, "angle", ltdoc, "angle", 360.0), 360.0)
			if angle <= 0.0 or angle >= 360.0:
				angle = 360.0
			var l_hidden: bool = _coerce_bool(ltdoc.get("hidden", false), false)
			if l_hidden:
				inv_hidden += 1
			inv_lights += 1
			norm_lights.append({
				"id": _extract_str(ltdoc, "_id", ""),
				"x": _to_float(ltdoc.get("x", 0.0), 0.0),
				"y": _to_float(ltdoc.get("y", 0.0), 0.0),
				"bright": bright,
				"dim": dim,
				"angle": angle,
				"color": _extract_str(lcfg, "color", _extract_str(ltdoc, "tintColor", "#ffffff")),
				"hidden": l_hidden,
			})

		# Tiles
		var raw_tiles: Array = _pick_child_docs(sdoc, "tiles", tiles_by_scene, sid)
		var norm_tiles: Array[Dictionary] = []
		for t_var: Variant in raw_tiles:
			if not (t_var is Dictionary):
				continue
			var tdoc: Dictionary = t_var
			var raw_timg: String = _extract_src_field(tdoc, "texture")
			if raw_timg.is_empty():
				raw_timg = _extract_str(tdoc, "img", "")
			var t_img_ref: String = _register_asset(raw_timg, world_id, source, assets, warnings, unsupported_refs)
			var t_hidden: bool = _coerce_bool(tdoc.get("hidden", false), false)
			if t_hidden:
				inv_hidden += 1
			inv_tiles += 1
			norm_tiles.append({
				"id": _extract_str(tdoc, "_id", ""),
				"img_ref": t_img_ref,
				"x": _to_float(tdoc.get("x", 0.0), 0.0),
				"y": _to_float(tdoc.get("y", 0.0), 0.0),
				"width": maxf(1.0, _to_float(tdoc.get("width", 100.0), 100.0)),
				"height": maxf(1.0, _to_float(tdoc.get("height", 100.0), 100.0)),
				"rotation": _to_float(tdoc.get("rotation", 0.0), 0.0),
				"z_order": _to_int(_pick_non_null(tdoc, "sort", tdoc, "z", 0), 0),
				"hidden": t_hidden,
			})

		# Tokens
		var raw_tokens: Array = _pick_child_docs(sdoc, "tokens", tokens_by_scene, sid)
		var norm_tokens: Array[Dictionary] = []
		for tok_var: Variant in raw_tokens:
			if not (tok_var is Dictionary):
				continue
			var tokdoc: Dictionary = tok_var
			var tid: String = _extract_str(tokdoc, "_id", "")
			var tname: String = _extract_str(tokdoc, "name", "").strip_edges()
			var actor_id_raw: Variant = tokdoc.get("actorId", null)
			var actor_id: String = str(actor_id_raw).strip_edges() if actor_id_raw is String else ""

			var linked_actor: Dictionary = {}
			var actor_missing: bool = false
			var tok_actor_type: String = "npc"
			if not actor_id.is_empty() and actor_by_id.has(actor_id):
				linked_actor = actor_by_id[actor_id]
				tok_actor_type = str(linked_actor.get("actor_type", "npc"))
			else:
				actor_missing = true
				tok_actor_type = "npc"
				warnings.append("场景 %s 棋子 %s 的 actorId 无效或缺失（%s），已保留棋子占位" % [sname, tname if not tname.is_empty() else tid, actor_id if not actor_id.is_empty() else "null"])

			if tname.is_empty():
				tname = str(linked_actor.get("name", "Unnamed Token"))

			var raw_tok_src: String = _extract_src_field(tokdoc, "texture")
			if raw_tok_src.is_empty():
				raw_tok_src = _extract_str(tokdoc, "img", "")
			var tok_img_ref: String = ""
			if not raw_tok_src.is_empty():
				tok_img_ref = _register_asset(raw_tok_src, world_id, source, assets, warnings, unsupported_refs)
			elif not linked_actor.is_empty():
				tok_img_ref = str(linked_actor.get("token_img_ref", ""))

			var tw: float = maxf(0.1, _to_float(_pick_non_null(tokdoc, "width", linked_actor, "token_width", 1.0), 1.0))
			var th: float = maxf(0.1, _to_float(_pick_non_null(tokdoc, "height", linked_actor, "token_height", 1.0), 1.0))
			var tscale: float = 1.0
			if tokdoc.get("texture", null) is Dictionary and _is_num((tokdoc["texture"] as Dictionary).get("scaleX", null)):
				tscale = _to_float((tokdoc["texture"] as Dictionary).get("scaleX", 1.0), 1.0)
			elif _is_num(tokdoc.get("scale", null)):
				tscale = _to_float(tokdoc.get("scale", 1.0), 1.0)
			if tscale <= 0.0:
				tscale = 1.0

			var sight_enabled: bool = false
			var sight_range: float = 0.0
			var sight_angle: float = 360.0
			if tokdoc.get("sight", null) is Dictionary:
				var sdict: Dictionary = tokdoc["sight"]
				sight_enabled = _coerce_bool(sdict.get("enabled", false), false)
				sight_range = maxf(0.0, _to_float(sdict.get("range", 0.0), 0.0))
				sight_angle = _to_float(sdict.get("angle", 360.0), 360.0)
			else:
				sight_enabled = _coerce_bool(tokdoc.get("vision", false), false)
				sight_range = maxf(0.0, maxf(_to_float(tokdoc.get("dimSight", 0.0), 0.0), _to_float(tokdoc.get("brightSight", 0.0), 0.0)))
				sight_angle = _to_float(tokdoc.get("sightAngle", 360.0), 360.0)
			if sight_angle <= 0.0 or sight_angle >= 360.0:
				sight_angle = 360.0

			var tok_hidden: bool = _coerce_bool(tokdoc.get("hidden", false), false)
			if tok_hidden:
				inv_hidden += 1
			inv_tokens += 1

			var default_disp: int = _to_int(linked_actor.get("disposition", -1), -1) if not linked_actor.is_empty() else -1
			var tok_disp: int = _to_int(_pick_non_null(tokdoc, "disposition", linked_actor, "disposition", default_disp), default_disp)
			var tok_link: bool = _coerce_bool(_pick_non_null(tokdoc, "actorLink", linked_actor, "actor_link", false), false)

			norm_tokens.append({
				"id": tid,
				"name": tname,
				"actor_id": actor_id,
				"actor_type": tok_actor_type,
				"actor_missing": actor_missing,
				"img_ref": tok_img_ref,
				"x": _to_float(tokdoc.get("x", 0.0), 0.0),
				"y": _to_float(tokdoc.get("y", 0.0), 0.0),
				"width": tw,
				"height": th,
				"scale": tscale,
				"rotation": _to_float(tokdoc.get("rotation", 0.0), 0.0),
				"hidden": tok_hidden,
				"disposition": tok_disp,
				"actor_link": tok_link,
				"sight_enabled": sight_enabled,
				"sight_range": sight_range,
				"sight_angle": sight_angle,
			})

		if sdoc.get("notes", null) is Array:
			inv_notes += (sdoc["notes"] as Array).size()
		if sdoc.get("drawings", null) is Array:
			inv_drawings += (sdoc["drawings"] as Array).size()

		all_scenes.append({
			"id": sid,
			"name": sname,
			"active": _coerce_bool(sdoc.get("active", false), false),
			"width": width,
			"height": height,
			"padding": padding,
			"shift_x": shift_x,
			"shift_y": shift_y,
			"scene_x": scene_x,
			"scene_y": scene_y,
			"grid_size": grid_size,
			"grid_type": grid_type,
			"grid_distance": grid_distance,
			"grid_units": grid_units,
			"background_ref": background_ref,
			"foreground_ref": foreground_ref,
			"hidden": s_hidden,
			"folder_name": _resolve_folder_path(sdoc.get("folder", null), raw_folders),
			"tiles": norm_tiles,
			"walls": norm_walls,
			"lights": norm_lights,
			"tokens": norm_tokens,
		})

	# Option-filtered scenes & actors for downstream mapper
	var filtered_scenes: Array[Dictionary] = []
	var selected_tiles_count: int = 0
	var selected_lights_count: int = 0
	var selected_dangling_tokens_count: int = 0
	var selected_image_refs: Dictionary = {}

	if import_scenes and not world_bg_ref.is_empty():
		var wbg_meta: Dictionary = assets.get(world_bg_ref, {})
		if not _coerce_bool(wbg_meta.get("unsupported_ext", false), false) and not _coerce_bool(wbg_meta.get("unsafe", false), false):
			if download_remote_assets or str(wbg_meta.get("kind", "")) != "remote":
				selected_image_refs[world_bg_ref] = true

	if import_scenes:
		for sc: Dictionary in all_scenes:
			if not include_hidden and bool(sc.get("hidden", false)):
				continue
			var f_tiles: Array[Dictionary] = []
			for t: Dictionary in sc["tiles"]:
				if not include_hidden and bool(t.get("hidden", false)):
					continue
				f_tiles.append(t)
				selected_tiles_count += 1
				var tref: String = str(t.get("img_ref", ""))
				if not tref.is_empty():
					selected_image_refs[tref] = true

			var f_lights: Array[Dictionary] = []
			for lt: Dictionary in sc["lights"]:
				if not include_hidden and bool(lt.get("hidden", false)):
					continue
				f_lights.append(lt)
				selected_lights_count += 1

			var f_walls: Array[Dictionary] = []
			for w: Dictionary in sc["walls"]:
				if not include_hidden and int(w.get("door", 0)) == 2:
					continue
				f_walls.append(w)

			var f_tokens: Array[Dictionary] = []
			for tok: Dictionary in sc["tokens"]:
				if not include_hidden and bool(tok.get("hidden", false)):
					continue
				var ttype: String = str(tok.get("actor_type", "npc"))
				if ttype == "character" and not import_characters:
					continue
				if ttype != "character" and not import_monsters:
					continue
				f_tokens.append(tok)
				if bool(tok.get("actor_missing", false)):
					selected_dangling_tokens_count += 1
				var tok_ref: String = str(tok.get("img_ref", ""))
				if not tok_ref.is_empty():
					selected_image_refs[tok_ref] = true

			var bg_r: String = str(sc.get("background_ref", ""))
			if not bg_r.is_empty():
				selected_image_refs[bg_r] = true
			var fg_r: String = str(sc.get("foreground_ref", ""))
			if not fg_r.is_empty():
				selected_image_refs[fg_r] = true

			var f_sc: Dictionary = sc.duplicate(false)
			f_sc["tiles"] = f_tiles
			f_sc["lights"] = f_lights
			f_sc["walls"] = f_walls
			f_sc["tokens"] = f_tokens
			filtered_scenes.append(f_sc)

	var filtered_actors: Array[Dictionary] = []
	var selected_char_count: int = 0
	var selected_npc_count: int = 0
	for act: Dictionary in all_actors:
		var atype: String = str(act.get("actor_type", "npc"))
		if atype == "character":
			if not import_characters:
				continue
			selected_char_count += 1
		else:
			if not import_monsters:
				continue
			selected_npc_count += 1
		filtered_actors.append(act)
		for aref_key: String in ["img_ref", "token_img_ref"]:
			var aref: String = str(act.get(aref_key, ""))
			if not aref.is_empty():
				selected_image_refs[aref] = true

	var valid_selected_image_count: int = 0
	for sref_var: Variant in selected_image_refs.keys():
		var sref: String = str(sref_var)
		var ameta: Dictionary = assets.get(sref, {})
		if _coerce_bool(ameta.get("unsupported_ext", false), false) or _coerce_bool(ameta.get("unsafe", false), false):
			continue
		if not download_remote_assets and str(ameta.get("kind", "")) == "remote":
			continue
		valid_selected_image_count += 1

	var remote_assets: Dictionary = {}
	if download_remote_assets:
		for ak_var: Variant in assets.keys():
			var ak: String = str(ak_var)
			var am: Dictionary = assets[ak]
			if str(am.get("kind", "")) == "remote":
				remote_assets[ak] = 1

	var total_records: int = (
		all_scenes.size()
		+ inv_levels
		+ inv_walls
		+ inv_doors
		+ inv_lights
		+ inv_tiles
		+ inv_tokens
		+ inv_notes
		+ inv_drawings
		+ all_actors.size()
		+ total_actor_items
		+ folder_docs.size()
	)

	var inspect_counts: Dictionary = {
		"records": total_records,
		"images": assets.size(),
		"selected_images": valid_selected_image_count,
		"maps": filtered_scenes.size() if import_scenes else 0,
		"characters": selected_char_count if import_characters else 0,
		"objects": (selected_npc_count + selected_dangling_tokens_count if import_monsters else 0) + (selected_tiles_count + selected_lights_count if import_scenes else 0),
		"text": inv_notes,
		"drawings": inv_drawings,
		"walls": inv_walls,
		"doors": inv_doors,
		"hidden": inv_hidden,
		"unsupported": unsupported_refs.size() + col_parse_errors,
	}

	if session != null and session.has_method("add_warning"):
		for w_out: String in warnings:
			session.add_warning(w_out)

	return {
		"ok": true,
		"model": {
			"world_meta": world_meta,
			"scenes": filtered_scenes,
			"actors": filtered_actors,
			"assets": assets,
			"warnings": warnings,
			"inspect_counts": inspect_counts,
			"remote_assets": remote_assets,
			"source_records": total_records,
		},
	}
