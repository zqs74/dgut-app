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
| `?seg=1` | 消息页默认停在「通知」

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
├── data/changelog.dart    版本记录数据（与根目录 CHANGELOG.md 同源）
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
- [ ] M2：课表数据层（三源导入）、课块详情 sheet
- [ ] M3：服务页搜索与折叠的真实数据
- [ ] M4：Android 真机验收（apk 已出，应用宝安装需手点确认）
- [ ] iOS：需要 macOS
- [ ] 鸿蒙：按决定另起 ArkTS/Web，不在本工程

## 两个已知的技术坑（改 Dock / 顶栏前先看）

1. **Dock 的材质不能用 `BoxDecoration.gradient`**：在这个 Stack 层级里，渐变会让整层子件在 CanvasKit 下不绘制（Dock 变成一块空白）。用 `color` + 顶层高光条替代。
2. **Dock 的材质也不要用 `BackdropFilter`**：同样会让子件消失（v0.1 时可用，改成 PageView 后失效）。顶栏的 BackdropFilter 没问题（它的 child 只有一个 Text）。

这两条已记录在 `../大三上/莞工统一App方案/文档-App需求清单与实现状态-2026-11-10.md`。
