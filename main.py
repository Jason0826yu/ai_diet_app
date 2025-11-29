import os
import logging
from typing import List, Optional

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from openai import OpenAI

# ========= 基本設定 =========

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Demo 用先全開
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logger = logging.getLogger("ai_diet_app")
logging.basicConfig(level=logging.INFO)

# OpenAI Client（用環境變數讀 API Key）
client = OpenAI()


# ========= Pydantic Models =========

class FoodLog(BaseModel):
    date: str
    time: str
    meal_type: str
    description: str


class Context(BaseModel):
    goal_type: str  # "muscle_gain" / "fat_loss" / "maintenance"
    today_date: Optional[str] = None
    current_time: Optional[str] = None
    timezone: Optional[str] = None


class UserProfile(BaseModel):
    age: Optional[int] = None
    gender: Optional[str] = None  # "male" / "female" / "other"
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    body_fat_percent: Optional[float] = None
    target_weight_kg: Optional[float] = None
    activity_level: Optional[str] = None  # "sedentary" / "normal" / "high"
    dietary_notes: Optional[str] = None  # 乳糖不耐、素食等備註
    country: Optional[str] = None        # "taiwan" / "japan" / "usa" / ...
    lifestyle: Optional[str] = None      # "student" / "office_worker" / ...


class AnalyzeDayRequest(BaseModel):
    context: Context
    request_type: str
    food_logs: List[FoodLog]
    user_profile: Optional[UserProfile] = None  # 之後前端會塞進來，可為 None


class AnalyzeDayResponse(BaseModel):
    success: bool
    score: int
    analysis_text: str
    is_backup: bool = False  # True = 用備用簡單邏輯，不是 OpenAI 回的


# ========= Health Check =========

@app.get("/health")
async def health():
    return {"status": "ok"}


# ========= 工具：根據紀錄粗略算一個分數 =========

def estimate_score(context: Context, food_logs: List[FoodLog]) -> int:
    """
    很簡單的 rule-based 分數，給 AI 當參考用。
    不用太準，重點是讓建議有「分數感」。
    """
    base = 50

    count = len(food_logs)
    if count == 0:
        return 50

    # 餐數適中加分
    if 2 <= count <= 4:
        base += 15
    elif count == 1 or count == 5:
        base += 5
    else:
        base -= 5

    # 目標微調
    if context.goal_type == "muscle_gain":
        base += 5
    elif context.goal_type == "fat_loss":
        base += 0
    else:  # maintenance
        base += 3

    # 限制在 40～95 之間
    base = max(40, min(95, base))
    return int(base)


# ========= 主功能：分析今天飲食 =========

@app.post("/analyze-day", response_model=AnalyzeDayResponse)
async def analyze_day(payload: AnalyzeDayRequest):
    ctx = payload.context
    logs = payload.food_logs
    profile = payload.user_profile

    # 0. 如果今天沒紀錄，就回一個友善訊息
    if not logs:
        text = (
            "【AI 分析結果】\n\n"
            "今天還沒有任何飲食紀錄喔。\n\n"
            "建議先記錄至少 1～2 餐，包含餐別（早餐／午餐／晚餐／點心）\n"
            "以及簡單描述你吃了什麼，這樣我才能給你比較有意義的建議。"
        )
        return AnalyzeDayResponse(
            success=True,
            score=50,
            analysis_text=text,
            is_backup=True,
        )

    # 1. 先用簡單規則估一個分數，作為 AI 參考
    score = estimate_score(ctx, logs)

    # 2. 把 food_logs 和 user_profile 整理成文字，給模型看
    goal_map = {
        "muscle_gain": "增肌",
        "fat_loss": "瘦身",
        "maintenance": "維持體態",
    }
    goal_text = goal_map.get(ctx.goal_type, "維持體態")

    # 食物紀錄摘要
    log_lines = []
    for i, log in enumerate(logs, 1):
        log_lines.append(
            f"{i}. {log.date} {log.time} ─ {log.meal_type}：{log.description}"
        )
    logs_text = "\n".join(log_lines)

    # 使用者個人資料摘要（可能為 None，要小心處理）
    profile_lines = []
    if profile:
        if profile.age:
            profile_lines.append(f"年齡：約 {profile.age} 歲")
        if profile.gender:
            profile_lines.append(f"性別：{profile.gender}")
        if profile.height_cm:
            profile_lines.append(f"身高：約 {profile.height_cm} 公分")
        if profile.weight_kg:
            profile_lines.append(f"體重：約 {profile.weight_kg} 公斤")
        if profile.activity_level:
            profile_lines.append(f"活動量：{profile.activity_level}")
        if profile.dietary_notes:
            profile_lines.append(f"飲食限制／備註：{profile.dietary_notes}")
        if profile.country:
            profile_lines.append(f"所在國家：{profile.country}")
        if profile.lifestyle:
            profile_lines.append(f"生活型態：{profile.lifestyle}")
    profile_text = "\n".join(profile_lines) if profile_lines else "未提供詳細個人資料。"

    # 根據國家，給模型不同指示
    country_hint = ""
    country = (profile.country or "").lower() if profile else ""
    if "taiwan" in country or "tw" == country:
        country_hint = (
            "使用台灣生活情境的例子，例如：便利商店（7-11、全家）、便當店、自助餐、手搖飲店等。"
        )
    elif "japan" in country or "jp" == country:
        country_hint = (
            "使用日本常見情境，例如：便利商店便當、定食屋、壽司店等。"
        )
    elif "korea" in country or "kr" == country:
        country_hint = (
            "使用韓國常見情境，例如：紫菜包飯、湯飯、炸雞配啤酒、便利商店等。"
        )
    elif "usa" in country or "us" == country or "united states" in country:
        country_hint = (
            "使用美國常見情境，例如：三明治店、沙拉吧、超市熟食、快餐店中較健康的選項。"
        )
    else:
        country_hint = (
            "使用一般城市生活情境的例子，例如：超市、便利商店、外食餐廳等。"
        )

    # 3. 呼叫 OpenAI：請他幫忙寫一段完整、像真人教練的建議
    system_prompt = f"""
你是一位貼身 AI 營養師，要用「自然的台灣中文」給出具體、可執行的飲食建議，
口吻友善、像在跟高中生說話，但不要太幼稚，也不要太命令式。

使用者目前的目標是：「{goal_text}」。

請依照以下原則回應：
1. 先用一行說明今天整體大概幾分（0–100 分），但數字請使用後端給你的分數：{score} 分。
2. 分成四個小段落，每一段前面加上明確標題：
   A. 今天整體表現總結
   B. 今天吃得不錯的地方
   C. 今天可以改進的地方
   D. 明天可以怎麼做更好（具體到「可以去哪裡買什麼類型的食物」）

3. 每一點都盡量具體，不要只說「多吃健康食物」，要像：
   - 「可以去全家買地瓜＋茶葉蛋」
   - 「自助餐選 1 份肉、2 份青菜，飯七分滿」
4. {country_hint}
5. 回覆請全部使用繁體中文，不要出現程式碼或 JSON，只要可讀文字即可。
6. 可以適度使用條列式（-、1. 2. 3.），讓內容好讀，但不要太長篇大論。
"""

    user_prompt = f"""
【今日基本資訊】
目標：{goal_text}
日期：{ctx.today_date or "-"}
時區：{ctx.timezone or "-"}

【使用者個人資料】
{profile_text}

【今日飲食紀錄】
{logs_text}

請根據以上資訊，產生一段「貼身 AI 營養教練」風格的回覆。
記得使用給你的分數 {score} 分作為整體評分的基準。
"""

    try:
        completion = client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.7,
        )

        ai_text = completion.choices[0].message.content or ""
        full_text = f"【AI 分析結果】\n\n{ai_text}"

        return AnalyzeDayResponse(
            success=True,
            score=score,
            analysis_text=full_text,
            is_backup=False,
        )

    except Exception as e:
        # 發生錯誤時：記 log，改用備用簡單訊息
        logger.error(f"OpenAI 錯誤：{e}")

        basic_country_note = (
            "你可以優先利用附近的便利商店、便當店、自助餐，"
            "盡量選擇有蛋白質（雞肉、魚、蛋、豆腐）和青菜的組合，"
            "飲料以無糖或微糖為主。"
        )

        backup_text = (
            "【AI 分析結果】\n\n"
            f"今天共有 {len(logs)} 筆飲食紀錄，粗略評估大約是 {score} 分。\n\n"
            "目前暫時無法連線到雲端 AI 模型，所以這是備用的簡單規則建議：\n\n"
            "・盡量讓每一餐都包含：蛋白質來源、一些澱粉、至少一份蔬菜。\n"
            "・含糖手搖飲的頻率控制在一週 1–2 次，其他時間以水或無糖茶為主。\n"
            "・若你想要增肌，可以特別注意每天至少有 2–3 餐有明顯的蛋白質來源。\n"
            "・若你想要瘦身，可以先從減少含糖飲料和油炸開始，"
            "改成烤、滷、清蒸等做法。\n\n"
            f"{basic_country_note}\n\n"
            "之後如果雲端 AI 恢復正常，再按一次分析，就會得到更客製化的文字建議。"
        )

        return AnalyzeDayResponse(
            success=True,
            score=score,
            analysis_text=backup_text,
            is_backup=True,
        )
