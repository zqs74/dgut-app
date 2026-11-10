# 莞工统一 App · Flutter 原型

东莞理工学院统一 App 的第一版可运行原型。设计语言（DGUT Glass）在网页里定稿，这里把它落成 Flutter。

- 设计真源：`D:\16037\Documents\大三上\莞工统一App方案\motion\`（`dgut.css` / `dgut.js` / `DESIGN.md` / `index.html`）
- 实现规格：`motion\交接-Flutter实现-2026-11-10-v2.md`
- 本轮交付说明：`motion\交付-Flutter原型M1-2026-11-10.md`

## 跑起来

```powershell
$env:Path='D:\16037\Dev\flutter\bin;'+$env:Path
cd D:\16037\Documents\DSHproject\dgut_app

flutter run -d chrome     # 浏览器
flutter run -d windows    # Windows 桌面原生窗口
```

深链参数：

| 参数 | 作用 |
|---|---|
| `?p=0..4` | 直接落在 首页 / 课表 / 服务 / 消息 / 我的 |
| `?dark=1` | 强制深色 |
| `?demo=1` | 每 1.8 秒自动轮播五页，用来验收切页过渡与果冻 |
| `?boot=changelog` | 启动即打开版本更新历史 |
| `?boot=theme` | 启动即弹外观选择浮层 |
| `?seg=1` | 消息页默认停在「通知」 |
| `?seed=1` | 写入 5 门**示例**课（仅在课表为空时），用于验收网格、撞课、单周与非本周淡显 |
| `?seed=reset` | 清空全部课表与覆盖层 |

例：`http://127.0.0.1:8901/?p=1&dark=1`

## 目录

```
lib/
├── theme/
│   ├── dgut_tokens.dart   31 色明暗两套 + 12 级字阶 + 圆角/间距/阴影
│   ├── dgut_motion.dart   时长/曲线/弹簧/果冻/模糊公式 + 页面过渡
│   └── dgut_theme.dart    ThemeData 组装（含中文字体 fallback）
├── components/
│   ├── dgut_basics.dart   行/按钮/胶囊/分组标题/统计行/搜索/披露/进度/键值/主块
│   ├── dgut_header.dart   大标题（随滚动收缩淡出，带视差补偿）
│   ├── dgut_topbar.dart   顶栏（σ = 30·t²，纯模糊不叠底色）
│   ├── dgut_edge_blur.dart 三层连续边缘模糊 + 接缝层
│   ├── dgut_dock.dart     Dock（跟手胶囊 / 双轴果冻 / 玻璃层）
│   ├── dgut_timeline.dart 一天的时间线
│   ├── dgut_theme_sheet.dart 外观三选一浮层
│   └── dgut_page_scaffold.dart 页面骨架（滚动驱动收口）
├── model/
│   ├── course.dart        课程 + 时段（一门课挂多段）、周集合压缩文案
│   ├── term_calendar.dart 学期日历：周次与日期互算、调休例外
│   └── course_override.dart 单节覆盖层（换教室 / 停课，界面待接）
├── store/
│   ├── store.dart         本机存储门面（shared_preferences + JSON）
│   └── timetable_repository.dart 课表仓储：读写、按来源合并、当周统计
├── data/
│   ├── default_term.dart  默认学期（第 1 周周一 = 2026-08-31）
│   └── changelog.dart     版本记录数据（与根目录 CHANGELOG.md 同源）
├── pages/                 五页 + changelog_page
├── shell/dgut_shell.dart  外壳：PageView 切页 + 顶栏 + 上下边缘 + Dock + 环境光
└── main.dart              主题模式切换与深链
```

## 设计约束（改代码前先读）

1. 不在 widget 里写裸 `Color(0x…)`，一律走 `DgutColors`
2. 不用 `Card` / `ListTile` / 默认 `AppBar`
3. 玻璃只出现在顶栏、Dock、详情返回栏；内容区不透明
4. 主色只出现在"点"上：状态点、3px 左边线、链接、CTA
5. 版面节奏用 8 的倍数；元件内部尺寸（课表网格 gap 3、行高 24、圆角 5/7）照原型像素走
6. 动效数值以 `dgut.css` / `dgut.js` 为准，不以文档转述为准

## 环境

| 项 | 值 |
|---|---|
| Flutter | 3.47.8 stable（`D:\16037\Dev\flutter`） |
| Dart | 3.13.7 |
| Android SDK | 36.0.0（`D:\16037\Dev\Android\sdk`，含 platform-tools / platforms;android-36 / build-tools;36.0.0） |
| JDK | 21（`D:\Programs\Java\jdk-21.0.12.1+1`，**不是** PATH 上的 JDK 8） |
| Gradle | 走代理 `127.0.0.1:7897`（配置在 `C:\Users\16037\.gradle\gradle.properties`） |

## 进度

- [x] M1：theme + 组件 + 首页 + 五页外壳 + 顶栏/边缘/大标题/切页动效
- [x] v0.2.0：PageView 左右切页 + 渐进式运动、明暗改浮层三选一、消息分段动画、版本更新历史、顶栏去底色与横线、Dock 玻璃层
- [x] v0.3.0：应用内更新（检查 → 下载 → 唤起系统安装器）
- [x] v0.4.0：顶栏与边缘的两层模糊合并为一层；Dock 指示胶囊跟手、按压形变、拖动切页
- [x] v0.6.0：课表数据骨架 —— 本地存储、手动录入、周视图接真数据、课块详情浮层、按来源合并
- [ ] M2 剩余：粘贴导入与教务读取两条数据源、侧滑式详情（.dg-sheet + Hero）
- [ ] M3：服务页搜索与折叠的真实数据
- [ ] M4：Android 真机验收（apk 已出，应用宝安装需手点确认）
- [ ] iOS：需要 macOS
- [ ] 鸿蒙：按决定另起 ArkTS/Web，不在本工程

## 三个已知的技术坑（改 Dock / 顶栏前先看）

1. **`Container(decoration: BoxDecoration(gradient: …, boxShadow: …))` 配 `clipBehavior` 会让子件在 CanvasKit 下不绘制**（Dock 变空白）。v0.4.0 改成 `ClipRRect → BackdropFilter → Container(color)`，顶部高光单独用 `DecoratedBox(gradient)` 画在 Stack 里，两条都正常。
2. **`BackdropFilter` 不能叠**：同一屏三层以上会把 CanvasKit 卡住，滚轮完全无响应（v0.4.0 实测）。现在顶/底各最多两层（主层 + 44px 羽化带）。
3. **`ShaderMask(BlendMode.dstIn)` 包 `BackdropFilter` 在 CanvasKit 下无效**：白色渐变会被当 `srcOver` 画出来，整块变白。要做模糊衰减只能靠分层叠加，或者上 fragment shader。

这三条已记录在 `../大三上/莞工统一App方案/文档-App需求清单与实现状态-2026-11-10.md`。
