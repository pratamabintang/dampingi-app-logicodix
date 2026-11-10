class AIError(Exception):
    user_message = "Asisten sedang tidak dapat menjawab. Coba lagi sebentar lagi."


class AITimeout(AIError):
    user_message = "Asisten butuh waktu terlalu lama. Coba kirim ulang pesanmu."


class AIUnavailable(AIError):
    """Layanan AI error / tidak bisa dihubungi."""


class AIBadOutput(AIError):
    """AI menjawab, tapi bentuk jawabannya tidak sesuai skema."""