// supabase/functions/kis-proxy/index.ts
//
// Flutter 앱은 KIS appkey/appsecret을 전혀 모른다. 대신 이 함수한테
// "어떤 KIS endpoint를, 어떤 파라미터로" 불러달라고 요청하면, 이 함수가
// 서버에 보관된 키로 실제 KIS API를 대신 호출해서 결과만 그대로 돌려준다.
//
// 요청 형식 (클라이언트 → 이 함수):
//   GET /kis-proxy?path=/uapi/domestic-stock/v1/quotations/inquire-price&FID_COND_MRKT_DIV_CODE=J&FID_INPUT_ISCD=005930
//   headers: { x-kis-tr-id: 'FHKST01010100', x-kis-tr-cont: '' (선택) }
//
// path 파라미터를 뺀 나머지 쿼리 파라미터는 그대로 KIS로 전달된다.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

  const expiresAt = new Date(Date.now() + (json.expires_in - 600) * 1000);

  await supabase.from("stock_kis_token").upsert({
    id: 1,
    access_token: json.access_token,
    expires_at: expiresAt.toISOString(),
  });

  return json.access_token;
}

Deno.serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const url = new URL(req.url);
  const path = url.searchParams.get("path");

  if (!path) {
    return new Response(JSON.stringify({ error: "path 파라미터가 없어요" }), {
      status: 400,
    });
  }

  const trId = req.headers.get("x-kis-tr-id");
  if (!trId) {
    return new Response(
      JSON.stringify({ error: "x-kis-tr-id 헤더가 없어요" }),
      { status: 400 },
    );
  }
  const trCont = req.headers.get("x-kis-tr-cont") ?? "";

  // path, 이 함수 자체 인증용 쿼리 제외한 나머지는 그대로 KIS로 전달
  url.searchParams.delete("path");
  const kisUrl = `${KIS_BASE_URL}${path}?${url.searchParams.toString()}`;

  try {
    const token = await getKisToken(supabase);

    const kisRes = await fetch(kisUrl, {
      headers: {
        authorization: `Bearer ${token}`,
        appkey: Deno.env.get("KIS_APP_KEY")!,
        appsecret: Deno.env.get("KIS_APP_SECRET")!,
        tr_id: trId,
        tr_cont: trCont,
        custtype: "P",
      },
    });

    const body = await kisRes.text();

    return new Response(body, {
      status: kisRes.status,
      headers: {
        "Content-Type": "application/json",
        // 클라이언트의 페이지네이션(tr_cont) 로직이 그대로 동작하도록 전달
        "tr_cont": kisRes.headers.get("tr_cont") ?? "",
      },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
    });
  }
});