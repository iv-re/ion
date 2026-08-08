import 'package:equatable/equatable.dart';
import 'package:http_headers/src/header.dart';
import 'package:http_headers/src/typed_header.dart';
import 'package:http_headers/src/util.dart';

/// The `Cache-Control` header field,
/// defined in [RFC 7234 Section 5.2](https://datatracker.ietf.org/doc/html/rfc7234#section-5.2)
/// and [RFC 8246](https://www.rfc-editor.org/rfc/rfc8246).
///
/// Specifies directives for caches along the request/response chain.
///
/// ```dart
/// final cc = CacheControlHeader(
///   noCache: true,
///   maxAge: Duration(seconds: 300),
/// );
/// final decoded = CacheControlHeader.decode(['no-cache, max-age=300']);
/// ```
final class CacheControlHeader extends Equatable implements TypedHeader {
  /// Creates a `Cache-Control` header.
  const CacheControlHeader({
    this.noCache = false,
    this.noStore = false,
    this.noTransform = false,
    this.onlyIfCached = false,
    this.mustRevalidate = false,
    this.isPublic = false,
    this.isPrivate = false,
    this.isImmutable = false,
    this.mustUnderstand = false,
    this.proxyRevalidate = false,
    this.maxAge,
    this.maxStale,
    this.minFresh,
    this.sMaxAge,
  });

  /// Decodes this header type from raw header values.
  static CacheControlHeader? decode(Iterable<String> values) {
    if (values.isEmpty) return null;
    var noCache = false;
    var noStore = false;
    var noTransform = false;
    var onlyIfCached = false;
    var mustRevalidate = false;
    var isPublic = false;
    var isPrivate = false;
    var isImmutable = false;
    var mustUnderstand = false;
    var proxyRevalidate = false;
    Duration? maxAge;
    Duration? maxStale;
    Duration? minFresh;
    Duration? sMaxAge;

    for (final item in parseCsv(values)) {
      final part = item.trim();
      final eqIdx = part.indexOf('=');
      if (eqIdx == -1) {
        switch (part.toLowerCase()) {
          case 'no-cache':
            noCache = true;
          case 'no-store':
            noStore = true;
          case 'no-transform':
            noTransform = true;
          case 'only-if-cached':
            onlyIfCached = true;
          case 'must-revalidate':
            mustRevalidate = true;
          case 'public':
            isPublic = true;
          case 'private':
            isPrivate = true;
          case 'immutable':
            isImmutable = true;
          case 'must-understand':
            mustUnderstand = true;
          case 'proxy-revalidate':
            proxyRevalidate = true;
        }
      } else {
        final key = part.substring(0, eqIdx).trim().toLowerCase();
        final val = part.substring(eqIdx + 1).trim().replaceAll('"', '');
        final secs = int.tryParse(val);
        if (secs != null && secs >= 0) {
          switch (key) {
            case 'max-age':
              maxAge = Duration(seconds: secs);
            case 'max-stale':
              maxStale = Duration(seconds: secs);
            case 'min-fresh':
              minFresh = Duration(seconds: secs);
            case 's-maxage':
              sMaxAge = Duration(seconds: secs);
          }
        }
      }
    }

    return CacheControlHeader(
      noCache: noCache,
      noStore: noStore,
      noTransform: noTransform,
      onlyIfCached: onlyIfCached,
      mustRevalidate: mustRevalidate,
      isPublic: isPublic,
      isPrivate: isPrivate,
      isImmutable: isImmutable,
      mustUnderstand: mustUnderstand,
      proxyRevalidate: proxyRevalidate,
      maxAge: maxAge,
      maxStale: maxStale,
      minFresh: minFresh,
      sMaxAge: sMaxAge,
    );
  }

  final bool noCache;
  final bool noStore;
  final bool noTransform;
  final bool onlyIfCached;
  final bool mustRevalidate;
  final bool isPublic;
  final bool isPrivate;
  final bool isImmutable;
  final bool mustUnderstand;
  final bool proxyRevalidate;
  final Duration? maxAge;
  final Duration? maxStale;
  final Duration? minFresh;
  final Duration? sMaxAge;

  @override
  String get name => HttpHeader.cacheControl.name;

  @override
  List<Object?> get props => [
    noCache,
    noStore,
    noTransform,
    onlyIfCached,
    mustRevalidate,
    isPublic,
    isPrivate,
    isImmutable,
    mustUnderstand,
    proxyRevalidate,
    maxAge,
    maxStale,
    minFresh,
    sMaxAge,
  ];

  @override
  Iterable<String> encode() {
    final dirs = <String>[];
    if (noCache) dirs.add('no-cache');
    if (noStore) dirs.add('no-store');
    if (noTransform) dirs.add('no-transform');
    if (onlyIfCached) dirs.add('only-if-cached');
    if (mustRevalidate) dirs.add('must-revalidate');
    if (isPublic) dirs.add('public');
    if (isPrivate) dirs.add('private');
    if (isImmutable) dirs.add('immutable');
    if (mustUnderstand) dirs.add('must-understand');
    if (proxyRevalidate) dirs.add('proxy-revalidate');
    if (maxAge != null) dirs.add('max-age=${maxAge!.inSeconds}');
    if (maxStale != null) dirs.add('max-stale=${maxStale!.inSeconds}');
    if (minFresh != null) dirs.add('min-fresh=${minFresh!.inSeconds}');
    if (sMaxAge != null) dirs.add('s-maxage=${sMaxAge!.inSeconds}');

    if (dirs.isEmpty) return const [];
    return [dirs.join(', ')];
  }
}
