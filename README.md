# 宿舍智联实验室 / DormLink

HarmonyOS 应用开发期末大作业（主题三：联动实验室——智能宿舍自动化规则编排 App）。
作者：陈俊宇，学号 20230313203，2023 级物联网工程 2 班，独立完成（无组队）。

- GitHub 仓库：https://github.com/2026chen-cmyk/DormLink
- GitHub 账号：2026chen-cmyk

学生在页面上自行编排"满足条件就执行设备动作"的联动方案，用 Mock 环境检验效果，并观察执行顺序与冲突处理。

## 一、功能一览

| 编号 | 功能 | 说明 |
| --- | --- | --- |
| F01 | 4 类可控设备 | 照明灯、空调、窗帘、插座，均支持开/关与手动点击切换 |
| F02 | 3 项 Mock 环境 | 温度 0～50 ℃、照度 0～1000 lx、人数 0～8（整数），非法输入拒绝 |
| F03 | 规则管理 | 默认 4 条；支持新增、编辑、删除、启停；每条 1～2 个 AND 条件；优先级 0～100 |
| F04 | 规则引擎 | 优先级降序 → 同级按 id 升序依次执行；同一设备被高优先级占用后，后续规则记"冲突跳过" |
| F05 | 执行记录 | 每条规则一条记录：序号、时间、规则名、输入快照、状态（执行/未匹配/冲突跳过）、设备原值→新值与原因；最多保留 200 条 |
| F06 | 场景演练 | "学习场景"（30 ℃/200 lx/2 人）、"夜间无人"（24 ℃/30 lx/0 人）一键填入环境 |
| F07 | 持久化 | Preferences 库 `dorm_link` / 键 `snapshot_v1`，保存版本、环境、设备、规则、日志、nextRuleId；杀进程重启后完整恢复 |
| F08 | 异常保护 | 存档校验失败提示且不覆盖；保存中禁止重复提交；保存失败提示并允许重试 |

默认规则（首次启动写入）：

1. `#1 有人且昏暗时开灯` P80：人数 > 0 **且** 照度 < 300 → 开灯（双条件 AND 示例）
2. `#2 高温开启空调` P60：温度 > 26 → 开空调
3. `#3 无人关闭照明` P90：人数 = 0 → 关灯
4. `#4 白天打开窗帘` P50：照度 > 500 → 开窗帘

## 二、开发环境

| 项目 | 版本 / 路径 |
| --- | --- |
| 操作系统 | Windows 11（本机 ASUS） |
| IDE | DevEco Studio 5.0.13.230，安装于 `C:\HuaweiApp\DevEco Studio` |
| SDK | HarmonyOS SDK API 17（5.0.5.165），`C:\HuaweiApp\DevEco Studio\sdk` |
| 构建工具 | DevEco 自带 hvigor（`tools\hvigor\bin\hvigorw.bat`） |
| 语言/框架 | ArkTS + ArkUI（Stage 模型），bundleName `com.chenjunyu.dormlink` |
| 运行设备 | HarmonyOS 模拟器 Huawei_Phone（HarmonyOS 5.0.5(17)，phone_x86），`127.0.0.1:5555` |
| 业务测试 | Node.js v22.23.2 `node --test`（类型擦除直接执行 Engine.ets） |

> 工程原 `compileSdkVersion` 为 `5.0.0(12)`，本机只安装 API 17，构建报 `SDK component missing`。
> 已将 `build-profile.json5` 的 `compileSdkVersion` 与 `compatibleSdkVersion` 改为 `"5.0.5(17)"`，改动已随源码提交。

## 三、运行方法

方式一（推荐，IDE 运行）：

1. DevEco Studio → Open 打开本目录，等待 Sync 完成（IDE 使用自带 hvigor/ohpm，工程未附 wrapper）。
2. File → Project Structure → Signing Configs 勾选自动签名（本机账号登录华为开发者帐号后生成）。
3. 选择 entry 模块 → 目标设备（模拟器/真机）→ Run。

方式二（命令行构建 + 未签名 HAP 安装，本机实测路径）：

```powershell
# 1) 配置工具链环境（沙箱/精简 PATH 时必须显式指定，否则报 spawn cmd.exe / java ENOENT）
$env:NODE_HOME      = "C:\HuaweiApp\DevEco Studio\tools\node"
$env:DEVECO_SDK_HOME= "C:\HuaweiApp\DevEco Studio\sdk"
$env:JAVA_HOME      = "C:\HuaweiApp\DevEco Studio\jbr"
$env:PATH = "C:\Windows\System32;C:\Windows;C:\HuaweiApp\DevEco Studio\jbr\bin;C:\HuaweiApp\DevEco Studio\tools\node"

# 2) 构建
& "C:\HuaweiApp\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default -p module=entry@default assembleHap --no-daemon

# 3) 安装并启动（开发版镜像不校验签名，未签名 HAP 可直接安装）
$hdc = "C:\HuaweiApp\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe"
& $hdc -t 127.0.0.1:5555 install -r "entry\build\default\outputs\default\entry-default-unsigned.hap"
& $hdc -t 127.0.0.1:5555 shell "aa start -a EntryAbility -b com.chenjunyu.dormlink"

# 4) 模拟杀进程后重启，观察持久化恢复
& $hdc -t 127.0.0.1:5555 shell "aa force-stop com.chenjunyu.dormlink"
& $hdc -t 127.0.0.1:5555 shell "aa start -a EntryAbility -b com.chenjunyu.dormlink"
```

构建结果：`BUILD SUCCESSFUL`，产物 `entry\build\default\outputs\default\entry-default-unsigned.hap`（约 122 KB）。
告警仅两条：`app_icon.svg is defined repeatedly`（图标资源重复定义）与 `Will skip sign 'hos_hap'`（未配置 signingConfigs）。

方式三（业务逻辑测试，不需要设备）：

```powershell
cd DormLink
node --test tests/engine.test.mjs        # 18 条用例，约 0.17 s
```

## 四、运行截图（screenshots/）

| 截图 | 内容 |
| --- | --- |
| `01-首屏默认状态.jpeg` | 冷启动读取 Preferences，环境 28 ℃/150 lx/2 人，4 台设备关闭，4 条规则 |
| `02-学习场景联动.jpeg` | 学习场景 30/200/2 → 灯、空调开启，窗帘与插座保持关闭 |
| `03-夜间无人联动.jpeg` | 夜间无人 24/30/0 → P90 规则关灯，空调无关闭规则保持开启 |
| `04-冲突执行后.jpeg` | 新增 P95 规则后环境 30/200/2 → 灯关、空调开 |
| `05-冲突跳过记录.jpeg` | 日志 #11、#12 明确记录"冲突跳过"及优先级原因 |
| `06-重启后恢复.jpeg` | `aa force-stop` 后再启动，环境与设备状态原样恢复，提示"已载入本地状态" |
| `07-重启后规则列表.jpeg` | 改名后的 #3（两人时强制关灯，P90）与新增的 #5（高温优先开启空调，P95）均恢复 |

运行过程取证以 `screenshots/` 内 7 张真实截图为准；设备端不提供 `screenrecord`，本机也未能在录制视频，故仓库暂不含 `demo.mp4`，如需提交录屏可自行用手机或 DevEco 设备镜像录制。

## 五、目录结构

```
DormLink/
├─ AppScope/                     应用级配置与资源
├─ entry/src/main/ets/
│  ├─ entryability/EntryAbility.ets    UIAbility 入口
│  ├─ model/Engine.ets                 规则引擎：校验、排序执行、冲突裁决、快照编解码
│  ├─ store/StateStore.ets             Preferences 持久化
│  └─ pages/Index.ets                  单页 ArkUI：环境、设备、规则、日志四区
├─ entry/src/test/               Hypium 用例（Engine.test.ets / List.test.ets）
├─ tests/engine.test.mjs         Node 业务自动化测试（直接跑 Engine.ets 同源码）
├─ docs/                         软件需求说明书、测试与验收记录、录屏与截图清单
├─ screenshots/                  实测截图
└─ build-profile.json5 等        构建配置
```

## 六、测试与验收

- 业务自动化：18/18 通过（正常 8、边界 6、异常 4），覆盖 AND 组合、停用、优先级冲突、同级 id 顺序、阈值边界、NaN/越界/小数人数、快照往返、损坏存档、200 条日志截断、入参不被修改等。原始输出见 `docs/node-test-results.txt`。
- 平台验证：API 17 编译成功 → 安装成功 → 两场景联动 → 新增/改名/改阈值规则 → 冲突跳过 → 杀进程重启恢复，全部通过。
- 验证中修复的真实缺陷（详见 `docs/测试与验收记录.md`）：
  1. ForEach 键为 `d.id` / `r.id`（不含状态），执行后设备卡片与规则卡片不刷新 → 键改为包含 `on`/`enabled`/`priority` 等可变字段；
  2. 四处 `Select` 缺 `.value()`，只显示箭头不显示当前选项 → 补充 `.value()` 与四个标签数组。
- 已知限制（环境限制，非应用缺陷）：模拟器 `uitest` 无法命中 `Select` 弹出浮层，故表单中的设备/动作/字段下拉无法用脚本改选，UI 自动化改用纯文本框路径制造冲突；设备端无 `screenrecord`。

## 七、文档

- `docs/软件需求说明书.md`：范围、功能需求、模块接口、数据模型、分工、测试与验收标准。
- `docs/测试与验收记录.md`：18 条自动化用例结果、平台验收实测结论、缺陷修复记录。
- `docs/录屏与截图清单.md`：截图与录屏清单。
