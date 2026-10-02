import os
import sys
import unittest
from pathlib import Path

from bson import ObjectId
from fastapi.testclient import TestClient
from pymongo.errors import PyMongoError

os.environ.setdefault("MONGO_URI", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "semob_test")

CAMINHO_SRC = Path(__file__).resolve().parents[1] / "src"
sys.path.insert(0, str(CAMINHO_SRC))

import main


class ResultadoInsercao:
    def __init__(self, inserted_id):
        self.inserted_id = inserted_id


class ColecaoUsuariosFalsa:
    def __init__(self):
        self.documentos = []

    def find_one(self, filtro):
        return next(
            (
                documento.copy()
                for documento in self.documentos
                if all(documento.get(chave) == valor for chave, valor in filtro.items())
            ),
            None,
        )

    def insert_one(self, documento):
        documento_salvo = documento.copy()
        documento_salvo["_id"] = ObjectId()
        self.documentos.append(documento_salvo)
        return ResultadoInsercao(documento_salvo["_id"])

    def find(self):
        return [documento.copy() for documento in self.documentos]


class ColecaoComErro(ColecaoUsuariosFalsa):
    def find_one(self, filtro):
        raise PyMongoError("detalhes internos do banco")


class TesteAutenticacao(unittest.TestCase):
    def setUp(self):
        self.colecao = ColecaoUsuariosFalsa()
        main.colecao_usuarios = self.colecao
        self.cliente = TestClient(main.app)
        self.usuario = {
            "nome": "Rafael Palumbo",
            "cpf": "12345678901",
            "email": "Rafa@Email.com",
            "celular": "11999999999",
            "senha": "12345678",
        }

    def cadastrar_usuario(self):
        return self.cliente.post("/usuarios", json=self.usuario)

    def test_a_cadastro_salva_hash_e_retorna_sucesso_sem_senha(self):
        resposta = self.cadastrar_usuario()

        self.assertEqual(resposta.status_code, 201)
        self.assertEqual(resposta.json()["mensagem"], "Usuário criado com sucesso")
        self.assertNotIn("senha", resposta.text)
        self.assertEqual(len(self.colecao.documentos), 1)

        usuario_salvo = self.colecao.documentos[0]
        self.assertEqual(usuario_salvo["email"], "rafa@email.com")
        self.assertNotIn("senha", usuario_salvo)
        self.assertIn("senha_hash", usuario_salvo)
        self.assertNotEqual(usuario_salvo["senha_hash"], "12345678")
        self.assertTrue(usuario_salvo["senha_hash"].startswith("$argon2"))

    def test_b_cadastro_repetido_ignorando_maiusculas_retorna_409(self):
        primeira_resposta = self.cadastrar_usuario()
        segunda_resposta = self.cadastrar_usuario()

        self.assertEqual(primeira_resposta.status_code, 201)
        self.assertEqual(segunda_resposta.status_code, 409)
        self.assertEqual(segunda_resposta.json()["detail"], "E-mail já cadastrado")
        self.assertEqual(len(self.colecao.documentos), 1)

    def test_c_login_com_email_normalizado_e_senha_correta_retorna_usuario(self):
        self.assertEqual(self.cadastrar_usuario().status_code, 201)

        resposta = self.cliente.post(
            "/login",
            json={"email": "  RAFA@EMAIL.COM  ", "senha": "12345678"},
        )

        self.assertEqual(resposta.status_code, 200)
        self.assertEqual(resposta.json()["mensagem"], "Login realizado com sucesso")
        self.assertEqual(resposta.json()["usuario"]["nome"], "Rafael Palumbo")
        self.assertEqual(resposta.json()["usuario"]["email"], "rafa@email.com")
        self.assertNotIn("senha", resposta.text)

    def test_d_login_com_senha_incorreta_retorna_401(self):
        self.assertEqual(self.cadastrar_usuario().status_code, 201)

        resposta = self.cliente.post(
            "/login",
            json={"email": "rafa@email.com", "senha": "senha-incorreta"},
        )

        self.assertEqual(resposta.status_code, 401)
        self.assertEqual(resposta.json()["detail"], "E-mail ou senha inválidos")

    def test_e_login_com_email_inexistente_retorna_401(self):
        resposta = self.cliente.post(
            "/login",
            json={"email": "inexistente@email.com", "senha": "12345678"},
        )

        self.assertEqual(resposta.status_code, 401)
        self.assertEqual(resposta.json()["detail"], "E-mail ou senha inválidos")

    def test_f_listagem_nao_expoe_senha_nem_hash(self):
        self.assertEqual(self.cadastrar_usuario().status_code, 201)

        resposta = self.cliente.get("/usuarios")

        self.assertEqual(resposta.status_code, 200)
        self.assertEqual(len(resposta.json()), 1)
        self.assertEqual(
            set(resposta.json()[0]),
            {"id", "nome", "email"},
        )
        self.assertNotIn("senha", resposta.text)
        self.assertNotIn("hash", resposta.text)

    def test_cadastro_rejeita_campos_essenciais_invalidos(self):
        resposta = self.cliente.post(
            "/usuarios",
            json={
                "nome": " ",
                "cpf": "123",
                "email": "email-invalido",
                "celular": "1199",
                "senha": "curta",
            },
        )

        self.assertEqual(resposta.status_code, 400)
        self.assertEqual(resposta.json()["detail"], "Dados inválidos")
        self.assertNotIn("curta", resposta.text)
        self.assertEqual(self.colecao.documentos, [])

    def test_falha_do_mongo_retorna_500_sem_detalhes_internos(self):
        main.colecao_usuarios = ColecaoComErro()

        resposta = self.cliente.post("/usuarios", json=self.usuario)

        self.assertEqual(resposta.status_code, 500)
        self.assertEqual(
            resposta.json()["detail"],
            "Não foi possível concluir o cadastro",
        )
        self.assertNotIn("detalhes internos", resposta.text)

    def test_cors_nao_permite_credenciais(self):
        resposta = self.cliente.options(
            "/login",
            headers={
                "Origin": "http://localhost:5000",
                "Access-Control-Request-Method": "POST",
            },
        )

        self.assertEqual(resposta.status_code, 200)
        self.assertNotIn("access-control-allow-credentials", resposta.headers)


if __name__ == "__main__":
    unittest.main()
