import io
import json
import logging
import re
from pathlib import Path
from typing import Literal

import pandas as pd
from bs4 import BeautifulSoup
from fastapi import FastAPI, File, HTTPException, Query, Request, UploadFile, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError
from pydantic import BaseModel, Field, field_validator
from pymongo import ASCENDING
from pymongo.errors import DuplicateKeyError, PyMongoError

from conexao import db
from consultas import filtros_relatorios, listar_relatorios, opcoes_dashboard, resumo_dashboard
from importacao import importar_zip

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

colecao_usuarios = db["usuarios"]
colecao_relatorios_mensais = db["relatorios_mensais"]
password_hash = PasswordHash.recommended()
PADRAO_EMAIL = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


@app.on_event("startup")
def preparar_indices_de_consulta():
    """Mantém as consultas de período e de listagem limitadas por índices."""
    try:
        colecao_relatorios_mensais.create_index([
            ("arquivo_origem", ASCENDING), ("categoria", ASCENDING),
            ("dados_tratados.linha", ASCENDING),
        ])
        colecao_relatorios_mensais.create_index([
            ("categoria", ASCENDING), ("dados_tratados.data", ASCENDING),
        ])
    except PyMongoError:
        logging.getLogger(__name__).warning("Índices de consulta indisponíveis")


@app.exception_handler(RequestValidationError)
async def tratar_erro_validacao(request: Request, erro: RequestValidationError):
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


@app.get("/health")
def health():
    try:
        db.command("ping")
    except PyMongoError:
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"status": "indisponivel", "banco": "indisponivel"},
        )
    return {"status": "ok", "banco": "conectado"}


@app.get("/dashboard/opcoes")
def consultar_opcoes_dashboard():
    try:
        return opcoes_dashboard(colecao_relatorios_mensais)
    except PyMongoError as erro:
        raise HTTPException(503, "Não foi possível consultar o Dashboard") from erro


@app.get("/dashboard/resumo")
def consultar_resumo_dashboard(
    periodo: str | None = Query(default=None, pattern=r"^\d{4}-(0[1-9]|1[0-2])$"),
    abrangencia: Literal["Mensal", "Quinzenal"] | None = None,
):
    try:
        if periodo is None or abrangencia is None:
            opcoes = opcoes_dashboard(colecao_relatorios_mensais)
            periodo = periodo or opcoes["periodo_padrao"]
            if abrangencia is None:
                atual = next((item for item in opcoes["periodos"]
                              if item["periodo"] == periodo), None)
                abrangencia = (atual["abrangencias"][0] if atual else None)
        if periodo is None or abrangencia is None:
            raise HTTPException(404, "Nenhum relatório disponível")
        return resumo_dashboard(colecao_relatorios_mensais, periodo, abrangencia)
    except PyMongoError as erro:
        raise HTTPException(503, "Não foi possível consultar o Dashboard") from erro


@app.get("/relatorios/filtros")
def consultar_filtros_relatorios():
    try:
        return filtros_relatorios(colecao_relatorios_mensais)
    except PyMongoError as erro:
        raise HTTPException(503, "Não foi possível consultar os relatórios") from erro


@app.get("/relatorios")
def consultar_relatorios(
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=25, ge=1, le=100),
    tipo: str | None = Query(default=None, min_length=1, max_length=100),
    periodo: str | None = Query(default=None, pattern=r"^\d{4}-(0[1-9]|1[0-2])$"),
    linha: str | None = Query(default=None, min_length=1, max_length=50),
    abrangencia: Literal["Mensal", "Quinzenal"] | None = None,
):
    try:
        return listar_relatorios(
            colecao_relatorios_mensais, page, limit, tipo, periodo, linha,
            abrangencia,
        )
    except PyMongoError as erro:
        raise HTTPException(503, "Não foi possível consultar os relatórios") from erro


def ler_tabelas(arquivo, *, milhares=",", decimal="."):
    if hasattr(arquivo, "read"):
        conteudo_html = arquivo.read()
        if isinstance(conteudo_html, bytes):
            conteudo_html = conteudo_html.decode("cp1252")
    elif isinstance(arquivo, Path) or (isinstance(arquivo, str) and "<" not in arquivo):
        conteudo_html = Path(arquivo).read_bytes().decode("cp1252")
    else:
        conteudo_html = arquivo

    tabelas = pd.read_html(
        io.StringIO(conteudo_html), encoding="cp1252",
        thousands=milhares, decimal=decimal,
    )
    tabelas = [
        tabela
        for tabela in tabelas
        if len(tabela.columns) > 1
        and not str(tabela.columns[0]).startswith("SmartDataSource")
    ]
    if not tabelas:
        return []
    soup = BeautifulSoup(conteudo_html, "html.parser")
    cabecalhos_tabelas = []
    for tabela_html in soup.find_all("table", class_="data"):
        cabecalhos = [celula.get_text(" ", strip=True) for celula in tabela_html.find_all("th")]
        if cabecalhos and not cabecalhos[0].startswith("SmartDataSource"):
            cabecalhos_tabelas.append(cabecalhos)
    for tabela, cabecalhos in zip(tabelas, cabecalhos_tabelas):
        if len(cabecalhos) == len(tabela.columns):
            tabela.columns = cabecalhos
    return tabelas


def ler_tabela(arquivo, *, milhares=",", decimal="."):
    tabelas = ler_tabelas(arquivo, milhares=milhares, decimal=decimal)
    return max(tabelas, key=len) if tabelas else pd.DataFrame()


def normalizar_valor_numerico(valor):
    if pd.isna(valor) or isinstance(valor, (int, float)):
        return valor
    texto = str(valor).strip().replace(" ", "")
    if "," in texto and "." in texto:
        return texto.replace(".", "").replace(",", ".")
    if "," in texto:
        return texto.replace(",", ".")
    return texto


def normalizar_inteiro_com_milhar(valor):
    if isinstance(valor, str):
        texto = valor.strip().replace(" ", "")
        if re.fullmatch(r"[+-]?\d{1,3}(?:\.\d{3})+", texto):
            return texto.replace(".", "")
    return normalizar_valor_numerico(valor)


def padronizar(arquivo, mapeamento, inteiros=(), decimais=(), datas=(),
               inteiros_com_milhar=()):
    tabela = arquivo.copy() if isinstance(arquivo, pd.DataFrame) else ler_tabela(arquivo).copy()
    tabela.columns = [str(coluna).strip() for coluna in tabela.columns]
    tabela = tabela.rename(columns=mapeamento)

    for coluna in inteiros:
        if coluna in tabela.columns:
            normalizar = (normalizar_inteiro_com_milhar
                          if coluna in inteiros_com_milhar
                          else normalizar_valor_numerico)
            valores = tabela[coluna].map(normalizar)
            tabela[coluna] = pd.to_numeric(valores, errors="coerce").fillna(0).astype("int64")

    for coluna in decimais:
        if coluna in tabela.columns:
            valores = tabela[coluna].map(normalizar_valor_numerico)
            tabela[coluna] = pd.to_numeric(valores, errors="coerce").fillna(0.0)

    for coluna in datas:
        if coluna in tabela.columns:
            tabela[coluna] = pd.to_datetime(tabela[coluna], dayfirst=True, errors="coerce")
    return tabela


def tratar_fcv(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "manha_p": "manha_programadas", 
        "manha_r": "manha_realizadas",
        "tarde_p": "tarde_programadas", 
        "tarde_r": "tarde_realizadas",
        "noite_p": "noite_programadas", 
        "noite_r": "noite_realizadas",
        "programadas": "viagens_programadas", 
        "realizadas": "viagens_realizadas",
    }, inteiros=("manha_programadas", "manha_realizadas", "tarde_programadas", "tarde_realizadas", "noite_programadas", "noite_realizadas", "viagens_programadas", "viagens_realizadas"), datas=("data",))


def tratar_resumo_fxhr(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "Fx_Hor": "faixa_horaria", 
        "Nr_Veiculos": "numero_veiculos",
        "Nr_Viagens": "numero_viagens",
    }, inteiros=("numero_veiculos", "numero_viagens"), datas=("data",))


def tratar_fxhr(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "Linha": "linha", 
        "Fx_Hor": "faixa_horaria",
        "Nr_Veiculos": "numero_veiculos", 
        "Nr_Viagens": "numero_viagens", 
        "Partidas": "partidas",
    }, inteiros=("numero_veiculos", "numero_viagens", "partidas"), datas=("data",))


def tratar_linhas(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "Linha": "linha", 
        "kmTotal": "quilometragem_total", 
        "nrViagens": "numero_viagens",
    }, inteiros=("numero_viagens",), decimais=("quilometragem_total",), datas=("data",))


def tratar_viag_ninic(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "Linha": "linha", 
        "Atendimento": "atendimento", 
        "Prefixo": "prefixo",
        "Atividade": "atividade", 
        "Motorista": "motorista", 
        "Sentido": "sentido", 
        "Tabela": "tabela",
        "statusSaida": "status_saida", 
        "statusChegada": "status_chegada",
        "inicioProgramado": "inicio_programado", 
        "inicioRealizado": "inicio_realizado",
        "fimProgramado": "fim_programado", 
        "fimRealizado": "fim_realizado",
        "kmProd": "km_produtivo", 
        "kmImprod": "km_improdutivo", 
        "kmTotal": "km_total",
    }, decimais=("km_produtivo", "km_improdutivo", "km_total"), datas=("data",))


def tratar_viag_nrealiz(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "Linha": "linha", 
        "Atendimento": "atendimento", 
        "Prefixo": "prefixo",
        "Atividade": "atividade", 
        "Motorista": "motorista", 
        "Sentido": "sentido", 
        "Tabela": "tabela",
        "statusSaida": "status_saida", 
        "statusChegada": "status_chegada",
        "inicioProgramado": "inicio_programado", 
        "inicioRealizado": "inicio_realizado",
        "fimProgramado": "fim_programado", 
        "fimRealizado": "fim_realizado",
        "kmProd": "km_produtivo", 
        "kmImprod": "km_improdutivo", 
        "kmTotal": "km_total",
    }, decimais=("km_produtivo", "km_improdutivo", "km_total"), datas=("data",))


def tratar_viag_nterm(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "Linha": "linha", 
        "Atendimento": "atendimento", 
        "Prefixo": "prefixo",
        "Atividade": "atividade", 
        "Motorista": "motorista", 
        "Sentido": "sentido", 
        "Tabela": "tabela",
        "statusSaida": "status_saida", 
        "statusChegada": "status_chegada",
        "inicioProgramado": "inicio_programado", 
        "inicioRealizado": "inicio_realizado",
        "fimProgramado": "fim_programado", 
        "fimRealizado": "fim_realizado",
        "kmProd": "km_produtivo", 
        "kmImprod": "km_improdutivo", 
        "kmTotal": "km_total",
    }, decimais=("km_produtivo", "km_improdutivo", "km_total"), datas=("data",))


def tratar_viagens(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "Linha": "linha", 
        "Prefixo": "prefixo", 
        "Atividade": "atividade",
        "Sentido": "sentido", 
        "Fx_Hor": "faixa_horaria", 
        "inicioRealizado": "inicio_realizado",
        "fimRealizado": "fim_realizado", 
        "kmProd": "km_produtivo",
        "kmImprod": "km_improdutivo", 
        "kmTotal": "km_total",
    }, decimais=("km_produtivo", "km_improdutivo", "km_total"), datas=("data",))


def tratar_passageiros(arquivo):
    tabela = (arquivo if isinstance(arquivo, pd.DataFrame)
              else ler_tabela(arquivo, milhares=".", decimal=","))
    contagens = ("passageiros_catraca", "passageiros_antecipados",
                 "passageiros_nao_pagantes", "total_passageiros")
    return padronizar(tabela, {
        "Mês": "mes", 
        "Dia": "dia", 
        "Catraca": "passageiros_catraca",
        "Antecipados": "passageiros_antecipados", 
        "Não Pagantes": "passageiros_nao_pagantes",
        "Total Passageiros": "total_passageiros",
    }, inteiros=("dia", *contagens), inteiros_com_milhar=contagens)


def tratar_saldos(arquivo):
    if isinstance(arquivo, pd.DataFrame):
        tabela = arquivo
    else:
        tabelas = ler_tabelas(arquivo)
        if not tabelas:
            tabela = pd.DataFrame()
        else:
            tabela = tabelas[0]
            for proxima in tabelas[1:]:
                chaves = [coluna for coluna in ("Mês", "Dia") if coluna in tabela.columns and coluna in proxima.columns]
                tabela = tabela.merge(proxima, on=chaves, how="outer") if chaves else pd.concat([tabela, proxima], ignore_index=True)
    return padronizar(tabela, {
        "Mês": "mes", 
        "Dia": "dia", 
        "Série": "serie",
        "Créditos transferidos para cartões": "creditos_transferidos_cartoes",
        "Créditos transferidospara cartões": "creditos_transferidos_cartoes",
        "Saldo Final": "saldo_final", 
        "Total Vendas": "total_vendas",
        "Total Utilização": "total_utilizacao", 
        "Crédito Circulante": "credito_circulante",
    }, inteiros=("dia",), decimais=("creditos_transferidos_cartoes", "saldo_final", "total_vendas", "total_utilizacao", "credito_circulante"))


def tratar_resumo_geral(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "diaSem": "dia_semana", 
        "nrVeiculos": "numero_veiculos",
        "nrMaxVeicFx": "veiculos_pico_faixa", 
        "nrViagensProgr": "viagens_programadas",
        "nrViagensRealiz": "viagens_realizadas", 
        "Dif Viagens": "diferenca_viagens",
        "kmProd": "km_produtivo", 
        "kmImprod": "km_improdutivo", 
        "kmTotal": "km_total",
    }, inteiros=("numero_veiculos", "veiculos_pico_faixa", "viagens_programadas", "viagens_realizadas", "diferenca_viagens"), decimais=("km_produtivo", "km_improdutivo", "km_total"), datas=("data",))


def tratar_padrao(arquivo):
    return padronizar(arquivo, {
        "Data": "data", 
        "Mês": "mes", 
        "Dia": "dia", 
        "Linha": "linha",
        "Fx_Hor": "faixa_horaria", 
        "Nr_Veiculos": "numero_veiculos",
        "Nr_Viagens": "numero_viagens", 
        "Partidas": "partidas", 
        "kmTotal": "km_total",
        "nrViagens": "numero_viagens", 
        "Catraca": "passageiros_catraca",
        "Antecipados": "passageiros_antecipados", 
        "Não Pagantes": "passageiros_nao_pagantes",
        "Total Passageiros": "total_passageiros",
    }, inteiros=("dia", "numero_veiculos", "numero_viagens", "partidas", "nrViagens", "passageiros_catraca", "passageiros_antecipados", "passageiros_nao_pagantes", "total_passageiros"), decimais=("km_total",), datas=("data",))


def identificar_tratamento(nome_origem):
    if isinstance(nome_origem, str) and "<" in nome_origem:
        nome_origem = ""
    nome = re.sub(r"[^a-z0-9]+", "_", str(nome_origem).lower().replace("\\", "/").split("/")[-1])
    if "fcv" in nome:
        categoria, tratamento = "fcv", tratar_fcv
    elif "resumo_fxhr" in nome or "mensal_resumo" in nome:
        categoria, tratamento = "resumo_fxhr", tratar_resumo_fxhr
    elif "fxhr" in nome:
        categoria, tratamento = "fxhr", tratar_fxhr
    elif "linhas" in nome:
        categoria, tratamento = "linhas", tratar_linhas
    elif "viag_ninic" in nome:
        categoria, tratamento = "viag_ninic", tratar_viag_ninic
    elif "viag_nrealiz" in nome:
        categoria, tratamento = "viag_nrealiz", tratar_viag_nrealiz
    elif "viag_nterm" in nome:
        categoria, tratamento = "viag_nterm", tratar_viag_nterm
    elif "viagens" in nome:
        categoria, tratamento = "viagens", tratar_viagens
    elif "passageiros" in nome:
        categoria, tratamento = "passageiros", tratar_passageiros
    elif "saldos" in nome:
        categoria, tratamento = "saldos", tratar_saldos
    elif re.search(r"(?:mensal|quinzenal)_?\d{6}", nome):
        categoria, tratamento = "resumo_geral", tratar_resumo_geral
    else:
        categoria, tratamento = "padrao", tratar_padrao
    return categoria, tratamento


def rotear_arquivo(arquivo, nome_arquivo=None):
    nome_origem = nome_arquivo or (arquivo if isinstance(arquivo, (str, Path)) else "")
    categoria, tratamento = identificar_tratamento(nome_origem)
    return categoria, tratamento(arquivo)


@app.post("/relatorios/importar-zip")
def importar_relatorios_zip(file: UploadFile = File(...)):
    return importar_zip(file, colecao_relatorios_mensais, identificar_tratamento)


@app.post("/converter_relatorio_html")
@app.post("/relatorios/upload-mensal")
async def upload_relatorio_html(file: UploadFile = File(...)):
    if not file.filename or not file.filename.lower().endswith((".html", ".htm")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Envie um arquivo HTML",
        )

    try:
        conteudo_html = (await file.read()).decode("cp1252")
        categoria, dataframe = rotear_arquivo(conteudo_html, file.filename)
        registros = json.loads(
            dataframe.to_json(orient="records", date_format="iso", force_ascii=False)
        )
    except (ValueError, UnicodeDecodeError, pd.errors.ParserError) as erro:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Não foi possível processar o arquivo HTML: {erro}",
        ) from erro

    return {
        "arquivo": file.filename,
        "categoria": categoria,
        "quantidade": len(registros),
        "dados": registros,
    }
