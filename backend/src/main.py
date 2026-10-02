from bson import ObjectId
from conexao import db
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

colecao_usuarios = db["usuarios"]

class Usuario(BaseModel):
    nome: str
    email: str

def formatar_usuario(u):
    return {
        "id": str(u.get("_id", "")),
        "nome": u.get("nome", "Sem Nome"),
        "email": u.get("email", "Sem Email"),
    }

@app.post("/usuarios")
def criar_usuario(usuario: Usuario):
    resultado = colecao_usuarios.insert_one(usuario.model_dump())
    return {"id": str(resultado.inserted_id), "mensagem": "Criado com sucesso!"}


@app.get("/usuarios")
def listar_usuarios():
    usuarios = list(colecao_usuarios.find())
    return [formatar_usuario(u) for u in usuarios]