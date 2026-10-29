import re
from collections import defaultdict
from datetime import date, datetime, timedelta


MESES = {
    "janeiro": 1, "fevereiro": 2, "março": 3, "abril": 4,
    "maio": 5, "junho": 6, "julho": 7, "agosto": 8,
    "setembro": 9, "outubro": 10, "novembro": 11, "dezembro": 12,
}
PADRAO_CAMINHO = re.compile(r"(?:^|/)([^/]+)_(\d{4})/(Mensal|Quinzenal)/", re.I)
ABRANGENCIAS = ("Mensal", "Quinzenal")


def periodo_abrangencia_do_arquivo(caminho):
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
    filtro = filtro_relatorios(colecao, tipo, periodo, linha, abrangencia)
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


def filtro_relatorios(colecao, tipo=None, periodo=None, linha=None,
                      abrangencia=None):
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
            filtro["arquivo_origem"] = {"$in": []}
            return filtro
        filtro["arquivo_origem"] = {"$in": arquivos}

    return filtro


def exportar_relatorios_csv(colecao, tipo=None, periodo=None, linha=None,
                            abrangencia=None):
    filtro = filtro_relatorios(colecao, tipo, periodo, linha, abrangencia)
    cursor = colecao.find(filtro, {
        "arquivo_origem": 1, "categoria": 1, "tabela": 1, "linha": 1,
        "dados_originais": 1, "dados_tratados": 1,
    }).sort("_id", -1)
    return list(cursor)


def _estagio_data(campo_data):
    return {"$addFields": {"_data_relatorio": {"$dateFromString": {
        "dateString": {"$substrBytes": [campo_data, 0, 10]},
        "format": "%Y-%m-%d", "onError": None, "onNull": None,
    }}}}


def _data_mes_dia():
    dia = {"$convert": {"input": "$dados_tratados.dia", "to": "int",
                        "onError": None, "onNull": None}}
    return {"$addFields": {"_data_relatorio": {"$dateFromString": {
        "dateString": {"$concat": [
            "$dados_tratados.mes", "-",
            {"$cond": [{"$lt": [dia, 10]},
                       {"$concat": ["0", {"$toString": dia}]},
                       {"$toString": dia}]},
        ]},
        "format": "%Y-%m-%d", "onError": None, "onNull": None,
    }}}}


def _agrupar_por_dia(colecao, categoria, campos, inicio, fim, linha=None,
                     mes_dia=False):
    criterios = {"categoria": categoria}
    if linha:
        criterios["dados_tratados.linha"] = linha
    pipeline = [{"$match": criterios}, _data_mes_dia() if mes_dia else
                _estagio_data("$dados_tratados.data"),
                {"$match": {"_data_relatorio": {"$ne": None}}}]
    if inicio is not None and fim is not None:
        inicio_data = datetime.combine(inicio, datetime.min.time())
        fim_exclusivo = datetime.combine(fim + timedelta(days=1), datetime.min.time())
        pipeline.append({"$match": {"_data_relatorio": {
            "$gte": inicio_data, "$lt": fim_exclusivo,
        }}})
    pipeline.extend([
                {"$group": {"_id": {"$dateToString": {
                    "format": "%Y-%m-%d", "date": "$_data_relatorio",
                }}, **{nome: {"$sum": f"$dados_tratados.{campo}"}
                       for nome, campo in campos.items()}}},
                {"$sort": {"_id": 1}}])
    return list(colecao.aggregate(pipeline))


def resumo_relatorios(colecao, inicio, fim, granularidade="diaria", linha=None):
    operacao_categoria = "linhas" if linha else "resumo_geral"
    operacao_campos = ({"viagens_realizadas": "numero_viagens",
                        "quilometragem_km": "quilometragem_total"} if linha else {
        "viagens_programadas": "viagens_programadas",
        "viagens_realizadas": "viagens_realizadas",
        "quilometragem_km": "km_total",
    })
    operacao = _agrupar_por_dia(
        colecao, operacao_categoria, operacao_campos, inicio, fim, linha,
    )
    passageiros = [] if linha else _agrupar_por_dia(colecao, "passageiros", {
        "passageiros_catraca": "passageiros_catraca",
        "passageiros_antecipados": "passageiros_antecipados",
        "passageiros_nao_pagantes": "passageiros_nao_pagantes",
    }, inicio, fim, mes_dia=True)
    financeiro = [] if linha else _agrupar_por_dia(colecao, "saldos", {
        "total_vendas": "total_vendas",
        "total_utilizacao": "total_utilizacao",
        "saldo_final": "saldo_final",
    }, inicio, fim, mes_dia=True)

    def indexar(itens):
        return {item["_id"]: item for item in itens}

    operacao_por_dia = indexar(operacao)
    passageiros_por_dia = indexar(passageiros)
    financeiro_por_dia = indexar(financeiro)
    datas = sorted(set(operacao_por_dia) | set(passageiros_por_dia) |
                   set(financeiro_por_dia))
    por_periodo = {}
    for texto_data in datas:
        dia = date.fromisoformat(texto_data)
        if granularidade == "semanal":
            segunda = dia - timedelta(days=dia.weekday())
            chave = segunda.isoformat()
        elif granularidade == "mensal":
            chave = dia.strftime("%Y-%m")
        else:
            chave = texto_data
        ponto = por_periodo.setdefault(chave, {
            "periodo": chave, "viagens_programadas": 0,
            "viagens_realizadas": 0, "quilometragem_km": 0,
            "passageiros_catraca": 0, "passageiros_antecipados": 0,
            "passageiros_nao_pagantes": 0, "total_vendas": 0,
            "total_utilizacao": 0, "saldo_final": None,
            "dias_operacao": 0,
        })
        if texto_data in operacao_por_dia:
            ponto["dias_operacao"] += 1
        for fonte, indice in ((operacao_por_dia, texto_data),
                              (passageiros_por_dia, texto_data),
                              (financeiro_por_dia, texto_data)):
            item = fonte.get(indice, {})
            for campo in ponto:
                if campo in ("periodo", "saldo_final"):
                    continue
                ponto[campo] += item.get(campo, 0) or 0
        if texto_data in financeiro_por_dia:
            ponto["saldo_final"] = financeiro_por_dia[texto_data].get("saldo_final")

    serie = list(por_periodo.values())
    totais = {
        campo: sum(item.get(campo, 0) or 0 for item in serie)
        for campo in ("viagens_programadas", "viagens_realizadas",
                      "quilometragem_km", "passageiros_catraca",
                      "passageiros_antecipados", "passageiros_nao_pagantes",
                      "total_vendas", "total_utilizacao")
    }
    totais["passageiros_pagantes"] = (totais.pop("passageiros_catraca") +
                                       totais.pop("passageiros_antecipados"))
    totais["total_passageiros"] = (totais["passageiros_pagantes"] +
                                    totais["passageiros_nao_pagantes"])
    totais["saldo_final"] = next((item["saldo_final"] for item in reversed(serie)
                                  if item["saldo_final"] is not None), None)
    totais["dias_com_dados"] = len(datas)
    if not operacao:
        for campo in ("viagens_programadas", "viagens_realizadas", "quilometragem_km"):
            totais[campo] = None
    if linha:
        for campo in ("passageiros_pagantes", "passageiros_nao_pagantes",
                      "total_passageiros", "total_vendas", "total_utilizacao",
                      "saldo_final"):
            totais[campo] = None
    for ponto in serie:
        ponto["passageiros_pagantes"] = (ponto["passageiros_catraca"] +
                                          ponto["passageiros_antecipados"])
        ponto["total_passageiros"] = (ponto["passageiros_pagantes"] +
                                       ponto["passageiros_nao_pagantes"])
        if linha:
            ponto["viagens_programadas"] = None
            for campo in ("passageiros_catraca", "passageiros_antecipados",
                          "passageiros_nao_pagantes", "passageiros_pagantes",
                          "total_passageiros", "total_vendas", "total_utilizacao"):
                ponto[campo] = None
    return {"inicio": inicio.isoformat() if inicio else None,
            "fim": fim.isoformat() if fim else None,
            "granularidade": granularidade, "indicadores": totais,
            "serie": serie}


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
