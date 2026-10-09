# PI-SEMOB

Aplicação Flutter com API FastAPI e MongoDB. Após o login, o Dashboard resume dados reais dos relatórios importados. O menu abre Dashboard, Operação (importação de ZIP), Relatórios (consulta paginada) e Configurações (conta, conexão e logout).

## Preparação no VS Code

1. Instale Python 3.10+, MongoDB e Flutter 3.38+ (a versão testada foi 3.47.7). Use as extensões Python e Flutter/Dart do VS Code.
2. No terminal da raiz do projeto, prepare o backend:

   ```bash
   python -m venv .venv
   source .venv/bin/activate
   pip install -r backend/requirements.txt
   cp backend/.env.example backend/.env
   ```

3. Ajuste `MONGO_URI` e `DB_NAME` em `backend/.env`. Inicie o MongoDB e a API:

   ```bash
   cd backend
   uvicorn main:app --app-dir src --reload
   ```

4. Em outro terminal, inicie o Flutter:

   ```bash
   cd frontend
   flutter pub get
   flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:8000
   ```

   Se a API estiver em outro computador, use `flutter run -d chrome --dart-define=API_BASE_URL=http://IP:8000`. No emulador Android, o endereço padrão é `http://10.0.2.2:8000`.

5. Entre com um usuário cadastrado no MongoDB. A tela envia e-mail e senha para `POST /login` e abre o **Dashboard** apenas após a resposta válida. Abra o menu hambúrguer para acessar **Operação**, **Relatórios** e **Configurações**. Em Operação, arraste o ZIP para a área indicada ou use **Selecionar arquivo**.

O Flutter usa `http`, `cross_file`, `desktop_drop`, `file_picker` e `fl_chart` (gráficos Dart/Flutter). `flutter pub get` instala essas dependências. O backend usa as dependências já listadas em `backend/requirements.txt`.

### Usuário de teste local

Com a API e o MongoDB em execução, cadastre um usuário pelo terminal:

```bash
curl -X POST http://127.0.0.1:8000/usuarios \
  -H 'Content-Type: application/json' \
  -d '{"nome":"Usuário de teste","cpf":"12345678901","email":"teste.semob@example.com","celular":"11999999999","senha":"SenhaTeste123!"}'
```

Use **teste.semob@example.com** e **SenhaTeste123!** somente no ambiente local. Se a API retornar `409`, o e-mail já está cadastrado; escolha outro e-mail. O login retorna `401` quando o usuário não existe ou a senha está incorreta.

## Importação

O endpoint `POST /relatorios/importar-zip` aceita um campo multipart chamado `file`. Ele exige ZIP de até 50 MB e limita o conteúdo extraído a 500 MB, cada arquivo a 100 MB e o total a 500 entradas. Caminhos inseguros e links simbólicos são recusados. Os relatórios HTML em CP1252 são lidos em fluxo, um membro do ZIP por vez, e gravados em lotes de 500 documentos na coleção `relatorios_mensais`.

Cada documento guarda `dados_originais` com nomes e valores exibidos no relatório, `dados_tratados` com a conversão das funções existentes, `categoria`, `arquivo_origem`, `tabela`, `linha` e `chave_importacao`. A chave tem índice único e permite reenviar o mesmo ZIP sem duplicar suas linhas. Relatórios mensal e quinzenal mantêm origens separadas. A resposta traz totais e detalhes por arquivo para inseridos, ignorados por duplicidade e rejeitados. Linhas de total dos relatórios também são importadas.

O processamento é síncrono: a interface mostra o progresso de leitura do upload e, depois, atividade indeterminada enquanto o servidor importa. Se o banco falhar durante o processo, parte dos lotes anteriores pode já estar gravada; reenviar o mesmo ZIP é seguro pela chave de deduplicação. Após inserções novas, inclusive quando a API informa uma falha parcial com contagem de inseridos, Dashboard e Relatórios recarregam os dados. Se um HTML for alterado e reenviado no mesmo caminho, a chave inclui os valores da linha e a versão alterada será um novo documento; verifique a origem antes de usar ambos para análise.

## Dados e Dashboard

Na coleção `relatorios_mensais` consultada em 08/10/2026 havia **127.793 documentos**. Cada documento tem `arquivo_origem` (string com caminho do HTML), `categoria` (string), `tabela` (inteiro), `linha` (inteiro de posição no HTML), `dados_originais` (mapa de nomes e valores de texto), `dados_tratados` (mapa de valores convertidos) e `chave_importacao` (string de deduplicação). Foram encontradas 11 categorias: `fcv` (94), `fxhr` (16.541), `linhas` (828), `passageiros` (83), `resumo_fxhr` (1.894), `resumo_geral` (94), `saldos` (167), `viag_ninic` (15), `viag_nrealiz` (125), `viag_nterm` (21) e `viagens` (107.931).

Os caminhos indicam **julho/2026 mensal**, **agosto/2026 mensal e quinzenal** e **setembro/2026 quinzenal**. O período e a abrangência são derivados do caminho do arquivo, sem criar campos novos no banco. O filtro do Dashboard mantém Mensal e Quinzenal separados, pois as datas podem se sobrepor.

Os cards de viagens programadas, viagens realizadas e quilometragem vêm dos dias de `resumo_geral` (`dados_tratados.data`, `viagens_programadas`, `viagens_realizadas`, `km_total`). O gráfico diário usa as mesmas linhas. O gráfico de faixas soma `numero_viagens` de `resumo_fxhr` por `faixa_horaria`. O ranking soma `numero_viagens` de `linhas` por `linha` e mostra as oito maiores. Linhas de total sem data ou com rótulo vazio ficam fora dessas somas para evitar contagem dupla.

O card de passageiros soma os dias de `passageiros`. Neste arquivo, `dados_tratados.total_passageiros` perdeu o separador de milhar em alguns registros (`"16.544"` virou `16`); por isso a consulta converte `dados_originais["Total Passageiros"]` no MongoDB, removendo o ponto de milhar. Os documentos armazenados permanecem intactos. Um card sem dados para a categoria selecionada mostra `—`. Julho tem passageiros parciais; o total do card reflete os dias existentes, não uma estimativa do mês inteiro.

## Consultas da API

| Rota | Uso |
| --- | --- |
| `GET /health` | Status da API e conexão MongoDB para Configurações. |
| `GET /dashboard/opcoes` | Períodos e abrangências disponíveis. |
| `GET /dashboard/resumo?periodo=2026-08&abrangencia=Mensal` | Cards, evolução, faixas e oito linhas em agregações no MongoDB. |
| `GET /relatorios/filtros` | Períodos, categorias e abrangências para filtros. |
| `GET /relatorios?page=1&limit=25&tipo=linhas&periodo=2026-08&abrangencia=Mensal&linha=01` | Página de documentos, total e número de páginas. `limit` vai de 1 a 100. |

A página Relatórios permite filtrar por período, categoria, abrangência e linha de transporte, abrir os valores originais e tratados de cada documento e navegar entre páginas. Apenas a página solicitada é enviada ao Flutter. O login atual valida o usuário no banco, mas não emite token; ao recarregar o Flutter Web é necessário entrar novamente.

## Testes

```bash
cd backend
python -m pip install -r requirements-dev.txt
python -m unittest discover -s tests -v
```

```bash
cd frontend
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Para testar as páginas no VS Code, entre com o usuário local; confira que o Dashboard abre, mude período e abrangência; no menu abra Operação e importe o ZIP (o reenvio deve apresentar itens ignorados por duplicidade); abra Relatórios, aplique filtros, expanda um registro e navegue para a página seguinte; em Configurações confira usuário/status e saia da conta. Um login inválido deve permanecer na tela de login.

Para conferir dados importados no MongoDB, abra o `mongosh` e execute `use semob` (ou o nome configurado) e `db.relatorios_mensais.countDocuments({})`. O ZIP de referência fica fora do repositório; selecione-o pela interface para validar a integração com seu MongoDB.
