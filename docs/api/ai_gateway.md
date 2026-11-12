# AI gateway bersama (`backend/app/ai/`)

Satu pintu untuk semua pemanggilan Gemini: chatbot (C) dan ringkasan mingguan (D).
Fitur lain **tidak** memanggil `google.genai` langsung.

## Pakai

```python
from pydantic import BaseModel, ConfigDict, Field

from app.ai import AIError, Turn
from app.ai.config import build_gateway


class SummaryOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")   # field tambahan dari AI ditolak
    overview: str = Field(min_length=1)


gateway = build_gateway()                       # baca AI_PROVIDER, GEMINI_API_KEY, GEMINI_MODEL dari .env

try:
    out = await gateway.generate(SYSTEM_PROMPT, [Turn("user", payload_json)], SummaryOutput)
    overview = out.overview                     # sudah divalidasi Pydantic
except AIError as exc:
    ...                                         # fallback; exc.user_message aman ditampilkan
```

| | |
|---|---|
| `generate(system, turns, Output, schema=None) -> Output` | `system` dikirim sebagai `system_instruction` (terpisah dari `turns`). Skema JSON diturunkan otomatis dari `Output` (tanpa `title`); isi `schema=` hanya kalau perlu skema khusus. |
| `reply(system, turns) -> AIReply` | Khusus chat: `generate(..., AIReply, REPLY_JSON_SCHEMA)`. |
| `json_schema_for(Output)` | Melihat skema yang akan dikirim ke Gemini. |

## Yang otomatis berlaku untuk semua fitur

| Kejadian | Error | `user_message` |
|---|---|---|
| Lebih dari `AI_TIMEOUT_SECONDS` (default 20 dtk) | `AITimeout` | Asisten butuh waktu terlalu lama… |
| Kuota / rate limit Gemini habis (429) | `AIBusy` | Asisten sedang banyak dipakai… |
| Gemini error lain / tidak terjangkau | `AIUnavailable` | Asisten sedang tidak dapat menjawab… |
| Jawaban bukan JSON / tidak cocok dengan `Output` | `AIBadOutput` | Asisten sedang tidak dapat menjawab… |

Semuanya turunan `AIError`. Tanpa retry otomatis. Log hanya mencatat jenis error / kode status, bukan isi request.

## Tes tanpa Gemini

```python
from app.ai import AIGateway
from app.ai.providers import FakeProvider

provider = FakeProvider(response={"overview": "Mood cenderung stabil."})
gateway = AIGateway(provider)
# provider.calls   -> [(system, turns)]   apa yang dikirim
# provider.schemas -> [schema]            skema yang diminta
# FakeProvider(raw="bukan json") / (error=RuntimeError()) / (delay=1) untuk skenario gagal
```

Dengan `AI_PROVIDER=fake` (default), `build_gateway()` memakai `FakeProvider` sehingga backend jalan tanpa kunci dan tanpa kuota.