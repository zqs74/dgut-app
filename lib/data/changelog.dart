/// 版本更新记录（App 内展示 + 与根目录 CHANGELOG.md 同源）
///
/// 书写规范见 `大三上/莞工统一App方案/文档-版本更新书写规范-2026-11-10.md`：
/// 版本头只写版本号 + 日期；正文按 新增 / 优化 / 调整 / 修复 / 移除 五类归并，
/// 空分组不写；一条一句话，动词开头，≤ 40 字，写用户可观察的变化。
class ChangelogSection {
  const ChangelogSection({required this.title, required this.items});

  final String title;
  final List<String> items;
}

class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.sections,
  });

  final String version;
  final String date;
  final List<ChangelogSection> sections;
}

const String kCurrentVersion = '0.4.2';

const List<ChangelogEntry> kChangelog = [
  ChangelogEntry(
    version: 'v0.4.2',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '修复',
        items: [
          '顶栏只留一层模糊，去掉下沿那条羽化带',
          '大标题收起时不留下半透明残影，缩到最小后交给顶栏标题',
          '版本更新历史的返回按钮改成玻璃圆钮，不再压住页面标题',
        ],
      ),
      ChangelogSection(
        title: '优化',
        items: [
          '底部选中胶囊放大到 60×48，图标与文字之间留出间距',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.4.1',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '修复',
        items: [
          '缺「安装未知应用」权限时直接给「去开启」，跳到系统授权页，回来自动继续',
          '检查更新的失败原因改成看得懂的说法，不再直接抛 HandshakeException',
        ],
      ),
      ChangelogSection(
        title: '调整',
        items: [
          '下载进度里那行灰色提示去掉',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.4.0',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '新增',
        items: [
          '在底部 Dock 上左右拖动即可切页，松手才提交',
          '再点当前 tab 回到页面顶部',
        ],
      ),
      ChangelogSection(
        title: '优化',
        items: [
          '底部指示胶囊跟手移动，按下即跟随手指',
          'Dock 按压时整条轻微上浮拉伸，图标颜色随手位渐变',
          'Dock 收窄为更紧凑的胶囊，五个入口重新分配间距',
        ],
      ),
      ChangelogSection(
        title: '修复',
        items: [
          '顶栏与边缘各画一次模糊造成的两层，合并为一层',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.3.0',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '新增',
        items: [
          '安卓端支持应用内更新：检查到新版可就地下载并安装',
        ],
      ),
      ChangelogSection(
        title: '调整',
        items: [
          '「我的」新增「检查更新」入口，当前版本号同时显示在这里',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.2.0',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '新增',
        items: [
          '页面支持左右滑动切换，内容随手指渐进移动',
          '「我的」新增版本更新历史，按时间轴倒序排列',
          '外观改为底部三选一，当前档位直接显示在列表右侧',
        ],
      ),
      ChangelogSection(
        title: '优化',
        items: [
          '大标题滚动时缩小淡出，不再整块滚出屏幕',
          '底部 Dock 玻璃更透，内容从下方经过时能看见模糊',
          '消息页切换待办与通知时横向滑入滑出，不再硬切',
        ],
      ),
      ChangelogSection(
        title: '调整',
        items: [
          '顶栏去掉叠加的白色底层，只保留模糊',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.1.0',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '新增',
        items: [
          '五页骨架：首页、课表、服务、消息、我的',
          '首页今日时间线，进行中的课加重显示',
          '课表 12 节 × 7 天网格，撞课在同一格上下叠放',
          '课表非本周课程淡化并改虚线边，一眼区分',
          '服务页 22 项按四组折叠，默认只展开第一组',
          '消息页把最急一条升为主块，其余压成紧凑行',
          '我的页用「还差 22 分」一个总数字加三条进度',
        ],
      ),
      ChangelogSection(
        title: '优化',
        items: [
          '顶栏、底部 Dock、上下边缘采用玻璃材质',
          '滚动时顶栏浮现并加强模糊，内容从玻璃下穿过',
          '支持浅色与深色两套配色，跟随系统切换',
        ],
      ),
    ],
  ),
];
