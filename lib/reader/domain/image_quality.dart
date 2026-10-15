/// The decoded page's MIME type, not its archive/container extension, owns
/// rendering preferences. Unknown supported raster types use the fallback.
enum RasterFormat {
  jpeg,
  png,
  webp,
  other;

  static RasterFormat fromMediaType(String mediaType) =>
      switch (mediaType.split(';').first.trim().toLowerCase()) {
        'image/jpeg' || 'image/jpg' => jpeg,
        'image/png' => png,
        'image/webp' => webp,
        _ => other,
      };
}

enum ImageSampling { nearest, smooth, high }

enum VisualFilter { original, grayscale, sepia, inverted }

final class RasterQuality {
  const RasterQuality({
    this.sampling = ImageSampling.high,
    this.filter = VisualFilter.original,
  });
  final ImageSampling sampling;
  final VisualFilter filter;
  Map<String, String> toJson() => {
    'sampling': sampling.name,
    'filter': filter.name,
  };
  factory RasterQuality.fromJson(Map<String, dynamic> json) => RasterQuality(
    sampling: ImageSampling.values.firstWhere(
      (value) => value.name == json['sampling'],
      orElse: () => ImageSampling.high,
    ),
    filter: VisualFilter.values.firstWhere(
      (value) => value.name == json['filter'],
      orElse: () => VisualFilter.original,
    ),
  );
  @override
  bool operator ==(Object other) =>
      other is RasterQuality &&
      sampling == other.sampling &&
      filter == other.filter;
  @override
  int get hashCode => Object.hash(sampling, filter);
}
