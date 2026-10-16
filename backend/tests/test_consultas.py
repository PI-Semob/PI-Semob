import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4

from fastapi.testclient import TestClient
from pymongo.errors import PyMongoError

os.environ.setdefault("MONGO_URI", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "semob_test")
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

import main


RAIZ = "Dados de Utilização do Transporte Municipal/Agosto_2026"
MENSAL = f"{RAIZ}/Mensal"
QUINZENAL = f"{RAIZ}/Quinzenal"


def documento(categoria, arquivo, dados, originais=None, linha=1):
    return {
        "categoria": categoria,
        "arquivo_origem": arquivo,
        "tabela": 1,
        "linha": linha,
        "dados_originais": originais or {"Data": "01/08/2026"},
        "dados_tratados": dados,
    }


class TesteConsultas(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            main.db.command("ping")
        except PyMongoError:
            raise unittest.SkipTest("MongoDB local indisponível")
        cls.colecao = main.db[f"test_consultas_{uuid4().hex}"]
        cls.colecao.insert_many([
            documento("resumo_geral", f"{MENSAL}/Mensal_202608.html",
                      {"data": "2026-08-01T00:00:00.000", "viagens_programadas": 10,
                       "viagens_realizadas": 9, "km_total": 50.5}),
            documento("resumo_geral", f"{MENSAL}/Mensal_202608.html",
                      {"data": "2026-08-02T00:00:00.000", "viagens_programadas": 20,
                       "viagens_realizadas": 18, "km_total": 100.0}, linha=2),
            documento("resumo_geral", f"{MENSAL}/Mensal_202608.html",
                      {"data": None, "viagens_programadas": 30,
                       "viagens_realizadas": 27, "km_total": 150.5}, linha=3),
            documento("resumo_geral", f"{QUINZENAL}/Quinzenal_202608.html",
                      {"data": "2026-08-01T00:00:00.000", "viagens_programadas": 10,
                       "viagens_realizadas": 9, "km_total": 50.5}),
            documento("passageiros", f"{MENSAL}/Passageiros_Mensal.html",
                      {"mes": "2026-08", "dia": 1, "total_passageiros": 1},
                      {"Mês": "2026-08", "Dia": "01", "Total Passageiros": "1.234"}),
            documento("passageiros", f"{MENSAL}/Passageiros_Mensal.html",
                      {"mes": "2026-08", "dia": 0, "total_passageiros": 9},
                      {"Mês": "2026-08", "Dia": "Total Mês", "Total Passageiros": "9.999"},
                      linha=2),
            documento("resumo_fxhr", f"{MENSAL}/Mensal_Resumo_FxHr_202608.html",
                      {"data": "2026-08-01T00:00:00.000", "faixa_horaria": "4hs",
                       "numero_viagens": 3}),
            documento("resumo_fxhr", f"{MENSAL}/Mensal_Resumo_FxHr_202608.html",
                      {"data": "2026-08-02T00:00:00.000", "faixa_horaria": "4hs",
                       "numero_viagens": 2}, linha=2),
            documento("resumo_fxhr", f"{MENSAL}/Mensal_Resumo_FxHr_202608.html",
                      {"data": "2026-08-01T00:00:00.000", "faixa_horaria": "5hs",
                       "numero_viagens": 4}, linha=3),
            documento("resumo_fxhr", f"{MENSAL}/Mensal_Resumo_FxHr_202608.html",
                      {"data": None, "faixa_horaria": "", "numero_viagens": 999}, linha=4),
            documento("resumo_fxhr", f"{MENSAL}/Mensal_Resumo_FxHr_202608.html",
                      {"data": "2026-08-01T00:00:00.000", "faixa_horaria": None,
                       "numero_viagens": 999}, linha=5),
            documento("linhas", f"{MENSAL}/Mensal_Linhas_202608.html",
                      {"data": "2026-08-01T00:00:00.000", "linha": "01",
                       "numero_viagens": 7}, linha=1),
            documento("linhas", f"{MENSAL}/Mensal_Linhas_202608.html",
                      {"data": "2026-08-02T00:00:00.000", "linha": "01",
                       "numero_viagens": 8}, linha=2),
            documento("linhas", f"{MENSAL}/Mensal_Linhas_202608.html",
                      {"data": "2026-08-01T00:00:00.000", "linha": "02",
                       "numero_viagens": 5}, linha=3),
            documento("linhas", f"{MENSAL}/Mensal_Linhas_202608.html",
                      {"data": None, "linha": "", "numero_viagens": 999}, linha=4),
            documento("linhas", f"{MENSAL}/Mensal_Linhas_202608.html",
                      {"data": "2026-08-01T00:00:00.000", "linha": None,
                       "numero_viagens": 999}, linha=5),
        ])

    @classmethod
    def tearDownClass(cls):
        cls.colecao.drop()

    def setUp(self):
        self.anterior = main.colecao_relatorios_mensais
        main.colecao_relatorios_mensais = self.colecao
        self.cliente = TestClient(main.app)

    def tearDown(self):
        main.colecao_relatorios_mensais = self.anterior

    def test_opcoes_usam_periodo_e_abrangencia_dos_arquivos_reais(self):
        resposta = self.cliente.get("/dashboard/opcoes")
        self.assertEqual(resposta.status_code, 200, resposta.text)
        self.assertEqual(resposta.json()["periodos"], [
            {"periodo": "2026-08", "abrangencias": ["Mensal", "Quinzenal"]}
        ])
        self.assertEqual(resposta.json()["periodo_padrao"], "2026-08")
        self.assertEqual(resposta.json()["abrangencia_padrao"], "Mensal")

    def test_dashboard_soma_dias_sem_duplicar_total_ou_quinzenal(self):
        resposta = self.cliente.get(
            "/dashboard/resumo?periodo=2026-08&abrangencia=Mensal"
        )
        self.assertEqual(resposta.status_code, 200, resposta.text)
        dados = resposta.json()
        self.assertEqual(dados["indicadores"], {
            "viagens_programadas": 30,
            "viagens_realizadas": 27,
            "quilometragem_total": 150.5,
            "total_passageiros": 1234,
            "dias_com_dados": 2,
        })
        self.assertEqual([p["data"] for p in dados["evolucao"]],
                         ["2026-08-01", "2026-08-02"])
        self.assertEqual(dados["faixas_horarias"], [
            {"faixa_horaria": "4hs", "numero_viagens": 5},
            {"faixa_horaria": "5hs", "numero_viagens": 4},
        ])
        self.assertEqual(dados["linhas"][0], {"linha": "01", "numero_viagens": 15})

    def test_relatorios_filtra_linha_de_transporte_e_pagina_resultados(self):
        resposta = self.cliente.get(
            "/relatorios?page=2&limit=1&tipo=linhas&periodo=2026-08"
            "&abrangencia=Mensal&linha=01"
        )
        self.assertEqual(resposta.status_code, 200, resposta.text)
        dados = resposta.json()
        self.assertEqual((dados["pagina"], dados["limite"], dados["total"],
                          dados["paginas"]), (2, 1, 2, 2))
        self.assertEqual(len(dados["itens"]), 1)
        self.assertEqual(dados["itens"][0]["dados_tratados"]["linha"], "01")
        self.assertEqual(dados["itens"][0]["categoria"], "linhas")
        self.assertIn("id", dados["itens"][0])
        self.assertNotIn("_id", dados["itens"][0])

    def test_filtros_e_validacao_de_paginacao(self):
        resposta = self.cliente.get("/relatorios/filtros")
        self.assertEqual(resposta.status_code, 200, resposta.text)
        self.assertIn("2026-08", resposta.json()["periodos"])
        self.assertIn("linhas", resposta.json()["tipos"])
        self.assertEqual(resposta.json()["abrangencias"], ["Mensal", "Quinzenal"])
        self.assertEqual(self.cliente.get("/relatorios?limit=101").status_code, 400)
        self.assertEqual(self.cliente.get("/relatorios?periodo=2026-13").status_code, 400)

    def test_health_retorna_status_sem_expor_erro_do_mongo(self):
        class BancoIndisponivel:
            def command(self, *_args):
                raise PyMongoError("segredo interno")

        with patch.object(main, "db", BancoIndisponivel()):
            resposta = self.cliente.get("/health")
        self.assertEqual(resposta.status_code, 503)
        self.assertEqual(resposta.json(), {
            "status": "indisponivel", "banco": "indisponivel"
        })
        self.assertNotIn("segredo interno", resposta.text)


if __name__ == "__main__":
    unittest.main()
