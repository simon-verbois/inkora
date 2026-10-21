// CLDR integer forms: one, few, many/other. Titles from Komga never enter here.
const quantityUnits = {
  'en': {
    "screen": ["screen", "screens", "screens"],
    "update": ["update", "updates", "updates"],
    'book': ['book', 'books', 'books'],
    'page': ['page', 'pages', 'pages'],
    'item': ['item', 'items', 'items'],
    'series': ['series', 'series', 'series'],
    'volume': ['volume', 'volumes', 'volumes'],

    'pageLeft': ["page left", "pages left", "pages left"],
  },
  'fr': {
    "screen": ["écran", "écrans", "écrans"],
    "update": ["mise à jour", "mises à jour", "mises à jour"],
    'book': ['livre', 'livres', 'livres'],
    'page': ['page', 'pages', 'pages'],
    'item': ['élément', 'éléments', 'éléments'],
    'series': ['série', 'séries', 'séries'],
    'volume': ['tome', 'tomes', 'tomes'],

    'pageLeft': ["page restante", "pages restantes", "pages restantes"],
  },
  'de': {
    "screen": ["Bildschirmlänge", "Bildschirmlängen", "Bildschirmlängen"],
    "update": ["Aktualisierung", "Aktualisierungen", "Aktualisierungen"],
    'book': ['Buch', 'Bücher', 'Bücher'],
    'page': ['Seite', 'Seiten', 'Seiten'],
    'item': ['Eintrag', 'Einträge', 'Einträge'],
    'series': ['Reihe', 'Reihen', 'Reihen'],
    'volume': ['Band', 'Bände', 'Bände'],

    'pageLeft': ["Seite übrig", "Seiten übrig", "Seiten übrig"],
  },
  'es': {
    "screen": ["pantalla", "pantallas", "pantallas"],
    "update": ["actualización", "actualizaciones", "actualizaciones"],
    'book': ['libro', 'libros', 'libros'],
    'page': ['página', 'páginas', 'páginas'],
    'item': ['elemento', 'elementos', 'elementos'],
    'series': ['serie', 'series', 'series'],
    'volume': ['volumen', 'volúmenes', 'volúmenes'],

    'pageLeft': ["página restante", "páginas restantes", "páginas restantes"],
  },
  'it': {
    "screen": ["schermata", "schermate", "schermate"],
    "update": ["aggiornamento", "aggiornamenti", "aggiornamenti"],
    'book': ['libro', 'libri', 'libri'],
    'page': ['pagina', 'pagine', 'pagine'],
    'item': ['elemento', 'elementi', 'elementi'],
    'series': ['serie', 'serie', 'serie'],
    'volume': ['volume', 'volumi', 'volumi'],

    'pageLeft': ["pagina rimanente", "pagine rimanenti", "pagine rimanenti"],
  },
  'pl': {
    "screen": ["ekran", "ekrany", "ekranów"],
    "update": ["aktualizacja", "aktualizacje", "aktualizacji"],
    'book': ['książka', 'książki', 'książek'],
    'page': ['strona', 'strony', 'stron'],
    'item': ['element', 'elementy', 'elementów'],
    'series': ['seria', 'serie', 'serii'],
    'volume': ['tom', 'tomy', 'tomów'],

    'pageLeft': ["strona do końca", "strony do końca", "stron do końca"],
  },
  'nl': {
    "screen": ["schermlengte", "schermlengtes", "schermlengtes"],
    "update": ["update", "updates", "updates"],
    'book': ['boek', 'boeken', 'boeken'],
    'page': ['pagina', "pagina’s", "pagina’s"],
    'item': ['item', 'items', 'items'],
    'series': ['serie', 'series', 'series'],
    'volume': ['deel', 'delen', 'delen'],

    'pageLeft': ["pagina over", "pagina’s over", "pagina’s over"],
  },
  'pt': {
    "screen": ["ecrã", "ecrãs", "ecrãs"],
    "update": ["atualização", "atualizações", "atualizações"],
    'book': ['livro', 'livros', 'livros'],
    'page': ['página', 'páginas', 'páginas'],
    'item': ['elemento', 'elementos', 'elementos'],
    'series': ['série', 'séries', 'séries'],
    'volume': ['volume', 'volumes', 'volumes'],

    'pageLeft': ["página restante", "páginas restantes", "páginas restantes"],
  },
  'ro': {
    "screen": ["ecran", "ecrane", "de ecrane"],
    "update": ["actualizare", "actualizări", "de actualizări"],
    'book': ['carte', 'cărți', 'de cărți'],
    'page': ['pagină', 'pagini', 'de pagini'],
    'item': ['element', 'elemente', 'de elemente'],
    'series': ['serie', 'serii', 'de serii'],
    'volume': ['volum', 'volume', 'de volume'],

    'pageLeft': ["pagină rămasă", "pagini rămase", "de pagini rămase"],
  },
  'el': {
    "screen": ["οθόνη", "οθόνες", "οθόνες"],
    "update": ["ενημέρωση", "ενημερώσεις", "ενημερώσεις"],
    'book': ['βιβλίο', 'βιβλία', 'βιβλία'],
    'page': ['σελίδα', 'σελίδες', 'σελίδες'],
    'item': ['στοιχείο', 'στοιχεία', 'στοιχεία'],
    'series': ['σειρά', 'σειρές', 'σειρές'],
    'volume': ['τόμος', 'τόμοι', 'τόμοι'],

    'pageLeft': ["σελίδα ακόμη", "σελίδες ακόμη", "σελίδες ακόμη"],
  },
  'hu': {
    "screen": ["képernyő", "képernyő", "képernyő"],
    "update": ["frissítés", "frissítés", "frissítés"],
    'book': ['könyv', 'könyv', 'könyv'],
    'page': ['oldal', 'oldal', 'oldal'],
    'item': ['elem', 'elem', 'elem'],
    'series': ['sorozat', 'sorozat', 'sorozat'],
    'volume': ['kötet', 'kötet', 'kötet'],

    'pageLeft': ["oldal van hátra", "oldal van hátra", "oldal van hátra"],
  },
  'cs': {
    "screen": ["obrazovka", "obrazovky", "obrazovek"],
    "update": ["aktualizace", "aktualizace", "aktualizací"],
    'book': ['kniha', 'knihy', 'knih'],
    'page': ['strana', 'strany', 'stran'],
    'item': ['položka', 'položky', 'položek'],
    'series': ['série', 'série', 'sérií'],
    'volume': ['svazek', 'svazky', 'svazků'],

    'pageLeft': ["strana do konce", "strany do konce", "stran do konce"],
  },
};
