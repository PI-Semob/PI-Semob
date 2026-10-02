import re

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError
from pydantic import BaseModel, Field, field_validator
from pymongo.errors import DuplicateKeyError, PyMongoError

from conexao import db

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

colecao_usuarios = db["usuarios"]
password_hash = PasswordHash.recommended()
PADRAO_EMAIL = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


@app.exception_handler(RequestValidationError)
async def tratar_erro_validacao(_request: Request, _erro: RequestValidationError):
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"detail": "Dados inválidos"},
    )


class UsuarioCadastro(BaseModel):
    nome: str = Field(min_length=1, max_length=120)
    cpf: str = Field(pattern=r"^\d{11}$")
    email: str = Field(min_length=3, max_length=254)
    celular: str = Field(pattern=r"^\d{11}$")
    senha: str = Field(min_length=8, max_length=128)

    @field_validator("nome", mode="before")
    @classmethod
    def limpar_nome(cls, valor):
        return valor.strip() if isinstance(valor, str) else valor

    @field_validator("email", mode="before")
    @classmethod
    def normalizar_e_validar_email(cls, valor):
        if not isinstance(valor, str):
            return valor

        email = valor.strip().lower()
        if not PADRAO_EMAIL.fullmatch(email):
            raise ValueError("E-mail inválido")
        return email


class LoginEntrada(BaseModel):
    email: str = Field(min_length=1, max_length=254)
    senha: str = Field(min_length=1, max_length=128)

    @field_validator("email", mode="before")
    @classmethod
    def normalizar_email(cls, valor):
        return valor.strip().lower() if isinstance(valor, str) else valor


class UsuarioResumo(BaseModel):
    id: str
    nome: str
    email: str


class CadastroResposta(BaseModel):
    id: str
    mensagem: str


class LoginResposta(BaseModel):
    mensagem: str
    usuario: UsuarioResumo


def formatar_usuario(usuario):
    return {
        "id": str(usuario.get("_id", "")),
        "nome": usuario.get("nome", "Sem Nome"),
        "email": usuario.get("email", "Sem Email"),
    }


def senha_valida(senha: str, hash_salvo: str | None):
    if not hash_salvo:
        return False

    try:
        return password_hash.verify(senha, hash_salvo)
    except (TypeError, UnknownHashError):
        return False


@app.post(
    "/usuarios",
    response_model=CadastroResposta,
    status_code=status.HTTP_201_CREATED,
)
def criar_usuario(usuario: UsuarioCadastro):
    try:
        if colecao_usuarios.find_one({"email": usuario.email}):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="E-mail já cadastrado",
            )

        dados_usuario = usuario.model_dump(exclude={"senha"})
        dados_usuario["senha_hash"] = password_hash.hash(usuario.senha)
        resultado = colecao_usuarios.insert_one(dados_usuario)
    except HTTPException:
        raise
    except DuplicateKeyError as erro:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="E-mail já cadastrado",
        ) from erro
    except PyMongoError as erro:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Não foi possível concluir o cadastro",
        ) from erro

    return {
        "id": str(resultado.inserted_id),
        "mensagem": "Usuário criado com sucesso",
    }


@app.post("/login", response_model=LoginResposta)
def login(credenciais: LoginEntrada):
    try:
        usuario = colecao_usuarios.find_one({"email": credenciais.email})
    except PyMongoError as erro:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Não foi possível realizar o login",
        ) from erro

    if not usuario or not senha_valida(
        credenciais.senha,
        usuario.get("senha_hash"),
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-mail ou senha inválidos",
        )

    return {
        "mensagem": "Login realizado com sucesso",
        "usuario": formatar_usuario(usuario),
    }


@app.get("/usuarios", response_model=list[UsuarioResumo])
def listar_usuarios():
    try:
        usuarios = list(colecao_usuarios.find())
    except PyMongoError as erro:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Não foi possível listar os usuários",
        ) from erro

    return [formatar_usuario(usuario) for usuario in usuarios]
