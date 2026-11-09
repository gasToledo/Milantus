/// Lo que comparten los borradores de arma y armadura para leer y validar los
/// números de un formulario (todo texto). Los códigos de error son los de
/// `CreatureDraft`: `number`, `integer` y `range:min:max`, más `negative` y
/// `decimal` para el peso.
library;

String draftText(Object? v) => (v?.toString() ?? '').trim();

/// El peso como texto de formulario: «2» y no «2.0», que es como se escribe.
String weightText(double w) =>
    w == w.truncateToDouble() ? '${w.toInt()}' : '$w';

/// Valida un entero de [min] a [max]. Vacío es error salvo con [optional].
void checkInt(
  Map<String, String> out,
  Map<String, dynamic> form,
  String key,
  int min,
  int max, {
  required bool optional,
}) {
  final text = draftText(form[key]);
  if (text.isEmpty) {
    if (!optional) out[key] = 'number';
    return;
  }
  final n = int.tryParse(text);
  if (n == null) {
    out[key] = 'integer';
  } else if (n < min || n > max) {
    out[key] = 'range:$min:$max';
  }
}

/// El peso (obligatorio, no negativo) y el precio en cobre (entero de 0 a
/// 100.000.000): lo que arma y armadura piden igual.
void checkEconomy(Map<String, String> out, Map<String, dynamic> form) {
  final weight = draftText(form['weight']);
  if (weight.isEmpty) {
    out['weight'] = 'number';
  } else {
    final w = double.tryParse(weight);
    if (w == null) {
      out['weight'] = 'decimal';
    } else if (w < 0) {
      out['weight'] = 'negative';
    }
  }
  checkInt(out, form, 'costCp', 0, 100000000, optional: false);
}
