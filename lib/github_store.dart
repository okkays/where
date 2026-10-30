part of './store.dart';

class GithubStore extends Store {
  const GithubStore({required super.token});

  static bool tokenFormatMatches(String token) {
    return token.startsWith('github_pat_');
  }

  @override
  checkTokenStatus() async {
    if (token.trim().isEmpty) {
      return .pending;
    }
    final github = GitHub(auth: .withToken(token));
    final rates = await github.misc.getRateLimit();
    if ((rates.limit ?? 0) < 100) {
      return .invalid;
    }
    return .valid;
  }
}
