# Spec: repositório da aula de AWS, Terraform e Kubernetes

Data: 2026-11-16 · Repositório: `santo-projeto` (pasta local `santo_projeto`)

## 1. Intenção

O professor (dono deste repositório) dá esta semana uma aula para alunos iniciantes em nuvem. (Atualização de 16/11: a aula vai das 8h às 12h; o conteúdo continua o de 90 minutos, com mais tempo de prática para os alunos e dois intervalos.) Ele mostra um projeto completo, com três pastas, indo do repositório para a internet: o Terraform modular cria a infraestrutura na AWS, a API roda no Kubernetes (EKS) e o front é publicado no S3. Depois os alunos clonam o mesmo repositório e sobem a API num cluster deles.

Já existem dois docs da aula, e este repositório precisa bater com eles:

- **Roteiro da demonstração** (para o professor): https://claude.ai/artifact/KksVhYknkS6PcgKDuoxqzS. Uma cópia em texto, com todo o código, está em `2026-11-16-aula-infra-roteiro-referencia.md`, nesta mesma pasta.
- **Guia do participante** (para os alunos): https://claude.ai/artifact/84trFcnbNVicMbhbnDAq7n. O resumo do que ele exige do repositório está na seção 6.

O código do Roteiro nunca foi executado. O objetivo desta implementação é transformá-lo num repositório que **funciona de verdade**, provado por um ensaio completo na AWS e no kind, para o professor chegar na aula sem surpresas.

## 2. Objetivos

1. Criar as três pastas (`infra`, `back`, `front`) com o código do Roteiro, corrigido onde o ensaio mostrar erro.
2. Criar quatro scripts em `scripts/` que transformam a preparação e a limpeza em um comando cada (seção 5).
3. Publicar a imagem da API em duas versões (`v1` e `v2`) num registro público, para os alunos usarem sem conta AWS.
4. Rodar o ensaio completo na conta AWS do professor e no kind local, medindo os tempos (seção 7).
5. Atualizar os dois docs da aula com o que mudou: nome do repositório, endereço da imagem e correções vindas do ensaio.

## 3. Não objetivos

- Suíte de testes automatizados além dos testes de fumaça do ensaio. O pipeline de CI/CD é conteúdo da aula (ver `2026-11-16-aula-cicd-design.md`).
- HTTPS, CloudFront e domínio próprio. O Roteiro explica para a turma por que a aula usa HTTP.
- Estado remoto do Terraform. O estado fica local, porque o Roteiro mostra o `terraform.tfstate` como "a memória" do Terraform.
- Outros ambientes além de `envs/aula.tfvars`. A estrutura permite criar mais, mas nenhum é criado.
- Scripts que rodem em Windows ou Linux. Os scripts são para o Mac do professor; os alunos não usam os scripts.

## 4. Anti-objetivos: falhas mesmo que "funcione"

- **Recurso esquecido ligado na AWS** depois do ensaio ou da aula, gerando cobrança.
- **Credencial no repositório ou na tela:** chave AWS ou token do GitHub em qualquer arquivo ou na tela, e o ID da conta em qualquer arquivo versionado. O repositório vai ser público. O ID da conta pode aparecer na tela, nas URLs do ECR e do bucket, porque a AWS não o trata como segredo.
- **Aluno precisando de conta AWS ou de credencial do professor** para fazer a parte prática.
- **Repositório diferente do que os docs mostram:** outros nomes de pasta, outros comandos ou outras portas. O aluno lê o Guia e o professor lê o Roteiro; se o código mudar, o doc muda junto.
- **Complexidade que esconde a aula:** abstrações, frameworks ou ferramentas a mais que um iniciante precisaria entender para seguir o código. O código precisa continuar legível na tela do projetor.

## 5. O que construir

### 5.1 Estrutura

```
santo-projeto/
├── infra/      # Terraform: raiz + modules/{rede,ecr,eks,site} + envs/aula.tfvars (código do Roteiro)
├── back/       # API FastAPI em quatro camadas + Dockerfile + k8s/ (código do Roteiro)
├── front/      # React (Vite) em quatro camadas (código do Roteiro)
├── scripts/    # preparar.sh, publicar-imagens.sh, destruir.sh, conferir.sh
├── docs/       # esta spec e a referência do Roteiro
├── README.md
└── .gitignore
```

- O código das três pastas é o do Roteiro, arquivo por arquivo. Mudanças só para corrigir o que o ensaio mostrar que não funciona; cada mudança é anotada para entrar no doc.
- **`projeto = "santo-projeto"` no `aula.tfvars`** (o Roteiro usa `projeto-aula`). Os nomes de VPC, cluster e bucket seguem esse valor.
- **Front:** gerado com `npm create vite@latest front -- --template react`; o `src/` é trocado pelos cinco arquivos do Roteiro e os arquivos de exemplo do template são removidos (CSS, assets e o `App.jsx` antigo).
- **`back/requirements.txt` com versões fixas**, definidas no ensaio, como o Roteiro pede.
- **`.gitignore`:** `.terraform/`, `*.tfstate*`, `node_modules/`, `dist/`, `.env*` e `__pycache__/`. O `.terraform.lock.hcl` continua versionado, para os alunos baixarem as mesmas versões dos providers.
- **`README.md`** curto, para quem chega pelo GitHub: o que é o projeto, a árvore de pastas e como fazer a parte prática com kind, apontando o Guia como roteiro principal.

### 5.2 Imagens da API

| Onde | Endereço | Arquitetura | Para quem |
|---|---|---|---|
| ECR da conta do professor | URL do `terraform output repositorios` + `:v1` (e `:v2` na demonstração) | `linux/amd64` | O cluster EKS da demonstração |
| GHCR público | `ghcr.io/$GITHUB_USER/santo-projeto-back:v1` e `:v2` | `linux/amd64` e `linux/arm64` | Os alunos (kind e navegador) e o kind no Mac do professor |

- **GHCR em vez do Docker Hub, que o Roteiro cita como exemplo.** Os alunos do laboratório saem para a internet pelo mesmo IP, e o Docker Hub limita downloads anônimos por IP; na aula isso apareceria como `ImagePullBackOff` em vários alunos ao mesmo tempo.
- **Imagens multi-arquitetura**, porque o Mac do professor é ARM e as máquinas do laboratório e os nós do EKS são x86.
- **A `v2` difere da `v1` só na mensagem** `"Ola, turma! Esta e a versao 2."`, trocada em `back/app/application/obter_saudacao.py`. O repositório fica sempre na `v1`; a `v2` é gerada a partir de uma cópia temporária.
- **O pacote no GHCR precisa estar público.** Depois do primeiro envio, o professor muda a visibilidade no GitHub (passo manual). O script confere se um download anônimo funciona.
- **Cópia da imagem de nó do kind no GHCR.** O `kind create cluster` baixa a imagem `kindest/node` do Docker Hub, que limita downloads anônimos por IP (algo como 10 por hora; conferir o limite atual). Com 30 alunos no mesmo IP, isso trava a aula. Por isso, `publicar-imagens.sh` também copia a `kindest/node` da versão padrão do kind instalado para `ghcr.io/$GITHUB_USER/kindest-node:<versão>`, multi-arquitetura e pública. O Guia passa a usar `kind create cluster --name aula --image ghcr.io/...`.

### 5.3 Scripts

Todos em bash, com `set -euo pipefail`, rodados a partir da raiz do repositório, usando o perfil AWS `default` na região `us-east-1`. Nenhum imprime credenciais.

**`scripts/preparar.sh`** faz a preparação do Roteiro ("No dia, uma hora antes"):
1. Confere as ferramentas (`aws`, `terraform`, `kubectl`, `docker`, `jq`, `node`) e a identidade AWS.
2. Roda `terraform init` e `terraform apply -var-file=envs/aula.tfvars` em `infra/`.
3. Faz o login no ECR, o build com `--platform linux/amd64` e o push de `back:v1`.
4. Roda `aws eks update-kubeconfig` e espera os nós ficarem `Ready`.
5. Troca `URL-DO-REPOSITORIO` em `back/k8s/deployment.yaml` pela URL real do ECR. Isso altera o arquivo localmente, e essa alteração não deve ser versionada.
6. Mostra no fim: nome do cluster, URL do ECR, bucket, URL do site e o tempo total.

**`scripts/publicar-imagens.sh`** publica no GHCR:
- Lê `GITHUB_USER` e `GITHUB_TOKEN` (token com `write:packages`) do ambiente e falha com uma mensagem clara se faltarem.
- Usa `docker buildx` para publicar `v1` e `v2` multi-arquitetura. A `v2` é gerada a partir de uma cópia temporária de `back/` com a mensagem trocada.
- Adiciona o rótulo `org.opencontainers.image.source` apontando para o repositório no GitHub.
- No fim, confere que um download anônimo das duas tags funciona. Se falhar, avisa que o pacote ainda está privado.

**`scripts/destruir.sh`** limpa na ordem do Roteiro:
1. `kubectl delete -f back/k8s/` e espera o load balancer sumir, para ele não ficar órfão e travar a remoção da VPC.
2. `terraform destroy -var-file=envs/aula.tfvars` em `infra/`.
3. Devolve o placeholder `URL-DO-REPOSITORIO` ao `deployment.yaml`.
4. Chama `conferir.sh`.

**`scripts/conferir.sh`** só lê, nunca apaga. Lista em `us-east-1` o que pode ter sobrado do projeto: instâncias EC2, load balancers (clássicos e v2), NAT Gateways, Elastic IPs, clusters EKS, repositórios ECR, buckets S3 com prefixo `santo-projeto`, grupos de log `/aws/eks/santo-projeto*` e chaves KMS do cluster que não estejam em exclusão agendada. Termina com "nada sobrando" ou com a lista do que sobrou. O código de saída é diferente de zero se sobrou algo.

A conta é tratada como dedicada à aula: na verificação de 16/11 não havia repositórios ECR nem buckets S3, e só a VPC padrão. Mesmo assim, o script filtra pelo nome do projeto e pela tag `Projeto=santo-projeto` sempre que der. O que existir sem essa marca aparece numa lista à parte ("outros recursos na região") e não conta como sobra.

## 6. O que o Guia do participante exige do repositório

O Guia é o que os alunos seguem; o repositório precisa fazer cada passo dele funcionar:

- **Clonar com `git clone ENDERECO-DO-REPOSITORIO`** e entrar na pasta com `cd`. O Guia hoje diz `cd projeto-aula` e vai passar a dizer `cd santo-projeto`.
- **Exercício "siga a variável" (sem AWS):** `repositorios` aparece em `envs/aula.tfvars` → `variables.tf` → `main.tf` (module `ecr`) → `modules/ecr/variables.tf` → `modules/ecr/main.tf` → `modules/ecr/outputs.tf` e `outputs.tf`. O código do Roteiro já faz esse caminho; ele não pode ser quebrado.
- **Os sete passos com `kubectl`,** usando `IMAGEM` como a imagem do GHCR:
  - `kubectl create deployment back --image=IMAGEM:v1 --replicas=2 --port=8000`
  - `kubectl port-forward deployment/back 8000:8000`
  - `curl localhost:8000/api/saudacao`, que devolve `mensagem` e `servidor`
  - `kubectl scale deployment back --replicas=6`
  - `kubectl delete pod NOME`
  - `kubectl set image deployment/back '*=IMAGEM:v2'`, depois do qual a mensagem passa a ser a da versão 2
  - `kubectl rollout undo deployment/back`
- **O `port-forward` prende um único pod e cai quando esse pod é apagado ou trocado.** O Guia já diz para repetir o passo 3 depois do passo 5; o ensaio confirma que isso basta e que vale o mesmo depois do `set image` e do `rollout undo`. Se não bastar, só o texto do Guia muda; o repositório não ganha Service nem configuração extra para isso.
- **As máquinas do laboratório são Windows com WSL.** Os comandos do Guia rodam no terminal do WSL (bash), então `curl` e as aspas simples funcionam como estão. O Guia passa a dizer isso explicitamente e a avisar para não usar PowerShell nem `cmd`. O caminho B (kind) supõe Docker acessível de dentro do WSL e o kind instalado no WSL. Não dá para ensaiar esse caminho num Windows; o ensaio no kind do Mac cobre os comandos.
- **Desafio:** encontrar o arquivo da mensagem (`back/app/application/obter_saudacao.py`, camada `application`) e responder qual arquivo de `infra/` muda para criar outro repositório (`envs/aula.tfvars`).

## 7. Ensaio

Quem implementa roda o ensaio por inteiro e registra o resultado em `docs/ensaio.md`: tempos de cada etapa, o que falhou, o que foi corrigido e o custo estimado.

**Antes de começar:**
- Confirmar que o usuário AWS do perfil `default` agora tem permissão total. Hoje ele não tem permissão para EKS, NAT Gateway nem CloudWatch Logs; o professor vai anexar `AdministratorAccess`. Teste: `aws eks list-clusters` responde sem erro. Se continuar negado, parar e avisar o professor.
- O alerta de orçamento já existe na conta.
- **Conferir o bloqueio de acesso público do S3 no nível da conta (`s3control get-public-access-block`). Nunca desligá-lo.**
  - **Desligado:** o módulo `site` e a publicação do front no S3 seguem como no Roteiro.
  - **Ligado (decisão do professor: não desligar):**
    - o módulo `site` e os outputs `bucket_site` e `url_site` saem da raiz;
    - o passo 6 da Parte 2 vira `npm run dev` no notebook com `VITE_API_URL` apontando para o load balancer;
    - o Roteiro é ajustado: cronograma, Parte 2, tabela do encerramento e o módulo `site` na árvore.

**Parte local (sem custo):**
1. Rodar o back com Docker e chamar `/api/saudacao` e `/health`.
2. Rodar o front com `npm run dev` apontando para o back local, e conferir que a página lista as respostas.
3. Rodar `terraform fmt -check` e `terraform validate` em `infra/`.
4. Publicar as imagens no GHCR com `publicar-imagens.sh`. Nessa hora pedir ao professor `GITHUB_USER`, `GITHUB_TOKEN` e que torne o pacote público.
5. Instalar o kind (Homebrew), criar o cluster com a imagem de nó do GHCR e fazer os sete passos do Guia, exatamente como estão escritos, com a imagem da API do GHCR. Depois apagar o cluster.

**Parte na AWS (com custo, uma rodada só):**
1. `preparar.sh`, cronometrado.
2. Parte 1 do Roteiro:
   - `plan` sem mudanças
   - `terraform output`
   - acrescentar um item a `repositorios`, rodar `plan` (que deve mostrar 1 to add) e `apply`
   - voltar o `.tfvars` ao original e aplicar de novo
3. Parte 2 do Roteiro, passos 1 a 9:
   - deploy
   - load balancer respondendo
   - escala para 6
   - `curl`
   - build e `s3 sync` do front, com a página aberta pela URL do site chamando a API
   - apagar um pod
   - `v2` no ECR com `set image`
   - `rollout undo`
4. `destruir.sh` e `conferir.sh` terminando em "nada sobrando".

**Segunda rodada, do professor:** depois do ensaio técnico, o professor roda tudo de novo sozinho, só com os scripts e o Roteiro, narrando e gravando a tela. Essa gravação é o plano B se a internet do laboratório falhar. Por isso:
- os scripts precisam funcionar numa segunda rodada do zero, depois de um `destruir.sh`;
- `docs/ensaio.md` termina com um passo a passo curto para essa rodada: o que rodar, em que ordem, quanto tempo esperar e como destruir no fim.

**Regra de segurança:** se a parte na AWS travar e não houver correção em cerca de 30 minutos, destruir tudo e retomar depois. A infraestrutura nunca fica de pé sem alguém acompanhando.

## 8. Atualização dos docs da aula

Depois do ensaio, editar os dois docs:
- Trocar `projeto-aula` por `santo-projeto`.
- No Guia, preencher o campo "Imagem da API" com o endereço do GHCR. No Roteiro, trocar "Docker Hub" por GHCR e o motivo.
- Substituir os passos da preparação do Roteiro pela chamada aos scripts, mantendo os comandos manuais como explicação.
- Corrigir no Roteiro tudo o que o ensaio mudou: código, tempos, custos e o aviso de "nenhum código foi executado".
- Responder no Roteiro as perguntas em aberto que já foram decididas: data, máquinas Windows com WSL, gravação feita pelo professor.
- No Guia:
  - dizer que os comandos rodam no terminal do WSL;
  - trocar o comando do kind para a imagem de nó do GHCR;
  - colocar o Killercoda como saída imediata se o kind travar.

## 9. Ambiente e restrições

- **Máquina:** Mac ARM (arm64).
- **Ferramentas instaladas:** AWS CLI 2.37, Terraform 1.17, kubectl 1.36, Docker 29.9 com buildx, Node 26, npm 11, jq 1.7 e git.
- **Faltam:** kind, que entra no ensaio via Homebrew. O `gh` não é necessário.
- **Python local:** 3.9. O back roda pelo Docker, com Python 3.12, então isso não importa.
- **Versões do Roteiro:** provider AWS `~> 6.0`, módulo VPC `~> 6.0` e módulo EKS `~> 21.0`. Os nomes de parâmetros do EKS v21 foram escritos de memória e precisam ser validados.
- **Prazo:** a aula é na quarta-feira, 18/11/2026.
  - O ensaio técnico na AWS acontece assim que a parte local passar, até terça (17/11).
  - Os docs ficam atualizados na terça (17/11), a tempo de o professor fazer a rodada gravada no mesmo dia.
- **Ainda não é um repositório git.** Criar o repositório no GitHub e enviar o código é do professor, ou é feito quando ele pedir.

## 10. Abordagens consideradas

| Abordagem | Troca | Escolha |
|---|---|---|
| A. Só o código do Roteiro | Menor, mas a preparação e a limpeza continuam como comandos soltos, com mais risco de erro no dia | Não |
| **B. Código do Roteiro + scripts da aula + caminho kind testado** | Um pouco mais de código, mas o ensaio vira um comando só e a limpeza fica conferida | **Escolhida pelo professor** |
| C. B + testes e CI | Mais robusto, mas foge do foco da aula e aumenta o que o aluno lê | Não |

Dentro da B, quem implementa descartou:
- **Makefile no lugar dos scripts**, porque a sintaxe atrapalha a leitura e o Roteiro fala em comandos de shell.
- **Estado remoto do Terraform**, porque exige criar um bucket antes do bucket e esconde o `tfstate` que o Roteiro mostra.
- **Workspaces ou Terragrunt**, porque o Roteiro já usa um `.tfvars` por ambiente.

## 11. Decisões

**Decididas pelo professor:**
- Abordagem B.
- Ensaio real na conta dele, com o perfil AWS `default`, cuja permissão total ele mesmo libera.
- Repositório na conta pessoal do GitHub.
- Aula na quarta, 18/11.
- Não desligar o bloqueio de acesso público do S3; se estiver ligado, o front roda local.
- Laboratório com Windows e WSL.
- Ele grava a própria rodada.

**Decididas por quem desenhou a spec (podem ser revistas):**
- GHCR em vez do Docker Hub.
- Imagens multi-arquitetura.
- `v2` gerada a partir de uma cópia temporária.
- Nome `santo-projeto` no repositório e no `aula.tfvars`.
- Estado local do Terraform.
- Scripts em bash só para Mac.
- README curto.
- `preparar.sh` edita o `deployment.yaml` no lugar, e `destruir.sh` restaura o placeholder.
- Cópia da imagem de nó do kind no GHCR, para fugir do limite do Docker Hub.
- ID da conta permitido na tela, mas não em arquivos versionados.
- Conta tratada como dedicada, com `conferir.sh` filtrando pelo nome e pela tag do projeto.
- Problema do `port-forward` resolvido só no texto do Guia, se precisar.

**Ficam com quem implementa:**
- Versões fixas do `requirements.txt` e do `package.json`.
- Detalhes internos e mensagens dos scripts.
- Texto do README.
- Correções no código do Roteiro que o ensaio exigir, desde que anotadas para os docs.
