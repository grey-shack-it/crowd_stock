// supabase/functions/process-queue/index.ts
//
// 1~2분마다 cron으로 실행: stock_batch_queue에서 최대 BATCH_SIZE개를 꺼내
// KIS 회원사(inquire-member) API로 HHI 근사값을 계산해 stock_daily_metrics에
// 저장한다. 성공하면 큐에서 삭제, 실패하면 status='failed' + retry_count 증가.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const BATCH_SIZE = 50;
const MAX_RETRY = 3;
const KIS_BASE_URL = "https://openapi.koreainvestment.com:9443";

async function getKisToken(supabase: any): Promise<string> {
  const { data: cached } = await supabase
    .from("stock_kis_token")
    .select("access_token, expires_at")
    .eq("id", 1)
    .maybeSingle();

  if (cached && new Date(cached.expires_at) > new Date()) {
    return cached.access_token;
  }

  const res = await fetch(`${KIS_BASE_URL}/oauth2/tokenP`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      grant_type: "client_credentials",
      appkey: Deno.env.get("KIS_APP_KEY"),
      appsecret: Deno.env.get("KIS_APP_SECRET"),
    }),
  });

  const json = await res.json();
  if (!json.access_token) {
    throw new Error(`토큰 발급 실패: ${JSON.stringify(json)}`);
  }

  // 만료 10분 여유 두고 캐싱 (보통 24시간짜리 토큰)
  const expiresAt = new Date(Date.now() + (json.expires_in - 600) * 1000);

  await supabase.from("stock_kis_token").upsert({
    id: 1,
    access_token: json.access_token,
    expires_at: expiresAt.toISOString(),
  });

  return json.access_token;
}

async function fetchBrokerHhi(token: string, stockCode: string): Promise<number> {
  const url =
    `${KIS_BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-member` +
    `?FID_COND_MRKT_DIV_CODE=J&FID_INPUT_ISCD=${stockCode}`;

  const res = await fetch(url, {
    headers: {
      authorization: `Bearer ${token}`,
      appkey: Deno.env.get("KIS_APP_KEY")!,
      appsecret: Deno.env.get("KIS_APP_SECRET")!,
      tr_id: "FHKST01010600",
      custtype: "P",
    },
  });

  if (!res.ok) {
    throw new Error(`inquire-member 실패 (${stockCode}): ${res.status}`);
  }

  const json = await res.json();

  if (json.rt_cd !== "0") {
    throw new Error(`KIS 에러 (${stockCode}): ${json.msg_cd} ${json.msg1}`);
  }

  const output = (json.output ?? [])[0] ?? {};

  // 매수 상위 5개 증권사 비중으로 HHI 근사값 계산
  let hhi = 0;
  for (let i = 1; i <= 5; i++) {
    const ratio = parseFloat(output[`shnu_mbcr_rlim${i}`] ?? "0");
    hhi += Math.pow(ratio / 100, 2);
  }

  return hhi;
}

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: queueItems, error: queueError } = await supabase
    .from("stock_batch_queue")
    .select("id, stock_code, trade_date, retry_count")
    .or(`status.eq.pending,and(status.eq.failed,retry_count.lt.${MAX_RETRY})`)
    .order("id", { ascending: true })
    .limit(BATCH_SIZE);

  if (queueError) {
    return new Response(JSON.stringify({ error: queueError.message }), {
      status: 500,
    });
  }

  if (!queueItems || queueItems.length === 0) {
    return new Response(JSON.stringify({ processed: 0, message: "대기열 비어있음" }));
  }

  const token = await getKisToken(supabase);

  let succeeded = 0;
  let failed = 0;

  for (const item of queueItems) {
    try {
      const brokerHhi = await fetchBrokerHhi(token, item.stock_code);

      await supabase.from("stock_daily_metrics").upsert(
        {
          stock_code: item.stock_code,
          trade_date: item.trade_date,
          broker_hhi: brokerHhi,
        },
        { onConflict: "stock_code,trade_date" },
      );

      await supabase.from("stock_batch_queue").delete().eq("id", item.id);
      succeeded++;
    } catch (e) {
      await supabase
        .from("stock_batch_queue")
        .update({
          status: "failed",
          retry_count: item.retry_count + 1,
          last_error: String(e),
        })
        .eq("id", item.id);
      failed++;
    }

    // KIS 호출 속도 제한 감안, 짧게 텀 두기
    await new Promise((r) => setTimeout(r, 100));
  }

  return new Response(
    JSON.stringify({ processed: queueItems.length, succeeded, failed }),
    { headers: { "Content-Type": "application/json" } },
  );
});