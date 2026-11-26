"""소상공인 상가(상권)정보 API에서 서울·부산 샵을 받아 assets/data/public_shops.json 으로 저장.

실행: python tool/fetch_shops.py
키는 환경변수 DATA_GO_KR_KEY 또는 프로젝트 위쪽 폴더의 .env.local 에서 읽음 (한 줄로 넣을 것).
"""
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter

API = "https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInDong"
# (구분, 코드): 시도 단위. 지역을 늘리려면 여기에 추가 (예: 경기 41, 인천 28, 대구 27)
REGIONS = [("ctprvnCd", "11"), ("ctprvnCd", "26")]  # 서울, 부산
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "public_shops.json")

# 앱의 shopCategories 와 같은 문자열. 위에서부터 먼저 맞는 것으로 분류.
# shortcut: 업종명·상호 키워드로 분류해서 일부 오분류 가능, 정확도가 필요하면 결과를 직접 검수
RULES = [
    ("🎨 타투", lambda s, n: re.search(r"타투|tattoo", n, re.I)),
    ("👁️ 속눈썹", lambda s, n: re.search(r"속눈썹|래쉬|래시|lash", n, re.I)),
    ("💄 메이크업", lambda s, n: re.search(r"메이크업|makeup|make-up", n, re.I)),
    ("💅 네일", lambda s, n: "네일" in s or re.search(r"네일|nail", n, re.I)),
    ("🎂 케이크", lambda s, n: re.search(r"케이크|케익|cake", n, re.I)),
    ("💐 꽃집", lambda s, n: "꽃" in s or re.search(r"꽃|플라워|flower", n, re.I)),
]

# 카테고리별로 허용하는 업종(소분류명). 상호 키워드만 맞고 업종이 다른 곳(여행사 '스타투어', 한정식 '꽃' 등)을 걸러냄
BEAUTY = {"네일숍", "피부 관리실", "미용실"}
ALLOWED = {
    "🎨 타투": {"시각 디자인업", "패션/섬유/기타 전문 디자인업", "피부/비뇨기과 의원"},
    "👁️ 속눈썹": BEAUTY,
    "💄 메이크업": BEAUTY,
    "💅 네일": BEAUTY,
    "🎂 케이크": {"빵/도넛", "카페"},
    "💐 꽃집": {"꽃집"},
}


def fetch_page(key, div_id, code, page):
    query = urllib.parse.urlencode({
        "serviceKey": key, "divId": div_id, "key": code,
        "type": "json", "numOfRows": 1000, "pageNo": page,
    })
    # 기본 Python-urllib User-Agent 는 공공데이터 게이트웨이가 403으로 막는 경우가 있음
    req = urllib.request.Request(f"{API}?{query}", headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(3):  # 수백 페이지를 받으니 일시적인 끊김은 다시 시도
        try:
            with urllib.request.urlopen(req, timeout=60) as res:
                text = res.read().decode("utf-8")
            break
        except urllib.error.HTTPError as e:
            # 오류 본문만 출력 (요청 URL에는 키가 들어 있어서 출력하지 않음)
            sys.exit(f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')[:300]}")
        except OSError as e:
            if attempt == 2:
                sys.exit(f"{code} {page}페이지 연결 실패: {e}")
            time.sleep(5)
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        sys.exit(f"API가 JSON이 아닌 응답을 보냄 (키 확인 필요):\n{text[:300]}")
    result = data["header"]["resultCode"]
    if result == "03":  # 데이터 없음 = 마지막 페이지 다음
        return [], 0
    if result != "00":
        sys.exit(f"API 오류 {result}: {data['header'].get('resultMsg')}")
    return data["body"]["items"], data["body"]["totalCount"]


def classify(item):
    scls, name = item.get("indsSclsNm") or "", item.get("bizesNm") or ""
    if "팬케이크" in name:
        return None
    for category, match in RULES:
        if match(scls, name):
            return category if scls in ALLOWED[category] else None
    return None


def key_from_env_file():
    """환경변수가 없으면 위쪽 폴더의 .env.local (vercel env pull 결과)에서 DATA_GO_KR_KEY 를 찾음"""
    folder = os.path.abspath(os.path.dirname(__file__))
    while True:
        path = os.path.join(folder, ".env.local")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                for line in f:
                    name, _, value = line.strip().partition("=")
                    if name == "DATA_GO_KR_KEY":
                        return value.strip().strip('"')
        parent = os.path.dirname(folder)
        if parent == folder:
            return ""
        folder = parent


def main():
    # Encoding 키(%2B 등 포함)를 넣어도 동작하게 한 번 풀어줌 (아래에서 다시 인코딩함)
    raw = os.environ.get("DATA_GO_KR_KEY", "").strip() or key_from_env_file()
    key = urllib.parse.unquote(raw)
    if not key:
        sys.exit("DATA_GO_KR_KEY 가 없어요. PowerShell 환경변수나 .env.local 에 넣어 주세요.")
    print(f"인증키 {len(key)}자 읽음")  # 키 내용은 일부라도 출력하지 않음

    shops = []
    for div_id, code in REGIONS:
        page, total = 1, None
        while True:
            items, count = fetch_page(key, div_id, code, page)
            total = total or count
            if not items:
                break
            for item in items:
                category = classify(item)
                if category:
                    shops.append({
                        "industry": item.get("indsSclsNm") or "",  # 오분류 검수용 (저장 전에 뺌)
                        "id": item["bizesId"],
                        "name": item["bizesNm"] + (f" {item['brchNm']}" if item.get("brchNm") else ""),
                        "category": category,
                        "address": item.get("rdnmAdr") or item.get("lnoAdr") or "",
                        "floor": f"{item['flrNo']}층" if item.get("flrNo") else "",
                        "lat": round(float(item["lat"]), 6),
                        "lng": round(float(item["lon"]), 6),
                    })
            print(f"{code} page {page}: {page * 1000}/{total} (누적 {len(shops)}곳)", flush=True)
            if page * 1000 >= total:
                break
            page += 1

    print(Counter((s["category"], s.pop("industry")) for s in shops).most_common(40))
    with open(OUT, "w", encoding="utf-8") as f:
        # 앱이 통째로 읽는 파일이라 공백 없이 저장 (용량 줄이기)
        json.dump(shops, f, ensure_ascii=False, separators=(",", ":"))
    print(f"\n{len(shops)}곳 저장 -> {os.path.normpath(OUT)} ({os.path.getsize(OUT) // 1024}KB)")
    print(Counter(s["category"] for s in shops))


if __name__ == "__main__":
    main()
