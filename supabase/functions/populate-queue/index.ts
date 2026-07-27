// supabase/functions/populate-queue/index.ts
//
// 매일 한 번(장 마감 후) 실행: stock_universe의 활성 종목을 오늘 날짜로
// stock_batch_queue에 채워 넣는다. 이미 있는 (종목,날짜) 조합은 건드리지
// 않는다 (upsert, ignore duplicates) — 중복 실행돼도 안전하게.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // KST 기준 오늘 날짜 (yyyy-mm-dd)
  const today = new Date(
    new Date().toLocaleString("en-US", { timeZone: "Asia/Seoul" }),
  );
  const tradeDate = today.toISOString().slice(0, 10);

  const stocks: { stock_code: string }[] = [];
  const pageSize = 1000;

  for (let from = 0; ; from += pageSize) {
    const { data: page, error: listError } = await supabase
      .from("stock_universe")
      .select("stock_code")
      .eq("is_active", true)
      .range(from, from + pageSize - 1);

    if (listError) {
      return new Response(JSON.stringify({ error: listError.message }), {
        status: 500,
      });
    }

    stocks.push(...(page ?? []));
    if (!page || page.length < pageSize) break;
  }

  const rows = (stocks ?? []).map((s) => ({
    stock_code: s.stock_code,
    trade_date: tradeDate,
    status: "pending",
  }));

  // 500개씩 나눠서 insert (한 번에 너무 큰 요청 방지)
  const chunkSize = 500;
  let inserted = 0;

  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    const { error } = await supabase
      .from("stock_batch_queue")
      .upsert(chunk, { onConflict: "stock_code,trade_date", ignoreDuplicates: true });

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message, insertedSoFar: inserted }),
        { status: 500 },
      );
    }
    inserted += chunk.length;
  }

  return new Response(
    JSON.stringify({ tradeDate, queued: inserted }),
    { headers: { "Content-Type": "application/json" } },
  );
});