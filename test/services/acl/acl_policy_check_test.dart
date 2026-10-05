import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/services/acl/acl_policy_check.dart';

/// ACL 策略的本地预检与自动修复。
///
/// 背景：Headscale 要求 `groups` 成员是**含 `@` 的用户引用**（`alice@` = alice 名下的
/// 设备）。写成裸用户名时服务端只在保存时报错：
///   `username must contain @,got:"lcmyhome"`
/// 这里覆盖"保存前就能发现并修好"的这条路径。
void main() {
  group('localIssues', () {
    test('组员缺少 @ 会被指出，位置与取值正确', () {
      final issues = AclPolicyCheck.localIssues(
        '{"groups":{"group:home":["lcmyhome"]}}',
      );
      expect(issues, hasLength(1));
      expect(issues.first.code, AclIssueCode.groupMemberNeedsAt);
      expect(issues.first.path, 'groups."group:home"[0]');
      expect(issues.first.value, 'lcmyhome');
    });

    test('已经含 @ 的成员（邮箱、alice@）不再报问题', () {
      final issues = AclPolicyCheck.localIssues(
        '{"groups":{"group:a":["alice@example.com","bob@"]}}',
      );
      expect(issues, isEmpty);
    });

    test('组名缺少 group: 前缀会被指出', () {
      final issues = AclPolicyCheck.localIssues(
        '{"groups":{"admins":["alice@"]}}',
      );
      expect(issues.map((i) => i.code),
          contains(AclIssueCode.invalidGroupName));
    });

    test('非 JSON 内容报 notJson（例如 huJSON 注释或语法错误）', () {
      expect(AclPolicyCheck.localIssues('{ // comment\n}').single.code,
          AclIssueCode.notJson);
      expect(AclPolicyCheck.localIssues('').single.code, AclIssueCode.notJson);
      expect(AclPolicyCheck.localIssues('[]').single.code, AclIssueCode.notJson);
    });

    test('没有 groups 或成员为空时不报问题', () {
      expect(AclPolicyCheck.localIssues('{}'), isEmpty);
      expect(AclPolicyCheck.localIssues('{"groups":{}}'), isEmpty);
      expect(AclPolicyCheck.localIssues('{"groups":{"group:a":[]}}'), isEmpty);
    });

    test('多个组、多个成员一次性全部列出', () {
      final issues = AclPolicyCheck.localIssues(
        '{"groups":{"group:a":["bob","alice@"],"group:b":["carol"]}}',
      );
      expect(issues, hasLength(2));
      expect(issues.map((i) => i.value).toList(), ['bob', 'carol']);
    });
  });

  group('autoFix', () {
    test('给缺少 @ 的成员补 @', () {
      final fixed = AclPolicyCheck.autoFix('{"groups":{"group:home":["lcmyhome"]}}');
      expect(fixed, isNotNull);
      expect(json.decode(fixed!)['groups']['group:home'], ['lcmyhome@']);
    });

    test('修复后本地预检不再有问题（往返一致）', () {
      const broken = '{"groups":{"group:home":["lcmyhome","alice@example.com"]}}';
      final fixed = AclPolicyCheck.autoFix(broken)!;
      expect(AclPolicyCheck.localIssues(fixed), isEmpty);
      // 已经含 @ 的成员保持不变
      expect(json.decode(fixed)['groups']['group:home'],
          ['lcmyhome@', 'alice@example.com']);
    });

    test('无需修改时返回 null（调用方据此决定是否显示"修复"按钮）', () {
      expect(AclPolicyCheck.autoFix('{"groups":{"group:a":["a@"]}}'), isNull);
      expect(AclPolicyCheck.autoFix('{}'), isNull);
      expect(AclPolicyCheck.autoFix(''), isNull);
      expect(AclPolicyCheck.autoFix('not json'), isNull);
    });

    test('保留策略的其他内容', () {
      const policy = '{"acls":[{"action":"accept","src":["*"],"dst":["*:*"]}],'
          '"groups":{"group:a":["bob"]},"tagOwners":{"tag:x":["group:a"]}}';
      final fixed = AclPolicyCheck.autoFix(policy)!;
      final decoded = json.decode(fixed) as Map<String, dynamic>;
      expect(decoded['acls'], isNotEmpty);
      expect(decoded['tagOwners']['tag:x'], ['group:a']);
      expect(decoded['groups']['group:a'], ['bob@']);
    });
  });
}
