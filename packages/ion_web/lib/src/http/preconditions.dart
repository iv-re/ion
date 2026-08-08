import 'package:ion_web/src/http/http.dart';

/// Evaluates RFC 7232 & RFC 7233 HTTP Preconditions and Range evaluation rules
/// in standard precedence order.
abstract class HttpPreconditions {
  /// Checks `If-Match` header against [currentEtag].
  static bool? checkIfMatch(IfMatchHeader? ifMatch, ETagHeader? currentEtag) {
    if (ifMatch == null) return null;
    if (currentEtag == null) return false;
    return ifMatch.preconditionPasses(currentEtag);
  }

  /// Checks `If-Unmodified-Since` header against [modTime].
  static bool? checkIfUnmodifiedSince(
    IfUnmodifiedSinceHeader? ifUnmodifiedSince,
    DateTime? modTime,
  ) {
    if (ifUnmodifiedSince == null || _isZeroTime(modTime)) {
      return null;
    }
    return ifUnmodifiedSince.preconditionPasses(_truncateToSeconds(modTime!));
  }

  /// Checks `If-None-Match` header against [currentEtag].
  static bool? checkIfNoneMatch(
    IfNoneMatchHeader? ifNoneMatch,
    ETagHeader? currentEtag,
  ) {
    if (ifNoneMatch == null) return null;
    if (currentEtag == null) return true;
    return ifNoneMatch.preconditionPasses(currentEtag);
  }

  /// Checks `If-Modified-Since` header against [modTime] for GET/HEAD methods.
  static bool? checkIfModifiedSince(
    HttpMethod method,
    IfModifiedSinceHeader? ifModifiedSince,
    DateTime? modTime,
  ) {
    if (method != .get && method != .head) return null;
    if (ifModifiedSince == null || _isZeroTime(modTime)) {
      return null;
    }
    return ifModifiedSince.isModified(_truncateToSeconds(modTime!));
  }

  /// Checks `If-Range` header against [modTime] and [currentEtag] for GET/HEAD methods.
  static bool? checkIfRange(
    HttpMethod method,
    IfRangeHeader? ifRange,
    DateTime? modTime,
    ETagHeader? currentEtag,
  ) {
    if (method != .get && method != .head) return null;
    if (ifRange == null) return null;

    final isModified = ifRange.isModified(
      etag: currentEtag,
      lastModified: modTime != null
          ? LastModifiedHeader(_truncateToSeconds(modTime))
          : null,
    );
    return !isModified;
  }

  /// Evaluates all HTTP preconditions according to RFC 7232 Section 6
  /// precedence rules.
  ///
  /// Returns status override (`304 Not Modified` or `412 Precondition Failed`),
  /// or `null` if preconditions passed, along with valid `rangeHeader`
  /// if applicable.
  static (HttpStatusCode? statusOverride, RangeHeader? validRange)
  checkPreconditions({
    required HttpMethod method,
    required IfMatchHeader? ifMatch,
    required IfUnmodifiedSinceHeader? ifUnmodifiedSince,
    required IfNoneMatchHeader? ifNoneMatch,
    required IfModifiedSinceHeader? ifModifiedSince,
    required IfRangeHeader? ifRange,
    required RangeHeader? rangeHeader,
    required DateTime? modTime,
    required ETagHeader? currentEtag,
  }) {
    // If-Match / If-Unmodified-Since
    var ch = checkIfMatch(ifMatch, currentEtag);
    ch ??= checkIfUnmodifiedSince(ifUnmodifiedSince, modTime);
    if (ch == false) {
      return (.preconditionFailed, null);
    }

    // If-None-Match / If-Modified-Since
    switch (checkIfNoneMatch(ifNoneMatch, currentEtag)) {
      case false:
        if (method == .get || method == .head) {
          return (.notModified, null);
        } else {
          return (.preconditionFailed, null);
        }
      case null:
        if (checkIfModifiedSince(method, ifModifiedSince, modTime) == false) {
          return (.notModified, null);
        }
      case true:
        break;
    }

    // If-Range & Range
    final validRange =
        (rangeHeader != null &&
            rangeHeader.raw.isNotEmpty &&
            checkIfRange(method, ifRange, modTime, currentEtag) != false)
        ? rangeHeader
        : null;

    return (null, validRange);
  }
}

bool _isZeroTime(DateTime? t) {
  return t == null || t.millisecondsSinceEpoch == 0;
}

DateTime _truncateToSeconds(DateTime t) {
  return DateTime.fromMillisecondsSinceEpoch(
    (t.millisecondsSinceEpoch ~/ 1000) * 1000,
    isUtc: t.isUtc,
  );
}
