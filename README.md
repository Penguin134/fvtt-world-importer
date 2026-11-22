# `fvtt-world-importer` 详细实现方案与技术设计文档

> **目标运行时**：Fu VTT 现役 `Practice` 主线（`fus.session-plugin.v1`，`host_api = 1`，`scope = "session"`，`Godot Engine v4.8.beta1.mono` + `.NET 10 CoreCLR`）  
> **插件标识**：目录 `mods/fvtt-world-importer/`｜清单 ID `fvtt_world_importer`｜入口 `entry.gd`  
> **适用范围**：通用 Foundry VTT（FVTT v9–v14，NeDB 与 LevelDB）世界包导入（`.zip` 归档与已解压目录 `world.json`），以 `bgdia` 作为主要实证基准样本；当前范围映射 **场景**、**角色卡资源** 与 **怪物资源**（不将法术、装备作为独立 Fu VTT 资源导出）。

---

## 1. 实证依据与 Fu VTT 现役能力边界矩阵

### 1.1 实证基线与只读来源索引

本文档全部 Fu VTT 宿主契约、存储约束与 SDK 行为均直接核实自以下基线（零臆造 API、零混用已废弃 `FUS-F2` 分支 `f2.feature_plugin.v1`）：

| 实证来源 | 版本 / 标识 | 核实内容 |
| :--- | :--- | :--- |
| 官方源码只读库 | `<FUS_REPO_DIR>@282aee64`（`origin/codex/fuvtt-project-sync`，`v0.0.56`） | `ImportBridge`、`PluginPackageJob*.cs`、`SharedAssetStore.cs`、`EntityLibraryJob`/`EntityLibraryStore`、`WorldSnapshot`、`ObstacleShapes`、`FobrWallKernel`、`ImageHeader`、`CampaignImageFiles`、`grid_config.gd`、`simple_fog` |
| Steam Playtest 客户端 | `v0.0.57`（Commit `3f20e8e`，`2026-11-20`） | 内嵌 PCK 行为对齐与 `fus.session-plugin.v1` 主线一致性 |
| Monorepo 共享文档 | `shared/docs/{plugin-lifecycle,desktop-and-scene-api,macro-and-rules,playtest-notes}.md` | 生命周期校验、图层/ECS 18 组件图谱、障碍物烘焙、双线隔离约束 |
| Monorepo 防腐层 SDK | `shared/sdk/fu_sdk/v1.gd`（`SDK_VERSION = "1.1.0"`）及 `adapters/host_v1_adapter.gd` | `ImportSession`、`WorldBuilder`、实体不变量守卫与待修复缺口 |
| 本地工具链 | `shared/tools/fuvtt_devtools/{validator,packager,host_verifier}.py` | 静态门禁、ZIP 排除规则、`MockHostBridge` / `headless_probe.gd` 行为 |
| FVTT 实证样本 | `<FVTT_WORLD_DIR>`（v14.369 / `dnd5e 6.0.6` 迁移版）与 `<FVTT_WORLD_ZIP>`（v9.269 / `dnd5e 1.6.3` 原版） | LevelDB/Snappy/WAL 字节格式、NeDB、`bgdia` 31 场景 / 229 演员 / 3857 墙体 / 131 光源 / 227 瓦片 / 618 棋子特例 |

### 1.2 现役能力与硬边界对照矩阵

| 领域 | 现役支持能力（Verified Supported） | 明确边界 / 限制（Verified Boundaries） | 本插件应对策略 |
| :--- | :--- | :--- | :--- |
| **插件入口与运行时** | `fus.session-plugin.v1` 后台线程瞬态 `RefCounted`；`inspect_import(path, options, host)` 与 `prepare_import(path, options, host)` | 无 `FILE_MODE_OPEN_DIR` 目录选择器；无桌面运行时 UI、自定义宏、斜杠命令、第三方 `.pck` 或 `ISteamUGC` | 声明 `import_extensions: ["zip", "json"]`（用户选 `.zip` 或目录内 `world.json`）；纯离线生成 `.world` |
| **宿主会话桥接 (`ImportBridge`)** | `empty_world()`、`cancelled()`、`report()`、`warn()`、`begin_preview()`、`preview_entity()`、`finish_geometry_preview()`、`archive_image(url, proxy)`、`host.root`、`host.destination` | 1. `archive_image` 仅支持 `http://`/`https://`；<br>2. `ImportBridge.inspect()` / `run()` 无条件用文件名覆盖活动名（选择 `world.json` 时固定命名为 `"world"`）；<br>3. `ImportBridge.inspect()` 把 `result.assets` 全部键传给 `ProbeAssets` 并覆盖 `unique_images = result.assets.size()`；<br>4. `ImportBridge.run()` 硬编码 `metadata.module_choices = []` | 1. 本地/ZIP 图片直走 `SharedAssetStore.Publish`（或 `verify-host` 哈希回退）；<br>2. `inspect_import()` 在 `download_remote_assets == true` 时仅将 `http`/`https` 放进 `assets`（`false` 时 `assets = {}` 避免 `ProbeAssets` 卡顿），本地图只计入 `counts.images`；<br>3. `prepare_import()` 发出非致命提醒并在 `world.modules` 与楼层名保留真实 `world.title`；<br>4. 文档明确提示 `grid_alignment`/`simple_fog` 需 GM 在战役设置启用 |
| **防腐层 SDK (`FuSdk` / `WorldBuilder`)** | `create_session`、`create_world_builder`、`add_floor`、`set_active_floor`、`add_layer`、`begin_bounds_preview`、`finish_geometry_preview`、`add_map_tile`、`add_token`、`add_object_sprite`、`add_wall`/`door`/`window`/`glass_wall`/`air_cutout`、`add_text_note`/`pin`、`add_vector_drawing`、`attach_unit_marker`、`attach_simple_vision`/`light`、`set_module_state`、`build_result` | 与 `v1.1.0` 实测发现的 5 项 SDK/Adapter 缺口：<br>1. `host_v1_adapter.gd:27,167` 使用 `ALLOWED_RES_IMAGE_EXTENSIONS = ["png","jpg","jpeg","webp","svg"]` 校验 `asset://`——错拒 `.bmp`、错放 `.svg`；<br>2. `host_v1_adapter.gd:267-272` (`build_inspect_ok`) 遗漏 `import_confirmation.gd:62` 必读的 `source_bytes` 与 `decoded_bytes`；<br>3. `v1.gd:156-157` 当传入 `archive_remote_image` 的 `proxy` 为 `""` 且 `_options.has("proxy")` 时，会执行 `str(_options.get("proxy", ""))` 把 `null` 转为 `"Null"`；<br>4. `WorldBuilder` 缺少 `rename_floor()`，而 `empty_world()` 固定预建 `"1F"`（Floor 0）；<br>5. `host_v1_adapter.gd:1013` `find_entity_by_id()` 每次 `attach_*` 做 `O(N)` 线性扫描 | **M4 推荐修复 `fu_sdk`**：拆分 `ALLOWED_ASSET_IMAGE_EXTENSIONS = ["png","jpg","jpeg","webp","bmp"]`、在 `build_inspect_ok` 补齐 `source_bytes`/`decoded_bytes`、安全强转 `proxy`、新增 `WorldBuilder.rename_floor()`。同时插件侧**双保险兜底**：统一将 `.bmp`/`.svg` 转为 `.png`，在 `entry.gd` 显式注入 `source_bytes`/`decoded_bytes`/`name`/`unique_images`，并在调用 `sdk.create_session(host, clean_options)` **前**先完成 `proxy` 与布尔选项的安全强转 |
| **图片校验与资产库 (`SharedAssetStore` / `ImageHeader`)** | `ImageHeader` 支持 `png`/`jpg`/`webp`/`bmp`（`MAX_SIDE = 32768`，`MAX_PIXELS = 134217728`）；`SharedAssetStore.Publish(dir, ref, bytes)` 返回 JSON 字符串，支持跨战役硬链接去重 | 1. 宿主与 Godot `Image` 均**不支持 `.gif`**；<br>2. `CampaignImageFiles` 与 `SharedAssetStore.Publish` 不接受 `.svg`（实机 `import_bridge.gd` 栅格化为 `.png`）；<br>3. `SharedAssetStore.Publish` 校验 `RootFor(dir)`（须为 `sessions/桌面 ..._<32hex>`）与 `SHA256(bytes)`；<br>4. `verify-host` 的 `MockHostBridge` 无 `destination`/`root` 且不存在 `SharedAssetStore.cs` | 魔数 + `ImageHeader` 前置预检（杜绝 Godot `ERROR:` 日志）；`.bmp`/`.svg` 转 `.png`；`.gif` 记警告降级（或 `skip_missing_assets=false` 中止）；运行时嗅探 `SharedAssetStore.cs` + `host.destination`，测试/探针回退仅计算 `asset://<sha256>.<ext>` |
| **世界/图层/实体与几何烘焙** | `1..512` 楼层、`1..256` 图层/层（`<= 4096` 总图层）、`MAX_ENTITIES = 10000`、`32 MiB` `.world` 上限、`world.modules`（`<= 128` 项、单项 `<= 6 MiB`、总计 `<= 8 MiB`）；`ObstacleShapes` 自动注入 `comp_obstacle.gd` 并用 `FobrWallKernel` 做布尔切割 | `z_index` 严格为 `0`；`components[0..1]` 严格为 `[comp_visual, comp_permission]`；`entity_size >= 4x4`；`footprint_radius ∈ [0.5, 4096]`；`comp_unit` 禁止用于 `entity_type == "map"`；`FobrWallKernel.AuthorReadPaths` 读 `vector_drawing.paths` 并要求每环 `>= 3` 顶点且 `|Area| >= 1e-12`（`ClipperD Precision = 6`） | 2 点 FVTT 墙体全部挤出为 4 顶点矩形（半宽 `half_w >= maxf(4.0, grid * 0.06)`），过滤 `< 0.5` px / `< 1e-3` 退化线段；严格遵守先提交几何并 `finish_geometry_preview()`，再写地图与棋子 |
| **角色卡与怪物资源能力边界** | `BoardToken`（`entity_type = "unit"` + `comp_unit` + `comp_simple_vision`/`light`）；`world.modules` 结构化档案保存；`EntityLibraryJob` / `EntityLibraryStore`（`OpenLibrary`/`ReadLibraryRecords`/`WriteLibraryRecord`/`AdoptLibraryAsset`/`ShareLibraryAsset`）写入 `<root>/entity-library/` 可复用的 `folder`/`unit`/`preset` 记录 | 1. 现役 `Practice` 18 个组件中**无原生 Character Sheet / Monster Statblock / Bestiary 表单组件**；<br>2. `scenes/candidates/*`（含 `comp_entity_note`、`comp_initiative`、`comp_resource_pool`、`comp_scene_box`）在宿主中为候选/停放组件（`EntityStateCodec.prepare()` / `parked: true` 语义）；<br>3. `MaterializeLibraryAsset` 与缩略图预览读取 `<root>/entity-library/assets/`（仅 `Publish` 到会话目录不够，必须 `AdoptLibraryAsset`） | 角色与怪物统一映射为 `unit` 棋子 + 紧凑归档至 `world.modules`；仅当 `SharedAssetStore.cs`、`host.root`、`host.destination` 校验全满足且开关开启时才安全写入 `entity-library`（并链式传递 `.revision`），测试环境零污染真实用户目录 |
| **可选内置模块 (`grid_alignment` / `simple_fog`)** | `grid_alignment`（8 键精确配置，`cell_size ∈ [8, 4096]`）与 `simple_fog`（`comp_simple_vision`/`light`）均为现役内置可选模块 | `grid_alignment` 为**全局单一方格网格**（不支持六边形/逐楼层独立尺寸），且因 `module_choices = []` 导入后默认关闭，需 GM 手动开启 | 取主方格场景校准 `grid_alignment` 写入 `world.modules`；同时写入棋子与光源的 `simple_fog` 组件，并在提醒中说明需 GM 开启 |

---

## 2. 双输入源解析与 `plugin.json` 配置映射设计

### 2.1 `.zip` 归档与已解压目录（`world.json`）双输入解析规则

宿主 `plugin_import.gd:83` 仅校验扩展名是否在 `import_extensions: ["zip", "json"]` 内，因此在进入 `entry.gd` 时可能传入任意 `.zip` 或非 `world.json` 的 `.json` 文件（如 `gateway.json`）。`src/fvtt_source.gd` 统一抽象两类输入：

1. **输入源判定与快速拒绝**：
   - 若 `path.get_extension().to_lower() == "json"`：
     - 严格要求 `path.get_file().to_lower() == "world.json"`，否则 `fvtt_source.open()` 立即返回 `{ok: false, reason: "请选择 FVTT 世界清单文件 world.json（当前：%s）" % path.get_file()}`（由 `entry.gd` 包装为 `session.err_failed(...)`）。
     - 以 `path.get_base_dir()` 作为虚拟根路径（`source_kind = "dir"`）。
   - 若 `path.get_extension().to_lower() == "zip"`：
     - 使用 Godot `ZIPReader` 打开（实测对中文 CJK 路径如 `<FVTT_WORLD_ZIP>` 返回 `OK`）。若 `open(path) != OK`，立即返回失败。
     - 过滤噪声条目：跳过目录条目（以 `/` 结尾）、路径任一段为 `__MACOSX`、basename 为 `.DS_Store` 或以 `._` 开头的 AppleDouble 元数据（`bgdia` 压缩包中含 2,805 条 `__MACOSX/` 与 `._*`）。
     - **注意 `ZIPReader` 大小写敏感**：建立两层索引表：
       - `exact_entries`：规范化 `/` 路径集合；
       - `lower_to_exact`：全小写路径 → 原始 ZIP 条目路径映射，用于处理 FVTT 资产引用与文件系统大小写差异。
     - **`world.json` 根目录探测（仅允许深度 0 或深度 1）**：
       - 优先检查深度 0：`world.json`（不区分大小写命中唯一项则 `root_prefix = ""`）；
       - 否则检查所有深度 1 条目 `<dir>/world.json`：若恰好 1 个，设 `root_prefix = "<dir>/"`；若 `0` 个（包括全部位于深度 `>= 2`），拒绝并返回 `"归档内未在根目录或一级子目录找到 world.json"`；若 `> 1` 个，拒绝并返回 `"归档包含多个候选 world.json，无法唯一确定世界根目录"`。
2. **清单强校验**：
   - 读取 `world.json` 字节并剥离 UTF-8 BOM（`0xEF 0xBB 0xBF` / `U+FEFF`），调用 `JSON.parse_string()`；
   - 验证结果为 `Dictionary`，且至少具备 FVTT 世界清单特征键：`id` 或 `name`（非空字符串）**且** 包含 `system`、`coreVersion`（或 `version`）、`title` 之一；否则拒绝（拦截任意合法 JSON 伪装成 `world.json`）。
3. **相对路径与 URL 解码解析**：
   - FVTT 常见资产引用格式：
     - `worlds/<world_id>/...`（或直接相对路径如 `scenes/backgrounds/...`）：剥离可选前导 `/` 及 `worlds/<world_id>/`（亦兼容 `world_json.id` 与 `root_name` 不一致时尝试两者），再执行 **percent-decode**（如 `Side%20View%20of%20the%20Scab.webp` → `Side View of the Scab.webp`）。
     - `http://` / `https://`：识别为远端图片引用（`kind = "remote"`）。
     - `systems/...`、`icons/...`、`assets/...`（如 `assets/srd5e/img/BGDIA/...`）：先检查本地包内是否实际附带对应相对路径；若不存在则标记 `kind = "system"`（`exists = false`，缺失系统包引用）。

### 2.2 `plugin.json` 配置映射与变体安全强转

**当前 M1 基线 `plugin.json`（6 项设置）**：

| 设置 `id` | 类型 | 默认值 | 语义与映射影响 |
| :--- | :--- | :--- | :--- |
| `proxy` | `"string"` | `""` | 仅用于 `session.archive_remote_image(url, _proxy)`；`entry.gd` **必须**在调用 `sdk.create_session(host, clean_options)` **前**先构造经 `_coerce_string` + `.strip_edges()` 清洗的 `clean_options`，否则当传入 `proxy = ""` 且原 `options` 含 `proxy: null` 时，`v1.gd:156-157` 仍会回读原 `_options` 并把 `null` 转为 `"Null"` |
| `import_scenes` | `"bool"` | `true` | 控制是否创建场景楼层、底图、瓦片、墙体门窗、光源与全局网格 |
| `import_characters` | `"bool"` | `true` | 控制是否导入 `type == "character"` 演员（含场景内对应棋子与资源登记） |
| `import_monsters` | `"bool"` | `true` | 控制是否导入 `type == "npc"` 演员（含载具/战车等特化 NPC 与无主/游离棋子） |
| `include_hidden` | `"bool"` | `true` | 控制是否导入 FVTT `hidden: true` 的瓦片、棋子、隐藏墙体/秘密门（`door == 2`）；若为 `false`，跳过这些隐藏对象并在 `inspect` 计入 `hidden` |
| `skip_missing_assets` | `"bool"` | `true` | `true` 时缺失本地文件、系统引用（`assets/srd5e/...`）、离线远端 URL、不支持格式（`.gif`）均记 `session.add_warning()` 并降级为 `sprite_path = ""` 占位色块；`false` 时直接中止返回 `err_failed` |

**M4 计划新增设置（总计 `8 <= 32`，严格仅用 `"bool"`/`"string"`，M2 阶段保持 M1 `plugin.json` 不变）**：

| 计划新增 `id` | 类型 | 默认值 | 设计原因 |
| :--- | :--- | :--- | :--- |
| `register_entity_library` | `"bool"` | `true` | 允许用户在实机客户端控制是否同步将导入的角色与怪物（含未放置到任何场景的演员目录条目）注册到全局 `entity-library` |
| `download_remote_assets` | `"bool"` | `true` | 离线或受限网络下，允许用户跳过 `bgdia` 中多达 217 个外网图片 URL 的下载等待，而不必关闭缺失资源容错 |

**安全强转约束**：`entry.gd` 在 `inspect_import()` 与 `prepare_import()` 入口处必须先构造净化后的 `clean_options` 字典（`proxy` 经 `_coerce_string(val, "").strip_edges()`，所有开关经 `_coerce_bool(val, fallback)`——显式处理 `TYPE_BOOL`/`TYPE_INT`/`TYPE_FLOAT`/`TYPE_STRING` `"true"/"1"/"yes"/"on"` vs `"false"/"0"/"no"/"off"`，拒绝 `NaN`/`null` 误判），**再将其传入 `sdk.create_session(host, clean_options)`**，彻底避免 `v1.gd:156-157` 把 `null` 强转为 `"Null"`。

### 2.3 `inspect_import(path, options, host)` 精确返回契约

对照 `import_bridge.gd:119-151` 与 `import_confirmation.gd:62`：

```gdscript
{
	"ok": true,
	"name": world_title_or_basename, # 实机 ImportBridge 会用 filename 覆盖；verify-host 可读到真实 world.title
	"sha256": FileAccess.get_sha256(path),
	"source_bytes": int,             # 源文件字节数（ZIP 或 world.json）
	"decoded_bytes": int,            # 逻辑世界数据总量估计（ZIP 为已扫描条目解压后字节和；目录为 world.json + 集合 + 本地引用图片字节和）
	"unique_images": int,            # 唯一图片引用总去重数（注：实机 ImportBridge.inspect() 会再被 assets.size() 覆盖）
	"counts": {
		"records": int,              # 有效 FVTT 集合文档总数（scenes + actors + folders + 场景子文档）
		"images": int,               # 检测到的全部唯一图片引用数（本地 + 远端 + 缺失/不支持）
		"selected_images": int,      # 按当前 import_* / include_hidden 开关实际将被处理的可导入图片数
		"maps": int,                 # 场景底图 + 瓦片数（受 import_scenes 控制）
		"characters": int,           # character 演员 + 关联角色棋子数（受 import_characters 控制）
		"objects": int,              # npc/怪物资源 + 棋子 + 独立光源锚点数（受 import_monsters / import_scenes 控制）
		"text": int,                 # 文本注释数（当前为 0 或文本图钉计数）
		"drawings": int,             # 矢量绘图数（当前为 0）
		"walls": int,                # 普通墙体（door == 0）数
		"doors": int,                # 门与秘密门（door in [1, 2]）数
		"hidden": int,               # 被标记 hidden / secret 的条目数
		"unsupported": int,          # 明确不支持的格式（如 .gif）或结构损坏计数
	},
	"assets": {
		# 铁律：仅当 download_remote_assets == true 时放入 http:// 或 https:// URL（值 = 估计字节或 1）；
		# 当 download_remote_assets == false 时必须返回空字典 {}，防止 ImportBridge.inspect() 调用 ProbeAssets 在离线 URL 上卡顿（counts.images 仍统计检测到的全部引用）。
		# 绝不放入本地路径或缺失 system 路径，否则 PluginPackageJob.ProbeAssets 会把本地图错误统计为 unknown_images。
	},
}
```

---

## 3. FVTT v9–v14 世界包二进制与数据结构规范（含 `bgdia` 实证特例）

### 3.1 数据库探测优先级与混合版本兼容性

在 `<FVTT_WORLD_DIR>`（`v14.369` 升级版）中，`data/` **同时存在** 15 个 LevelDB 子目录与 15 个遗留 `.db` 文件（共 16 个不同集合名：14 对同名集合 + 仅 LevelDB 的 `effects/` + 仅 `.db` 的 `sessions.db`），且 actors 内部 **206/229 已迁移至 `dnd5e 6.0.6`，仍有 23/229 保留 v9 子字段形态**（如 `Skeleton` 与 `Scavenger`）。因此解析器与规范化器必须遵守以下两项铁律：

1. **集合读取优先级（逐集合独立判定，不唯 `coreVersion` 单向锁死）**：
   - 若 `fvtt_leveldb.has_collection(source, coll)` 为 `true`（即 `data/<coll>/` 下存在 `CURRENT`、`MANIFEST-*` 或 `*.ldb` / `*.log`），优先使用 **LevelDB** 读取；仅当 `coreVersion < 11` 且 LevelDB 目录无有效数据或不存在时，回退读取 **NeDB** `data/<coll>.db`。
   - 必需集合：`scenes`、`actors`（若两者均完全缺失或无法解析出有效根结构，返回 `err_failed`）；可选集合：`folders`（不存在时视为空目录树）。
2. **逐字段防御性规范化**：`fvtt_normalizer.gd` 不按 `world.json.coreVersion` 做硬分支，而是对每个文档、每个字段按「新版本结构 → 旧版本结构 → 安全默认值」顺序回退。

### 3.2 纯 GDScript LevelDB 解析规范（`src/fvtt_leveldb.gd`）

经对 `bgdia/data/{scenes,actors,folders,settings,...}/` 全部 SSTable 与 Manifest 的逐字节解码核对（100% 匹配 Python 参考器记录数：`!scenes!=31`、`!scenes.levels!=31`、`!scenes.lights!=131`、`!scenes.tiles!=227`、`!scenes.tokens!=618`、`!scenes.tokens.delta!=38`、`!scenes.walls!=3857`、`!actors!=229`、`!actors.items!=1787`、`!actors.effects!=59`、`!actors.items.effects!=29`、`!folders!=62` 存活 / 115 原始条目）：

1. **`CURRENT` 与 `MANIFEST-*` 活性文件解析**：
   - 读取 `data/<coll>/CURRENT`（去掉末尾 `\r\n`），得到活动清单文件名（如 `MANIFEST-000009`）。
   - `MANIFEST-*` 按 **32 KiB WAL 物理分块**（见 3.2.4）重组记录，每条记录为 `VersionEdit`（变长 Tag 为无符号 LEB128 `varint32`）：
     - `1` (`kComparator`)：`varint32 len` + UTF-8 字符串；
     - `2` (`kLogNumber`)：`varint64 file_num`（当前活动 `.log` 编号）；
     - `3` (`kNextFileNumber`)：`varint64`；
     - `4` (`kLastSequence`)：`varint64`；
     - `5` (`kCompactPointer`)：`varint32 level` + `varint32 key_len` + bytes；
     - `6` (`kDeletedFile`)：`varint32 level` + `varint64 file_num`（**实证**：`settings/MANIFEST-000006` 明确发出 `DeletedFile (1,9)` 与 `(2,5)`）；
     - `7` (`kNewFile`)：`varint32 level` + `varint64 file_num` + `varint64 file_size` + `varint32 min_len` + `min_key` + `varint32 max_len` + `max_key`；
     - `9` (`kPrevLogNumber`)：`varint64 file_num`。
   - **降级策略**：若 `CURRENT` 或 `MANIFEST-*` 缺失/截断，回退按文件名排序扫描目录下所有 `*.ldb` 与 `*.log`。
2. **`.ldb` SSTable 二进制布局**：
   - **48 字节 Footer**（位于文件末尾 `buf[len - 48 : len]`）：
     - `metaindex_handle`: `BlockHandle`（`offset: varint64`, `size: varint64`）；
     - `index_handle`: `BlockHandle`（`offset: varint64`, `size: varint64`）；
     - 零填充至第 `40` 字节；
     - 末 8 字节（小端 `uint64`）：Magic **`0xdb4775248b80fb57`**（字节序 `57 fb 80 8b 24 75 47 db`）。
   - **Block 物理封装**（`index_handle` 与所有 Data Block 通用）：
     - `raw = buf[offset : offset + size]`；
     - `ctype = buf[offset + size]`：`0` = 未压缩（`scenes/000008.ldb` 中 8/511 块），`1` = Snappy 压缩（503/511 块）；
     - `masked_crc32c = uint32_le(buf[offset + size + 1 : offset + size + 5])`（Castagnoli 多项式 `0x82F63B78`，`mask(c) = (((c >> 15) | ((c & 0xffffffff) << 17)) + 0xa282ead8) & 0xffffffff`，校验范围为 `buf[offset : offset + size + 1]`，可在解析选项开启或用于坏块诊断）。
   - **Block 内部前缀压缩与 Restart Array**：
     - 末尾 4 字节小端 `uint32`：`num_restarts`；
     - `restarts_offset = len(block) - 4 - 4 * num_restarts`；
     - 从 `pos = 0` 循环至 `pos == restarts_offset`：依次读取 `shared: varint32`、`non_shared: varint32`、`val_len: varint32`、`key_delta[non_shared]`、`value[val_len]`，重建 `key = prev_key.slice(0, shared) + key_delta`；
     - Index Block 的 `value` 为 Data Block 的 `BlockHandle(offset, size)`；Data Block 的 `key` 为 `InternalKey`（长度 `>= 8`），拆分 `user_key = key[:-8]` 与小端 `uint64 tag = uint64_le(key[-8:])`：
       - `value_type = tag & 0xFF`（`0 = Deletion` 墓碑，`1 = Value`）；
       - `sequence = tag >> 8`（56 位序号）。
3. **Snappy 块解压规范（`src/snappy.gd`）**：
   - 开头读取 `uncompressed_length: varint32`（设 `max_output_bytes` 安全上限，默认 `64 MiB`，防止畸形流 OOM）。
   - 循环解析操作字节 `tag`（`kind = tag & 0x03`）：
     - `kind == 0b00`（Literal）：`l6 = tag >> 2`；`l6 < 60` 时 `len = l6 + 1`；`l6 ∈ 60..63` 时读取 `extra = l6 - 59`（`1..4` 字节）小端整数 `len = uint_le + 1`（`bgdia` 实测 `l6 == 60/61` 出现数千次）。
     - `kind == 0b01`（1B 偏移拷贝）：`len = ((tag >> 2) & 0x07) + 4`（`4..11`），`offset = ((tag & 0xE0) << 3) | next_byte`（`1..2047`）。
     - `kind == 0b10`（2B 偏移拷贝）：`len = (tag >> 2) + 1`（`1..64`），`offset = uint16_le`。
     - `kind == 0b11`（4B 偏移拷贝）：`len = (tag >> 2) + 1`（`1..64`），`offset = uint32_le`。
   - **强制重叠自拷贝（RLE）规则**：校验 `offset > 0` 且 `offset <= out_pos` 后，**必须逐字节循环拷贝**（`for i in length: out[out_pos] = out[out_pos - offset]; out_pos += 1`），严禁整块 `slice` 拷贝——`bgdia` 中存在 **645 处** `offset < length` 重叠自拷贝块（仅 `scenes/000008.ldb` 即占 267 处）。最后校验 `out_pos == uncompressed_length`。
4. **`.log` WAL 32 KiB 分帧与 `WriteBatch`**：
   - 按 `32768` 字节对齐读取物理块；块尾不足 `7` 字节则跳过填充至下一块起点。
   - 7 字节头：`checksum: uint32_le`、`length: uint16_le`、`type: uint8`（`0=Zero/EOF, 1=Full, 2=First, 3=Middle, 4=Last`）。重组分片记录后，解析 `WriteBatch`：
     - `[0..8)`: `batch_seq: uint64_le`；`[8..12)`: `count: uint32_le`；
     - 第 `i` 项（`0 .. count-1`）：`op_type: uint8`（`0=Deletion, 1=Value`）、`key_len: varint32`、`user_key`；若 `op_type == 1` 再读 `val_len: varint32` 与 `val_bytes`；赋予 `seq = batch_seq + i`。
   - 遇到尾部截断时安全终止并记录警告，不崩溃。
5. **去重、墓碑与 FVTT `classic-level` 键名空间**：
   - 对全部活动 `.ldb` 与活动 `.log` 记录按 `user_key` 聚合，保留 **`sequence` 最大**者（实证 `folders/000005.ldb` 115 条原始项去重为 62 条存活目录）；若最大 `sequence` 的 `value_type == 0`，则删除该 `user_key`。
   - UTF-8 键结构：`!<sublevel>!<id>`（或复合键 `<parentId>.<childId>`），值为无前置二进制头的纯 UTF-8 JSON 字符串：
     - `scenes`：`!scenes!<sid>`、`!scenes.levels!<sid>.<lid>`（v14 存放 `background.src`/`foreground.src`）、`!scenes.walls!<sid>.<wid>`、`!scenes.lights!<sid>.<lid>`、`!scenes.tiles!<sid>.<tid>`、`!scenes.tokens!<sid>.<tid>`、`!scenes.tokens.delta!<sid>.<tid>`；
     - `actors`：`!actors!<aid>`、`!actors.items!<aid>.<iid>`、`!actors.effects!<aid>.<eid>`、`!actors.items.effects!<aid>.<iid>.<eid>`；
     - `folders`：`!folders!<fid>`。

### 3.3 NeDB JSONL 解析规范（`src/fvtt_nedb.gd`）

- 读取 `data/<coll>.db`（UTF-8，剥离首部 BOM），按 `\n` 逐行解析 JSON 对象。
- 若存在 `{"$$deleted": true, "_id": "<id>"}`（或无 `_id` 的删除行），从内存 `docs_by_id` 移除对应 `_id`。
- 同一 `_id` 后出现记录覆盖先前记录（保留最后有效版本，维持插入/更新顺序）。
- 单行损坏（非法 JSON 或非 Dictionary）时计数 `parse_errors += 1` 并记入 `warnings` 跳过，不中断整表导入。

### 3.4 `scenes` 与 `actors` 规范化细则及 `bgdia` 实证特例（`src/fvtt_normalizer.gd`）

#### A. `scenes` 坐标与字段语义（已由 `bgdia` 31 个场景全部外墙边界验证）
- **背景与前景**：按序探测 `!scenes.levels!<sid>.<initialLevel>`（或首个 level）的 `background.src` / `foreground.src` → `scene.background.src` / `scene.foreground` → v9 `scene.img` / `scene.foreground`；全部路径做 percent-decode（解决 `Side%20View%20of%20the%20Scab.webp`）。
- **网格解析**：兼容 v12–v14 `scene.grid` 字典（`size, type, distance, units`）与 v9–v11 扁平字段（`grid, gridType, gridDistance, gridUnits`）。`grid_type`: `0 = Gridless`, `1 = Square`, `2..5 = Hex`。
- **Padding 与 `shiftX`/`shiftY`**：FVTT 画布将拉伸后的底图置于 `(scene_x, scene_y)`，尺寸为 `(width, height)`（注意：`DMG Ship Layout` 原图 `2288x1613` 被拉伸至 `scene.width=3100, scene.height=2185`，`grid=51, shiftX=23, shiftY=45`）：
  $$\text{pad}_w = \begin{cases} \lceil (W \cdot \text{padding}) / G \rceil \cdot G, & \text{padding} > 0 \land G > 0 \\ \text{round}(W \cdot \text{padding}), & \text{otherwise} \end{cases}$$
  $$\text{scene\_x} = \text{pad}_w + \text{shiftX}, \quad \text{scene\_y} = \text{pad}_h + \text{shiftY}$$
- **画布坐标系子元素**（所有子文档均已在 FVTT 画布像素坐标中，**严禁**对位于 padding 留白区的光源裁剪丢弃，如 `Vanthampur Villa` 6 处、`Dungeon of the Dead Three` 2 处边距光源）：
  - `walls`：`c = [x0, y0, x1, y1]`、`door`（`0` 墙 / `1` 门 / `2` 秘密门）、`ds`（`0` 关 / `1` 开 / `2` 锁）、`move` / `sight` / `light` / `sense`（`0` 不阻挡 / `10` 受限 / `20` 常规）。
  - `lights`：`(x, y)` 为圆心；**v10–v14 读取 `light.config.{bright, dim, angle}` 优先，缺失时回退 v9 顶层 `light.{bright, dim, angle}`**（实证 `bgdia` 解压目录 `131/131` 条 v14 `!scenes.lights!` 均仅存于 `light.config`，顶层无此三键）；`angle <= 0 || angle >= 360` 归一为 `360.0°`（`bgdia` 131/131 v9 光源 `angle == 0`）；`bright` / `dim` 为场景距离单位，Fu VTT 世界半径 = `(maxf(bright, dim) / maxf(0.01, grid_distance)) * 64.0`；`hidden`（v10+ `hidden`，v9 默认 `false`）。
  - `tiles`：`(x, y)` 为左上角，像素尺寸 `(width, height)`，旋转 `rotation`（度 → 弧度），堆叠序 `sort`（v14）或 `z`（v9），`hidden`（注：实证 `Side View of the Scab` 4 块瓦片在 v9→v14 迁移时因 `y` 取整存在 `0.5 px` 舍入差异）。
  - `tokens`：`(x, y)` 为左上角，尺寸 `(token.width * grid_size, token.height * grid_size)`，中心点 `(x + w * 0.5, y + h * 0.5)`；**双版本视觉提取**：优先读取 v14 `token.sight.{enabled, range, angle}`，若缺失则回退 v9 `token.vision == true` 配合 `maxf(dimSight, brightSight)` 与 `sightAngle`（`bgdia` 实测 7/618 枚棋子启用视觉）；**悬空 `actorId` 兜底**：`bgdia` 解压目录（v14 LevelDB）实测有 **5 枚**（全部 `actorId: null`）、`.zip`（v9）有 **2 枚**（1 枚 `actorId: null` + 1 枚 `actorId` 在 `actors.db` 缺失）棋子找不到 `actors` 记录（如 `Death Slaad (Feebleminded)`、`Hiskaal`、`Tormentor`、`Devil's Ride`），必须保留放置并使用 token 自带 `name`、`texture.src`/`img`、`width/height`、`disposition`、内联 `actorData` 记警告。

#### B. `actors`（`character`、`npc` 与 Infernal War Machines）字段规范化
- **内嵌物品聚合**：v9 来自 `actor.items` 数组；v11–v14 从 `!actors.items!<aid>.<iid>` 装配至所属演员，提取 **AC** 与 **职业等级** 后即丢弃（**不导出**法术、装备为独立 Fu VTT 资源）。
- **HP 与属性**：`hp_value` / `hp_max` / `hp_temp`；6 项属性（`str/dex/con/int/wis/cha`）提取 `value`，若缺少 `mod`（v14 `dnd5e 6.0.6` 常省略）则按 `floor((val - 10) / 2.0)` 计算。
- **精确 AC 算法（100% 校验通过 `bgdia` 229 名演员：v14 中 `206` 名迁移至 `ac.calcs` [`104` `["natural"]`、`102` `["unarmored", "armored"]`] + `23` 名保留旧版 `ac.calc` [`14` `"default"`、`8` `"natural"`、`1` `"custom"`]，对应 v9 `112` `natural`、`116` `default`、`1` `custom`；所有数值提取在 GDScript 中必须先校验 `val != null && ((val is int) || (val is float && not is_nan(val)))` 再做 `int(val)`，严禁对 `null` 直接调用 `int()`）**：
  1. 若 `ac.override` 为有效数值（非 `null`）→ 直接返回 `int(ac.override)`；
  2. 规范化 `calc_str = (ac.calc.strip_edges().to_lower() if ac.calc is String else "")` 与 `calcs_arr`（将 `ac.calcs` 中的 `String` 元素转为小写数组，非数组视为空数组 `[]`），判定 `flat_allowed`：
     - 若 `calc_str != ""`：`flat_allowed = (calc_str in ["flat", "natural"])`（屏蔽 `"default"`/`"custom"`/`"mage"` 等残留 `ac.flat`）；
     - 否则（`calc_str == ""`）：`flat_allowed = calcs_arr.is_empty() or ("natural" in calcs_arr) or ("flat" in calcs_arr)`（放行 `dnd5e 6.0.6` `["natural"]`/`["flat"]` 与无模式标记的极简数据，同时拦截 `["unarmored", "armored"]`/`["custom"]`/`["mage"]` 等计算模式下的残留 `ac.flat`）；
     - 若 `flat_allowed` 且 `ac.flat` 为有效数值（非 `null`）→ 返回 `int(ac.flat)`（若 `ac.flat == null`，不崩溃，继续走第 3–5 步回退）；
  3. 遍历 `item.type == "equipment"` 且 `equipped == true` 的物品：
     - 护甲子类型 `atype`：先读 `item_sys.type.value`（v14），缺失时回退 `item_sys.armor.type`（v9），转小写；
     - 护甲基础值：`aval = int_or_zero(armor.value) + int_or_zero(armor.magicalBonus)`；
     - `atype == "shield"`：`shield_bonus = max(shield_bonus, aval)`；
     - `atype in ["light", "medium", "heavy", "natural"]`：取最高 `armor_base = aval`（标记 `has_armor = true`），确定 `dex_cap`（若 `armor.dex` 为有效数值则取 `int(armor.dex)`，否则 `"medium" -> 2`、`"heavy" -> 0`、其余 `null` 无上限）。
  4. `eff_dex = dex_mod if dex_cap == null else min(dex_mod, dex_cap)`，`base_armor = armor_base if has_armor else 10`，`computed = base_armor + eff_dex + shield_bonus`。
  5. 若 `calc_str == "custom" or ("custom" in calcs_arr)`，按序检查非空 `ac.formula`（v9–v12）与 `ac.formulas`（`dnd5e 5.x/6.x` 字符串数组）中首个可解析式（如 `Skeleton` `"@attributes.ac.armor + @attributes.ac.dex +1"` → `13`），替换 `@attributes.ac.armor` / `@attributes.ac.dex` / `@attributes.ac.shield` 后求值纯整数加减表达式；均为空或无法解析时回退 `computed`。
- **CR / 职业等级 / 速度 / 感官 / 传记 / 目录**：
  - `cr`：支持 `"0"` 字符串（`bgdia` 中 8 名）及分数 `"1/2"` / `"1/4"` / `"1/8"`；
  - `character` 等级：`details.level` 缺失时累加 `items[type == "class"]` 的 `system.levels`，并拼接职业摘要；
  - `movement` / `senses`：优先读取 v14 `movement.speeds`（数值可能为字符串如 `"30"`）与 `senses.ranges`，回退 v9 扁平字段；
  - `biography`：剥离 `<[^>]+>` HTML 标签、解码常见实体（`&amp;`/`&lt;`/`&gt;`/`&quot;`/`&#39;`/`&nbsp;`）并压缩空白；
  - `folders`：优先读取 `folder.folder`（v14 `!folders!`），回退 `folder.parent`（v9 `folders.db`），组装层级路径（如 `"Infernal War Machines/Machines"`）；
  - **Infernal War Machines 特例**：5 台载具均以 `type: "npc"` + `details.type.value: "custom"` + `details.type.custom: "vehicle..."` 存储，保留 `actor_type = "npc"` 并在 `sub_type` 标注 `"vehicle"`/`custom` 语义。

---

## 4. 模块拆分与类/方法契约（`entry.gd` + 7 个 `src/*.gd`）

### 4.1 全局加载与隔离约束
- 全部 8 个脚本均声明 `extends RefCounted`，**禁止 `class_name`**（防止 `host_verifier.py` 遍历 `res://pkg` 全部 `.gd` 时产生全局符号冲突），**禁止 `preload()`**。
- `src/*.gd` 之间**不持有顶层跨文件 `load()`**；统一由 `entry.gd` 通过 `(get_script() as Script).resource_path.split("::")[0].get_base_dir()` 运行时相对 `load("src/<name>.gd")` 并通过方法入参依赖注入。
- 每次导入都是无状态瞬态实例，绝不跨导入保存可变成员状态。

### 4.2 模块职责与公共方法签名表

| 文件路径 | 核心职责 | 精确公共方法签名与返回契约 |
| :--- | :--- | :--- |
| `entry.gd` | 生命周期调度、选项安全强转、取消点检查、进度/警告汇报、`FuSdk` 协调、返回字段兜底补全 | `inspect_import(path: String, options: Dictionary, host: RefCounted) -> Dictionary`（§2.3 契约）；<br>`prepare_import(path: String, options: Dictionary, host: RefCounted) -> Dictionary`（`{ok: true, world, counts: {entities, assets, source_records, merged_walls}}` 或 `{ok: false, reason}`） |
| `src/fvtt_source.gd` | `.zip`（`ZIPReader`）与解压目录 `world.json` 统一抽象；深度 0/1 发现；苹果垃圾文件过滤；大小写/URL 解码路径解析 | `open(path: String) -> Dictionary`（`{ok: true, source_kind: "zip"|"dir", root_name, world_json_bytes, source_bytes, file_count}` 或 `{ok: false, reason}`）；<br>`has_file(rel_path: String) -> bool`；`read_bytes(rel_path: String) -> PackedByteArray`；`read_text(rel_path: String) -> String`；<br>`list_files(prefix: String = "") -> PackedStringArray`；`list_subdirs(prefix: String = "") -> PackedStringArray`；<br>`resolve_asset_ref(ref: String, world_id: String = "") -> Dictionary`（`{kind: "local"|"remote"|"system"|"empty", rel_path, url, exists}`）；<br>`get_source_kind() -> String`；`close() -> void` |
| `src/fvtt_nedb.gd` | FVTT v9–v10 NeDB `data/*.db` 追加 JSONL 解析、`$$deleted` 墓碑压缩、BOM 剥离与坏行容错 | `read_collection(source: RefCounted, collection_name: String, session: RefCounted = null) -> Dictionary`（`{ok: true, docs: Array[Dictionary], raw_lines: int, deleted_count: int, parse_errors: int, warnings: Array[String]}`）；<br>`parse_jsonl(raw_bytes: PackedByteArray) -> Dictionary` |
| `src/snappy.gd` | 纯 GDScript Snappy 块解压（`varint32`、`l6=0..63`、`1/2/4B` 偏移、强制逐字节重叠拷贝 RLE） | `decompress(compressed: PackedByteArray, max_output_bytes: int = 67108864) -> Dictionary`（`{ok: true, data: PackedByteArray}` 或 `{ok: false, reason: String}`） |
| `src/fvtt_leveldb.gd` | FVTT v11–v14 LevelDB `data/<coll>/` 解析（`CURRENT`、`MANIFEST-*`、`.ldb` 48B Footer/Block/重启点/前缀压缩、`.log` 32KiB WAL/`WriteBatch`、`!sublevel!` 拆分与 `seq`/`vt` 合并） | `has_collection(source: RefCounted, collection_name: String) -> bool`；<br>`read_collection(source: RefCounted, collection_name: String, snappy_impl: RefCounted, session: RefCounted = null) -> Dictionary`（`{ok: true, docs: Array[Dictionary], sublevels: Dictionary, parse_errors: int, warnings: Array[String]}`）；<br>`parse_ldb_bytes(bytes: PackedByteArray, snappy_impl: RefCounted) -> Dictionary`；`parse_wal_bytes(bytes: PackedByteArray) -> Dictionary` |
| `src/fvtt_normalizer.gd` | 将 v9–v14 `world.json`、Scenes（含垫边坐标、墙/门/光/瓦片/棋子）、Actors（含 AC 计算、跳出法术装备）、Folders 规范化为中间模型并计算 `inspect_counts` | `normalize(world_json: Dictionary, collections: Dictionary, source: RefCounted, options: Dictionary, session: RefCounted = null) -> Dictionary`（`{ok: true, model: {world_meta, scenes, actors, assets, warnings, inspect_counts, remote_assets, source_records}}` 或 `{ok: false, reason}`；详见 §4.3 中间模型契约） |
| `src/fuvtt_assets.gd` | 魔数 + `ImageHeader` 预检（零 Godot `ERROR:` 日志）；`.bmp`/`.svg` → `.png`；`.gif` 跳过降级；`SharedAssetStore.Publish` 与 `MockHostBridge` 回退；`archive_remote_image` | `resolve_sprite_ref(logical_ref: String, asset_entry: Dictionary, source: RefCounted, host: RefCounted, session: RefCounted, options: Dictionary) -> Dictionary`（`{ok: true, sprite_path: String, status: "local_published"|"remote_archived"|"skipped"|"unsupported"}` 或 `{ok: false, reason}`）；<br>`publish_local_bytes(bytes: PackedByteArray, ext_hint: String, host: RefCounted, session: RefCounted) -> Dictionary` |
| `src/fuvtt_mapper.gd` | 两阶段 `WorldBuilder` 映射：多楼层（`<=512`）、图层、底图与瓦片、2 点墙体挤出 4 顶点多边形、`finish_geometry_preview()`、单位棋子 + 视野光照、`world.modules`（`<=6 MiB`/`8 MiB`，`.world <=32 MiB`）、安全门控 `entity-library` 注册 | `map_to_world(model: Dictionary, builder: RefCounted, assets_helper: RefCounted, source: RefCounted, host: RefCounted, session: RefCounted, options: Dictionary) -> Dictionary`（`{ok: true, source_records: int, merged_walls: int, registered_library_count: int}` 或 `{ok: false, reason}`） |

### 4.3 规范化中间模型契约（`fvtt_normalizer.gd` → `fuvtt_mapper.gd`）

- `world_meta`: `{id: String, title: String, core_version: String, system: String, system_version: String, source_kind: "zip" | "dir"}`
- `scenes`: `Array[Dictionary]`，每项包含 `{id, name, width, height, padding, shift_x, shift_y, scene_x, scene_y, grid_size, grid_type, grid_distance, grid_units, background_ref, foreground_ref, hidden, tiles, walls, lights, tokens}`
- `actors`: `Array[Dictionary]`，每项包含 `{id, name, actor_type ("character"|"npc"), sub_type, folder_name, img_ref, token_img_ref, token_width, token_height, token_scale, disposition, actor_link, ac, hp_value, hp_max, cr_or_level, abilities, speed, senses, biography, raw_summary}`
- `assets`: `Dictionary`，映射逻辑引用 `logical_ref -> {kind: "local"|"remote"|"system"|"empty", source_kind: "zip"|"dir"|"remote", resolved_path_or_url: String, external_or_missing: bool}`
- `warnings`: `Array[String]`

---

## 5. 完整 FVTT -> Fu VTT 映射规则与资产管线

### 5.1 两阶段导入执行顺序（强不变量）

为避免宿主导入界面卡顿并严格遵循 `ObstacleShapes.prepare_import()` 与 `ImportBridge` 预览协议，`entry.gd` 与 `fuvtt_mapper.gd` 按以下两阶段顺序执行：

1. **阶段 A（世界骨架 + 几何构建 + 预览闭合）**：
   - 计算全局/主场景 `world_source_units_per_cell`（首个方格场景 `grid_type == 1` 的 `grid_size`，无方格时默认 `100.0` 或 `150.0`）；调用 `builder.setup(session, world_source_units_per_cell)`。
   - 调用 `builder.begin_bounds_preview(total_items, total_source_bounds)`。
   - **Floor 0（`"1F"`）复用/重命名与活动楼层切换铁律**：
     - 严禁业务层绕过 `fu_sdk` 直接篡改 `world.catalog.floors[0]`；M4 先行在 `fu_sdk`（`v1.gd` + `host_v1_adapter.gd`）新增 `WorldBuilder.rename_floor(floor_uid: String, name: String) -> bool`。
     - 若存在 `>= 1` 个待导入场景：复用 `empty_world()` 默认建立的 `floors[0]`（`id = 0`）作为 Scene 0 承载楼层并调用 `builder.rename_floor(floor0_uid, scene0_name)`（未修补 SDK 时通过 `has_method("rename_floor")` 安全探测回退并记告警），后续 Scene `1..N-1` 调用 `builder.add_floor(scene_name, color, false)`（上限 `MAX_FLOORS = 512`，超限截断并 `add_warning`）；
     - **活动楼层显式切换铁律**：因为 `WorldBuilder._commit_entity`（`v1.gd:859-862`）无条件把实体绑定到当前 `_floor_uid`，而 `add_floor(..., false)` 不会切换 `_floor_uid`（仅传递 `layer_uid_override` 会触发 `world.members` 的 `floor_uid`/`layer_uid` 不一致错误），所以在**阶段 A 与阶段 B** 每次提交某场景实体前**必须**显式调用 **`builder.set_active_floor(floor_uid)`**！
     - 若无场景（仅导入角色/怪物资源）：保留 `"1F"` 作为单位默认宿主楼层（如有需要可新建 `"未分配角色与怪物"` 图层）。
   - 仅写入本阶段几何障碍物（墙/门/窗，确保 `ring >= 3` 顶点），全部提交后立即调用 **`builder.finish_geometry_preview()`**（返回 `false` 时检查 `session.is_cancelled()` 决定返回 `err_cancelled()` 或 `err_failed()`）。
2. **阶段 B（资产发布 + 底图/瓦片/棋子/光照 + 模块归档 + 素材库同步）**：
   - 逐项解析与发布底图、瓦片与演员贴图资产；
   - 按场景循环调用 **`builder.set_active_floor(floor_uid)`** 后写入 `map` 图层底图与瓦片、`entity` 图层棋子（`unit`）及环境光源锚点；返回前重置活动楼层至 Floor 0（`builder.set_active_floor(floor0_uid)`）；
   - 写入 `world.modules`（`grid_alignment` 与 `fvtt_world_importer` 档案）；
   - 执行安全门控的 `entity-library` 注册（先确保对应图片已 `Publish` 到 `host.destination`）；
   - 预算检查后 `fuvtt_mapper.map_to_world()` 返回 `{ok: true, source_records, merged_walls, registered_library_count}`，最后由 **`entry.gd`** 调用 `builder.build_result(res.source_records, res.merged_walls)`。

### 5.2 场景（`scenes`）→ 楼层、图层、地图与障碍物映射

| FVTT 源要素 | Fu VTT 目标映射 | 精确转换与不变量约束 |
| :--- | :--- | :--- |
| **Scene** | Floor（`id = 0..511`）+ 默认 `map`/`entity`/`obstacle` 3 层 | 最多 `512` 层；总图层 `<= 4096`（每层 `<= 256`）。`name` 经宿主规则清洗为 `1..96` 字符（去 C0/DEL/C1 控制字符）。写入前必须先调用 `builder.set_active_floor(floor_uid)`。**多网格统一缩放因子（先判无网格/无效网格，再做除法）**：`if scene.grid_type == 0 or scene_grid <= 0.0: scene_scale = 1.0`；`else`（即 `scene.grid_type != 0 && scene_grid > 0.0`）：`scene_scale = world_source_units_per_cell / scene_grid`（确保 `bgdia` 全部 `11` 个 `grid_type == 0` 且 `grid_size == 70 > 0` 的无网格场景明确回退 `1.0`，`20` 个方格场景统一缩放到每格 `64.0` Fu VTT 世界单位）；将 `scene_scale` 统一乘到该场景的 `MapTile`、`Tiles`、`Walls`（顶点与 `half_w`）、`Lights` 锚点 `center_src` 与 `Tokens` 的 `center_src` / `size_src`，使 `WorldBuilder` 再乘全局 `64.0 / world_source_units_per_cell` 后，每个 FVTT 格精确对齐 `64.0` Fu VTT 世界单位。 |
| **Scene Background** | `builder.add_map_tile(...)`（`map` 图层，`entity_type = "object"`, `selectable = false`） | 无论原图实际像素（如 `DMG Ship Layout` 原图 `2288x1613`），目标显示尺寸强制拉伸至 **`Vector2(scene.width, scene.height) * scene_scale`**，中心点 **`Vector2(scene_x + width * 0.5, scene_y + height * 0.5) * scene_scale`**，保障与画布空间墙体/棋子零像素漂移。 |
| **Scene Tiles** | `builder.add_map_tile(...)`（按 `z`/`sort` 排序写入 `map` 图层） | 中心点 `Vector2(tile.x + tile.width * 0.5, tile.y + tile.height * 0.5) * scene_scale`，尺寸 `Vector2(tile.width, tile.height) * scene_scale`，`rotation_rad = deg_to_rad(tile.rotation)`，尊重 `tile.hidden`（受 `include_hidden` 控制）。 |
| **Scene Walls** | `add_wall` / `add_door` / `add_window`（`obstacle` 图层） | 1. 缩放端点 `p0_s = p0 * scene_scale`、`p1_s = p1 * scene_scale`，过滤 `p0_s.distance_to(p1_s) < maxf(0.5, 1e-3)` 的零长度退化线段并记警告；<br>2. 沿法线 `n = Vector2(-dir.y, dir.x)` 以缩放后半厚 **`half_w = maxf(4.0, scene_grid * 0.06 * scene_scale)`**（即在全局源空间至少 `4.0` 单位）挤出 4 顶点闭环矩形（以中点 `(p0_s + p1_s) * 0.5` 为 `center_src`，局部顶点 `[p0_s-c-n*hw, p1_s-c-n*hw, p1_s-c+n*hw, p0_s-c+n*hw]`），保证 `path.Count == 4` 且 `|Area| >> 1e-12` 永不触发 `author_ring_degenerate`；<br>3. 分类映射：`door == 1 || door == 2` → `add_door(..., is_open = (ds == 1))`；`door == 0 && sight == 0 && move > 0` → `add_window`；其余阻挡视/移墙 → `add_wall`。 |
| **Scene Lights** | `add_object_sprite`（无贴图透明轻量锚点，`selectable = false`）+ `attach_simple_light` | 中心 `Vector2(light.x, light.y) * scene_scale`（**不裁剪** padding 区光源）；尺寸 `size_src = Vector2(32.0, 32.0) * scene_scale`、`hidden = light.hidden`；因 `add_object_sprite(..., "")` 默认会设 `show_fallback = true` 灰色方块，创建后必须将该锚点的 `entity.fallback_color` 与 `components[0].state.fallback_color` 设为 `Color(1, 1, 1, 0)` 且 `show_fallback = false` 避免地图出现灰块。`attach_simple_light` 直接接收**Fu VTT 世界单位**，故半径 **`radius_world = (maxf(bright, dim) / maxf(0.01, grid_distance)) * 64.0`**；`view_angle = 360.0`（当 `angle <= 0 || angle >= 360`）；`enabled = not light.hidden`。 |
| **Grid (`grid_alignment`)** | `world.modules.entries["grid_alignment"]`（`version = 1`） | 写入严格 8 键配置：`schema: "fus.grid_alignment.config"`, `version: 1`, `cell_size: clampf(64.0, 8.0, 4096.0)`, `offset: [0.0, 0.0]`（FVTT 画布网格原点 `(0, 0)` 直接对齐世界坐标 `(0, 0)`）, `color: [0.5, 0.55, 0.65, 0.7]`, `line_width: 1.0`, `snap_enabled: (grid_type == 1)`, `snap_strength: 0.1`。同时记录 `module_choices = []` 默认未激活限制。 |

### 5.3 角色卡与怪物资源映射（`BoardToken` + `world.modules` + `entity-library`）

1. **场景放置棋子（`BoardToken`）与未放置演员落盘**：
   - 使用 `builder.add_token(source_id, name, center_src, size_src, sprite_ref, rot_rad, scale, hidden, footprint_radius, locked, permission_state)`（其中 `center_src = Vector2(token.x + token_w_px * 0.5, token.y + token_h_px * 0.5) * scene_scale`）：
     - `entity_type = "unit"`、`selectable_in_select_mode = true`、`z_index == 0`；
     - `components[0..1]` 固定为 `[comp_visual.gd, comp_permission.gd]`；
     - 调用 `builder.attach_unit_marker(eid)` 挂载 `comp_unit.gd`（`{"schema_version": 1}`）至 `components[2]`；
     - 若有视觉/暗视范围（v14 `token.sight.enabled` 取 `token.sight.range`/`token.sight.angle`，或 v9 `token.vision == true` 取 `maxf(dimSight, brightSight)`/`sightAngle`，或回退演员 `senses.darkvision > 0`），按**Fu VTT 世界单位**换算 **`radius_world = (range_units / maxf(0.01, grid_distance)) * 64.0`**，调用 `builder.attach_simple_vision(eid, radius_world, angle, requires_light, true)`。
   - **尺寸与足迹约束**：`size_src = Vector2(maxf(4.0, token_w * scene_grid * scene_scale), maxf(4.0, token_h * scene_grid * scene_scale))`；`size_world = size_src * (64.0 / world_source_units_per_cell)`、`footprint_radius = clampf(minf(size_world.x, size_world.y) * 0.5, 0.5, 4096.0)`。
   - **权限映射**：`character`（或 `actor_link == true` / `disposition == 1`）默认 `all_players_can_operate = true, gm_can_operate = true`；`npc` 怪物默认 `all_players_can_operate = false, gm_can_operate = true`。
   - **未放置在任何场景中的演员**：若开启 `import_characters` / `import_monsters`，除写入 `world.modules` 与 `entity-library` 外，可在未关联任何场景时（或仅当用户需要桌面可见单位时）避免重复堆积——**设计约定**：未放置的 `actors` 目录条目优先通过 `world.modules` + `entity-library`（GM 可随时从素材库拖入桌面）承载；若整个世界 `scenes.is_empty()`（纯角色/怪物世界包），则将演员整齐排布网格放置到 `"1F"` `entity` 图层，确保 `verify-host` 与打开世界立即可见。
2. **结构化角色/怪物数据归档（`world.modules`）**：
   - 写入模块 ID **`"fvtt_world_importer"`**（`version = 1`，符合 `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$`）。
   - 存储世界元信息（保留真实 `title`、`core_version`、`system`）与规范化后的角色/怪物摘要（`id, name, actor_type, sub_type, folder_name, ac, hp_value, hp_max, cr_or_level, abilities, speed, senses, sprite_ref`，`biography` 剥离 HTML 且单条截断 `<= 2048` 字符）。
   - **体积守卫**：检查 `var_to_bytes(module_state).size() <= 6 * 1024 * 1024`、`var_to_bytes(world.modules).size() <= 8 * 1024 * 1024`、以及整份 `world` 载荷 `<= 30 * 1024 * 1024`（留足 `2 MiB` 余量应对 `CampaignRecord.wrap` 32 MiB 上限）；超限时按级回退：**① 裁剪 `biography` 摘要 → ② 裁剪 `raw_summary` 字段 → ③ 若整份 `.world` 仍逼近 `30 MiB` 上限则省略可选 `fvtt_world_importer` 档案条目**，并在每步记录 `session.add_warning()` 防止保存失败。
3. **全局素材库安全门控注册（`entity-library`）**：
   - **四重硬门控**（任一不满足立即跳过，确保 `verify-host` 与单元测试零污染真实用户目录）：
     1. `register_entity_library == true`；
     2. `ResourceLoader.exists("res://services/storage/SharedAssetStore.cs") == true`；
     3. `host.get("root")` 与 `host.get("destination")` 均为非空 `String`，且 `ProjectSettings.globalize_path(destination)` 位于 `ProjectSettings.globalize_path(root)` 下的 `sessions/桌面 ...` 目录；
     4. 非取消状态。
   - **注册流程**（使用 `SharedAssetStore.new()`）：
     1. 调用 `OpenLibrary(global_root)` 与 `ReadLibraryRecords(global_root)`——注意 **`ReadLibraryRecords` 直接返回 `Dictionary`**（`{ok, records, revision}`，非 JSON 字符串，不同于 `Publish` 与 `WriteLibraryRecord` 返回 JSON 字符串）；
     2. 为 FVTT 文件夹层级生成确定性 32 位小写十六进制 `folder_id`（`("fvtt:lib:folder:" + world_id + ":" + fid).sha256_text().left(32)`），写入 `kind = "folder"` 行（校验无环路）；
     3. 对每个待注册 `character` / `npc`：若已有已发布的 `asset://<64hex>.<ext>` 贴图，先调用 **`AdoptLibraryAsset(global_root, global_dest, reference)`** 与 **`ShareLibraryAsset(global_root, reference)`**（确保 `MaterializeLibraryAsset` 与缩略图预览能从 `<root>/entity-library/assets/` 读取到文件！）；
     4. 构造符合 `EntityLibraryJob.valid_row` 完整外层键规范的记录行（必填外层键：`version: 1`、`id` 32 位小写 hex、`name` 非空 `<= 256`、`kind`、`folder_id` 空串或 32 位 hex；非 `folder` 行另须包含 `reference`、`size: Vector2 >= 4x4`、`record: Dictionary`）。因 `ImportBridge.run()` 硬编码 `module_choices = []`（`simple_fog` 未启用）且 `EntityLibraryStore.prepare_placement()`（`entity_library_store.gd:342-349`）会拒绝含未启用可选模块组件（如 `comp_simple_vision.gd`）的 `preset`（报 `preset_component_unavailable`），**默认以 `kind = "unit"` 注册演员**（使用精确 9 键 `_image_record` `record.data`：`id, name, type="generic", category="library", size>=4x4, color=Color.WHITE, sprite=ref, components={"unit": {}}, selectable_in_select_mode=false`，无 `snapshot` 依赖）；若将来使用 `kind = "preset"`，其 `snapshot` 仅允许包含核心必选组件（`comp_visual.gd`、`comp_permission.gd`、`comp_unit.gd`）；
     5. 顺序调用 `WriteLibraryRecord(global_root, row.id, expected_bytes, var_to_bytes(row), current_revision)`，其中 **`expected_bytes = loaded.records.get(row.id, PackedByteArray())`**（保障确定性 ID 重复导入幂等更新，而非传空 `PackedByteArray()` 导致已存在记录写入失败；若字节完全相同可直接跳过），每次从返回 JSON 解析新的 `revision` 链式传入下一次写入。

### 5.4 图片资产验证、格式转换与发布管线（`src/fuvtt_assets.gd`）

1. **前置无报错检验（杜绝 Godot `ERROR:` 日志）**：
   - 先检查 `bytes.is_empty()` 与 `bytes.size() <= 512 * 1024 * 1024`。
   - **先检测二进制魔数**，再检测 `<svg` 文本：
     - PNG (`89 50 4E 47 0D 0A 1A 0A`)、JPG (`FF D8 FF`)、WEBP (`RIFF....WEBP`)、BMP (`42 4D`)、GIF (`47 49 46 38`)；
     - 仅当未命中上述二进制魔数且 `bytes.size() <= 2 MiB` 时，使用 **`.get_string_from_ascii()`** 探测 `<svg`（**严禁**对原始二进制字节调用 `.get_string_from_utf8()`，否则会向 `STDERR` 打印 `Unicode parsing error` 并触发 `verify-host` 失败！），同时校验不含 `<!ENTITY`/`<!DOCTYPE`、存在正宽高且像素 `<= 134217728`；
     - **显式拒绝 GIF（`47 49 46 38`）与未知字节**：**绝不**调用 `Image.load_*_from_buffer()`（实测传入空包或非法格式会打印 `ERROR:` 导致 `host_verifier.py` 失败）。
   - 对有效图片：校验尺寸 `1 <= w, h <= 32768` 且 `w * h <= 134217728`。
2. **格式规范化**：
   - `.png` / `.jpg` / `.jpeg` / `.webp`：通过 `Image.load_*_from_buffer` 确认像素可解码后，保留原始字节与规范扩展名（`jpeg` 归一或保留皆受支持）。
   - **`.bmp` 与 `.svg`**：分别调用 `Image.load_bmp_from_buffer` / `Image.load_svg_from_buffer`，再统一 `save_png_to_buffer()` 转为 **`.png`**（既满足 `SharedAssetStore.cs`/`CampaignImageFiles`，又彻底规避未修补版 `host_v1_adapter.gd` 拒绝 `.bmp`、错放 `.svg` 的冲突）。
   - **`.gif`**：若 `skip_missing_assets == true`，记警告并返回 `status = "unsupported", sprite_path = ""`；若 `false`，返回 `err_failed("unsupported_image_format:gif")`。
3. **双通道发布与缓存去重**：
   - 按 `logical_ref`（及内容 `sha256`）在单次导入内内存去重：
     - **本地 / ZIP 图片**：计算 `sha = Marshalls...` / `bytes` SHA-256，生成 `ref = "asset://%s.%s" % [sha256_hex, ext]`。若检测到实机 `SharedAssetStore.cs` 且 `host.destination` 合法，实例化并调用 `Publish(ProjectSettings.globalize_path(host.destination), ref, bytes)`，解析 JSON 检查 `ok == true` 并**记录本次直接 `Publish` 在 `destination/assets/` 下创建的物理文件路径**；若 `prepare_import` 中途被取消或失败，必须主动清理这些自发布文件（因 `ImportBridge._created_assets` 仅追踪 `archive_image()` 产生的路径，且 `DirAccess.remove_absolute(destination.path_join("assets"))` 无法删除非空目录）。若处于 `verify-host`（`MockHostBridge`）或单元测试无 `SharedAssetStore.cs`，跳过写盘直接返回合法 `ref`（同时仅在所有关键解析与阶段 A 几何校验通过后才落盘 `Publish`）。
     - **远端 `http://` / `https://` URL**：若 `download_remote_assets == true`，调用 `session.archive_remote_image(url, _proxy)`；失败时按 `skip_missing_assets` 降级为空串或报错中止。

---

## 6. 异常与边界处理矩阵及 M3–M5 自动化验证计划

### 6.1 异常与边界处理矩阵（14 项全覆盖）

| # | 异常 / 边界场景 | 检测位置 | 处理策略与期望结果 |
| :--- | :--- | :--- | :--- |
| 1 | 损坏或不可读的 `.zip` 文件 | `fvtt_source.open()` | 捕获 `ZIPReader.open != OK`，安全关闭句柄，返回 `{ok: false, reason: "无法打开 FVTT 压缩包（错误码 %d）" % err}`，由 `entry.gd` 包装为 `session.err_failed(...)` |
| 2 | 用户选中非 `world.json` 的 `.json`（如 `gateway.json`） | `fvtt_source.open()` | 立即返回 `{ok: false, reason: "请选择 FVTT 世界清单文件 world.json（当前：%s）" % path.get_file()}`，由 `entry.gd` 包装为 `session.err_failed(...)` |
| 3 | 缺失、深度 `> 1`、多候选或结构非法的 `world.json` | `fvtt_source.open()` | 剥离 UTF-8 BOM；校验唯一深度 0/1 命中、JSON 为 `Dictionary` 且含 FVTT 清单必备键，否则返回 `{ok: false, reason}`（`entry.gd` 转为 `session.err_failed(...)`） |
| 4 | 空文件或损坏的 `.db` / `.ldb` / `.log` | `fvtt_nedb` / `fvtt_leveldb` | `scenes` 与 `actors` 均缺失/不可读 → `err_failed`；NeDB 单坏行跳过+警告；WAL 尾部截断安全终止+警告；SSTable 魔数/Footer/Snappy 越界安全拒绝（严禁越界切片崩溃） |
| 5 | 悬空 `token.actorId`（如 `bgdia` 目录 5 枚、ZIP 2 枚） | `fvtt_normalizer.normalize()` | 保留棋子放置，回退至 token 自身 `name`、`img`/`texture.src`、`width/height`、`disposition` 与 `actorData`，标记 `actor_missing=true` 并 `add_warning` |
| 6 | `< 3` 顶点墙体（FVTT 2 点墙与 `< 0.5` px 退化线段） | `fuvtt_mapper.map_to_world()` | 有效 2 点线段按 `half_w = maxf(4.0, scene_grid * 0.06 * scene_scale)` 挤出 4 顶点矩形；缩放后 `< 0.5` px / `< 1e-3` 退化线段跳过并 `add_warning`，绝不传 `< 3` 顶点环给 `WorldBuilder` |
| 7 | `> 512` 场景楼层或 `> 10000` 实体超限 | `fuvtt_mapper.map_to_world()` | 楼层在 `512` 处截断、实体在 `10000` 处截断，发出明确的截断 `session.add_warning()`，不触发 `WorldSnapshot` 拒收 |
| 8 | `ac.calc == "default"` 或 `dnd5e 6.x` `ac.calcs`（`["unarmored", "armored"]`）导致的 `ac.flat == null` / `ac.value == null` / 残留 `ac.flat` | `fvtt_normalizer.normalize()` | 丢弃物品前，按 `ac.override` → `ac.calc`/`ac.calcs` 门控 `ac.flat` → 已装备护甲（兼容 `system.type.value` 与 `armor.type`）+ 敏捷上限 + 盾牌 + `custom` `formula`/`formulas` 准确算出 AC；缺失 `dex` 时兜底 `10` |
| 9 | 不支持的图片格式（`.bmp` / `.svg` / `.gif`） | `fuvtt_assets.gd` | 二进制魔数优先 + `.get_string_from_ascii()` `<svg` 探测 + `ImageHeader` 预检（零 `ERROR:` / `Unicode parsing error`）；`.bmp`/`.svg` 转 `.png` 发布；`.gif` 在 `skip_missing_assets == true` 时警告降级 `""`，`false` 时 `err_failed` |
| 10 | 缺失 `assets/srd5e/...`（221 项）与离线 `http/https` URL（217 项） | `fvtt_source` + `fuvtt_assets` | `download_remote_assets == true` 时 `inspect_import.assets` 仅含 `http`/`https`（`false` 时 `assets = {}` 避免 `ProbeAssets` 卡顿）；`prepare_import` 中缺失/离线引用在 `skip_missing_assets == true` 时降级占位并告警，`false` 时中止 |
| 11 | 用户中途取消（`session.is_cancelled()`） | `entry.gd` 与各循环边界 | 在开包前、集合间、每场景/演员/资产迭代前、`finish_geometry_preview()` 前后检查；释放 `ZIPReader`、清理自发布到 `destination/assets/` 的文件并返回 `session.err_cancelled()` |
| 12 | `32 MiB` `.world` 与 `8 MiB` `world.modules` 上限 | `fuvtt_mapper.map_to_world()` | 归档剥离 HTML 并截断 `biography <= 2048`；实测 `var_to_bytes(modules)`（`<= 6 MiB` 单条 / `<= 8 MiB` 总量）与 `var_to_bytes(world)`（`<= 30 MiB` 预算），超限时依次裁剪 `biography` → `raw_summary` → 省略可选 `fvtt_world_importer` 档案并告警 |
| 13 | 导入 `world.json` 时活动名被宿主覆写为 `"world"` | `entry.gd` / `fuvtt_mapper.gd` | `inspect_import` 返回真实 `world.title` 供 `verify-host` 核验；`prepare_import` 发告警说明宿主命名行为并在 `world.modules` 与楼层名保留真实 `world.title` |
| 14 | `entity-library` 测试隔离与 `.revision` 并发冲突 | `fuvtt_mapper.gd` | 仅当 `SharedAssetStore.cs` 存在且 `host.root` / `host.destination` 经规范校验匹配会话目录时以 `kind = "unit"` 默认写入；`ReadLibraryRecords` 按 `Dictionary` 解析并以 `loaded.records.get(row.id, PackedByteArray())` 作为 `expected_bytes` 链式传递更新后的 `revision` |

### 6.2 M3–M5 自动化与无头真机验证计划

> **目录落位铁律**：全部新增测试脚本与夹具必须放置于 `shared/tools/tests/`，临时验证产物与样本放置于 `build/fvtt-world-importer/` 或 `.cache/test_tmp/`，**严禁**在 `mods/fvtt-world-importer/` 下创建 `tests/`、`DESIGN.md`、`docs/` 或测试样本文件。  
> **沙箱分流铁律**：`validate` / `build` 与纯 Python 单元测试在沙箱内（`BypassSandbox: false`）执行；凡启动 `<GODOT_BIN>` 的无头单元测试、`verify-host` 与 E2E 运行器**必须**设置 `BypassSandbox: true`（避免 Godot Mono CoreCLR 在 Windows 沙箱内挂起）。

1. **M3 — 解析器与规范化器单元测试**（`shared/tools/tests/test_fvtt_world_importer_parsers.py` + 无头 GDScript 测试脚本）：
   - `fvtt_source`：深度 0/1 `world.json`、`__MACOSX`/`.DS_Store`/`._*` 过滤、CJK `.zip` 路径、大小写与 `%20` URL 解码、非 `world.json`（如 `gateway.json`）及坏 `.zip` 拒绝；
   - `snappy`：字面量（含 `l6 == 60/61`）、1/2/4 字节拷贝、重叠自拷贝 RLE（`offset < length`）、截断/超限流拒绝；
   - `fvtt_nedb`：追加更新、`$$deleted` 墓碑、UTF-8 BOM 剥离、单坏行恢复；
   - `fvtt_leveldb`：合成 `.ldb` + `.log`（32 KiB 跨块 `First/Middle/Last` 分片、`DeletedFile` Manifest、尾部截断恢复）+ 实测 `<FVTT_WORLD_DIR>/data/`（核对 `scenes == 31`、`actors == 229`、`folders == 62`、`walls == 3857`、`lights == 131`、`tiles == 227`、`tokens == 618`）；
   - `fvtt_normalizer`：验证 `<FVTT_WORLD_DIR>`（v14 混合 v9）与 `<FVTT_WORLD_ZIP>`（v9）产出一致的规范数量与 AC（`Fist of Bane == 18`, `Skeleton == 13`, `Arkhan == 22`, `Scavenger == 20`）、悬空 `actorId` 告警、`remote_assets` 仅含 `http`/`https`。
2. **M4 — 映射、资产管线与宿主集成验证**：
   - 无头 GDScript 单元测试：`fuvtt_assets`（PNG/JPG/WEBP/BMP→PNG/SVG→PNG、`.gif` 零 `ERROR:` 跳过、离线 `archive_remote_image` 模拟、`skip_missing_assets=false` 失败）与 `fuvtt_mapper`（4 顶点墙体挤出与 `< 0.5` px 过滤、Floor 0 处理、超限截断、`.world <= 30 MiB` 预算、取消点响应）；
   - 工具链全门禁：
     - `python -B shared/tools/fuvtt_cli.py validate fvtt-world-importer`（`BypassSandbox: false`）
     - `python -B shared/tools/fuvtt_cli.py build fvtt-world-importer`（`BypassSandbox: false`）
     - `python -B shared/tools/fuvtt_cli.py verify-host fvtt-world-importer --sample <FVTT_WORLD_DIR>/world.json`（`BypassSandbox: true`）
     - `python -B shared/tools/fuvtt_cli.py verify-host fvtt-world-importer --sample <FVTT_WORLD_ZIP>`（`BypassSandbox: true`）
     - 反向 `verify-host` 验证：坏 `.zip`、非 `world.json` 返回明确 `{ok: false, reason}` 且零 `SCRIPT ERROR` / `ObjectDB` 泄漏。
3. **M5 — E2E Tiers 1–4 验收与 Tier 5 对抗加固**：
   - 等待 E2E 轨道交付 `TEST_READY.md` 后，分别以 `<FVTT_WORLD_DIR>/world.json` 与 `<FVTT_WORLD_ZIP>` 运行 Tiers 1–4 端到端套件与 `shared/tools/tests/` 全量回归，核对 `31` 场景、墙体/门窗、角色与怪物数量及核心字段、`bytes_to_var(var_to_bytes(world))` 无损往返，最后执行 Tier 5 对抗模糊测试（畸形 Snappy/SSTable/NeDB/ZIP/恶意选项）完成发布封板。
