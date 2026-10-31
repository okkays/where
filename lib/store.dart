import 'dart:convert';

import 'package:flutter/material.dart';
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
  Future<Share?> shareFromId(String id, {bool isMine = false});

  /// Gets a share for the current user.
  /// Only works if the token is valid and we're able to reach the storage provider.
  Future<Share?> getOrCreateMyShare();

  Future<Duration> getRefreshInterval();

  Future<void> refreshSharesFromStore() async {
    final settings = await Settings.getSingleton();
    final List<String> toDelete = [];
    final List<String> toUpdate = [];
    final valid = {...settings.friends, settings.storage};

    final refreshInterval = await getRefreshInterval();

    await Share.iterateOverDb().forEach((share) {
      if (!valid.contains(share.storage)) {
        toDelete.add(share.storage);
        return;
      }

      if (share.updated.add(refreshInterval).isBefore(DateTime.now().toUtc())) {
        toUpdate.add(share.storage);
      }

      valid.remove(share.storage);
    });

    // What's left over needs to be populated / added:
    final List<String> toInsert = valid.whereType<String>().toList();

    print('TO UPDATE: ${toUpdate.join(', ')}');
    print('TO INSERT: ${toInsert.join(', ')}');
    print('TO DELETE: ${toDelete.join(', ')}');

    final inflatedUpdates =
        [
              ...await Future.wait(
                toUpdate.map(
                  (s) => shareFromId(s, isMine: settings.storage == s),
                ),
              ),
              ...await Future.wait(
                toInsert.map(
                  (s) => shareFromId(s, isMine: settings.storage == s),
                ),
              ),
            ]
            .whereType<Share>()
            .map((s) => s..updated = DateTime.now().toUtc())
            .toList();

    await Share.batch(insertOrUpdate: inflatedUpdates, delete: toDelete);
  }

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
