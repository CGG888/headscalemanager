import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/l10n/l10n.dart';

void main() {
  const fr = L10n(Locale('fr'));
  const en = L10n(Locale('en'));
  const zh = L10n(Locale('zh'));

  group('L10n.t', () {
    test('法语返回第一参数', () {
      expect(fr.t('Ajouter', 'Add', '添加'), 'Ajouter');
    });

    test('英语返回第二参数', () {
      expect(en.t('Ajouter', 'Add', '添加'), 'Add');
    });

    test('中文返回第三参数', () {
      expect(zh.t('Ajouter', 'Add', '添加'), '添加');
    });

    test('中文缺省时回退英语，便于分批补翻译', () {
      expect(zh.t('Ajouter', 'Add'), 'Add');
    });

    test('未知语言回退法语', () {
      expect(const L10n(Locale('de')).t('Ajouter', 'Add', '添加'), 'Ajouter');
    });

    test('isFr 只对法语为真', () {
      expect(fr.isFr, isTrue);
      expect(en.isFr, isFalse);
      expect(zh.isFr, isFalse);
    });
  });

  group('ApiOperation 标签', () {
    test('每个操作在三种语言下都非空，且中文与法文不同（防漏翻）', () {
      for (final op in ApiOperation.values) {
        for (final l in [fr, en, zh]) {
          expect(op.label(l).trim(), isNotEmpty, reason: '$op / ${l.languageCode}');
        }
        expect(op.label(zh), isNot(op.label(fr)), reason: '$op 缺少中文');
        expect(op.label(en), isNot(op.label(fr)), reason: '$op 缺少英文');
      }
    });
  });

  group('HeadscaleApiException 消息', () {
    test('中文消息：操作名 + 状态码 + 响应体', () {
      const e = HeadscaleApiException(
        operation: ApiOperation.loadNodes,
        l10n: zh,
        statusCode: 401,
        rawBody: 'unauthorized',
      );
      expect(e.toString(), '加载节点失败。状态码：401，响应：unauthorized');
    });

    test('法语/英语消息各自成形', () {
      const f = HeadscaleApiException(
        operation: ApiOperation.loadNodes,
        l10n: fr,
        statusCode: 500,
        rawBody: 'boom',
      );
      const g = HeadscaleApiException(
        operation: ApiOperation.loadNodes,
        l10n: en,
        statusCode: 500,
        rawBody: 'boom',
      );
      expect(f.toString(), contains('charger les nœuds'));
      expect(f.toString(), contains('Statut : 500'));
      expect(g.toString(), contains('load nodes'));
      expect(g.toString(), contains('Status: 500'));
    });

    test('无 HTTP 响应时不出现状态码占位', () {
      const e = HeadscaleApiException(
        operation: ApiOperation.fetchVersion,
        l10n: zh,
      );
      expect(e.toString(), '获取服务器版本失败');
    });

    test('detail 会附在操作名后', () {
      const e = HeadscaleApiException(
        operation: ApiOperation.expireKey,
        l10n: zh,
        detail: '42',
        statusCode: 404,
        rawBody: 'not found',
      );
      expect(e.toString(), startsWith('使密钥过期（42）失败'));
    });

    test('message() 可以用另一种语言重新渲染（界面切语言后仍能正确展示）', () {
      const e = HeadscaleApiException(
        operation: ApiOperation.deleteUser,
        l10n: fr,
        statusCode: 404,
        rawBody: 'x',
      );
      expect(e.message(zh), startsWith('删除用户失败'));
      expect(e.toString(), startsWith('Échec : supprimer l\'utilisateur'));
    });

    test('rawBody 保持服务端原文，供逻辑判断使用', () {
      const e = HeadscaleApiException(
        operation: ApiOperation.setTags,
        l10n: zh,
        statusCode: 500,
        rawBody: 'tag not permitted in tagOwners',
      );
      expect(e.rawBody, 'tag not permitted in tagOwners');
    });
  });
}
