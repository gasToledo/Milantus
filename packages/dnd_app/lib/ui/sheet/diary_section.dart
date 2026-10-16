part of '../sheet_screen.dart';

/// La pestaña **Diario**: el lado creativo del personaje, que hasta ahora era
/// un campo de notas libre y nada más.
///
/// Dos piezas con jerarquías distintas a propósito. El **trasfondo** está
/// siempre —aunque esté vacío, donde dice «Origen desconocido»— porque todo
/// personaje viene de algún lado; las **entradas** son opcionales y se acomodan
/// arrastrando, sin orden impuesto por la fecha.
///
/// Las dos tarjetas son widgets compartidos (`ui/diary_cards.dart`) porque el
/// PNJ del Modo DM las usa para su Trasfondo y sus Notas. Acá solo se les dice
/// de dónde sale cada dato y adónde vuelve.
///
/// Nada de acá es una regla: no llega al `ComputedSheet` ni cambia un número.
extension _SheetDiarySection on _SheetScreenState {
  Widget _buildDiario() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DiaryBackgroundCard(
        value: _c.background,
        ownerName: _c.name,
        shell: sheetCard,
        // Se escribe sobre el mismo personaje y se autoguarda con `touch`,
        // igual que hacían las notas: producir un `Character` nuevo por cada
        // tecla recompilaría la ficha entera mientras alguien escribe.
        onChanged: (v) {
          _c.background = v;
          ctrl.touch(_c);
        },
      ),
      const SizedBox(height: 16),
      DiaryEntriesCard(
        entries: _c.diary,
        ownerName: _c.name,
        title: context.l10n.diaryEntries,
        shell: sheetCard,
        onChanged: (lista) => _replace(_c.copyWith(diary: lista)),
        uploadImage: (bytes) =>
            ctrl.api.savePortrait(characterId: _c.id, bytes: bytes),
        deleteImage: ctrl.api.deletePortrait,
      ),
    ],
  );
}
