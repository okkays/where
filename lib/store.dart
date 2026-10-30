import 'dart:convert';

import 'package:github/github.dart';

import './share.dart';
import './settings.dart';

part './github_store.dart';

enum TokenStatus { valid, invalid, pending }

abstract class Store {
  final String token;
  static final Map<String, Store> _singletons = {};

  const Store({required this.token});

  Future<TokenStatus> checkTokenStatus();

  /// Gets a share for another user by ID.
  Future<Share?> shareFromId(String id);

  /// Gets a share for the current user.
  /// Only works if the token is valid and we're able to reach the storage provider.
  Future<Share?> getOrCreateMyShare();

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
