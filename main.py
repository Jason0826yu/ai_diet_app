import os
import logging
from typing import List, Optional, Literal, Any
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# --------- Logging ----------
logger = logging.getLogger("ai_diet_backend")
logging.basicConfig(level=logging.INFO)

# --------- FastAPI ----------
app = FastAPI(title="AI Diet Backend", version="1.0.0")

# 允許跨網域（給 Flutter 打）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # demo 先放寬，之後可改成指定網域
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --------- Models (Request) ----------
GoalType = Literal["muscle_gain", "fat_loss", "maintenance"]

class Context(BaseModel):
    goal_type: GoalType = "maintenance"
    today_date: Optional[str] = None
    current_time: Optional[str] = None
    timezone: Optional[str] = "Asia/Taipei"

class FoodLog(BaseModel):
    date: Optional[str] = None
    time: Optional[str] = None
    meal_type: str
    description: str

class UserProfile(BaseModel):
    age: Optional[int] = None
    gender: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    body_fat_percent: Optional[float] = None
    target_weight_kg: Optional[float] = None
    activity_level: Optional[str] = None
    dietary_notes: Optional[str] = None
    country: Optional[str] = None
    lifestyle: Optional[str] = None

class AnalyzeDayRequest(BaseModel):
    context: Context
    food_logs: List[FoodLog] = Field(default_factory=list)
    user_profile: Optional[UserProfile] = None

# --------- Models (Response) ----------
class AnalyzeDayResponse(BaseModel):
    success: bool = True
    score: int
    analysis_text: str
    is_backup: bool = False

# --------- Helpers ----------
def estimate_score(goal_type: str, logs: List[FoodLog]) -> int:
    # 很簡單的估分：先能動、可 demo，之後你再換成更聰明的規則/模型
    if not logs:
        return 50

    text = " ".join([x.description for x in logs]).lower()
    score = 60

    # 有蛋白質關鍵字加分
    protein_kw = ["雞", "牛", "豬", "魚", "蛋", "豆腐", "豆漿", "優格", "鮪魚", "牛奶"]
    veg_kw = ["菜", "青菜", "沙拉", "花椰菜", "菠菜", "高麗菜", "番茄", "小黃瓜"]
    sugar_kw = ["珍奶", "奶茶", "可樂", "含糖", "手搖", "多糖", "全糖", "半糖"]

    if any(k in text for k in protein_kw):
        score += 10
    if any(k in text for k in veg_kw):
        score += 10
    if any(k in text for k in sugar_kw):
        score -= 10

    # 目標微調
    if goal_type == "muscle_gain" and any(k in text for k in protein_kw):
        score += 5
    if goal_type == "fat_loss" and any(k in text for k in sugar_kw):
        score -= 5

    # clamp
    score = max(0, min(100, score))
    return score


def goal_text(goal_type: str) -> str:
    return {
        "muscle_gain": "增肌",
        "fat_loss": "瘦身",
        "maintenance": "維持體態",
    }.get(goal_type, "維持體態")


def country_hint(profile: Optional[UserProfile]) -> str:
    c = (profile.country or "").strip().lower() if profile else ""
    if "台" in c or "taiwan" in c or c in ("tw",):
        return "請用台灣情境舉例（7-11、全家、便當店、自助餐、早餐店、手搖飲），講出『去哪裡買什麼』。"
    if "japan" in c or c in ("jp",) or "日本" in c:
        return "請用日本情境舉例（コンビニ、定食、超市熟食）。"
    if "korea" in c or c in ("kr",) or "韓" in c:
        return "請用韓國情境舉例（便利商店、湯飯、紫菜包飯）。"
    if "usa" in c or "united states" in c or c in ("us",):
        return "請用美國情境舉例（超市熟食、salad bar、sandwich）。"
    return "請用一般城市情境舉例（超市、便利商店、外食）。"


def format_profile(profile: Optional[UserProfile]) -> str:
    if not profile:
        return "未提供個人資料。"
    lines = []
    if profile.age is not None: lines.append(f"年齡：{profile.age}")
    if profile.gender: lines.append(f"性別：{profile.gender}")
    if profile.height_cm is not None: lines.append(f"身高：{profile.height_cm} cm")
    if profile.weight_kg is not None: lines.append(f"體重：{profile.weight_kg} kg")
    if profile.body_fat_percent is not None: lines.append(f"體脂：{profile.body_fat_percent}%")
    if profile.target_weight_kg is not None: lines.append(f"目標體重：{profile.target_weight_kg} kg")
    if profile.activity_level: lines.append(f"活動量：{profile.activity_level}")
    if profile.dietary_notes: lines.append(f"飲食限制：{profile.dietary_notes}")
    if profile.country: lines.append(f"國家：{profile.country}")
    if profile.lifestyle: lines.append(f"生活型態：{profile.lifestyle}")
    return "\n".join(lines) if lines else "未提供個人資料。"


def format_logs(logs: List[FoodLog]) -> str:
    if not logs:
        return "（無紀錄）"
    out = []
    for i, x in enumerate(logs, 1):
        dt = (x.date or "") + (" " + x.time if x.time else "")
        out.append(f"{i}. {dt} {x.meal_type}：{x.description}")
    return "\n".join(out)


async def call_openai(system_prompt: str, user_prompt: str) -> str:
    # 關鍵：不要在 import 時就初始化 OpenAI，避免沒 key 就整個炸
    from openai import OpenAI

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY not set")

    client = OpenAI(api_key=api_key)

    resp = client.chat.completions.create(
        model=os.getenv("OPENAI_MODEL", "gpt-4.1-mini"),
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.8,
    )
    return (resp.choices[0].message.content or "").strip()


# --------- Routes ----------
@app.get("/health")
def health():
    return {"ok": True}


@app.post("/analyze-day", response_model=AnalyzeDayResponse)
async def analyze_day(payload: AnalyzeDayRequest):
    ctx = payload.context
    logs = payload.food_logs
    profile = payload.user_profile

    # 沒紀錄：直接回友善文字（analysis_text 一定要有）
    if not logs:
        text = (
            "【AI 分析結果】\n\n"
            "你今天還沒有任何飲食紀錄。\n"
            "先記錄至少 1～2 餐（餐別＋吃了什麼），我才能做個人化建議。"
        )
        return AnalyzeDayResponse(score=50, analysis_text=text, is_backup=True)

    score = estimate_score(ctx.goal_type, logs)
    gtext = goal_text(ctx.goal_type)
    phint = country_hint(profile)

    system_prompt = f"""
你是一位「專屬貼身 AI 營養師」，用繁體中文、台灣口吻，講得具體、像真人教練。
目標：{gtext}

你必須照這個格式回覆（每段都要有）：
A. 今天整體表現總結
B. 今天吃得不錯的地方
C. 今天可以改進的地方
D. 明天可以怎麼做更好（要非常具體：去哪裡買、買什麼、怎麼點）

規則：
- 先在最上面寫：今天整體大概 {score} 分（0–100）。
- 不要講大道理，要給可執行的選項。
- {phint}
- 不要輸出 JSON、不要輸出程式碼。
""".strip()

    user_prompt = f"""
【使用者個人資料】
{format_profile(profile)}

【今日飲食紀錄】
{format_logs(logs)}
""".strip()

    try:
        ai_text = await call_openai(system_prompt, user_prompt)

        # 重要：保證不會空字串，避免你 App 顯示「後端回傳空白」
        if not ai_text:
            raise RuntimeError("OpenAI returned empty content")

        full_text = f"【AI 分析結果】\n\n{ai_text}"
        return AnalyzeDayResponse(score=score, analysis_text=full_text, is_backup=False)

    except Exception as e:
        logger.error(f"OpenAI error: {e}")

        backup = (
            "【AI 分析結果】\n\n"
            f"今天整體大概 {score} 分。\n\n"
            "目前暫時無法取得雲端 AI 回覆，所以先給你『快速可用』的建議：\n"
            "A. 今天整體表現總結\n"
            "- 先讓每餐至少有：蛋白質＋主食＋一份蔬菜。\n\n"
            "B. 今天吃得不錯的地方\n"
            "- 你有記錄，這件事本身就很強。\n\n"
            "C. 今天可以改進的地方\n"
            "- 下一餐優先補蛋白質（茶葉蛋/雞胸/豆漿/優格）。\n"
            "- 加一份青菜（自助餐夾兩樣青菜）。\n\n"
            "D. 明天可以怎麼做更好\n"
            "- 7-11/全家：烤地瓜＋茶葉蛋＋無糖豆漿\n"
            "- 便當店：主菜選雞/魚，飯七分滿，多一份青菜\n"
        )
        return AnalyzeDayResponse(score=score, analysis_text=backup, is_backup=True)
