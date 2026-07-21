/// 참여확산도(0~100)를 Confidence Multiplier(0.5배~1.5배)로 변환한다.
/// 확산도 50(평소 수준)일 때 1.0배가 되도록 위아래 대칭으로 설계했다.
///
/// 확산도 0 (완전 집중)  -> 0.5배
/// 확산도 50 (평소 수준) -> 1.0배
/// 확산도 100 (완전 확산) -> 1.5배
class ConfidenceMultiplierCalculator {
  const ConfidenceMultiplierCalculator();

  double calculate(double participationSpread) {
    return 0.5 + (participationSpread / 100.0);
  }
}
