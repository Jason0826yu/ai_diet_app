import os
from fastapi import FastAPI, Request
from openai import OpenAI

# 從環境變數拿你的 OPENAI_API_KEY
client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))

app = FastAPI()


# ========= 健康檢查 =========
@app.get("/health")
def health():
    return {"status": "ok"}


# ========= 主要分析 API（不丟 400/422，永遠回 200） =========
@app.post("/analyze-day")
async def analyze_day(request: Request):
    """
    這裡不用 Pydantic，直接吃任何 JSON，
    解析失敗或資料怪怪的，也只會回「備用建議」，不會丟 400/422。
    """

    # 預設值：如果等等解析失敗，可以用這些當保底
    score = 60
    meal_count = 0
    logs_text = "（今天沒有成功取得詳細的飲食紀錄）"
    goal_text = "維持體態"
    goal_type = "unknown"
    timezone = "Asia/Taipei"
    today_date = "（未提供）"
    request_type = ""
    profile_text = "（未填個人資料）"

    try:
        data = await request.json()
    except Exception:
        # 連 JSON 都解析失敗：回一個通用備用建議
        backup = f"""
目前後端沒有成功收到你的詳細資料，不過先給你一個簡單的方向：

今天粗略評分約 {score} 分。

你可以先這樣做：
1. 每天至少 1–2 餐有蛋白質：去 7-11 / 全家 買茶葉蛋、無糖豆漿、雞胸肉沙拉。
2. 至少一餐看得到青菜：去便當店 / 自助餐說「飯少一點，多一份青菜」。
3. 含糖飲料盡量壓在 0–1 杯，其餘改成無糖茶或白開水。
"""
        return {
            "score": score,
            "summary": backup,
            "suggestions": [],
        }

    # 走到這裡代表至少 JSON 解析成功了
    context = data.get("context") or {}
    request_type = data.get("request_type") or ""
    food_logs = data.get("food_logs") or []
    user_profile = data.get("user_profile") or {}

    # 目標
    goal_type = (context.get("goal_type") or "").strip()
    if goal_type == "muscle_gain":
        goal_text = "增肌"
    elif goal_type == "fat_loss":
        goal_text = "瘦身"
    elif goal_type == "maintenance":
        goal_text = "維持體態"
    else:
        goal_text = "維持體態"

    today_date = context.get("today_date") or (
        food_logs[0].get("date") if isinstance(food_logs, list) and food_logs else "（未提供）"
    )
    timezone = context.get("timezone") or "Asia/Taipei"

    # 整理今天吃的東西
    if isinstance(food_logs, list) and len(food_logs) > 0:
        meal_count = len(food_logs)
        lines = []
        for log in food_logs:
            if not isinstance(log, dict):
                continue
            time_str = log.get("time", "")
            meal_type = log.get("meal_type", "")
            desc = log.get("description", "")
            lines.append(f"- {time_str}{desc}")
        if lines:
            logs_text = "\n".join(lines)
        else:
            logs_text = "（有收到 food_logs，但內容格式怪怪的，無法完整解析）"
    else:
        meal_count = 0
        logs_text = "（今天沒有提供任何具體的餐點紀錄）"

    # 粗略打分（只是給一個感覺）
    base_score = 50 + min(4, meal_count) * 10
    if goal_type == "fat_loss" and meal_count >= 5:
        base_score -= 10
    score = max(30, min(95, base_score))

    # 個人資料（會影響 AI 語氣與建議）
    profile_lines = []
    if isinstance(user_profile, dict):
        age = user_profile.get("age")
        gender = user_profile.get("gender")
        height_cm = user_profile.get("height_cm")
        weight_kg = user_profile.get("weight_kg")
        body_fat = user_profile.get("body_fat")
        target_weight_kg = user_profile.get("target_weight_kg")
        activity_level = user_profile.get("activity_level")
        special_diet = user_profile.get("special_diet")
        location = user_profile.get("location")

        if age is not None:
            profile_lines.append(f"年齡：{age}")
        if gender:
            profile_lines.append(f"性別：{gender}")
        if height_cm is not None:
            profile_lines.append(f"身高：{height_cm} 公分")
        if weight_kg is not None:
            profile_lines.append(f"體重：{weight_kg} 公斤")
        if body_fat is not None:
            profile_lines.append(f"體脂率：約 {body_fat}%")
        if target_weight_kg is not None:
            profile_lines.append(f"目標體重：{target_weight_kg} 公斤")
        if activity_level:
            profile_lines.append(f"活動量：{activity_level}")
        if special_diet:
            profile_lines.append(f"特殊飲食需求：{special_diet}")
        if location:
            profile_lines.append(f"地點：{location}")

    if profile_lines:
        profile_text = "\n".join(profile_lines)

    # ===== 給模型的角色指令（更重視個人資料） =====
    instructions = """
你是一位在台灣的營養教練，對台灣高中生日常飲食非常熟（便當店、自助餐、學校附近小吃、全家、7-11、萊爾富、OK 便利商店……）。

請用【繁體中文、台灣用語】，口氣友善、實際可行，不要太嚴厲，像學長姐或家教老師在聊天。

請特別根據「使用者個人資料」調整建議，包括：
- 年齡、性別
- 身高、體重、（如果有）體脂率
- 目標體重：如果現在比目標重很多，減脂建議要更明確；如果已經接近目標，不要太嚴格。
- 活動量：久坐 / 普通 / 高度活動，會影響吃的份量與碳水需求。
- 特殊飲食需求：例如乳糖不耐、素食，要避免不適合的食物，主動給替代方案。
- 地點（如果有）：例如在台北，可以更肯定說「附近便利商店一定有」。

另外，請注意：
1. 使用者的大部分飲食來源會是：
   - 便利商店（全家、7-11、萊爾富、OK）
   - 便當店、自助餐
   - 學校附近小吃、學校福利社
   - 手搖飲店
   預算有限，不要建議太貴或太難找到的食物。

2. 建議一定要「具體」＋「在台灣買得到」，像是：
   - 便利商店：寫清楚可以買「茶葉蛋、地瓜、無糖茶、沙拉、飯糰、無糖豆漿、雞胸肉」。
   - 便當店 / 自助餐：可以說「跟老闆說飯少一點，多一份青菜，主菜選雞胸、魚、滷雞腿」。
   - 小吃店：例如「滷味多點青菜、豆干、蛋，少一點內臟和炸物」。

3. 如果使用者有標示特殊飲食（例如：乳糖不耐、素食），務必：
   - 避免不適合的食材
   - 主動幫他找在台灣超商或便當店「買得到的替代方案」。

4. 【很重要】系統已經幫你算出一個「今天整體分數（0–100）」，你不要自己再重新打分，只要沿用這個分數來形容即可。
   - 可以用「大概 xx 分左右」、「接近 xx 分」這種說法，但數字要跟系統給的一致。

5. 回答內容的結構建議：
   A. 今天整體大概幾分（0–100 分），引用系統給你的分數，簡單講 2–3 句理由，理由可以結合：個人資料＋今天的紀錄。
   B. 今天吃得不錯的地方（條列 2–4 點），可以提到：
      - 有符合他目標（增肌 / 瘦身 / 維持體態）
      - 有照顧到蛋白質、青菜、全穀類、喝水等
   C. 今天可以改進的地方（條列 2–4 點），要根據他的目標和個人資料微調：
      - 目標增肌：多提醒蛋白質和總熱量夠不夠
      - 目標瘦身：提醒總量控制與含糖飲料頻率
      - 維持體態：提醒維持目前好習慣、避免暴飲暴食
   D. 明天可以怎麼做更好（給 3–5 個非常具體的行動建議），每一點都要寫：
      - 吃什麼（舉例）
      - 大概要吃多少（大概份量就好，例如「一碗飯」、「一小杯」、「一份主菜」）
      - 可以去哪裡買（便利商店 / 便當店 / 自助餐 / 學校福利社……）。
"""

    # ===== 給模型看的 input =====
    user_prompt = f"""
[系統評估分數（0–100）]
{score}

[使用者目標]
{goal_text}（原始代碼：{goal_type or "未提供"}）

[使用者所在地]
台灣（時區：{timezone}）

[今天日期]
{today_date}

[request_type]
{request_type}

[使用者個人資料]
{profile_text}

[今天的飲食紀錄]
{logs_text}

請依照上面的說明，幫這位在台灣的學生做「真正個人化」的飲食分析與具體建議。
"""

    try:
        resp = client.responses.create(
            model="gpt-4o-mini",
            instructions=instructions.strip(),
            input=user_prompt.strip(),
        )
        ai_text = resp.output_text
    except Exception as e:
        print("OpenAI 錯誤：", e)
        ai_text = f"""
目前暫時無法連線到真正的 AI 模型，以下是備用的簡單建議：

今天粗略評分約 {score} 分。

你可以先這樣做：
1. 每天至少 1–2 餐有蛋白質：在 7-11 / 全家 買茶葉蛋、無糖豆漿、雞胸肉沙拉。
2. 至少一餐看得到青菜：去便當店 / 自助餐說「飯少一點，多一份青菜」。
3. 含糖飲料盡量壓在 0–1 杯，其餘改成無糖茶或白開水。

之後 AI 恢復正常時，就會用你這些紀錄做更細的分析。
"""

    # 不管怎樣都回 200，讓前端好處理
    return {
        "score": score,
        "summary": ai_text,
        "suggestions": [],
    }
