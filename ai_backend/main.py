from fastapi import FastAPI
from pydantic import BaseModel
from typing import List

app = FastAPI()

class FoodRecord(BaseModel):
    time: str
    mealType: str
    description: str

class AnalyzeRequest(BaseModel):
    date: str
    goal: str
    records: List[FoodRecord]

class AnalyzeResponse(BaseModel):
    score: int
    summary: str
    suggestions: List[str]

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/analyze-day", response_model=AnalyzeResponse)
def analyze_day(req: AnalyzeRequest):
    # 先用假 AI 回傳
    score = 75
    summary = f"今天共記錄 {len(req.records)} 餐，整體飲食尚可。"
    suggestions = [
        "多補充蛋白質",
        "少喝含糖飲料",
        "每餐加一份蔬菜"
    ]

    return AnalyzeResponse(
        score=score,
        summary=summary,
        suggestions=suggestions
    )
