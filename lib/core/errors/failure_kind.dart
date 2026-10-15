/// Stable categories for future repository and reader error mapping.
enum FailureKind {
  cancelled,
  authentication,
  permission,
  notFound,
  offlineUnavailable,
  corruptContent,
  transientNetwork,
  rateLimited,
  serverRejected,
}
