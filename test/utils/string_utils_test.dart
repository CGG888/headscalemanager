import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/utils/string_utils.dart';

void main() {
  group('normalizeUserName', () {
    test('normalise les noms simples sans email', () {
      expect(normalizeUserName('jean'), 'jean');
      expect(normalizeUserName('Jean'), 'jean');
    });

    test('normalise les emails standards', () {
      expect(normalizeUserName('jean@synology.me'), 'jean');
      expect(normalizeUserName('Bob@Example.com'), 'bob');
    });

    test('normalise les emails avec points multiples (cas OIDC)', () {
      expect(
        normalizeUserName('marine.leclerc.pro@gmail.com'),
        'marine-leclerc-pro',
      );
      expect(
        normalizeUserName('first.middle.last@domain.org'),
        'first-middle-last',
      );
    });

    test('remplace les caractères spéciaux et évite les tirets consécutifs', () {
      expect(normalizeUserName('john_doe+test@gmail.com'), 'john-doe-test');
      expect(normalizeUserName('..alice--bob..'), 'alice-bob');
    });

    test('fournit un repli sur user si chaîne vide ou uniquement caractères spéciaux', () {
      expect(normalizeUserName(''), 'user');
      expect(normalizeUserName('...'), 'user');
      expect(normalizeUserName('@gmail.com'), 'user');
    });
  });
}
