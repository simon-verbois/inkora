import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/network/komga/komga_client.dart';
import '../../../reader/data/page_network_gate.dart';
import '../../../reader/domain/page_source.dart';

typedef CoverKey = ({String kind, String id, int modified});

/// Evictable account-scoped posters share the existing foreground network gate.
/// One serialized disk writer bounds total cache use; remote bytes are streamed.
final class CoverRepository {
  CoverRepository(
    this.client,
    this.gate,
    this.directory,
    this.accountId, {
    this.diskBudget = 64 * 1024 * 1024,
    this.memoryBudget = 8 * 1024 * 1024,
  });
  final KomgaClient client;
  final PageNetworkGate gate;
  final Directory directory;
  final String accountId;
  final int diskBudget, memoryBudget;
  final _memory = <String, Uint8List>{};
  final _signals = <CancellationController>{};
  final _active = <CoverKey, int>{};
  final _etags = <String, String>{};
  final _validated = <String, DateTime>{};
  final _refreshes = <CoverKey, Future<Uint8List?>>{};
  final _pending = <CoverKey, _CoverAcquisition>{};
  final _changes = StreamController<CoverKey>.broadcast(sync: true);
  final _versions = <String, int>{};

  /// Content version for decoded-image identity: bumped only when revalidation
  /// returns different bytes, so reloading identical bytes (memory eviction,
  /// disk read) reuses the already decoded image.
  int version(CoverKey key) => _versions[_name(key)] ?? 0;

  /// Memory-pressure trim: drops encoded bytes; disk cache remains.
  void trimMemory() {
    _memory.clear();
    _memoryBytes = 0;
  }

  Stream<CoverKey> get changes => _changes.stream;

  void Function() track(CoverKey key) {
    _active.update(key, (count) => count + 1, ifAbsent: () => 1);
    return () {
      final count = _active[key] ?? 0;
      if (count <= 1) {
        _active.remove(key);
      } else {
        _active[key] = count - 1;
      }
    };
  }

  Future<void> revalidateActive({bool onlyIfStale = false}) async {
    final keys = _active.keys.toList();
    // Keep validation concurrency bounded and below foreground reader demand.
    for (var offset = 0; offset < keys.length && !_closed; offset += 2) {
      await Future.wait(
        keys
            .skip(offset)
            .take(2)
            .map((key) => revalidate(key, onlyIfStale: onlyIfStale)),
      );
    }
  }

  Future<Uint8List?> revalidate(CoverKey key, {bool onlyIfStale = false}) {
    if (_closed) return Future.value(null);
    final validated = _validated[_name(key)];
    if (onlyIfStale &&
        validated != null &&
        DateTime.now().difference(validated) < const Duration(minutes: 5)) {
      return Future.value(peek(key));
    }
    return _refreshes[key] ??= load(key, CancellationController(), force: true)
        .whenComplete(() {
          _refreshes.remove(key);
        });
  }

  int _memoryBytes = 0;
  bool _closed = false;
  Future<void> _diskTail = Future.value();
  int _queuedWriteBytes = 0;

  String _name(CoverKey key) => sha256
      .convert(
        utf8.encode(jsonEncode([accountId, key.kind, key.id, key.modified])),
      )
      .toString();

  /// Reuse the exact byte object so Flutter can also reuse its decoded image.
  Uint8List? peek(CoverKey key) {
    if (_closed) return null;
    final name = _name(key);
    final bytes = _memory.remove(name);
    if (bytes != null) _memory[name] = bytes;
    return bytes;
  }

  Future<Uint8List?> load(
    CoverKey key,
    CancellationController signal, {
    bool force = false,
    bool speculative = false,
  }) {
    if (_closed || signal.isCancelled) return Future.value(null);
    final cached = peek(key);
    if (!force && cached != null) return Future.value(cached);
    if (_pending[key]?.signal.isCancelled == true) _pending.remove(key);
    final acquisition = _pending.putIfAbsent(key, () {
      final owned = _CoverAcquisition();
      owned.request = PageRequest(
        priority: PagePriority.download,
        maximumBytes: 2 * 1024 * 1024,
        onForegroundDemand: owned.signal.cancel,
        borrowForegroundSlot: true,
        deadline: speculative ? const Duration(seconds: 1) : Duration.zero,
      );
      owned.future = _load(key, owned.signal, owned.request, force: force)
          .whenComplete(() {
            owned.done = true;
            if (identical(_pending[key], owned)) _pending.remove(key);
          });
      return owned;
    });
    if (!speculative) {
      acquisition.request.deadline = Duration.zero;
      gate.pump();
    }
    acquisition.subscribers++;
    _CoverAcquisition? owner = acquisition;
    Completer<Uint8List?>? waiting = Completer<Uint8List?>();
    final result = waiting.future;
    void finish(Uint8List? bytes) {
      final completion = waiting;
      final current = owner;
      waiting = null;
      owner = null;
      if (current != null && --current.subscribers == 0 && !current.done) {
        current.signal.cancel();
      }
      completion?.complete(bytes);
    }

    unawaited(signal.whenCancelled.then((_) => finish(null)));
    unawaited(acquisition.future.then(finish));
    return result;
  }

  Future<Uint8List?> _load(
    CoverKey key,
    CancellationController signal,
    PageRequest request, {
    bool force = false,
  }) async {
    if (_closed || signal.isCancelled) return null;
    final name = _name(key);
    var cached = peek(key);
    if (cached != null && !force) return cached;
    _signals.add(signal);
    try {
      final file = File('${directory.path}/$name.cover');
      try {
        final validator = File('${file.path}.validator');
        if (!_etags.containsKey(name) &&
            await validator.exists() &&
            await validator.length() <= 1024) {
          try {
            final metadata = jsonDecode(
              await validator.readAsString(),
            ) as Map<String, dynamic>;
            final etag = metadata['etag'];
            if (etag is String &&
                etag.length <= 256 &&
                !etag.contains('\n') &&
                !etag.contains('\r')) {
              _etags[name] = etag;
            }
            _validated[name] = DateTime.parse(metadata['validated'] as String);
          } catch (_) {
            /* Missing/corrupt validators trigger a full GET. */
          }
        }
        if (cached == null && await file.exists()) {
          final size = await file.length();
          if (size > 0 && size <= 2 * 1024 * 1024) {
            final bytes = await file.readAsBytes();
            if (_closed || signal.isCancelled) return null;
            _remember(name, bytes);
            unawaited(
              file
                  .setLastModified(DateTime.now())
                  .catchError((Object _) => file),
            );
            cached = bytes;
            if (!force) return bytes;
          }
          if (cached == null) await file.delete();
        }
      } on FileSystemException {
        /* Posters remain usable without disk cache. */
      }
      final token = CancelToken();
      unawaited(signal.whenCancelled.then((_) => token.cancel()));
      await gate.acquire(signal, request);
      late Uint8List bytes;
      String? etag;
      try {
        final response = await client.thumbnailResult(
          key.kind,
          key.id,
          cancelToken: token,
          etag: cached == null ? null : _etags[name],
        );
        bytes = response.bytes ?? cached!;
        etag = response.etag;
      } finally {
        gate.release(request);
      }
      // Disk eviction must not hold a network slot needed by a reader page.
      if (cached != null && await _sameBytes(cached, bytes)) bytes = cached;
      if (_closed || signal.isCancelled) return null;
      _remember(name, bytes);
      if (etag == null) {
        _etags.remove(name);
      } else {
        _etags[name] = etag;
      }
      _validated[name] = DateTime.now().toUtc();
      if (cached != null && !identical(cached, bytes)) {
        _versions.update(name, (version) => version + 1, ifAbsent: () => 1);
        _changes.add(key);
      }
      if (_queuedWriteBytes + bytes.length <= 4 * 1024 * 1024) {
        _queuedWriteBytes += bytes.length;
        final write = _diskTail
            .then((_) => _write(file, bytes, etag))
            .whenComplete(() => _queuedWriteBytes -= bytes.length);
        _diskTail = write.catchError((Object _) {});
      }
      // Present the image immediately; disk publication is independent of UI.
      return bytes;
    } catch (_) {
      return cached; // Failed revalidation keeps usable artwork visible.
    } finally {
      _signals.remove(signal);
    }
  }

  static Future<bool> _sameBytes(Uint8List a, Uint8List b) async {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    // Revalidation runs on navigation/resume; large artwork must not perform
    // a byte-by-byte scan on the UI isolate while a route is animating.
    if (a.length > 256 * 1024) {
      return Isolate.run(() => _compareBytes(a, b));
    }
    return _compareBytes(a, b);
  }

  static bool _compareBytes(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _remember(String name, Uint8List bytes) {
    _memoryBytes -= _memory.remove(name)?.length ?? 0;
    _memory[name] = bytes;
    _memoryBytes += bytes.length;
    while (_memoryBytes > memoryBudget && _memory.isNotEmpty) {
      final evicted = _memory.keys.first;
      _memoryBytes -= _memory.remove(evicted)!.length;
      _etags.remove(evicted);
      _validated.remove(evicted);
    }
  }

  Future<void> _write(File file, Uint8List bytes, String? etag) async {
    if (_closed || bytes.length > diskBudget) return;
    try {
      await directory.create(recursive: true);
      final validator = File('${file.path}.validator');
      // Account for replaced bytes so the running total stays an upper bound.
      final replaced = _diskBytes == null
          ? 0
          : await _sizeOf(file) + await _sizeOf(validator);
      final partial = File('${file.path}.part');
      await partial.writeAsBytes(bytes, flush: true);
      if (_closed) {
        await partial.delete();
        return;
      }
      await partial.rename(file.path);
      final validation = jsonEncode({
        'etag': etag,
        'validated': DateTime.now().toUtc().toIso8601String(),
      });
      final validationBytes = utf8.encode(validation).length;
      var written = bytes.length;
      if (bytes.length + validationBytes <= diskBudget) {
        await validator.writeAsString(validation);
        written += validationBytes;
      } else if (await validator.exists()) {
        await validator.delete();
      }
      // A full directory walk only seeds the running total or enforces the
      // budget once it is exceeded, instead of stat-ing every file per write.
      final known = _diskBytes;
      if (known != null) {
        final next = known - replaced + written;
        if (next <= diskBudget) {
          _diskBytes = next;
          return;
        }
      }
      _diskBytes = await _evictDisk();
    } on FileSystemException {
      _diskBytes = null; // Re-seed from disk on the next write.
      /* Evictable artwork is best-effort. */
    }
  }

  int? _diskBytes;

  Future<int> _sizeOf(File file) async {
    try {
      return await file.length();
    } on FileSystemException {
      return 0;
    }
  }

  /// Least-recently-used eviction by file modification time (reads touch
  /// covers). A deleted cover takes its validator with it.
  Future<int> _evictDisk() async {
    final files = <(File, FileStat)>[];
    final sizes = <String, int>{};
    var size = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      files.add((entity, stat));
      sizes[entity.path] = stat.size;
      size += stat.size;
    }
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    for (final entry in files) {
      if (size <= diskBudget) break;
      final path = entry.$1.path;
      final remaining = sizes.remove(path);
      if (remaining == null) continue; // Already removed with its cover.
      await entry.$1.delete();
      size -= remaining;
      if (!path.endsWith('.validator')) {
        final validator = File('$path.validator');
        final validatorSize = sizes.remove(validator.path);
        if (validatorSize != null) {
          await validator.delete();
          size -= validatorSize;
        }
      }
    }
    return size;
  }

  void close() {
    _closed = true;
    for (final signal in _signals.toList()) {
      signal.cancel();
    }
    _memory.clear();
    _active.clear();
    _etags.clear();
    _validated.clear();
    unawaited(_changes.close());
    _memoryBytes = 0;
  }

  /// Tests/maintenance may wait for queued best-effort writes without delaying UI.
  Future<void> flush() => _diskTail;
}

final class _CoverAcquisition {
  final signal = CancellationController();
  late final Future<Uint8List?> future;
  late final PageRequest request;
  int subscribers = 0;
  bool done = false;
}
