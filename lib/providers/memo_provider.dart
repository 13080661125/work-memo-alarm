import 'package:flutter/foundation.dart';

import '../models/memo.dart';
import '../services/storage_service.dart';

/// =============================================================
/// 备忘录状态管理
/// -------------------------------------------------------------
/// 所有对备忘录的增删改查都通过它完成：
///   修改内存数据 → 写入本地存储 → notifyListeners() 刷新界面
/// =============================================================
class MemoProvider extends ChangeNotifier {
  MemoProvider(this._storage);

  final StorageService _storage;

  List<Memo> _memos = <Memo>[];
  String _keyword = '';
  MemoSortMode _sortMode = MemoSortMode.createDesc;

  /// 删除备忘录时，需要同步删除它绑定的闹钟。
  /// 这里用回调解耦，避免 MemoProvider 直接依赖 AlarmProvider 造成循环引用。
  Future<void> Function(String memoId)? deleteLinkedAlarm;

  /// 从本地读取数据（在 main 中调用一次）
  void load() {
    _memos = _storage.loadMemos();
    _sortMode = _storage.loadSortMode();
    notifyListeners();
  }

  /// 全部备忘录
  List<Memo> get memos => List<Memo>.unmodifiable(_memos);

  /// 搜索关键词
  String get keyword => _keyword;

  /// 当前排序方式
  MemoSortMode get sortMode => _sortMode;

  /// 未完成数量（首页统计用）
  int get pendingCount => _memos.where((Memo m) => !m.done).length;

  /// 界面真正展示的列表：先按关键词过滤，再按排序方式排序
  List<Memo> get visibleMemos {
    final String kw = _keyword.trim().toLowerCase();
    List<Memo> result = _memos;

    // 搜索：同时匹配标题和正文，忽略大小写
    if (kw.isNotEmpty) {
      result = result.where((Memo m) {
        return m.title.toLowerCase().contains(kw) ||
            m.content.toLowerCase().contains(kw);
      }).toList();
    }

    // 排序
    final List<Memo> sorted = List<Memo>.from(result);
    switch (_sortMode) {
      case MemoSortMode.createDesc:
        sorted.sort((Memo a, Memo b) => b.createdAt.compareTo(a.createdAt));
        break;
      case MemoSortMode.createAsc:
        sorted.sort((Memo a, Memo b) => a.createdAt.compareTo(b.createdAt));
        break;
      case MemoSortMode.priorityDesc:
        sorted.sort((Memo a, Memo b) {
          final int cmp = b.priority.weight.compareTo(a.priority.weight);
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
        break;
      case MemoSortMode.priorityAsc:
        sorted.sort((Memo a, Memo b) {
          final int cmp = a.priority.weight.compareTo(b.priority.weight);
          return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
    return sorted;
  }

  /// 设置搜索关键词
  void setKeyword(String value) {
    _keyword = value;
    notifyListeners();
  }

  /// 切换排序方式（同时持久化，下次启动保持）
  Future<void> setSortMode(MemoSortMode mode) async {
    _sortMode = mode;
    await _storage.saveSortMode(mode);
    notifyListeners();
  }

  /// 根据 id 查找
  Memo? byId(String id) {
    for (final Memo m in _memos) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// 新增备忘录
  Future<void> add(Memo memo) async {
    _memos.add(memo);
    await _persist();
  }

  /// 更新备忘录（用新对象替换同 id 的旧对象）
  Future<void> update(Memo memo) async {
    final int index = _memos.indexWhere((Memo m) => m.id == memo.id);
    if (index >= 0) {
      _memos[index] = memo;
    } else {
      _memos.add(memo);
    }
    await _persist();
  }

  /// 删除备忘录（同时回调删除关联闹钟）
  Future<void> remove(String id) async {
    _memos.removeWhere((Memo m) => m.id == id);
    await deleteLinkedAlarm?.call(id);
    await _persist();
  }

  /// 勾选/取消完成
  Future<void> toggleDone(String id) async {
    final Memo? memo = byId(id);
    if (memo == null) return;
    memo.done = !memo.done;
    memo.updatedAt = DateTime.now();
    await _persist();
  }

  /// 绑定 / 解绑提醒（保存闹钟 id）
  Future<void> setAlarmId(String memoId, String? alarmId) async {
    final Memo? memo = byId(memoId);
    if (memo == null) return;
    memo.alarmId = alarmId;
    memo.updatedAt = DateTime.now();
    await _persist();
  }

  /// 写入本地存储并通知界面刷新
  Future<void> _persist() async {
    await _storage.saveMemos(_memos);
    notifyListeners();
  }
}
