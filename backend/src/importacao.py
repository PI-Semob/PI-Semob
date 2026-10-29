import codecs
import hashlib
import json
import stat
import zipfile
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import PurePosixPath
from typing import Callable

import pandas as pd
from fastapi import HTTPException, status
from pydantic import BaseModel, Field, field_validator
from pymongo import UpdateOne
from pymongo.errors import BulkWriteError, DuplicateKeyError, PyMongoError


LIMITE_ZIP = 50 * 1024 * 1024
LIMITE_EXTRAIDO = 500 * 1024 * 1024
LIMITE_ARQUIVO = 100 * 1024 * 1024
LIMITE_ENTRADAS = 500
TAMANHO_LOTE = 500


class DocumentoImportado(BaseModel):
    chave_importacao: str = Field(min_length=64, max_length=64)
    arquivo_origem: str = Field(min_length=1)
    categoria: str = Field(min_length=1)
    tabela: int = Field(ge=1)
    linha: int = Field(ge=1)
    dados_originais: dict[str, str]
    dados_tratados: dict

    @field_validator("dados_originais")
    @classmethod
    def validar_dados(cls, dados):
        if not dados or any(not nome.strip() for nome in dados):
            raise ValueError("Linha sem campos válidos")
        return dados


class LeitorTabelasHTML(HTMLParser):
    """Emite linhas de tabelas de dados sem guardar o HTML inteiro."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.linhas = []
        self.tabela_atual = 0
        self.dentro_tabela = False
        self.cabecalhos = []
        self.linha_atual = []
        self.numero_linha = 0
        self.celula = None
        self.tipo_celula = None

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.dentro_tabela = "data" in dict(attrs).get("class", "").split()
            if self.dentro_tabela:
                self.tabela_atual += 1
                self.cabecalhos = []
                self.numero_linha = 0
        elif self.dentro_tabela and tag == "tr":
            self.linha_atual = []
        elif self.dentro_tabela and tag in ("th", "td"):
            self.celula = []
            self.tipo_celula = tag
        elif self.celula is not None and tag == "br":
            self.celula.append(" ")

    def handle_data(self, data):
        if self.celula is not None:
            self.celula.append(data)

    def handle_endtag(self, tag):
        if self.dentro_tabela and tag in ("th", "td") and self.celula is not None:
            valor = "".join(self.celula).strip()
            if self.tipo_celula == "th":
                self.cabecalhos.append(valor)
            else:
                self.linha_atual.append(valor)
            self.celula = None
            self.tipo_celula = None
        elif self.dentro_tabela and tag == "tr":
            if self.linha_atual and not (
                self.cabecalhos and self.cabecalhos[0].startswith("SmartDataSource")
            ):
                self.numero_linha += 1
                self.linhas.append((self.tabela_atual, self.numero_linha,
                                    tuple(self.cabecalhos), tuple(self.linha_atual)))
            self.linha_atual = []
        elif tag == "table":
            self.dentro_tabela = False


def validar_entradas(compactado):
    entradas = compactado.infolist()
    if len(entradas) > LIMITE_ENTRADAS:
        raise HTTPException(status_code=413, detail="ZIP contém arquivos demais")
    if sum(info.file_size for info in entradas) > LIMITE_EXTRAIDO:
        raise HTTPException(status_code=413, detail="ZIP descompactado excede o limite")

    arquivos_html = []
    for info in entradas:
        caminho = info.filename.replace("\\", "/")
        partes = PurePosixPath(caminho).parts
        modo = info.external_attr >> 16
        if (caminho.startswith("/") or ".." in partes or not partes
                or any(parte.endswith(":") for parte in partes)
                or stat.S_ISLNK(modo)):
            raise HTTPException(status_code=400, detail="ZIP contém caminho inseguro")
        if info.file_size > LIMITE_ARQUIVO or (
            info.compress_size and info.file_size > info.compress_size * 300
        ):
            raise HTTPException(status_code=413, detail="ZIP contém arquivo excessivo")
        if not info.is_dir() and caminho.lower().endswith((".html", ".htm")):
            arquivos_html.append(info)

    if not arquivos_html:
        raise HTTPException(status_code=400, detail="ZIP não contém relatórios HTML")
    return arquivos_html


def chave_da_linha(arquivo, tabela, linha, dados):
    identidade = json.dumps(
        [arquivo, tabela, linha, dados], ensure_ascii=False,
        sort_keys=True, separators=(",", ":"),
    )
    return hashlib.sha256(identidade.encode("utf-8")).hexdigest()


def inserir_lote(colecao, documentos):
    operacoes = [
        UpdateOne(
            {"chave_importacao": documento["chave_importacao"]},
            {"$setOnInsert": documento},
            upsert=True,
        )
        for documento in documentos
    ]
    try:
        resultado = colecao.bulk_write(operacoes, ordered=False)
        return resultado.upserted_count, resultado.matched_count
    except BulkWriteError as erro:
        detalhes = erro.details or {}
        falhas = detalhes.get("writeErrors", [])
        if any(falha.get("code") != 11000 for falha in falhas):
            raise
        inseridos = detalhes.get("nUpserted", 0)
        ignorados = detalhes.get("nMatched", 0) + len(falhas)
        return inseridos, ignorados


def reservar_zip(arquivo, colecao_hashes):
    if not arquivo.filename or not arquivo.filename.lower().endswith(".zip"):
        raise HTTPException(status_code=400, detail="Envie um arquivo ZIP")

    arquivo.file.seek(0, 2)
    tamanho = arquivo.file.tell()
    arquivo.file.seek(0)
    if tamanho == 0:
        raise HTTPException(status_code=400, detail="Arquivo ZIP vazio")
    if tamanho > LIMITE_ZIP:
        raise HTTPException(status_code=413, detail="ZIP excede o limite de 50 MB")

    resumo = hashlib.sha256()
    while bloco := arquivo.file.read(64 * 1024):
        resumo.update(bloco)
    hash_zip = resumo.hexdigest()
    arquivo.file.seek(0)

    try:
        with zipfile.ZipFile(arquivo.file) as compactado:
            validar_entradas(compactado)
    except (zipfile.BadZipFile, zipfile.LargeZipFile) as erro:
        arquivo.file.seek(0)
        raise HTTPException(status_code=400, detail="Arquivo ZIP inválido") from erro
    finally:
        arquivo.file.seek(0)

    try:
        colecao_hashes.create_index("hash_sha256", unique=True)
        registro = colecao_hashes.insert_one({
            "hash_sha256": hash_zip,
            "nome_arquivo": arquivo.filename,
            "status": "processando",
            "iniciado_em": datetime.now(timezone.utc),
        })
    except DuplicateKeyError as erro:
        raise HTTPException(
            status_code=409,
            detail="Este arquivo ZIP já foi importado anteriormente.",
        ) from erro
    except PyMongoError as erro:
        raise HTTPException(
            status_code=503,
            detail="Não foi possível verificar o arquivo no banco de dados.",
        ) from erro

    arquivo.file.seek(0)
    return registro.inserted_id


def concluir_zip(colecao_hashes, id_registro):
    colecao_hashes.update_one(
        {"_id": id_registro},
        {"$set": {"status": "concluido"}},
    )


def liberar_zip(colecao_hashes, id_registro):
    colecao_hashes.delete_one({"_id": id_registro})


def importar_zip(
    arquivo,
    colecao,
    identificar_tratamento,
    on_progresso: Callable[[str, int], None] | None = None,
):
    def avisar(mensagem, percentual):
        if on_progresso:
            on_progresso(mensagem, max(0, min(100, percentual)))

    if not arquivo.filename or not arquivo.filename.lower().endswith(".zip"):
        raise HTTPException(status_code=400, detail="Envie um arquivo ZIP")

    arquivo.file.seek(0, 2)
    tamanho = arquivo.file.tell()
    arquivo.file.seek(0)
    if tamanho == 0:
        raise HTTPException(status_code=400, detail="Arquivo ZIP vazio")
    if tamanho > LIMITE_ZIP:
        raise HTTPException(status_code=413, detail="ZIP excede o limite de 50 MB")

    try:
        compactado = zipfile.ZipFile(arquivo.file)
    except (zipfile.BadZipFile, zipfile.LargeZipFile) as erro:
        raise HTTPException(status_code=400, detail="Arquivo ZIP inválido") from erro

    with compactado:
        entradas = validar_entradas(compactado)
        tamanho_total = max(1, sum(info.file_size for info in entradas))
        bytes_processados = 0
        resultado = {
            "arquivo": arquivo.filename,
            "arquivos_processados": 0,
            "arquivos_rejeitados": 0,
            "inseridos": 0,
            "ignorados": 0,
            "rejeitados": 0,
            "detalhes": [],
        }
        try:
            colecao.create_index(
                "chave_importacao", unique=True,
                partialFilterExpression={"chave_importacao": {"$exists": True}},
            )
        except PyMongoError as erro:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Banco de dados indisponível para importação",
            ) from erro

        avisar("Extraindo arquivos do ZIP...", 15)
        for indice, info in enumerate(entradas, start=1):
            categoria, tratamento = identificar_tratamento(info.filename)
            detalhe = {
                "arquivo": info.filename, "categoria": categoria,
                "inseridos": 0, "ignorados": 0, "rejeitados": 0,
                "avisos": [],
            }
            resultado["detalhes"].append(detalhe)
            leitor = LeitorTabelasHTML()
            decodificador = codecs.getincrementaldecoder("cp1252")()
            lote = []

            def processar_lote():
                if not lote:
                    return
                validos = []
                for tabela, linha, cabecalhos, valores in lote:
                    if (not cabecalhos or len(cabecalhos) != len(valores)
                            or len(set(cabecalhos)) != len(cabecalhos)):
                        detalhe["rejeitados"] += 1
                        continue
                    dados = dict(zip(cabecalhos, valores))
                    validos.append((tabela, linha, dados))
                lote.clear()
                if not validos:
                    return

                tabela_dados = pd.DataFrame([item[2] for item in validos])
                try:
                    tratados = tratamento(tabela_dados)
                    dados_tratados = json.loads(tratados.to_json(
                        orient="records", date_format="iso", force_ascii=False,
                    ))
                    if len(dados_tratados) != len(validos):
                        raise ValueError("Quantidade de linhas convertidas divergente")
                except (ValueError, TypeError, KeyError) as erro:
                    detalhe["avisos"].append(f"Tratamento não aplicado: {erro}")
                    dados_tratados = [{} for _ in validos]

                documentos = []
                for (tabela, linha, dados), tratado in zip(validos, dados_tratados):
                    try:
                        documento = DocumentoImportado.model_validate({
                            "chave_importacao": chave_da_linha(
                                info.filename, tabela, linha, dados,
                            ),
                            "arquivo_origem": info.filename,
                            "categoria": categoria,
                            "tabela": tabela,
                            "linha": linha,
                            "dados_originais": dados,
                            "dados_tratados": tratado,
                        })
                        documentos.append(documento.model_dump())
                    except (ValueError, TypeError):
                        detalhe["rejeitados"] += 1
                if documentos:
                    inseridos, ignorados = inserir_lote(colecao, documentos)
                    detalhe["inseridos"] += inseridos
                    detalhe["ignorados"] += ignorados

            try:
                avisar(
                    f"Processando arquivo {indice} de {len(entradas)}: {info.filename}",
                    20 + int(bytes_processados / tamanho_total * 75),
                )
                with compactado.open(info) as membro:
                    while bloco := membro.read(64 * 1024):
                        bytes_processados += len(bloco)
                        percentual = 20 + int(bytes_processados / tamanho_total * 75)
                        avisar(
                            f"Processando arquivo {indice} de {len(entradas)}: "
                            f"{info.filename}",
                            percentual,
                        )
                        leitor.feed(decodificador.decode(bloco))
                        for linha in leitor.linhas:
                            if lote and lote[-1][0] != linha[0]:
                                processar_lote()
                            lote.append(linha)
                            if len(lote) >= TAMANHO_LOTE:
                                processar_lote()
                        leitor.linhas.clear()
                    leitor.feed(decodificador.decode(b"", final=True))
                    leitor.close()
                    for linha in leitor.linhas:
                        if lote and lote[-1][0] != linha[0]:
                            processar_lote()
                        lote.append(linha)
                    processar_lote()
                if leitor.tabela_atual == 0:
                    detalhe["avisos"].append("Nenhuma tabela de dados encontrada")
                    resultado["arquivos_rejeitados"] += 1
                else:
                    resultado["arquivos_processados"] += 1
            except PyMongoError as erro:
                resultado["inseridos"] += detalhe["inseridos"]
                resultado["ignorados"] += detalhe["ignorados"]
                resultado["rejeitados"] += detalhe["rejeitados"]
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail={"mensagem": "Falha no MongoDB; importação parcial possível",
                            "resultado": resultado},
                ) from erro
            except (zipfile.BadZipFile, UnicodeError, OSError, RuntimeError) as erro:
                detalhe["avisos"].append(f"Falha ao ler HTML: {erro}")
                resultado["arquivos_rejeitados"] += 1

            resultado["inseridos"] += detalhe["inseridos"]
            resultado["ignorados"] += detalhe["ignorados"]
            resultado["rejeitados"] += detalhe["rejeitados"]

        avisar("Finalizando a importação...", 98)
        return resultado
