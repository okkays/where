part of './store.dart';

const filename = '_whereapp_share.json';

class GithubStore extends Store {
  final GitHub github;

  GithubStore({required super.token})
    : github = GitHub(auth: .withToken(token));

  static bool tokenFormatMatches(String token) {
    return token.startsWith('github_pat_');
  }

  @override
  checkTokenStatus() async {
    if (token.trim().isEmpty) {
      return .pending;
    }
    final rates = await github.misc.getRateLimit();
    if ((rates.limit ?? 0) < 100) {
      return .invalid;
    }
    return .valid;
  }

  @override
  Future<Share?> getOrCreateMyShare() async {
    if (github.auth.isAnonymous) return null;
    final settings = await Settings.getSingleton();
    if (settings.username.isEmpty) return null;

    final uuidFilename = '${settings.uuid}$filename';
    final existing = await _findCurrentUserGist(uuidFilename);

    final file = existing?.files?[uuidFilename];
    if (existing?.id != null && file?.content != null) {
      final decoded = jsonDecode(file!.content!);
      if (decoded == null) return null;
      return Share.fromDb(decoded)
        ..isMine = true
        ..storage = existing?.id ?? '';
    }

    final newShare = Share(
      name: settings.username,
      image: settings.image,
      storage: '',
      isMine: true,
      locations: [],
    );
    final newGist = await github.gists.createGist(
      {uuidFilename: jsonEncode(newShare.toDb())},
      description: 'Where app share information',
      public: false,
    );
    if (newGist.id == null) return null;
    return newShare..storage = newGist.id!;
  }

  Future<Gist?> _findCurrentUserGist(String uuidFilename) async {
    final matching = await github.gists.listCurrentUserGists().firstWhere(
      (gist) => gist.files?.containsKey(uuidFilename) ?? false,
      orElse: () => Gist(),
    );
    if (matching.id == null) return matching;
    return await github.gists.getGist(matching.id!);
  }

  @override
  Future<Share?> shareFromId(String id) async {
    Gist? gist;
    try {
      gist = await github.gists.getGist(id);
    } catch (e) {
      print(e);
      gist = null;
    }
    if (gist?.files == null) return null;
    final uuidFilename =
        gist?.files?.keys.firstWhere(
          (f) => f.endsWith(filename),
          orElse: () => '',
        ) ??
        '';
    if (uuidFilename.isEmpty) {
      return null;
    }

    final file = gist?.files?[uuidFilename];
    final shareRaw = file?.content;
    if (shareRaw == null) return null;

    final shareJson = jsonDecode(shareRaw);
    return Share.fromDb(shareJson)
      ..storage = id
      ..isMine = false;
  }
}
