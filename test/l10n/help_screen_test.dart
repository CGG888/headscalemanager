import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/l10n/l10n.dart';
import 'package:headscalemanager/screens/help_screen.dart';

/// 帮助页重构后的冒烟测试：单一页面在三种语言下都要能构建，
/// 且必须显示对应语言的标题（中文用户不应再看到英文/法文帮助页）。
void main() {
  Future<void> pumpHelp(WidgetTester tester, String code) async {
    await tester.pumpWidget(MaterialApp(
      locale: Locale(code),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HelpScreen(),
    ));
    await tester.pump();
  }

  testWidgets('法语帮助页构建并显示法文标题', (tester) async {
    await pumpHelp(tester, 'fr');
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.textContaining('Guide d'), findsWidgets);
  });

  testWidgets('英语帮助页构建并显示英文标题', (tester) async {
    await pumpHelp(tester, 'en');
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.textContaining('Help and User Guide'), findsOneWidget);
  });

  testWidgets('中文帮助页构建并显示中文标题', (tester) async {
    await pumpHelp(tester, 'zh');
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.textContaining('帮助与使用指南'), findsOneWidget);
  });

  testWidgets('中文帮助页不含拉丁语标题残留', (tester) async {
    await pumpHelp(tester, 'zh');
    expect(find.textContaining('Help and User Guide'), findsNothing);
    expect(find.textContaining('Guide d'), findsNothing);
  });
}
