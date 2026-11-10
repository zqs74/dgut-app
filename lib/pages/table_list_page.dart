import 'package:flutter/material.dart';

import '../components/dgut_basics.dart';
import '../components/dgut_page_scaffold.dart';
import '../components/dgut_sheet.dart';
import '../model/timetable_data.dart';
import '../store/timetable_repository.dart';
import '../theme/dgut_tokens.dart';

/// 我的课表（L3）：切换、新建、改名、删除。
class TableListPage extends StatefulWidget {
  const TableListPage({super.key});

  @override
  State<TableListPage> createState() => _TableListPageState();
}

class _TableListPageState extends State<TableListPage> {
  final ValueNotifier<DgutScrollInfo> _offset = ValueNotifier<DgutScrollInfo>(
    DgutScrollInfo.zero,
  );

  TimetableRepository get _repo => TimetableRepository.instance;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Future<String?> _askName({String initial = '', required String title}) async {
    final TextEditingController controller = TextEditingController(
      text: initial,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '课表名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _menu(TimetableData table) async {
    final String? action = await showDgutSheet<String>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DgutRow(
            title: '重命名',
            showChevron: false,
            onTap: () => Navigator.of(context).pop('rename'),
          ),
          DgutRow(
            title: '删除',
            showChevron: false,
            showDivider: false,
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'rename') {
      final String? name = await _askName(initial: table.name, title: '重命名');
      if (name != null) await _repo.renameTable(table.id, name);
    } else if (action == 'delete') {
      final bool? sure = await showDgutSheet<bool>(
        context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '删除「${table.name}」',
                style: DgutType.headline.copyWith(color: context.dg.ink),
              ),
            ),
            DgutRow(
              title: '取消',
              showChevron: false,
              onTap: () => Navigator.of(context).pop(false),
            ),
            DgutRow(
              title: '删除',
              showChevron: false,
              showDivider: false,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (sure == true) await _repo.deleteTable(table.id);
    }
  }

  Future<void> _create() async {
    final String? name = await _askName(title: '新建课表');
    if (name == null) return;
    await _repo.createTable(name);
  }

  @override
  Widget build(BuildContext context) {
    final DgutColors c = context.dg;

    return ListenableBuilder(
      listenable: _repo,
      builder: (BuildContext context, Widget? _) {
        return Scaffold(
          backgroundColor: c.bg,
          body: DgutPageScaffold(
            eyebrow: '课表设置',
            title: '我的课表',
            offset: _offset,
            footerHeight: 40,
            onBack: () => Navigator.of(context).maybePop(),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DgutSpace.pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: DgutSpace.s1),
                    for (final TimetableData table in _repo.tables)
                      DgutRow(
                        title: table.name,
                        value: '${table.courses.length} 门',
                        showChevron: false,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (table.id == _repo.activeId)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: c.blue,
                              ),
                            const SizedBox(width: 4),
                            DgutPressable(
                              onTap: () => _menu(table),
                              pressedOpacity: 0.7,
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: c.fill,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.more_horiz_rounded,
                                  size: 20,
                                  color: c.ink2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _repo.switchTable(table.id),
                      ),
                    DgutRow(
                      title: '新建课表',
                      leading: Icon(Icons.add_rounded, size: 18, color: c.blue),
                      showChevron: false,
                      showDivider: false,
                      onTap: _create,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
