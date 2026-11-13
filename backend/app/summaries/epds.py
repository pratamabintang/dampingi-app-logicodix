from pydantic import BaseModel, Field, validator

class EPDSResult(BaseModel):
    score: int = Field(..., ge=0, le=30, description="Lightweight EPDS‑like score (0‑30)")
    risk_flag: str = Field(..., description="Risk category derived from the score")

    @validator("risk_flag")
    def _validate_risk_flag(cls, v, values):
        score = values.get("score")
        if score is None:
            return v
        if 0 <= score <= 4:
            expected = "low"
        elif 5 <= score <= 9:
            expected = "moderate"
        else:
            expected = "high"
        if v != expected:
            raise ValueError(f"risk_flag '{v}' does not match score {score}, expected '{expected}'")
        return v