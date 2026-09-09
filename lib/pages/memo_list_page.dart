import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../models/memo.dart';
import '../providers/alarm_provider.dart';
import '../providers/memo_provider.dart';
import '../widgets/empty_view.dart';
import '../widgets/memo_card.dart';
import '../widgets/platform_adaptive.dart';
import 'memo_edit_page.dart';
import 'settings_page.dart';

/// =============================================================
/// 备忘录列表页（首页第一个标签页）
/// -------------------------------------------------------------
/// 功能：搜索、排序、勾选完成、滑动删除、新增
/// =============================================================
class MemoListPage extends StatelessWidget {
  const MemoListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // watch：数据变化时自动重建
    final MemoProvider memoProvider = context.watch<MemoProvider>();
    final AlarmProvider alarmProvider = context.watch<AlarmProvider>();
    final List<Memo> list = memoProvider.visibleMemos;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('工作备忘录'),
        actions: <Widget>[
          // 排序菜单
          PopupMenuButton<MemoSortMode>(
            icon: const Icon(Icons.sort),
            tooltip: '排序方式',
            onSelected: (MemoSortMode mode) =>
                context.read<MemoProvider>().setSortMode(mode),
            itemBuilder: (BuildContext context) {
              return MemoSortMode.values.map((MemoSortMode mode) {
                return PopupMenuItem<MemoSortMode>(
                  value: mode,
                  child: Row(
                    children: <Widget>[
                      Icon(
                        mode == memoProvider.sortMode
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(mode.label),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          // 设置入口（权限检查、铃声试听）
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const _SearchBar(),
          // 统计条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '共 ${list.length} 条 · 待办 ${memoProvider.pendingCount} 条',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyView(
                    icon: memoProvider.keyword.isEmpty
                        ? Icons.note_alt_outlined
                        : Icons.search_off,
                    title: memoProvider.keyword.isEmpty
                        ? '还没有备忘录'
                        : '没有找到匹配的备忘录',
                    subtitle: memoProvider.keyword.isEmpty
                        ? '点击右下角按钮，记录第一条工作笔记吧'
                        : '换个关键词试试，标题和正文都会被搜索',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                    itemCount: list.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Memo memo = list[index];
                      return MemoCard(
                        memo: memo,
                        // 查出绑定的闹钟，用于展示提醒时间
                        boundAlarm: memo.alarmId == null
                            ? null
                            : alarmProvider.byId(memo.alarmId!),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MemoEditPage(memo: memo),
                            ),
                          );
                        },
                        onToggleDone: () =>
                            context.read<MemoProvider>().toggleDone(memo.id),
                        onDelete: () => _confirmDelete(context, memo),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MemoEditPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('新建备忘录'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// 删除确认
  Future<void> _confirmDelete(BuildContext context, Memo memo) async {
    final bool? ok = await showAdaptiveConfirmDialog(
      context: context,
      title: '删除备忘录',
      content: '确定删除「${memo.title.isEmpty ? '无标题' : memo.title}」吗？\n其绑定的提醒闹钟也会一并删除。',
      confirmText: '删除',
      destructive: true,
    );
    if (ok == true && context.mounted) {
      await context.read<MemoProvider>().remove(memo.id);
      if (context.mounted) {
        showAdaptiveToast(context, '已删除');
      }
    }
  }
}

/// 搜索框（局部状态，避免整个列表被反复重建）
class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索标题或正文内容',
          hintStyle: const TextStyle(fontSize: 14, color: AppColors.doneGrey),
          border: InputBorder.none,
          icon: const Icon(Icons.search, color: AppColors.textSecondary),
          // 有内容时显示清除按钮
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _controller.clear();
                    context.read<MemoProvider>().setKeyword('');
                    setState(() {});
                  },
                ),
        ),
        onChanged: (String value) {
          context.read<MemoProvider>().setKeyword(value);
          setState(() {});
        },
      ),
    );
  }
}
