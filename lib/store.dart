import 'package:github/github.dart';
import 'package:where/settings.dart';

part './github_store.dart';

enum TokenStatus { valid, invalid, pending }

abstract class Store {
  final String token;
  static final Map<String, Store> _singletons = {};

  const Store({required this.token});

  Future<TokenStatus> checkTokenStatus();

  static Store? fromToken(String token) {
    if (GithubStore.tokenFormatMatches(token)) {
      return GithubStore(token: token);
    }
    return null;
  }

  static Future<Store?> fromSettings() async {
    final settings = await Settings.getSingleton();

    if (_singletons.containsKey(settings.token)) {
      return _singletons[settings.token];
    }

    final store = fromToken(settings.token);
    if (store != null) {
      _singletons[settings.token] = store;
    }
    return store;
  }
}
