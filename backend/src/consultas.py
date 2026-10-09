"""Consultas compactas dos relatórios importados para Dashboard e listagem."""

import re
from collections import defaultdict


MESES = {
    "janeiro": 1, "fevereiro": 2, "março": 3, "abril": 4,
    "maio": 5, "junho": 6, "julho": 7, "agosto": 8,
    "setembro": 9, "outubro": 10, "novembro": 11, "dezembro": 12,
}
PADRAO_CAMINHO = re.compile(r"(?:^|/)([^/]+)_(\d{4})/(Mensal|Quinzenal)/", re.I)
ABRANGENCIAS = ("Mensal", "Quinzenal")


def periodo_abrangencia_do_arquivo(caminho):
    """Lê somente o mês e a abrangência que constam no caminho de origem."""
    if not isinstance(caminho, str):
        return None
    encontrado = PADRAO_CAMINHO.search(caminho.replace("\\", "/"))
    if not encontrado:
        return None
    numero_mes = MESES.get(encontrado.group(1).casefold())
    if not numero_mes:
        return None
    abrangencia = encontrado.group(3).capitalize()
    return f"{encontrado.group(2)}-{numero_mes:02d}", abrangencia


def arquivos_e_periodos(colecao):
    arquivos = colecao.distinct("arquivo_origem")
    por_periodo = defaultdict(lambda: {"Mensal": [], "Quinzenal": []})
    for arquivo in arquivos:
        chave = periodo_abrangencia_do_arquivo(arquivo)
        if chave:
            periodo, abrangencia = chave
            por_periodo[periodo][abrangencia].append(arquivo)
    return por_periodo


def opcoes_dashboard(colecao):
    por_periodo = arquivos_e_periodos(colecao)
    periodos = [
        {"periodo": periodo,
         "abrangencias": [a for a in ABRANGENCIAS if grupos[a]]}
        for periodo, grupos in sorted(por_periodo.items(), reverse=True)
    ]
    return {
        "periodos": periodos,
        "periodo_padrao": periodos[0]["periodo"] if periodos else None,
        "abrangencia_padrao": periodos[0]["abrangencias"][0] if periodos else None,
    }


def filtros_relatorios(colecao):
    por_periodo = arquivos_e_periodos(colecao)
    return {
        "periodos": sorted(por_periodo, reverse=True),
        "tipos": sorted(tipo for tipo in colecao.distinct("categoria") if isinstance(tipo, str)),
        "abrangencias": list(ABRANGENCIAS),
    }


def arquivos_filtrados(por_periodo, periodo=None, abrangencia=None):
    if periodo:
        grupos = por_periodo.get(periodo, {})
        tipos = (abrangencia,) if abrangencia else ABRANGENCIAS
        return [arquivo for tipo in tipos for arquivo in grupos.get(tipo, ())]
    return [
        arquivo
        for grupos in por_periodo.values()
        for tipo in ((abrangencia,) if abrangencia else ABRANGENCIAS)
        for arquivo in grupos.get(tipo, ())
    ]


def listar_relatorios(colecao, pagina, limite, tipo=None, periodo=None,
                     linha=None, abrangencia=None):
    filtro = {}
    if tipo:
        filtro["categoria"] = tipo
    if linha:
        filtro["dados_tratados.linha"] = linha
    if periodo or abrangencia:
        arquivos = arquivos_filtrados(
            arquivos_e_periodos(colecao), periodo, abrangencia,
        )
        if not arquivos:
            return {"itens": [], "pagina": pagina, "limite": limite,
                    "total": 0, "paginas": 0}
        filtro["arquivo_origem"] = {"$in": arquivos}

    total = colecao.count_documents(filtro)
    campos = {"arquivo_origem": 1, "categoria": 1, "tabela": 1, "linha": 1,
              "dados_originais": 1, "dados_tratados": 1}
    cursor = colecao.find(filtro, campos).sort("_id", -1).skip(
        (pagina - 1) * limite
    ).limit(limite)
    itens = []
    for documento in cursor:
        documento["id"] = str(documento.pop("_id"))
        itens.append(documento)
    return {"itens": itens, "pagina": pagina, "limite": limite,
            "total": total, "paginas": (total + limite - 1) // limite}


def proximo_periodo(periodo):
    ano, mes = map(int, periodo.split("-"))
    return f"{ano + (mes == 12)}-{(mes % 12) + 1:02d}"


def resumo_dashboard(colecao, periodo, abrangencia):
    arquivos = arquivos_filtrados(arquivos_e_periodos(colecao), periodo, abrangencia)
    faixa_de_datas = {"$gte": periodo, "$lt": proximo_periodo(periodo)}

    def filtro(categoria, data=True):
        criterio = {"categoria": categoria, "arquivo_origem": {"$in": arquivos}}
        if data:
            criterio["dados_tratados.data"] = faixa_de_datas
        return criterio

    evolucao_bruta = list(colecao.aggregate([
        {"$match": filtro("resumo_geral")},
        {"$group": {
            "_id": {"$substrBytes": ["$dados_tratados.data", 0, 10]},
            "viagens_programadas": {"$sum": "$dados_tratados.viagens_programadas"},
            "viagens_realizadas": {"$sum": "$dados_tratados.viagens_realizadas"},
            "quilometragem_total": {"$sum": "$dados_tratados.km_total"},
        }},
        {"$sort": {"_id": 1}},
    ]))
    evolucao = [
        {"data": item["_id"],
         "viagens_programadas": item["viagens_programadas"],
         "viagens_realizadas": item["viagens_realizadas"]}
        for item in evolucao_bruta
    ]

    # A projeção numérica legada lê "16.544" como 16; o valor original guarda
    # corretamente o separador de milhar e permite somar sem alterar o banco.
    passageiros = list(colecao.aggregate([
        {"$match": {**filtro("passageiros", data=False),
                    "dados_tratados.mes": periodo,
                    "dados_tratados.dia": {"$gt": 0}}},
        {"$group": {"_id": None, "total": {"$sum": {"$convert": {
            "input": {"$replaceAll": {
                "input": "$dados_originais.Total Passageiros",
                "find": ".", "replacement": "",
            }},
            "to": "long", "onError": 0, "onNull": 0,
        }}}}},
    ]))

    faixas_brutas = list(colecao.aggregate([
        {"$match": {**filtro("resumo_fxhr"),
                    "dados_tratados.faixa_horaria": {"$type": "string", "$ne": ""}}},
        {"$group": {"_id": "$dados_tratados.faixa_horaria",
                    "numero_viagens": {"$sum": "$dados_tratados.numero_viagens"}}},
    ]))
    faixas = [
        {"faixa_horaria": item["_id"], "numero_viagens": item["numero_viagens"]}
        for item in sorted(
            faixas_brutas,
            key=lambda item: int(re.match(r"\d+", item["_id"]).group())
            if re.match(r"\d+", item["_id"]) else 99,
        )
    ]

    linhas_brutas = list(colecao.aggregate([
        {"$match": {**filtro("linhas"),
                    "dados_tratados.linha": {"$type": "string", "$ne": ""}}},
        {"$group": {"_id": "$dados_tratados.linha",
                    "numero_viagens": {"$sum": "$dados_tratados.numero_viagens"}}},
        {"$sort": {"numero_viagens": -1, "_id": 1}},
        {"$limit": 8},
    ]))
    linhas = [
        {"linha": item["_id"], "numero_viagens": item["numero_viagens"]}
        for item in linhas_brutas
    ]

    return {
        "periodo": periodo,
        "abrangencia": abrangencia,
        "indicadores": {
            "viagens_programadas": sum(
                item["viagens_programadas"] for item in evolucao_bruta
            ) if evolucao_bruta else None,
            "viagens_realizadas": sum(
                item["viagens_realizadas"] for item in evolucao_bruta
            ) if evolucao_bruta else None,
            "quilometragem_total": round(sum(
                item["quilometragem_total"] for item in evolucao_bruta
            ), 2) if evolucao_bruta else None,
            "total_passageiros": passageiros[0]["total"] if passageiros else None,
            "dias_com_dados": len(evolucao_bruta),
        },
        "evolucao": evolucao,
        "faixas_horarias": faixas,
        "linhas": linhas,
    }
