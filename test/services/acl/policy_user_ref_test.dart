import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/services/standard_acl_generator_service.dart';

/// Headscale 的策略解析器要求**用户引用必须含 `@`**（`alice@` = alice 名下的设备），
/// 否则保存策略时服务端返回 500：
///   `username must contain @,got:"lcmyhome"`
///
/// 仓库里既有的测试用例用户名清一色是邮箱形态（`jean@synology.me`），恰好都含 `@`，
/// 因此「本地创建的用户名不含 @」这条路径一直没被覆盖。本文件专门覆盖它。
void main() {
  // 本地（CLI 创建）用户：Headscale 里就是这种没有 @ 的名字，且没有 email
  final localUser = User(id: 'u1', name: 'lcmyhome');
  // OIDC 用户：名字本身就是邮箱，已含 @
  final oidcUser =
      User(id: 'u2', name: 'alice@example.com', email: 'alice@example.com');

  group('groups 成员必须是合法的 Headscale 用户引用', () {
    test('本地用户名（不含 @）应被补成 name@', () {
      final infra = PolicyInfrastructureBuilder.buildStandard(
        users: [localUser],
        nodes: const [],
      );

      expect(infra.groups.keys, contains('group:lcmyhome'));
      expect(infra.groups['group:lcmyhome'], contains('lcmyhome@'),
          reason: '缺少 @ 会被 Headscale 拒绝：username must contain @');
    });

    test('邮箱形态的用户名保持原样，不会被二次加 @', () {
      final infra = PolicyInfrastructureBuilder.buildStandard(
        users: [oidcUser],
        nodes: const [],
      );

      expect(infra.groups['group:alice'], contains('alice@example.com'));
      expect(infra.groups.values.expand((e) => e),
          isNot(contains('alice@example.com@')));
    });

    test('Standard 引擎生成的 groups 成员全部含 @', () {
      final policy = StandardAclGeneratorService()
          .generatePolicy(users: [localUser], nodes: const []);
      _expectAllGroupMembersValid(policy);
    });

    test('Legacy 引擎生成的 groups 成员全部含 @', () {
      final policy = NewAclGeneratorService()
          .generatePolicy(users: [localUser], nodes: const []);
      _expectAllGroupMembersValid(policy);
    });
  });
}

void _expectAllGroupMembersValid(Map<String, dynamic> policy) {
  final groups = (policy['groups'] as Map).cast<String, dynamic>();
  expect(groups, isNotEmpty, reason: '策略里应当包含 groups');
  for (final entry in groups.entries) {
    final members = (entry.value as List).cast<String>();
    expect(members, isNotEmpty, reason: '${entry.key} 不应为空');
    for (final member in members) {
      expect(member, contains('@'),
          reason: '${entry.key} 的成员「$member」缺少 @，Headscale 会拒绝该策略');
    }
  }
}
