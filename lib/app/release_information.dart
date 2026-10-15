import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final releaseInformationProvider =
    FutureProvider.autoDispose<ReleaseInformation>(
      (ref) => ReleaseInformation.load(rootBundle),
    );

enum ChangelogBlockKind { heading, paragraph, bullet }

final class ChangelogBlock {
  const ChangelogBlock(this.kind, this.text);
  final ChangelogBlockKind kind;
  final String text;
}

final class ChangelogSection {
  const ChangelogSection(this.title, this.blocks);
  final String title;
  final List<ChangelogBlock> blocks;
}

/// Bundled release notes are documentation, not runtime-translated UI copy.
/// Load only on About; no startup, catalogue or reader subscription is added.
final class ReleaseInformation {
  const ReleaseInformation(this.version, this.sections);
  final String version;
  final List<ChangelogSection> sections;

  static Future<ReleaseInformation> load(AssetBundle bundle) async {
    final (version, changelog) = await (
      bundle.loadString('VERSION'),
      bundle.loadString('CHANGELOG.md'),
    ).wait;
    if (version.trim().isEmpty) {
      throw const FormatException('Empty bundled VERSION');
    }
    return ReleaseInformation(version.trim(), parse(changelog));
  }

  /// The maintained changelog uses release headings, subheadings, paragraphs
  /// and bullet lists. Ignore its editorial preamble and empty Unreleased
  /// placeholder. Preserve source order and wrap continuation lines.
  static List<ChangelogSection> parse(String markdown) {
    final sections = <ChangelogSection>[];
    String? title;
    var blocks = <ChangelogBlock>[];
    void finish() {
      if (title != null && blocks.isNotEmpty) {
        sections.add(ChangelogSection(title, List.unmodifiable(blocks)));
      }
      blocks = [];
    }

    var continuation = false;
    for (final raw in markdown.split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith('## ')) {
        finish();
        title = line.substring(3).replaceFirst('[', '').replaceFirst(']', '');
        continuation = false;
      } else if (title == null || line.trim().isEmpty) {
        continuation = false;
      } else if (line.startsWith('### ')) {
        blocks.add(
          ChangelogBlock(ChangelogBlockKind.heading, line.substring(4)),
        );
        continuation = false;
      } else if (line.startsWith('- ')) {
        blocks.add(
          ChangelogBlock(ChangelogBlockKind.bullet, line.substring(2)),
        );
        continuation = true;
      } else if (!line.trimLeft().startsWith('<!--')) {
        if (continuation && blocks.isNotEmpty) {
          final previous = blocks.removeLast();
          blocks.add(
            ChangelogBlock(previous.kind, '${previous.text} ${line.trim()}'),
          );
        } else {
          blocks.add(ChangelogBlock(ChangelogBlockKind.paragraph, line.trim()));
        }
        continuation = true;
      }
    }
    finish();
    return List.unmodifiable(sections);
  }
}
