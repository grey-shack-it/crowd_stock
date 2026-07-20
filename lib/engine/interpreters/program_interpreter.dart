import '../models/crowd_engine_result.dart';

class ProgramInterpreter {
  const ProgramInterpreter();

  ProgramInterpretation interpret(double programScore) {
    if (programScore >= 60.0) {
      return ProgramInterpretation.nonArbitrageDominant;
    }

    if (programScore <= 40.0) {
      return ProgramInterpretation.arbitrageDominant;
    }

    return ProgramInterpretation.neutral;
  }
}
