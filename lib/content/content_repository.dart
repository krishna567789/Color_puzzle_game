/// Loads the content set: JSON from the asset bundle, or the identical copy
/// compiled into the binary when the bundle cannot be read.
///
/// Two rules hold this together. A document is only ever swapped in when it
/// parses *and* passes [validateContent], so a half-pasted file can never reach
/// a player. And the fallback is the same bytes as the shipped JSON rather than
/// a hand-maintained second copy, so the two cannot drift.
library;

import 'dart:convert';

import 'package:flutter/services.dart'
    show StandardMessageCodec, rootBundle;

import 'content_documents.dart';
import 'content_types.dart';
import 'content_validator.dart';
import 'generated/compiled_content.dart';

/// Reads one asset by path. Injected so a test or a tool can read from disk.
typedef ContentTextReader = Future<String> Function(String path);

/// How the bundle now serving got there.
class ContentSource {
  const ContentSource(this.version, this.isCompiledFallback, this.issues);

  /// The `contentVersion` of the bundle in force.
  final String version;

  /// True while the compiled copy serves, meaning the bundle was unreadable.
  final bool isCompiledFallback;

  /// Why a bundle from the asset bundle was refused, if one was.
  final List<String> issues;
}

/// The one content set the whole game reads.
class ContentRepository {
  /// The bundle in force. Never null, never half-loaded: it is either the
  /// compiled copy or a bundle that passed validation.
  static GameContent get content {
    if (!_loaded) useCompiledContent();
    return _content;
  }

  static ContentSource get source {
    if (!_loaded) useCompiledContent();
    return _source;
  }

  static GameContent _content = GameContent.notLoaded();
  static ContentSource _source = const ContentSource('none', true, []);
  static bool _loaded = false;

  /// Every JSON document the content set is made of, by asset path.
  static List<String> get documentPaths => kCompiledContent.keys.toList();

  /// Parses the compiled copy. Runs on the first read, so nothing has to await
  /// a file to know what a level costs or what a power-up sells for.
  static void useCompiledContent() {
    if (_loaded) return;
    _loaded = true;
    adopt(_decode(kCompiledContent), fromBundle: false);
  }

  /// Re-reads every document and swaps it in if the set is whole. Anything
  /// short of that leaves the current bundle serving, with the reason recorded
  /// in [source] for a build log to show.
  static Future<void> refresh({ContentTextReader? read}) async {
    useCompiledContent();
    final loader = read ?? ((path) => rootBundle.loadString(path));
    try {
      final raw = <String, String>{};
      for (final path in documentPaths) {
        raw[path] = await loader(path);
      }
      adopt(
        _decode(raw),
        fromBundle: true,
        assetExists: await packedAssets(),
      );
    } catch (error) {
      // No bundle and no network: the compiled set already serves.
      _source = ContentSource(_source.version, true, ['$error']);
    }
  }

  /// A check against the assets this build actually packed, so a document that
  /// names a banner or a bottle render nobody shipped is caught on launch
  /// rather than painted as an exception box on a player's screen.
  ///
  /// Null when the manifest cannot be read. That is a packaging problem, and
  /// calling it bad content would refuse a set that is perfectly fine.
  static Future<ContentAssetChecker?> packedAssets() async {
    try {
      final manifest = await rootBundle.load('AssetManifest.bin');
      final entries = const StandardMessageCodec().decodeMessage(manifest);
      if (entries is! Map) return null;
      final packed = {for (final path in entries.keys) '$path'};
      return packed.contains;
    } catch (_) {
      return null;
    }
  }

  static void adopt(
    Map<String, Map<String, dynamic>> documents, {
    required bool fromBundle,
    ContentAssetChecker? assetExists,
  }) {
    final issues = ContentIssues();
    final bundle = parseContentDocuments(documents, issues);
    if (bundle == null) {
      _refuse(issues.messages);
      return;
    }
    final problems = validateContent(bundle, assetExists: assetExists);
    if (problems.isNotEmpty) {
      _refuse(problems);
      return;
    }
    _content = bundle;
    _source = ContentSource(bundle.contentVersion, !fromBundle, const []);
  }

  /// Keeps the bundle already serving and records why the new one was refused.
  /// The reason travels rather than throwing: a content mistake should show up
  /// in a build log, not as an app that never opened.
  static void _refuse(List<String> reasons) {
    _source = ContentSource(
      _source.version,
      _source.isCompiledFallback,
      reasons,
    );
  }

  static Map<String, Map<String, dynamic>> _decode(Map<String, String> raw) {
    final decoded = <String, Map<String, dynamic>>{};
    for (final entry in raw.entries) {
      final value = jsonDecode(entry.value);
      decoded[entry.key] = value is Map<String, dynamic>
          ? value
          : <String, dynamic>{'unexpected': '${value.runtimeType}'};
    }
    return decoded;
  }
}
