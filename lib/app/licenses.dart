import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;
void registerInkoraLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'PDFium',
    ], await rootBundle.loadString('assets/licenses/pdfium-notices.txt'));
    yield LicenseEntryWithLineBreaks([
      'Readium Kotlin / Swift',
    ], await rootBundle.loadString('assets/licenses/readium-sdk.txt'));
    yield LicenseEntryWithLineBreaks([
      'Phosphor Icons',
    ], await rootBundle.loadString('assets/icons/LICENSE.txt'));
    yield LicenseEntryWithLineBreaks([
      'Libre Baskerville',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    for (final (name, asset) in const [
      ('Atkinson Hyperlegible', 'AtkinsonHyperlegible'),
      ('Crimson Text', 'CrimsonText'),
      ('Gentium Book Plus', 'GentiumBookPlus'),
      ('Lato', 'Lato'),
      ('PT Serif', 'PTSerif'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/fonts/$asset-OFL.txt'));
    }
  });
}
