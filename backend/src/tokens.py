import base64
import hashlib
import hmac
import json
import time


TEMPO_TOKEN_SEGUNDOS = 8 * 60 * 60


def _codificar(valor: bytes) -> str:
    return base64.urlsafe_b64encode(valor).rstrip(b"=").decode("ascii")


def _decodificar(valor: str) -> bytes:
    valor += "=" * (-len(valor) % 4)
    return base64.urlsafe_b64decode(valor)


def criar_token(usuario_id: str, segredo: str) -> str:
    dados = json.dumps({
        "sub": usuario_id,
        "exp": int(time.time()) + TEMPO_TOKEN_SEGUNDOS,
    }, separators=(",", ":")).encode("utf-8")
    conteudo = _codificar(dados)
    assinatura = hmac.new(
        segredo.encode("utf-8"), conteudo.encode("ascii"), hashlib.sha256,
    ).digest()
    return f"{conteudo}.{_codificar(assinatura)}"


def validar_token(token: str, segredo: str) -> str | None:
    try:
        conteudo, assinatura = token.split(".", 1)
        assinatura_recebida = _decodificar(assinatura)
        assinatura_correta = hmac.new(
            segredo.encode("utf-8"), conteudo.encode("ascii"), hashlib.sha256,
        ).digest()
        if not hmac.compare_digest(assinatura_recebida, assinatura_correta):
            return None

        dados = json.loads(_decodificar(conteudo))
        usuario_id = dados.get("sub")
        vencimento = dados.get("exp")
        if (not isinstance(usuario_id, str) or not usuario_id
                or not isinstance(vencimento, int)
                or vencimento <= int(time.time())):
            return None
        return usuario_id
    except (ValueError, TypeError, UnicodeError, json.JSONDecodeError):
        return None
