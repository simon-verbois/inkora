/// A validated directory URL that preserves reverse-proxy path prefixes.
final class ServerEndpoint {
  ServerEndpoint(String value) : uri = _normalize(value);

  final Uri uri;

  static Uri _normalize(String value) {
    final uri = Uri.parse(value);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(value, 'value', 'Expected an HTTPS server URL');
    }
    return uri.replace(
      path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
    );
  }

  Uri resolveApiPath(String relativePath) {
    final path = Uri.parse(relativePath);
    if (path.hasScheme ||
        path.hasAuthority ||
        path.path.startsWith('/') ||
        path.pathSegments.contains('..')) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Expected a relative API path',
      );
    }
    return uri.resolveUri(path);
  }
}
