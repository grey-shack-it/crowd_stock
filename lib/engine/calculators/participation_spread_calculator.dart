/// 회원사 집중도, 투자자 편중도, 프로그램매매(전체) 점수를 종합해
/// "참여확산도"(0~100, 높을수록 폭넓은 참여)를 계산한다.
///
/// 프로그램매매는 원래 차익/비차익을 나눠서 다루려 했으나, KIS API가
/// "종목별 + 차익/비차익 구분"을 동시에 제공하지 않아 하나로 합쳤다.
/// 역할(핵심근거가 "집중"이라고 할 때만 감점에 힘을 싣는 조건부 가중치)은 그대로다.
///
/// 계산 순서 (모두 "집중도" 기준으로 더한 뒤, 맨 마지막에 한 번만 뒤집는다):
/// 1. 핵심근거 = (회원사 + 투자자) 단순평균 — 확산의 직접 근거
/// 2. 프로그램매매감점 = 평소 초과분 × (핵심근거 / 100) — 핵심근거가 "집중"일 때만 작동
/// 3. 집중도점수 = 핵심근거 + 프로그램매매감점 (전부 나쁜 신호라 전부 +)
/// 4. 참여확산도 = 100 - 집중도점수
class ParticipationSpreadCalculator {
  const ParticipationSpreadCalculator();

  double calculate({
    required double brokerScore,
    required double investorScore,
    required double programScore,
  }) {
    final coreEvidence = (brokerScore + investorScore) / 2.0;

    final programExcess = (programScore - 50.0).clamp(0.0, 100.0);
    final programPenalty = programExcess * (coreEvidence / 100.0);

    final concentrationScore = (coreEvidence + programPenalty).clamp(0.0, 100.0);

    return 100.0 - concentrationScore;
  }
}
