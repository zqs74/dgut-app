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

const String kCurrentVersion = '0.8.0';

const List<ChangelogEntry> kChangelog = [
  ChangelogEntry(
    version: 'v0.8.0',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '新增',
        items: [
          '多课表：新建、切换、改名、删除，课程与学期各自独立',
          '上课时间可以逐节改，改完课表轴和详情立刻跟着变',
        ],
      ),
      ChangelogSection(
        title: '优化',
        items: [
          '旧版单张课表自动迁进「我的课表」，数据不用重录',
        ],
      ),
    ],
  ),

  ChangelogEntry(
    version: 'v0.7.2',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '新增',
        items: [
          '添加与编辑页底部固定保存条，不用滚到底找按钮',
          '撞课时在保存条上方提示与哪门课、哪几周冲突，按钮变「仍然保存」',
          '课程详情可以再加一个时间段',
        ],
      ),
    ],
  ),

  ChangelogEntry(
    version: 'v0.7.1',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '修复',
        items: [
          '周条上今天的小圆点压住周数，改到胶囊下方',
          '「回到本周」换成与底栏同材质的玻璃胶囊',
          '去掉表单里解释性的占位文字',
        ],
      ),
    ],
  ),

  ChangelogEntry(
    version: 'v0.7.0',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '新增',
        items: [
          '课表页按新设计重写：每节 48px，课名、备注与教室都读得清',
          '周末没课时自动收起，周一至周五各列更宽',
          '周条可直接跳周，翻到别的周时右下角出现「回到本周」',
          '课块第三行显示备注（点名、水课），详情页可看周次分布',
          '课表设置页：当前第几周、已添课程、添加课程三个入口',
        ],
      ),
      ChangelogSection(
        title: '优化',
        items: [
          '点课块先进详情、再进编辑，返回逐层退，不再一步跳回课表',
          '长按空白格直接新建，星期与节次已经填好',
          '今天这一列有底色，一条红线标出现在上到哪一节',
        ],
      ),
    ],
  ),  ChangelogEntry(
    version: 'v0.6.3',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '修复',
        items: [
          '修复二级页面标题收起时与顶栏标题错位、出现两个标题的问题',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.6.2',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '修复',
        items: [
          '修复二级页面返回按钮压住上方灰色小标签的问题',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.6.1',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '修复',
        items: [
          '修复添加课程页整页文字带一条黄线的问题',
          '修复星期与节次选项被拉满整行、看不出是按钮的问题',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.6.0',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '新增',
        items: [
          '课表可以自己建：填课程名、星期、节次与上课周，单周和跳周都能表达',
          '点课块查看这门课的全部时段、教师与教室，可逐段编辑或整门删除',
          '本周概况显示真实的门数、节数与撞课数',
        ],
      ),
      ChangelogSection(
        title: '优化',
        items: [
          '「第几周」按开学日期自动算，不再写死',
          '非本周的课淡显并在左侧标虚线，一眼看出这周不上',
        ],
      ),
    ],
  ),  ChangelogEntry(
    version: 'v0.5.3',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '调整',
        items: [
          '二级页的小标题与返回按钮同一条中轴，横向只剩 8px',
          '一级页的顶栏标题仍贴底，不跟着往上提',
          '大标题收缩的落点钉死，交接时不再跳位置',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.5.2',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '优化',
        items: [
          '安装前直接标出下载到的版本号，装完能核对',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.5.1',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '调整',
        items: [
          '更新失败只说实话：连不上 GitHub 就写连不上，不再解释原因',
          '删掉课表、消息、检查更新里解释性的一句说明',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.5.0',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '新增',
        items: [
          '平板适配：宽屏改为左侧导航栏 + 居中内容区，不再锁在 460 宽',
        ],
      ),
      ChangelogSection(
        title: '优化',
        items: [
          '内容按窗口宽度分三档：手机铺满、平板 720、大屏 840 居中',
          '底部 Dock 抬起一个手势条的高度，不再被系统横条压住',
        ],
      ),
    ],
  ),
  ChangelogEntry(
    version: 'v0.4.3',
    date: '2026-11-10',
    sections: [
      ChangelogSection(
        title: '修复',
        items: [
          '安装包改下到 cache 目录，修掉「Failed to find configured root」导致装不上',
        ],
      ),
    ],
  ),
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
