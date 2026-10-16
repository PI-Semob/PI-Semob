import io
import os
import sys
import unittest
import zipfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from fastapi.testclient import TestClient
from pymongo.errors import ServerSelectionTimeoutError

os.environ.setdefault("MONGO_URI", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "semob_test")
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

import main
import importacao


def criar_zip(arquivos):
    memoria = io.BytesIO()
    with zipfile.ZipFile(memoria, "w", zipfile.ZIP_DEFLATED) as compactado:
        for nome, conteudo in arquivos.items():
            compactado.writestr(nome, conteudo.encode("cp1252"))
    return memoria.getvalue()


HTML_PASSAGEIROS = """<html><table class='data'>
<tr><th>Mês</th><th>Dia</th><th>Total Passageiros</th></tr>
<tr><td>2026-08</td><td>01</td><td>16.544</td></tr>
<tr><td>2026-08</td><td>Total Mês</td><td>1.050.248</td></tr>
</table></html>"""


class ColecaoFalsa:
    def __init__(self):
        self.documentos = {}

    def create_index(self, *args, **kwargs):
        return "chave_importacao_1"

    def bulk_write(self, operacoes, ordered=False):
        inseridos = 0
        ignorados = 0
        for operacao in operacoes:
            chave = operacao._filter["chave_importacao"]
            if chave in self.documentos:
                ignorados += 1
            else:
                self.documentos[chave] = operacao._doc["$setOnInsert"]
                inseridos += 1
        return SimpleNamespace(upserted_count=inseridos, matched_count=ignorados)


class TesteImportacao(unittest.TestCase):
    def setUp(self):
        self.colecao_original = main.colecao_relatorios_mensais
        self.colecao = ColecaoFalsa()
        main.colecao_relatorios_mensais = self.colecao
        self.cliente = TestClient(main.app)

    def tearDown(self):
        main.colecao_relatorios_mensais = self.colecao_original

    def enviar(self, conteudo, nome="dados.zip"):
        return self.cliente.post(
            "/relatorios/importar-zip",
            files={"file": (nome, conteudo, "application/zip")},
        )

    def test_importa_todas_as_linhas_e_preserva_valores_originais(self):
        arquivo = criar_zip({"Agosto_2026/Mensal/Passageiros_Mensal.html": HTML_PASSAGEIROS})

        resposta = self.enviar(arquivo)

        self.assertEqual(resposta.status_code, 200, resposta.text)
        self.assertEqual(resposta.json()["inseridos"], 2)
        self.assertEqual(resposta.json()["ignorados"], 0)
        self.assertEqual(resposta.json()["rejeitados"], 0)
        documentos = list(self.colecao.documentos.values())
        self.assertEqual(documentos[0]["dados_originais"], {
            "Mês": "2026-08", "Dia": "01", "Total Passageiros": "16.544"
        })
        self.assertEqual(documentos[1]["dados_originais"]["Dia"], "Total Mês")
        self.assertEqual(documentos[0]["categoria"], "passageiros")
        self.assertEqual(documentos[0]["dados_tratados"]["total_passageiros"], 16544)
        self.assertEqual(documentos[1]["dados_tratados"]["total_passageiros"], 1050248)

    def test_conversao_html_de_passageiros_respeita_milhar(self):
        resposta = self.cliente.post(
            "/converter_relatorio_html",
            files={"file": ("Passageiros.html", HTML_PASSAGEIROS.encode("cp1252"),
                            "text/html")},
        )

        self.assertEqual(resposta.status_code, 200, resposta.text)
        self.assertEqual(
            [item["total_passageiros"] for item in resposta.json()["dados"]],
            [16544, 1050248],
        )

    def test_importacao_corrige_todas_as_contagens_de_passageiros(self):
        html = """<table class='data'>
        <tr><th>Mês</th><th>Dia</th><th>Catraca</th><th>Antecipados</th>
        <th>Não Pagantes</th><th>Total Passageiros</th></tr>
        <tr><td>2026-08</td><td>01</td><td>5.168</td><td>1.811</td>
        <td>10.700</td><td>16.544</td></tr></table>"""

        resposta = self.enviar(criar_zip({"Passageiros.html": html}))

        self.assertEqual(resposta.status_code, 200, resposta.text)
        tratado = next(iter(self.colecao.documentos.values()))["dados_tratados"]
        self.assertEqual(tratado["passageiros_catraca"], 5168)
        self.assertEqual(tratado["passageiros_antecipados"], 1811)
        self.assertEqual(tratado["passageiros_nao_pagantes"], 10700)
        self.assertEqual(tratado["total_passageiros"], 16544)

    def test_reimportacao_ignora_documentos_ja_inseridos(self):
        arquivo = criar_zip({"Agosto_2026/Mensal/Passageiros_Mensal.html": HTML_PASSAGEIROS})

        self.assertEqual(self.enviar(arquivo).json()["inseridos"], 2)
        segunda = self.enviar(arquivo)

        self.assertEqual(segunda.status_code, 200)
        self.assertEqual(segunda.json()["inseridos"], 0)
        self.assertEqual(segunda.json()["ignorados"], 2)
        self.assertEqual(len(self.colecao.documentos), 2)

    def test_processa_duas_tabelas_de_saldos_sem_mesclar_linhas(self):
        html = """<table class='data'><tr><th>Mês</th><th>Dia</th><th>Saldo Final</th></tr>
        <tr><td>2026-08</td><td>01</td><td>20.434.667,35</td></tr></table>
        <table class='data'><tr><th>Mês</th><th>Dia</th><th>Total Vendas</th></tr>
        <tr><td>2026-08</td><td>01</td><td>4.805,00</td></tr></table>"""

        resposta = self.enviar(criar_zip({"Saldos.html": html}))

        self.assertEqual(resposta.status_code, 200, resposta.text)
        self.assertEqual(resposta.json()["inseridos"], 2)
        documentos = list(self.colecao.documentos.values())
        self.assertEqual(documentos[0]["dados_originais"]["Saldo Final"], "20.434.667,35")
        self.assertEqual(documentos[1]["dados_originais"]["Total Vendas"], "4.805,00")
        self.assertEqual([doc["tabela"] for doc in documentos], [1, 2])

    def test_rejeita_linha_incompleta_sem_descartar_linha_valida(self):
        html = HTML_PASSAGEIROS.replace(
            "</table>", "<tr><td>2026-08</td><td>02</td></tr></table>"
        )

        resposta = self.enviar(criar_zip({"Passageiros.html": html}))

        self.assertEqual(resposta.status_code, 200)
        self.assertEqual(resposta.json()["inseridos"], 2)
        self.assertEqual(resposta.json()["rejeitados"], 1)
        self.assertEqual(len(self.colecao.documentos), 2)

    def test_bloqueia_caminho_inseguro_antes_de_inserir(self):
        arquivo = criar_zip({"../Passageiros.html": HTML_PASSAGEIROS})

        resposta = self.enviar(arquivo)

        self.assertEqual(resposta.status_code, 400)
        self.assertEqual(self.colecao.documentos, {})

    def test_recusa_formato_invalido(self):
        self.assertEqual(self.enviar(b"invalido").status_code, 400)
        self.assertEqual(self.enviar(b"invalido", "dados.txt").status_code, 400)

    def test_recusa_zip_acima_do_limite(self):
        arquivo = criar_zip({"Passageiros.html": HTML_PASSAGEIROS})

        with patch.object(importacao, "LIMITE_ZIP", len(arquivo) - 1):
            resposta = self.enviar(arquivo)

        self.assertEqual(resposta.status_code, 413)
        self.assertEqual(self.colecao.documentos, {})

    def test_falha_do_banco_retorna_erro_sem_detalhe_interno(self):
        class BancoIndisponivel(ColecaoFalsa):
            def create_index(self, *args, **kwargs):
                raise ServerSelectionTimeoutError("segredo interno")

        main.colecao_relatorios_mensais = BancoIndisponivel()

        resposta = self.enviar(criar_zip({"Passageiros.html": HTML_PASSAGEIROS}))

        self.assertEqual(resposta.status_code, 503)
        self.assertNotIn("segredo interno", resposta.text)


if __name__ == "__main__":
    unittest.main()
