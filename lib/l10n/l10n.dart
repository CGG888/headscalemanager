import 'package:flutter/widgets.dart';

/// 应用文案取值层（中文本地化“方案 C”第 1 档）。
///
/// 迁移前全库用 `isFr ? '法语' : 'English'` 这种二元内联三元表达文案，
/// 第三种语言无处安放。这里把它升级为三语取值：`t()` 的第三个参数是中文，
/// 未提供时回退英文，因此可以分批补翻译而不影响已完成的界面。
///
/// 刻意不引入 intl / ARB / codegen：现有 supportedLocales、
/// SharedPreferences 持久化、语言开关逻辑全部复用，构建流程保持不变。
class L10n {
  const L10n(this.locale);

  final Locale locale;

  /// 支持的语言，需与 main.dart 的 supportedLocales 保持一致。
  static const List<Locale> supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('zh'),
  ];

  static const List<String> supportedLanguageCodes = ['fr', 'en', 'zh'];

  static L10n of(BuildContext context) => L10n(Localizations.localeOf(context));

  /// 是否法语。迁移期保留，供无法用 t() 表达的分支使用。
  bool get isFr => locale.languageCode == 'fr';

  String get languageCode => locale.languageCode;

  /// 三语取词；[zh] 未提供时回退 [en]。
  String t(String fr, String en, [String? zh]) {
    switch (locale.languageCode) {
      case 'en':
        return en;
      case 'zh':
        return zh ?? en;
      default:
        return fr;
    }
  }
}

/// 便捷访问：`context.l10n.t('Ajouter', 'Add', '添加')`
extension L10nBuildContext on BuildContext {
  L10n get l10n => L10n(Localizations.localeOf(this));
}
