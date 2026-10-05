import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/services/policy_diff_service.dart';

/// 策略差异计算（保存前看清改动，避免误删规则）。
void main() {
  List<PolicyChange> diff(String a, String b) => PolicyDiffService.diff(a, b);

  test('新增与删除规则分别报告', () {
    final changes = diff(
      '{"acls":[{"action":"accept","src":["a"],"dst":["b:22"]}]}',
      '{"acls":[{"action":"accept","src":["c"],"dst":["d:22"]}]}',
    );
    expect(changes, hasLength(2));
    expect(changes.where((c) => c.kind == PolicyChangeKind.removed), hasLength(1));
    expect(changes.where((c) => c.kind == PolicyChangeKind.added), hasLength(1));
    expect(changes.first.path, 'acls[]');
  });

  test('键顺序不同不算变更（规范化比较）', () {
    final changes = diff(
      '{"acls":[{"action":"accept","src":["a"],"dst":["b:22"]}]}',
      '{"acls":[{"dst":["b:22"],"src":["a"],"action":"accept"}]}',
    );
    expect(changes, isEmpty);
  });

  test('组员变化报告为 changed，并给出新旧值', () {
    final changes = diff(
      '{"groups":{"admins":["alice@","bob@"]}}',
      '{"groups":{"admins":["alice@"]}}',
    );
    expect(changes, hasLength(1));
    expect(changes.first.kind, PolicyChangeKind.changed);
    expect(changes.first.path, 'groups.admins');
    expect(changes.first.detail, contains('alice@'));
  });

  test('新增与删除整个组分别报告', () {
    final added = diff('{"groups":{}}', '{"groups":{"dev":["a@"]}}');
    expect(added.single.kind, PolicyChangeKind.added);
    expect(added.single.path, 'groups.dev');

    final removed = diff('{"groups":{"dev":["a@"]}}', '{"groups":{}}');
    expect(removed.single.kind, PolicyChangeKind.removed);
  });

  test('顶层键新增/删除', () {
    final changes = diff('{}', '{"tagOwners":{"tag:server":["group:admins"]}}');
    expect(changes.single.kind, PolicyChangeKind.added);
    expect(changes.single.path, 'tagOwners');
  });

  test('完全相同的策略没有差异', () {
    const policy =
        '{"groups":{"a":["x@"]},"acls":[{"action":"accept","src":["group:a"],"dst":["*:443"]}]}';
    expect(diff(policy, policy), isEmpty);
  });

  test('策略不可解析时返回空列表（不抛异常）', () {
    expect(diff('{bad', '{}'), isEmpty);
    expect(diff('{}', '{bad'), isEmpty);
  });

  test('超长规则被截断，保证列表可读', () {
    final long = List.generate(80, (i) => 'tag:t$i').join(',');
    final changes = diff(
      '{}',
      '{"acls":[{"action":"accept","src":["$long"],"dst":["*:22"]}]}',
    );
    expect(changes.single.detail.length, lessThanOrEqualTo(160));
    expect(changes.single.detail, endsWith('...'));
  });
}
