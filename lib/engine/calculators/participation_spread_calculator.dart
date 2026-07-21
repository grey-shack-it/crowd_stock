/// 회원사 집중도, 투자자 편중도, 비차익/차익 프로그램 점수를 종합해
/// "참여확산도"(0~100, 높을수록 폭넓은 참여)를 계산한다.
///
/// 계산 순서 (모두 "집중도" 기준으로 더한 뒤, 맨 마지막에 한 번만 뒤집는다):
/// 1. 핵심근거 = (회원사 + 투자자) 단순평균 — 확산의 직접 근거
/// 2. 비차익감점 = 평소 초과분 × (핵심근거 / 100) — 핵심근거가 "집중"일 때만 작동
/// 3. 차익보정 = 평소 초과분 그대로 — 조건 없이 항상 작동 (순수 노이즈 보정)
/// 4. 집중도점수 = 핵심근거 + 비차익감점 + 차익보정 (전부 나쁜 신호라 전부 +)
/// 5. 참여확산도 = 100 - 집중도점수
class ParticipationSpreadCalculator {
  const ParticipationSpreadCalculator();

  double calculate({
    required double brokerScore,
    required double investorScore,
    required double nonArbitrageScore,
    required double arbitrageScore,
  }) {
    final coreEvidence = (brokerScore + investorScore) / 2.0;

    final nonArbitrageExcess = (nonArbitrageScore - 50.0).clamp(0.0, 100.0);
    final nonArbitragePenalty = nonArbitrageExcess * (coreEvidence / 100.0);

    final arbitragePenalty = (arbitrageScore - 50.0).clamp(0.0, 100.0);

    final concentrationScore =
        (coreEvidence + nonArbitragePenalty + arbitragePenalty).clamp(
          0.0,
          100.0,
        );

    return 100.0 - concentrationScore;
  }
}
