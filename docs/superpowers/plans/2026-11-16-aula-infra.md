# Repositório da aula (santo-projeto): plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIO: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar este plano tarefa por tarefa. Os passos usam checkbox (`- [ ]`) para acompanhamento.

**Objetivo:** entregar o repositório `santo-projeto` (infra, back, front e scripts) funcionando de verdade, provado por um ensaio local, no kind e na AWS, com os dois docs da aula atualizados até terça, 17/11.

**Arquitetura:**
- O código das três pastas vem do Roteiro (arquivo de referência) com poucas mudanças.
- Quatro scripts bash em `scripts/` cuidam da preparação, da publicação das imagens, da destruição e da conferência de custos.
- O ensaio é a bateria de testes: verificações por comando, sem suíte de testes automatizados, conforme os não objetivos da spec.

**Stack:**
- **Infra:** Terraform 1.17, provider AWS `~> 6.0`, módulos `terraform-aws-modules/vpc ~> 6.0` e `eks ~> 21.0`.
- **Back:** Python 3.12 e FastAPI (no Docker).
- **Front:** React com Vite (Node 26).
- **Ferramentas:** kubectl 1.36, kind, Docker com buildx, GHCR, AWS CLI 2 e jq.

**Spec:** `docs/superpowers/specs/2026-11-16-aula-infra-design.md`. O código-base está em `docs/superpowers/specs/2026-11-16-aula-infra-roteiro-referencia.md`, chamado de "Referência" neste plano.

## Restrições globais

- Região `us-east-1`, perfil AWS `default`. Nenhum script imprime credenciais.
- O ID da conta nunca entra em arquivo versionado (o repositório será público). Pode aparecer na tela.
- `projeto = "santo-projeto"` em `infra/envs/aula.tfvars`. Os nomes de VPC, cluster e bucket derivam desse valor.
- Imagens da API:
  - ECR: `linux/amd64`.
  - GHCR: `ghcr.io/$GITHUB_USER/santo-projeto-back:v1` e `:v2`, em `linux/amd64` e `linux/arm64`, públicas.
- Mensagem da `v1`: `Ola, turma! Esta e a versao 1.` Mensagem da `v2`: `Ola, turma! Esta e a versao 2.`. O repositório fica sempre na `v1`.
- Placeholder do deployment: `URL-DO-REPOSITORIO:v1` em `back/k8s/deployment.yaml`.
- API na porta 8000, com as rotas `GET /api/saudacao` → `{"mensagem","servidor"}` e `GET /health` → `{"status":"ok"}`.
- Outputs da raiz Terraform: `nome_cluster`, `repositorios` (mapa nome → URL), `bucket_site`, `url_site`.
- Scripts em bash com `set -euo pipefail`, rodados da raiz do repositório e só para macOS.
- **Nunca** desligar o bloqueio de acesso público do S3 da conta.
- Qualquer mudança no código da Referência é anotada em `docs/ensaio.md`, seção "Mudanças para os docs".
- Infraestrutura na AWS nunca fica de pé sem acompanhamento. Se travar e não houver correção em cerca de 30 minutos, rodar `destruir.sh`.

## Pontos de atenção na revisão

1. **Segunda rodada do zero:** `preparar.sh` depois de `destruir.sh` precisa funcionar, porque é a rodada que o professor grava. O teste está na Tarefa 8, passo 9.
2. **`destruir.sh` com o cluster já apagado ou o kubeconfig sem contexto:** precisa seguir para o `terraform destroy`, não abortar. Teste na Tarefa 8, passo 8.
3. **`publicar-imagens.sh` sem `GITHUB_TOKEN` ou `GITHUB_USER`:** sai com mensagem clara e código ≠ 0, antes de qualquer build. Teste na Tarefa 5, passo 2.
4. **`conferir.sh` numa conta com recursos que não são da aula (a VPC padrão):** eles não contam como sobra. Teste na Tarefa 4, passo 4.
5. **Imagem ARM no EKS (Mac ARM):** a imagem do ECR precisa ser amd64, ou os pods caem com `exec format error`. Teste na Tarefa 8, passo 3.

---

### Task 0: Repositório base

**Arquivos:**
- Criar: `.gitignore`

- [ ] **Passo 1:** rodar `git init -b main` na raiz `santo_projeto`.
- [ ] **Passo 2:** criar o `.gitignore` com `.terraform/`, `*.tfstate`, `*.tfstate.*`, `node_modules/`, `dist/`, `.env*`, `__pycache__/` e `.DS_Store`. O `.terraform.lock.hcl` **não** entra.
- [ ] **Passo 3:** verificar com `git check-ignore -v infra/.terraform/x infra/terraform.tfstate front/node_modules/x`. Esperado: as três linhas casam. `git check-ignore infra/.terraform.lock.hcl` não deve imprimir nada.
- [ ] **Passo 4:** commit `chore: repositório base` (`.gitignore`, `docs/`, `.vscode/`).

### Task 1: Back (API FastAPI)

**Arquivos:**
- Criar: `back/app/__init__.py` e um `__init__.py` vazio em cada camada (`domain`, `application`, `infrastructure`, `presentation`)
- Criar: `back/app/domain/saudacao.py`
- Criar: `back/app/application/obter_saudacao.py`
- Criar: `back/app/infrastructure/servidor_local.py`
- Criar: `back/app/presentation/api.py`
- Criar: `back/app/main.py`
- Criar: `back/requirements.txt`, `back/Dockerfile`, `back/.dockerignore`
- Criar: `back/k8s/deployment.yaml`, `back/k8s/service.yaml`

**Interfaces:**
- Produz:
  - imagem que escuta em `0.0.0.0:8000`;
  - classe `ObterSaudacao(servidor).executar() -> Saudacao`;
  - mensagem literal na linha `mensagem="Ola, turma! Esta e a versao 1.",` de `obter_saudacao.py`, que a Tarefa 5 troca por `sed`;
  - deployment e container com o nome `back`, e Service `back` do tipo LoadBalancer, porta 80 → 8000.

- [ ] **Passo 1:** copiar os arquivos da seção "Código: back" da Referência, sem alterar a lógica.
- [ ] **Passo 2:** fixar as versões do `requirements.txt` com o que o pip resolve hoje dentro de `python:3.12-slim`. Exemplo: `docker run --rm python:3.12-slim sh -c "pip install -q fastapi 'uvicorn[standard]' && pip freeze"`; manter só as linhas `fastapi==` e `uvicorn==` com o extra `[standard]`.
- [ ] **Passo 3:** criar o `.dockerignore` com `__pycache__` e `k8s`.
- [ ] **Passo 4:** rodar o build `docker build -t santo-back:local back`. Esperado: sucesso.
- [ ] **Passo 5:** testar a imagem. Rodar `docker run -d --rm -p 8000:8000 --name back-teste santo-back:local`. Depois verificar:
  - `curl -s localhost:8000/api/saudacao` devolve JSON com `"mensagem":"Ola, turma! Esta e a versao 1."` e `servidor` igual ao ID curto do container;
  - `curl -s localhost:8000/health` devolve `{"status":"ok"}`;
  - `curl -si -H 'Origin: http://exemplo' localhost:8000/api/saudacao | grep -i access-control-allow-origin` imprime `*`;
  - por fim, `docker stop back-teste`.
- [ ] **Passo 6:** commit `feat(back): API da saudação em quatro camadas`.

### Task 2: Front (React + Vite)

**Arquivos:**
- Criar: `front/` via `npm create vite@latest front -- --template react`
- Criar: `front/src/domain/saudacao.js`
- Criar: `front/src/application/obterSaudacao.js`
- Criar: `front/src/infrastructure/saudacaoApi.js`
- Criar: `front/src/presentation/App.jsx`
- Criar: `front/src/main.jsx`
- Remover: `front/src/App.jsx`, `front/src/App.css`, `front/src/index.css`, `front/src/assets/`, `front/public/vite.svg` e as referências a eles no `index.html`

**Interfaces:**
- Consome: a API da Tarefa 1 em `VITE_API_URL`.
- Produz: `npm run build` gera `front/dist/`, que a Tarefa 8 publica com `aws s3 sync`.

- [ ] **Passo 1:** gerar o projeto com o template (sem modo interativo; se o `create vite` perguntar algo, usar as flags dele para não perguntar). Copiar os cinco arquivos da seção "Código: front" da Referência e remover os arquivos de exemplo listados acima.
- [ ] **Passo 2:** rodar `cd front && npm install && npm run lint`. Esperado: nenhum erro de lint nem import quebrado.
- [ ] **Passo 3:** rodar `VITE_API_URL=http://localhost:8000 npm run build`. Esperado: sucesso, e `grep -r "localhost:8000/api/saudacao\|localhost:8000" dist/assets/*.js` encontra a URL.
- [ ] **Passo 4:** teste de fumaça no navegador.
  - Subir o back da Tarefa 1 na porta 8000 e o front com `VITE_API_URL=http://localhost:8000 npm run dev`.
  - Abrir a página (ferramenta Chrome, se disponível) e clicar duas vezes em "Chamar a API".
  - Esperado: dois itens na lista, cada um com "Respondido por <id do container>".
- [ ] **Passo 5:** commit `feat(front): página React em quatro camadas` (com o `package-lock.json`).

### Task 3: Infra (Terraform modular)

**Arquivos:**
- Criar: `infra/main.tf`, `infra/variables.tf`, `infra/outputs.tf` e `infra/envs/aula.tfvars`
- Criar: `infra/modules/{rede,ecr,eks,site}/{main,variables,outputs}.tf`
- Criar: `infra/.terraform.lock.hcl` (gerado)

**Interfaces:**
- Produz:
  - outputs `nome_cluster` (string), `repositorios` (map(string) nome → URL), `bucket_site` (string) e `url_site` (string `http://...`);
  - todos os recursos com a tag `Projeto=santo-projeto` via `default_tags`.

- [ ] **Passo 1:** copiar os arquivos da seção "Código: infra" da Referência. Os blocos `# modules/x/arquivo.tf` viram arquivos separados. A única mudança é no `aula.tfvars`: `projeto = "santo-projeto"`.
- [ ] **Passo 2:** rodar `cd infra && terraform fmt -recursive -check`. Esperado: código de saída 0. Se falhar, rodar `terraform fmt -recursive` e conferir o diff.
- [ ] **Passo 3:** rodar `terraform init -backend=false && terraform validate`.
  - Esperado: `Success! The configuration is valid.`
  - Se o EKS v21 recusar algum parâmetro (`name`, `endpoint_public_access`, `addons`, `before_compute`, `enable_cluster_creator_admin_permissions`), corrigir pelo README da versão baixada em `.terraform/modules/eks.eks/` e anotar em `docs/ensaio.md` › "Mudanças para os docs".
- [ ] **Passo 4:** rodar `terraform providers lock -platform=darwin_arm64 -platform=darwin_amd64 -platform=linux_amd64 -platform=windows_amd64`. Assim o lock serve para o Mac do professor e para os alunos no WSL.
- [ ] **Passo 5:** commit `feat(infra): raiz, módulos rede/ecr/eks/site e envs/aula.tfvars`.

### Task 4: Pré-checagem da conta e `conferir.sh`

**Arquivos:**
- Criar: `scripts/conferir.sh`
- Criar: `docs/ensaio.md`, com as seções "Pré-checagem", "Local", "kind", "AWS", "Mudanças para os docs" e "Rodada do professor"

**Interfaces:**
- Produz: `scripts/conferir.sh`, sem argumentos.
  - Imprime "nada sobrando" e sai com 0 quando não há recurso do projeto.
  - Caso contrário, lista o que sobrou por tipo e sai com 1.
  - Recursos sem a marca do projeto aparecem em "outros recursos na região" e não mudam o código de saída.

- [ ] **Passo 1: permissão.** Rodar `aws eks list-clusters --region us-east-1`.
  - Esperado: JSON sem erro.
  - Se der `AccessDenied`, **parar** e avisar o professor que o `AdministratorAccess` ainda não está no usuário do perfil `default`.
- [ ] **Passo 2: bloqueio do S3.** Rodar `aws s3control get-public-access-block --account-id "$(aws sts get-caller-identity --query Account --output text)"`.
  - Registrar o resultado em `docs/ensaio.md` › Pré-checagem, sem o ID da conta.
  - **Se `BlockPublicPolicy` ou `RestrictPublicBuckets` for `true`, ou se der erro `NoSuchPublicAccessBlockConfiguration`:**
    - `NoSuchPublicAccessBlockConfiguration` = desligado = segue normal.
    - Bloqueio ligado: remover `module "site"` e o `data "aws_caller_identity"` de `infra/main.tf`, os outputs `bucket_site` e `url_site` de `infra/outputs.tf` e a pasta `infra/modules/site/`.
    - Rodar `terraform validate`, anotar em "Mudanças para os docs" e fazer o commit `fix(infra): remove módulo site (bloqueio público do S3 ativo)`.
- [ ] **Passo 3:** escrever o `conferir.sh`.
  - Usar a AWS CLI e o jq.
  - **Com filtro do projeto:**
    - instâncias EC2 não terminadas com a tag `Projeto=santo-projeto` ou `kubernetes.io/cluster/santo-projeto`;
    - load balancers clássicos e v2 com a tag `kubernetes.io/cluster/santo-projeto` ou em VPC com a tag do projeto;
    - NAT Gateways não `deleted` em VPC do projeto;
    - Elastic IPs com a tag do projeto;
    - cluster EKS `santo-projeto`;
    - repositórios ECR criados pelo projeto (os nomes de `repositorios` no `aula.tfvars`);
    - buckets com prefixo `santo-projeto`;
    - grupos de log `/aws/eks/santo-projeto`;
    - aliases KMS `alias/eks/santo-projeto*` cuja chave não esteja `PendingDeletion`.
  - **Na lista "outros recursos na região":** o mesmo tipo de recurso sem a marca do projeto, exceto a VPC padrão.
- [ ] **Passo 4:** rodar `bash -n scripts/conferir.sh && scripts/conferir.sh; echo "saida=$?"`. Esperado: "nada sobrando" e `saida=0`, já que a conta hoje só tem a VPC padrão, que não pode aparecer como sobra.
- [ ] **Passo 5:** commit `feat(scripts): conferir.sh e registro do ensaio`.

### Task 5: Imagens públicas no GHCR (`publicar-imagens.sh`)

**Arquivos:**
- Criar: `scripts/publicar-imagens.sh`

**Interfaces:**
- Consome: `GITHUB_USER` e `GITHUB_TOKEN` (token com `write:packages`) do ambiente; a linha da mensagem da Tarefa 1.
- Produz:
  - `ghcr.io/$GITHUB_USER/santo-projeto-back:v1` e `:v2` (amd64 e arm64);
  - `ghcr.io/$GITHUB_USER/kindest-node:<tag da versão do kind>`;
  - na saída, o comando `kind create cluster --name aula --image ...` pronto para o Guia.

- [ ] **Passo 1:** escrever o script, nesta ordem:
  1. Validar as variáveis antes de qualquer outra coisa.
  2. Fazer o `docker login ghcr.io` via `--password-stdin`.
  3. Criar ou usar um builder buildx `santo-multi` com driver `docker-container`.
  4. Publicar a `v1` a partir de `back/`.
  5. Publicar a `v2` a partir de uma cópia em `mktemp -d`, com a linha da mensagem trocada por `sed`. Conferir com `grep` que a troca aconteceu e falhar se não aconteceu.
  6. Usar `--platform linux/amd64,linux/arm64 --push --label org.opencontainers.image.source=https://github.com/$GITHUB_USER/santo-projeto`.
  7. Copiar a imagem de nó do kind com `docker buildx imagetools create -t ghcr.io/$GITHUB_USER/kindest-node:<tag> kindest/node:<tag>@<digest>`. A tag e o digest ficam numa variável no topo do script, `KIND_NODE_IMAGE`, igual à imagem padrão da versão do kind instalada (das notas da versão do kind; anotar a versão).
  8. Por último, testar o download anônimo: `docker logout ghcr.io` e depois `docker buildx imagetools inspect` de cada imagem. Se falhar, imprimir "torne o pacote público em github.com/users/$GITHUB_USER/packages" e sair com 1.
- [ ] **Passo 2: falha sem variáveis.** Rodar `env -u GITHUB_TOKEN -u GITHUB_USER scripts/publicar-imagens.sh; echo "saida=$?"`. Esperado: mensagem dizendo quais variáveis faltam, `saida=1` e nenhum `docker build` executado.
- [ ] **Passo 3: checkpoint com o professor.** Pedir o usuário do GitHub e um token com `write:packages`. O professor exporta os dois no próprio terminal ou passa por `! export ...`; nunca gravar em arquivo. Rodar o script.
- [ ] **Passo 4: checkpoint com o professor.** Pedir que ele torne públicos os pacotes `santo-projeto-back` e `kindest-node` no GitHub. Rodar o script de novo. Esperado: o teste anônimo passa para as três imagens.
- [ ] **Passo 5: confirmar a `v2`.** Rodar `docker run --rm -d -p 8001:8000 --name v2 ghcr.io/$GITHUB_USER/santo-projeto-back:v2`. `curl -s localhost:8001/api/saudacao` precisa conter `versao 2`. Depois, `docker stop v2`.
- [ ] **Passo 6:** commit `feat(scripts): publicar-imagens.sh (GHCR multi-arquitetura + nó do kind)`.

### Task 6: Ensaio do caminho kind (o Guia, passo a passo)

**Arquivos:**
- Modificar: `docs/ensaio.md` › kind

**Interfaces:**
- Consome: as imagens da Tarefa 5. `IMAGEM=ghcr.io/$GITHUB_USER/santo-projeto-back`.

- [ ] **Passo 1:** rodar `brew install kind`, depois `kind create cluster --name aula --image ghcr.io/$GITHUB_USER/kindest-node:<tag>`. Em seguida, `kubectl get nodes` deve mostrar um nó `Ready`.
- [ ] **Passo 2:** rodar os sete passos do Guia **exatamente** como estão (spec, seção 6), com `kubectl get pods -w` num segundo terminal. Registrar, para cada passo, a saída obtida e se ela bate com o "Esperado" do Guia.
- [ ] **Passo 3:** verificar o `port-forward` depois do passo 5, do passo 6 e do passo 7.
  - Esperado: ele cai e voltar ao passo 3 resolve.
  - Se algo diferente acontecer, anotar o texto novo para o Guia em "Mudanças para os docs".
- [ ] **Passo 4:** fazer o desafio do Guia: 3 réplicas e apagar o pod que respondeu. Cronometrar quanto o substituto leva até `Running`.
- [ ] **Passo 5:** rodar `kubectl delete deployment back && kind delete cluster --name aula`.
- [ ] **Passo 6:** commit `docs: ensaio do caminho kind`.

### Task 7: `preparar.sh` e `destruir.sh`

**Arquivos:**
- Criar: `scripts/preparar.sh`
- Criar: `scripts/destruir.sh`

**Interfaces:**
- Consome: os outputs da Tarefa 3, o placeholder da Tarefa 1 e `scripts/conferir.sh`.
- Produz:
  - `preparar.sh` deixa o cluster com os nós `Ready`, `back:v1` (amd64) no ECR e `deployment.yaml` apontando para o ECR. Imprime o resumo e o tempo total.
  - `destruir.sh` deixa a conta sem recursos do projeto e o `deployment.yaml` com o placeholder. Termina com o código de saída do `conferir.sh`.

- [ ] **Passo 1:** escrever o `preparar.sh` com os seis passos da spec (seção 5.3).
  - O `sed` troca só o texto `URL-DO-REPOSITORIO`, então rodar de novo com a URL já posta não estraga nada.
  - O build usa `--platform linux/amd64`.
  - A espera pelos nós usa `kubectl wait --for=condition=Ready nodes --all --timeout=10m`.
- [ ] **Passo 2:** escrever o `destruir.sh`.
  1. Se `kubectl` alcançar o cluster `santo-projeto`, rodar `kubectl delete -f back/k8s/ --ignore-not-found` e esperar até 5 minutos que não haja load balancer com a tag `kubernetes.io/cluster/santo-projeto`. Se não alcançar, avisar e seguir.
  2. Rodar `terraform destroy -auto-approve -var-file=envs/aula.tfvars`.
  3. Restaurar o placeholder no `deployment.yaml` com `git checkout -- back/k8s/deployment.yaml`.
  4. Rodar `exec scripts/conferir.sh`.
- [ ] **Passo 3:** conferir a sintaxe com `bash -n scripts/preparar.sh && bash -n scripts/destruir.sh`. Esperado: sem saída.
- [ ] **Passo 4:** commit `feat(scripts): preparar.sh e destruir.sh`.

### Task 8: Ensaio na AWS (uma rodada técnica)

**Arquivos:**
- Modificar: `docs/ensaio.md` › AWS. Também qualquer arquivo de código que o ensaio obrigue a corrigir, anotado em "Mudanças para os docs".

**Interfaces:**
- Consome: todas as tarefas anteriores. Começar só depois que a Tarefa 4, passo 1, passar.

- [ ] **Passo 1:** rodar `time scripts/preparar.sh`. Esperado: nós `Ready` e resumo com cluster, ECR, bucket e URL do site. Anotar o tempo.
- [ ] **Passo 2: Parte 1 do Roteiro.**
  - `terraform plan -var-file=envs/aula.tfvars` → "No changes".
  - `terraform output`.
  - Acrescentar `"teste-aluno"` a `repositorios`, rodar `plan` (deve dar `1 to add`) e `apply`.
  - Voltar o `.tfvars` com `git checkout`, rodar `apply` (deve dar `1 to destroy`) e anotar os tempos.
- [ ] **Passo 3: Parte 2, passos 1 a 4.**
  - `kubectl apply -f back/k8s/`.
  - `kubectl get pods`: todos `Running`, sem `exec format error`.
  - `kubectl get service back` com o endereço do load balancer, anotando quanto tempo ele leva para responder.
  - `scale --replicas=6`.
  - `curl` cinco vezes em laço, anotando quantos nomes de pod diferentes aparecem.
- [ ] **Passo 4: passos 5 e 6, o front.**
  - Fazer o build com `VITE_API_URL=http://<LB>` e o `aws s3 sync` para `bucket_site`.
  - Abrir a `url_site` e clicar em "Chamar a API". Esperado: lista com o nome do pod.
  - **Se o módulo `site` foi removido na Tarefa 4,** fazer `npm run dev` com o mesmo `VITE_API_URL` e conferir em `localhost`.
- [ ] **Passo 5: passo 7, autorrecuperação.** Rodar `kubectl delete pod <um pod>`. Esperado: nasce um substituto, o total continua 6 e a página continua respondendo.
- [ ] **Passo 6: passos 8 e 9.**
  - Trocar a mensagem para a `v2`, fazer o build amd64, o push de `$REPO:v2` e `kubectl set image deployment/back back=$REPO:v2`. Clicar durante a troca e anotar se aparecem as duas mensagens.
  - Rodar `kubectl rollout undo deployment/back` e voltar o arquivo da mensagem com `git checkout`.
- [ ] **Passo 7:** rodar `time scripts/destruir.sh; echo "saida=$?"`. Esperado: `terraform destroy` sem erro, "nada sobrando", `saida=0` e `git status` sem mudança no `deployment.yaml`.
- [ ] **Passo 8: `destruir.sh` de novo, com tudo já destruído.** Rodar `scripts/destruir.sh; echo "saida=$?"`. Esperado: avisa que não alcança o cluster, o `terraform destroy` não faz nada e sai com `saida=0`.
- [ ] **Passo 9: segunda rodada do zero, curta.**
  - Rodar `scripts/preparar.sh` até os nós ficarem `Ready`, só para provar que a rodada do professor funciona.
  - Logo em seguida, `scripts/destruir.sh`. Esperado: `saida=0` nos dois.
- [ ] **Passo 10:** fechar a seção AWS do `docs/ensaio.md`:
  - tempo de cada etapa;
  - custo estimado: horas de EKS, nós, NAT e load balancer multiplicadas pelos preços da calculadora AWS em `us-east-1`;
  - o que falhou e como foi corrigido.
- [ ] **Passo 11:** commit `docs: ensaio na AWS` (com as correções de código, se houver).

### Task 9: README e rodada do professor

**Arquivos:**
- Criar: `README.md`
- Modificar: `docs/ensaio.md` › Rodada do professor

- [ ] **Passo 1:** escrever o `README.md`, com no máximo uma tela:
  - o que é o projeto (uma frase);
  - a árvore de pastas (a da spec, seção 5.1);
  - o caminho kind para os alunos, num terminal WSL: clonar, `kind create cluster` com a imagem de nó do GHCR e os sete passos;
  - um aviso para não rodar `terraform apply` (custo);
  - o link para o Guia como roteiro principal.
- [ ] **Passo 2:** escrever "Rodada do professor" em `docs/ensaio.md`:
  - pré-requisitos (perfil `default` com permissão e Docker aberto);
  - `scripts/preparar.sh` e quanto tempo esperar;
  - Parte 1 e Parte 2 do Roteiro, com os comandos;
  - `scripts/destruir.sh`;
  - o que conferir no fim;
  - lembrete de gravar a tela com o terminal em fonte grande.
- [ ] **Passo 3:** verificar com `grep -rnE '[0-9]{12}' --exclude-dir=node_modules --exclude-dir=.terraform .`. Esperado: nenhum ID de conta em arquivo versionado. Conferir manualmente cada número de 12 dígitos que aparecer.
- [ ] **Passo 4:** commit `docs: README e rodada do professor`.

### Task 10: Atualizar os docs da aula

**Arquivos:**
- Os docs Roteiro (https://claude.ai/artifact/KksVhYknkS6PcgKDuoxqzS) e Guia (https://claude.ai/artifact/84trFcnbNVicMbhbnDAq7n), editados pelo conector Claude Docs (`update`), sempre lendo antes de editar.

- [ ] **Passo 1: Roteiro.**
  - Trocar `projeto-aula` por `santo-projeto`.
  - Docker Hub → GHCR, com o motivo (limite por IP).
  - Na preparação, a chamada a `scripts/preparar.sh`, mantendo os comandos manuais como explicação.
  - Na Parte 1 e no Encerramento, `scripts/destruir.sh` e `scripts/conferir.sh`.
  - Tempos e custos medidos na Tarefa 8.
  - Responder as perguntas em aberto: aula em 18/11, Windows com WSL, gravação feita pelo professor.
  - Trocar o aviso "nenhum código foi executado" por "ensaiado em 17/11".
  - Aplicar tudo da seção "Mudanças para os docs".
  - Se o `site` saiu, ajustar o cronograma, a Parte 2, a árvore e o encerramento.
- [ ] **Passo 2: Guia.**
  - Mudar `cd projeto-aula` para `cd santo-projeto` e também a raiz da árvore.
  - Preencher "Imagem da API" com `ghcr.io/$GITHUB_USER/santo-projeto-back` (com o usuário real).
  - Dizer que os comandos rodam no terminal do WSL (não em PowerShell nem `cmd`).
  - Trocar o comando do kind no caminho B pelo da imagem de nó do GHCR.
  - Colocar o Killercoda como saída imediata se o kind travar.
  - Ajustar os passos do `port-forward` se a Tarefa 6 mostrou necessidade.
  - Preencher o endereço do repositório se ele já existir no GitHub; senão, deixar o campo.
- [ ] **Passo 3: verificação.** Ler os dois docs de novo e procurar `projeto-aula`, `Docker Hub` e `nenhum código`. Esperado: nada encontrado, exceto onde o texto explica a troca.

## Fora deste plano (com o professor)

- Criar o repositório público `santo-projeto` no GitHub e enviar o código (`git push`) só quando o professor pedir.
- Decidir se `docs/superpowers/` vai para o repositório público.
- Remover o `AdministratorAccess` do usuário depois da aula.
