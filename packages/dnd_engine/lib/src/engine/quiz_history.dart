import 'dart:math';

/// En qué caja está una pregunta y cuándo se respondió por última vez.
///
/// La caja va de 1 a 5. No es un dato que vea quien juega: la pantalla solo
/// dice que hay preguntas para repasar. [correct] y [wrong] cuentan respuestas,
/// no rachas.
class QuizCardState {
  final int box;
  final int lastRound;
  final int correct;
  final int wrong;

  const QuizCardState({
    required this.box,
    required this.lastRound,
    this.correct = 0,
    this.wrong = 0,
  });

  Map<String, dynamic> toJson() => {
        'box': box,
        'lastRound': lastRound,
        'correct': correct,
        'wrong': wrong,
      };

  /// Null si el objeto no es una caja usable. Una tarjeta rota se saltea; no
  /// tira el historial entero.
  static QuizCardState? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final box = raw['box'];
    final lastRound = raw['lastRound'];
    final correct = raw['correct'];
    final wrong = raw['wrong'];
    if (box is! int || lastRound is! int || correct is! int || wrong is! int) {
      return null;
    }
    if (box < 1 || box > 5 || lastRound < 0 || correct < 0 || wrong < 0) {
      return null;
    }
    return QuizCardState(
      box: box,
      lastRound: lastRound,
      correct: correct,
      wrong: wrong,
    );
  }
}

/// Lo que la pantalla guarda en el dispositivo entre rondas.
///
/// [round] es el número de la ronda que se está jugando (o la última que se
/// empezó). [cards] se indexa por la clave de la pregunta, que distingue el
/// tipo: el daño y la maestría de la misma arma no comparten tarjeta.
class QuizHistory {
  static const int currentVersion = 1;

  final int version;
  final int round;
  final Map<String, QuizCardState> cards;

  const QuizHistory({
    this.version = currentVersion,
    this.round = 0,
    this.cards = const {},
  });

  static const empty = QuizHistory();

  Map<String, dynamic> toJson() => {
        'version': version,
        'round': round,
        'cards': {for (final e in cards.entries) e.key: e.value.toJson()},
      };

  /// Un JSON ilegible o de una versión que este motor no conoce vuelve vacío.
  /// Guardar de vuelta una versión futura perdería campos: se descarta.
  factory QuizHistory.fromJson(Object? raw) {
    if (raw is! Map) return QuizHistory.empty;
    if (raw['version'] != currentVersion) return QuizHistory.empty;
    final round = raw['round'];
    final cardsRaw = raw['cards'];
    if (round is! int || round < 0 || cardsRaw is! Map) {
      return QuizHistory.empty;
    }
    final cards = <String, QuizCardState>{};
    for (final entry in cardsRaw.entries) {
      final id = entry.key;
      if (id is! String || id.isEmpty) continue;
      final state = QuizCardState.fromJson(entry.value);
      if (state != null) cards[id] = state;
    }
    return QuizHistory(round: round, cards: cards);
  }
}

/// Una respuesta ya cerrada. [cardId] es la clave de la pregunta.
class QuizAnswer {
  final String cardId;
  final bool correct;

  const QuizAnswer({required this.cardId, required this.correct});
}

/// Anota [answers] en [history] y devuelve el historial nuevo.
///
/// Una tarjeta que no estaba entra en la caja 1 y recién ahí se aplica el
/// resultado: el primer acierto queda en la 2, el primer error en la 1. Un
/// acierto sube una caja (hasta la 5); un error vuelve a la 1. [lastRound] es
/// el [QuizHistory.round] que ya tenía el historial: quien llama incrementa la
/// ronda al empezarla, no al responder.
///
/// Las claves que no vinieron en [answers] se conservan, aunque el catálogo ya
/// no las tenga. Borrarlas acá haría desaparecer un progreso que esta ronda
/// simplemente no sorteó.
QuizHistory quizRecordAnswers(QuizHistory history, List<QuizAnswer> answers) {
  final cards = Map<String, QuizCardState>.of(history.cards);
  for (final answer in answers) {
    if (answer.cardId.isEmpty) continue;
    final prev = cards[answer.cardId];
    final from = prev?.box ?? 1;
    cards[answer.cardId] = QuizCardState(
      box: answer.correct ? min(5, from + 1) : 1,
      lastRound: history.round,
      correct: (prev?.correct ?? 0) + (answer.correct ? 1 : 0),
      wrong: (prev?.wrong ?? 0) + (answer.correct ? 0 : 1),
    );
  }
  return QuizHistory(
      version: history.version, round: history.round, cards: cards);
}
