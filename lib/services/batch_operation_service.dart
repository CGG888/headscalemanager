import 'package:headscalemanager/models/node.dart';

/// 批量操作的结果。
///
/// 批量操作最容易"做一半失败"：所以这里分别记录成功与失败，而不是返回 bool
/// 或抛出第一个异常——UI 必须能把"哪些成功了、哪些失败、为什么"如实回报给用户。
class BatchResult {
  final List<String> succeeded = [];

  /// 失败的节点名 → 错误描述。
  final Map<String, String> failures = {};

  int get total => succeeded.length + failures.length;
  bool get hasFailures => failures.isNotEmpty;
  bool get allSucceeded => failures.isEmpty && succeeded.isNotEmpty;

  @override
  String toString() => 'BatchResult(ok=${succeeded.length}, failed=${failures.length})';
}

class BatchOperationService {
  const BatchOperationService._();

  /// 对每个节点依次执行 [action]，**单个节点失败不会中断其余节点**：
  /// 失败被记录下来，循环继续。
  ///
  /// [onProgress] 用于 UI 显示进度（已完成数, 总数）。
  static Future<BatchResult> run(
    Iterable<Node> nodes,
    Future<void> Function(Node node) action, {
    void Function(int done, int total)? onProgress,
  }) async {
    final result = BatchResult();
    final list = nodes.toList();

    for (var i = 0; i < list.length; i++) {
      final node = list[i];
      try {
        await action(node);
        result.succeeded.add(node.name);
      } catch (e) {
        result.failures[node.name] = e.toString();
      }
      onProgress?.call(i + 1, list.length);
    }
    return result;
  }

  /// 该节点**申请了但尚未批准**的路由——"批量批准路由"就是把这些补进已批准列表。
  static List<String> pendingRoutes(Node node) => node.availableRoutes
      .where((route) => !node.sharedRoutes.contains(route))
      .toList();

  /// 需要批准路由的节点（没有待批路由的节点会被跳过，避免无意义的请求）。
  static List<Node> nodesWithPendingRoutes(Iterable<Node> nodes) =>
      nodes.where((n) => pendingRoutes(n).isNotEmpty).toList();
}
