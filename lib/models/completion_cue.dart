const completionMorseLetters = [
  '.-..',
  '..',
  '-...',
  '.-.',
  '.',
  '...',
  '-.-.',
  '---',
  '---',
  '-',
];
const completionMorseUnit = Duration(milliseconds: 200);

class CompletionLightStep {
  const CompletionLightStep(this.lit, this.units);

  final bool lit;
  final int units;
}

final completionLightSteps = List<CompletionLightStep>.unmodifiable([
  for (var letter = 0; letter < completionMorseLetters.length; letter++) ...[
    for (
      var mark = 0;
      mark < completionMorseLetters[letter].length;
      mark++
    ) ...[
      CompletionLightStep(
        true,
        completionMorseLetters[letter][mark] == '.' ? 1 : 3,
      ),
      if (mark < completionMorseLetters[letter].length - 1)
        const CompletionLightStep(false, 1),
    ],
    CompletionLightStep(
      false,
      letter == completionMorseLetters.length - 1 ? 7 : 3,
    ),
  ],
]);

final completionLightCycle = Duration(
  milliseconds:
      completionMorseUnit.inMilliseconds *
      completionLightSteps.fold<int>(0, (total, step) => total + step.units),
);
