/// Optional display processing. Source files and decode budgets never change.
enum ImageEnhancement {
  off(0),
  gentle(.2),
  balanced(.45),
  strong(.7);

  const ImageEnhancement(this.strength);
  final double strength;

  static ImageEnhancement parse(Object? value) =>
      values.where((level) => level.name == value).firstOrNull ?? balanced;
}
