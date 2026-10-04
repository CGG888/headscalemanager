/// Utility functions for string manipulation.
extension StringUtils on String {
  /// Extracts the base domain from a URL string.
  ///
  /// For example:
  /// - 'https://headscale.example.com:8080' -> 'example.com'
  /// - 'http://localhost:8080' -> 'localhost'
  /// - 'https://sub.domain.co.uk' -> 'domain.co.uk'
  String? extractBaseDomain() {
    try {
      final uri = Uri.parse(this);
      final host = uri.host;

      // Handle IP addresses or localhost
      if (host.contains(RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')) ||
          host == 'localhost') {
        return host;
      }

      // Split by dot and take the last two parts for common domains (e.g., example.com)
      // This is a simplification and might not cover all TLDs (e.g., .co.uk) perfectly.
      final parts = host.split('.');
      if (parts.length >= 2) {
        return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
      }
      return host; // Fallback
    } catch (e) {
      // Handle invalid URL format
      return null;
    }
  }
}

/// 把用户名转成 **Headscale 策略里合法的用户引用**。
///
/// Headscale 的策略解析器要求每个用户引用都必须含 `@`
/// （语义：`alice@` = 「alice 名下的所有设备」）。本地（CLI）创建的用户名通常是
/// `lcmyhome` 这种不含 `@` 的形式，直接写进策略会被服务端拒绝：
///
///   `setting policy: parsing policy: ... json: cannot unmarshal JSON object into
///    Go v2.Group within "/groups": username must contain @,got:"lcmyhome"`
///
/// 已经含 `@` 的名字（例如 OIDC 用户的邮箱）原样返回，避免出现 `a@b@`。
String headscaleUserRef(String userName) =>
    userName.contains('@') ? userName : '$userName@';

/// Normalise un nom d'utilisateur en supprimant le domaine de l'e-mail,
/// en le mettant en minuscules et en remplaçant les caractères non-alphanumériques (dont '.') par des tirets.
/// Conforme aux exigences de nommage des tags et groupes Headscale/Tailscale.
///
/// Par exemple:
/// - 'User@example.com' -> 'user'
/// - 'marine.leclerc.pro@gmail.com' -> 'marine-leclerc-pro'
/// - 'Jean.Dupont@synology.me' -> 'jean-dupont'
String normalizeUserName(String userName) {
  final localPart =
      userName.contains('@') ? userName.split('@').first : userName;
  var sanitized = localPart.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
  sanitized = sanitized.replaceAll(RegExp(r'-+'), '-');
  if (sanitized.startsWith('-')) sanitized = sanitized.substring(1);
  if (sanitized.endsWith('-')) {
    sanitized = sanitized.substring(0, sanitized.length - 1);
  }
  return sanitized.isEmpty ? 'user' : sanitized;
}

/// Validation RFC 1123 pour les sous-domaines DNS.
///
/// Règles :
/// - Contient uniquement des lettres minuscules, chiffres, et tirets.
/// - Ne commence pas ni ne finit par un tiret.
/// - Longueur max 63 caractères.
final RegExp _dns1123Regex = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');

bool isValidDns1123Subdomain(String value) {
  return _dns1123Regex.hasMatch(value);
}

// Basic email regex for user name validation
final RegExp _emailRegex =
    RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

bool isValidEmail(String value) {
  return _emailRegex.hasMatch(value);
}

/// Headscale accepte soit un nom DNS (bob), soit un email (bob@domain.com) selon la config.
bool isValidHeadscaleUser(String value) {
  return isValidDns1123Subdomain(value) || isValidEmail(value);
}

/// Nettoie une chaîne pour la rendre conforme à la RFC 1123.
/// Remplace les caractères invalides par des tirets et s'assure des règles de début/fin.
String sanitizeDns1123Subdomain(String value) {
  var sanitized = value.toLowerCase();

  // Remplace tout ce qui n'est pas a-z, 0-9 par des tirets
  sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9]'), '-');

  // Supprime les tirets multiples (ex: 'te--st' -> 'te-st')
  sanitized = sanitized.replaceAll(RegExp(r'-+'), '-');

  // Supprime les tirets de début et de fin
  if (sanitized.startsWith('-')) sanitized = sanitized.substring(1);
  if (sanitized.endsWith('-')) {
    sanitized = sanitized.substring(0, sanitized.length - 1);
  }

  if (sanitized.length > 63) {
    sanitized = sanitized.substring(0, 63);
    if (sanitized.endsWith('-')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
  }

  return sanitized;
}
