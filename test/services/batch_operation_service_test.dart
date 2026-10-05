import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/batch_operation_service.dart';

/// 批量操作的结果聚合。
///
/// 关键行为：**单个节点失败不会中断其余节点**，且成功/失败都被记录下来——
/// 批量删节点或过期密钥时，"做了一半"是最需要如实回报的情况。
void main() {
  Node node(String id, String name,
          {List<String> approved = const [], List<String> available = const []}) =>
      Node(
        id: id,
        machineKey: 'mk$id',
        hostname: name,
        name: name,
        user: 'u',
        userId: '1',
        ipAddresses: const ['100.64.0.1'],
        online: true,
        lastSeen: DateTime.now(),
        sharedRoutes: approved,
        availableRoutes: available,
        isExitNode: false,
        isLanSharer: false,
        tags: const [],
        baseDomain: 'example.com',
        endpoint: '',
      );

  group('run', () {
    test('全部成功时只记录成功', () async {
      final nodes = [node('1', 'a'), node('2', 'b')];
      final applied = <String>[];
      final result = await BatchOperationService.run(nodes, (n) async {
        applied.add(n.name);
      });

      expect(result.succeeded, ['a', 'b']);
      expect(result.failures, isEmpty);
      expect(result.allSucceeded, isTrue);
      expect(applied, ['a', 'b']);
    });

    test('单个失败不影响其余节点，且记录失败原因', () async {
      final nodes = [node('1', 'a'), node('2', 'b'), node('3', 'c')];
      final result = await BatchOperationService.run(nodes, (n) async {
        if (n.name == 'b') throw Exception('boom');
      });

      expect(result.succeeded, ['a', 'c']);
      expect(result.failures.keys, ['b']);
      expect(result.failures['b'], contains('boom'));
      expect(result.total, 3);
      expect(result.hasFailures, isTrue);
      expect(result.allSucceeded, isFalse);
    });

    test('全部失败时成功列表为空', () async {
      final result = await BatchOperationService.run(
          [node('1', 'a')], (n) async => throw Exception('down'));
      expect(result.succeeded, isEmpty);
      expect(result.failures, hasLength(1));
      expect(result.allSucceeded, isFalse);
    });

    test('报告进度', () async {
      final progress = <int>[];
      await BatchOperationService.run(
        [node('1', 'a'), node('2', 'b'), node('3', 'c')],
        (n) async {},
        onProgress: (done, total) => progress.add(done),
      );
      expect(progress, [1, 2, 3]);
    });

    test('空列表不报错', () async {
      final result = await BatchOperationService.run([], (n) async {});
      expect(result.total, 0);
      expect(result.allSucceeded, isFalse); // 什么都没做，不该声称成功
    });
  });

  group('待批准路由', () {
    test('pendingRoutes 只列出未批准的', () {
      final n = node('1', 'a',
          approved: ['10.0.0.0/8'], available: ['10.0.0.0/8', '192.168.1.0/24']);
      expect(BatchOperationService.pendingRoutes(n), ['192.168.1.0/24']);
    });

    test('nodesWithPendingRoutes 跳过没有待批路由的节点', () {
      final withPending = node('1', 'a', available: ['192.168.1.0/24']);
      final noPending =
          node('2', 'b', approved: ['10.0.0.0/8'], available: ['10.0.0.0/8']);
      final result =
          BatchOperationService.nodesWithPendingRoutes([withPending, noPending]);
      expect(result.map((n) => n.name), ['a']);
    });
  });
}
