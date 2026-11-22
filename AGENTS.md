# 插件开发规范（`fvtt-world-importer`）

> 本插件由 `python shared/tools/fuvtt_cli.py init fvtt-world-importer` 初始化，面向 Fu vtt 现役 `Practice` 主线提供 Foundry VTT（FVTT）世界包导入能力。

## 1. 业务目标与适用范围

- **插件目录名**：`fvtt-world-importer`（目录使用 `kebab-case`）
- **清单插件 ID**：`fvtt_world_importer`（`plugin.json` 中 `id` 匹配 `^[a-z][a-z0-9_]{0,63}$`）
- **核心目标**：支持从 `.zip` 归档或已解压 FVTT 世界目录中的 `world.json` 两种输入来源导入通用 FVTT 世界包（v9–v14 NeDB/LevelDB），在 Fu vtt 中创建对应场景（地板/图层/底图/墙体门窗/照明/棋子）、角色卡资源与怪物资源（当前范围不包含法术与装备资源）。
- **目标宿主契约**：现役 `Practice` 主线（Steam Playtest），会话导入插件（`schema: "fus.session-plugin.v1"`、`scope: "session"`、`host_api: 1`）。严禁混用早期 `FUS-F2` 原型分支（`f2.feature_plugin.v1`）接口。

## 2. 目录结构、打包排除与防腐层 SDK 规范

- `plugin.json`：遵循 `fus.session-plugin.v1` 契约的插件清单（UTF-8 无 BOM，`<= 128 KiB`）；`settings`（仅允许 `"string"` 与 `"bool"` 类型）与 `import_extensions`（`["zip", "json"]`）均为硬必填数组。
- `entry.gd`：继承 `RefCounted` 的插件入口，暴露 `inspect_import(path, options, host)` 与 `prepare_import(path, options, host)`；禁止使用 `preload()`，通过 `(get_script() as Script).resource_path.get_base_dir()` 动态加载 `lib/fu_sdk/v1.gd`（开发态自动回退至 `../../shared/sdk/fu_sdk/v1.gd`）。
- `src/`：存放拆分的纯 GDScript 解析器与映射子脚本（通过相对路径 `load()` 加载，禁止 `preload()`）。
- `assets/`：存放插件自带静态资源（如需）。
- **打包排除与后续里程碑文件落位铁律（`packager.py` / `validator.py` `is_runtime_file()`）**：
  - `validator.py` / `packager.py` 仅排除路径段为 `__pycache__` 或以 `.` 开头的条目、`.pyc`/`.pyo` 文件，以及精确文件名 `AGENTS.md`、`README.md`、`.gitkeep`。
  - **其余放入 `mods/fvtt-world-importer/` 的任何文件（包括 `DESIGN.md`、`docs/`、`tests/`、`.json`/`.zip` 测试样本）都会被打包进发布 ZIP，且会被 `verify-host` 编译/加载。**
  - **M2 详细设计文档**：必须放置于 `mods/fvtt-world-importer/README.md`（不打包进 ZIP，仅做 UTF-8 无 BOM 检查）；禁止在 `mods/fvtt-world-importer/` 下新增 `DESIGN.md` 或 `docs/`。
  - **M3–M5 / E2E 自动化测试与样本**：Python / GDScript 测试与测试夹具放置于 `shared/tools/tests/`，临时验证样本与输出放置于 `build/fvtt-world-importer/` 或 `.cache/test_tmp/`；禁止在 `mods/fvtt-world-importer/` 下创建 `tests/` 或测试样本文件。
  - **编码与路径**：本目录所有 `.json`、`.gd`、`.md`、`.cfg` 必须为 UTF-8 无 BOM 且使用 LF（`\n`）换行；严禁硬编码本机绝对路径（统一使用 `<FUVTT_INSTALL_DIR>`、`<FUS_REPO_DIR>`、`<GODOT_BIN>` 占位符）。
- **`fu_sdk` 防腐层调用约束**：
  - 严禁在业务代码中直接拼装底层 `world.entity_state`、`world.members`、`fus.floor_layers.v2` 图层结构或硬编码 `res://scenes/entities/components/...` 路径。
  - 严禁向 `sprite_path` 写入 `user://` 路径（宿主仅接受 `""`、`asset://<sha256>.<ext>` 或 `res://` 贴图）。
  - 遵循两阶段导入顺序：先写入墙体/门窗/空气挖空/文字/矢量并调用 `builder.finish_geometry_preview()`，再归档图片并写入地图与棋子。
  - `inspect_import()` 返回值须在 `session.ok_inspect(...)` 基础上补齐 `name`、`source_bytes`、`decoded_bytes`、`unique_images` 与完整 12 项 `counts` 键，确保宿主 `ImportConfirmation` 正常读取。

## 3. 当前进度

- [x] M1：插件命名（`fvtt-world-importer` / `fvtt_world_importer`）、目录初始化、`plugin.json` / `AGENTS.md` / `entry.gd` 基线与 `validate` / `build` / `verify-host` 通关
- [x] M2：FVTT 世界包技术调研与详细实现方案文档（`mods/fvtt-world-importer/README.md`）
- [x] M3：FVTT 双输入源（`.zip` / 解压目录 `world.json`）、NeDB/LevelDB 解析与场景/角色/怪物规范化
- [x] M4：Fu VTT 场景几何/地板/角色与怪物资源映射、图片资产发布与完整 `entry.gd` 集成
- [x] M5：针对 `bgdia` 解压目录与 `.zip` 压缩包的 E2E 验证、异常边界测试与发布加固

## 4. 校验、构建与本地联调命令

在工作区根目录下执行以下命令（构建输出统一位于 `build/fvtt-world-importer/`，缓存位于 `.cache/`，客户端与引擎路径从根目录 `.env.local` 读取）：

```powershell
# 1. 静态契约门禁校验（对齐 C# PluginPackageJob 强门禁）
python shared/tools/fuvtt_cli.py validate fvtt-world-importer

# 2. 确定性打包（自动将 shared/sdk/fu_sdk/ 内嵌至包内 lib/fu_sdk/）
python shared/tools/fuvtt_cli.py build fvtt-world-importer

# 3. Godot 4.8-beta1 Mono 真机无头编译与导入回合验收（隔离证据收敛于 build/fvtt-world-importer/verify_evidence/）
python shared/tools/fuvtt_cli.py verify-host fvtt-world-importer
python shared/tools/fuvtt_cli.py verify-host fvtt-world-importer --sample <path-to-zip-or-world.json>

# 4A. 本地 HTTP 托管热更新流（配合 --bump-dev 在客户端插件面板“检查更新”免重启生效）
python shared/tools/fuvtt_cli.py build fvtt-world-importer --bump-dev
python shared/tools/fuvtt_cli.py serve

# 4B. 离线原子直写同步流（写入 <FUVTT_INSTALL_DIR>/FUS_Data/session_plugins/ 并更新 registry.json）
python shared/tools/fuvtt_cli.py sync fvtt-world-importer

# 5. 运行工具链与插件自动化测试
python -m unittest discover -s shared/tools/tests
```

## 5. 所需共享文档（按需引用）

开发本插件时，按当前任务仅读取所需文档，禁止全量无关加载：

- 防腐层 SDK 接口说明：`@../../shared/sdk/README.md`
- 插件入口与清单规范：`@../../shared/docs/plugin-lifecycle.md`
- 场景、迷雾、高度与权限接口：`@../../shared/docs/desktop-and-scene-api.md`
- 宏系统钩子与规则数据适配：`@../../shared/docs/macro-and-rules.md`
- 内测版本变动与兼容性记录：`@../../shared/docs/playtest-notes.md`
