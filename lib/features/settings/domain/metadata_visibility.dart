/// Device-owned presentation choices; catalogue/search data stays unchanged.
enum MetadataField {
  language('Language'),
  tags('Tags'),
  genres('Genres'),
  authors('Authors'),
  writers('Writer'),
  pencillers('Penciller'),
  inkers('Inker'),
  colorists('Colorist'),
  letterers('Letterer'),
  coverArtists('Cover artist'),
  editors('Editor'),
  translators('Translator'),
  publisher('Publisher'),
  releaseDate('Release date'),
  isbn('ISBN'),
  links('Links'),
  status('Publication status'),
  ageRating('Age rating'),
  readingDirection('Direction'),
  format('Format'),
  synopsis('Synopsis'),
  books('Books');

  const MetadataField(this.label);
  final String label;
  bool get isCredit => index >= writers.index && index <= translators.index;

  static MetadataField credit(String role) => switch (role
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('_', '')
      .replaceAll('-', '')) {
    'writer' => writers,
    'penciller' || 'penciler' || 'artist' => pencillers,
    'inker' => inkers,
    'colorist' || 'colourist' => colorists,
    'letterer' => letterers,
    'cover' || 'coverartist' => coverArtists,
    'editor' => editors,
    'translator' => translators,
    _ => authors,
  };
}

/// Value equality keeps unrelated preference updates out of metadata widgets.
final class MetadataVisibility {
  // Language is bit zero. Tags retain UiPreferences.hideTags compatibility.
  const MetadataVisibility({this.hiddenMask = 1});
  final int hiddenMask;
  bool shows(MetadataField field) => hiddenMask & (1 << field.index) == 0;
  bool showsCredit(String role) =>
      shows(MetadataField.authors) && shows(MetadataField.credit(role));
  MetadataVisibility withVisible(MetadataField field, bool visible) =>
      MetadataVisibility(
        hiddenMask: visible
            ? hiddenMask & ~(1 << field.index)
            : hiddenMask | (1 << field.index),
      );
  factory MetadataVisibility.fromJson(Object? value) {
    if (value is! List || value.any((item) => item is! String)) {
      return const MetadataVisibility();
    }
    var mask = 0;
    for (final field in MetadataField.values) {
      if (field != MetadataField.tags && value.contains(field.name)) {
        mask |= 1 << field.index;
      }
    }
    return MetadataVisibility(hiddenMask: mask);
  }
  List<String> toJson() => [
    for (final field in MetadataField.values)
      if (field != MetadataField.tags && !shows(field)) field.name,
  ];
  @override
  bool operator ==(Object other) =>
      other is MetadataVisibility && hiddenMask == other.hiddenMask;
  @override
  int get hashCode => hiddenMask.hashCode;
}
