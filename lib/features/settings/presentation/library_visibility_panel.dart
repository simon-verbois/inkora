import '../../../app/icons/inkora_icons.dart';
import '../../../app/widgets/inkora_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/l10n/app_strings.dart';
import '../../connection/application/session_controller.dart';
import '../../library/application/catalogue_providers.dart';
import '../../library/data/catalogue_store.dart';
import '../../library/data/library_visibility_store.dart';
import '../../library/domain/catalogue.dart';

final libraryVisibilityStoreProvider =
    FutureProvider.autoDispose<LibraryVisibilityStore?>((ref) async {
      final repository = await ref.watch(catalogueRepositoryProvider.future);
      return repository?.store.visibility;
    });

final libraryVisibilityProvider = StreamProvider.autoDispose<Set<String>?>((
  ref,
) async* {
  final store = await ref.watch(libraryVisibilityStoreProvider.future);
  if (store == null) {
    yield null;
    return;
  }
  yield* store.watch();
});

// Read the authenticated snapshot without the display filter so hidden
// libraries can always be selected again. Never include historical tombstones.
final accessibleLibrariesProvider =
    StreamProvider.autoDispose<List<CatalogueItem>>((ref) async* {
      final repository = await ref.watch(catalogueRepositoryProvider.future);
      if (repository == null) {
        yield [];
        return;
      }
      final store = CatalogueStore(
        repository.store.database,
        repository.store.accountId,
        applyLibraryVisibility: false,
      );
      yield* store.watchAvailableLibraries();
    });

class LibraryVisibilityPanel extends ConsumerStatefulWidget {
  const LibraryVisibilityPanel({super.key});

  @override
  ConsumerState<LibraryVisibilityPanel> createState() =>
      _LibraryVisibilityPanelState();
}

class _LibraryVisibilityPanelState
    extends ConsumerState<LibraryVisibilityPanel> {
  bool _saving = false;

  Future<void> _save(Set<String>? included) async {
    if (_saving) return;
    // Capture the account-owned store before awaiting or switching accounts.
    final store = ref.read(libraryVisibilityStoreProvider).asData?.value;
    if (store == null ||
        store.accountId != ref.read(sessionProvider).session?.accountId) {
      return;
    }
    setState(() => _saving = true);
    try {
      await store.save(included);
    } catch (_) {
      if (mounted) {
        notifyInk(context, 'Unable to save library selection. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraries = ref.watch(accessibleLibrariesProvider);
    final visibility = ref.watch(libraryVisibilityProvider);
    return ExpansionTile(
      key: const Key('library-visibility'),
      title: const LText('Libraries to display'),
      children: [
        if (libraries.hasError || visibility.hasError)
          TextButton(
            onPressed: () {
              ref.invalidate(accessibleLibrariesProvider);
              ref.invalidate(libraryVisibilityProvider);
            },
            child: const LText('Retry'),
          )
        else if (libraries.isLoading ||
            visibility.isLoading ||
            !libraries.hasValue ||
            !visibility.hasValue)
          const LinearProgressIndicator()
        else ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LText(
              'Only libraries available to this account are listed. Your selection applies to this account on this device.',
            ),
          ),
          SwitchListTile(
            key: const Key('all-accessible-libraries'),
            title: const LText('Show all accessible libraries'),
            value: visibility.requireValue == null,
            onChanged: _saving
                ? null
                : (all) => _save(
                    all
                        ? null
                        : libraries.requireValue.map((item) => item.id).toSet(),
                  ),
          ),
          if (libraries.requireValue.isEmpty)
            const InkEmptyState(
              icon: InkIcons.books,
              title: 'No saved libraries',
            ),
          for (final library in libraries.requireValue)
            CheckboxListTile(
              key: ValueKey('visible-library-${library.id}'),
              title: Text(library.title),
              value: visibility.requireValue?.contains(library.id) ?? true,
              onChanged: _saving
                  ? null
                  : (checked) {
                      final included = {
                        ...visibility.requireValue ??
                            libraries.requireValue
                                .map((item) => item.id)
                                .toSet(),
                      };
                      if (checked == true) {
                        included.add(library.id);
                      } else {
                        included.remove(library.id);
                      }
                      _save(included);
                    },
            ),
        ],
      ],
    );
  }
}
