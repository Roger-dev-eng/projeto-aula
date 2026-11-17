# Ensaio

## Pré-checagem

Feita em 16/11, perfil `default`, região `us-east-1`.

- **Permissão:** `aws eks list-clusters --region us-east-1` devolveu `{"clusters": []}`, sem erro. O usuário do perfil tem `AdministratorAccess`.
- **Bloqueio de acesso público do S3 (conta):** `aws s3control get-public-access-block` deu `NoSuchPublicAccessBlockConfiguration`, ou seja, desligado. O módulo `site` fica.
- **`scripts/conferir.sh` antes de tudo:** `nada sobrando`, `saida=0` (a conta só tinha a VPC padrão).
- **Ferramentas:** aws-cli 2.37.12, Terraform 1.17.2, kubectl 1.36.1, Docker 29.9.3 (Mac arm64), Node 26.13.0.

## Local

Feito em 16/11 no Mac do professor, com o contêiner do back na porta 8000 e o servidor de desenvolvimento do front na 5173.

- **Back:** a imagem foi construída e `curl -s localhost:8000/api/saudacao` devolve `{"mensagem":"Ola, turma! Esta e a versao 1.","servidor":"<id do contêiner>"}`. Cabeçalho CORS presente: `access-control-allow-origin: *`.
- **Front:** `npm run lint` sem avisos; o servidor de desenvolvimento na 5173 chama a API da 8000.
- **Infra (sem custo):** `terraform fmt -recursive -check` sem diferenças e `terraform validate` com `Success! The configuration is valid.`

## kind

Máquina: Mac ARM do professor fazendo o papel do aluno. kind v0.33.0, Docker 29.9.3. Imagem do nó: `ghcr.io/izaiasjun1dev/kindest-node:v1.37.0` (Kubernetes v1.37.0); imagem da API: `ghcr.io/izaiasjun1dev/santo-projeto-back:v1`/`:v2`. Os dois pulls funcionaram anonimamente (depois de `docker logout ghcr.io`).

- `kind create cluster --name aula --image ghcr.io/izaiasjun1dev/kindest-node:v1.37.0`: 36 s no total, com o pull do nó.
- `kubectl get nodes`: logo após o create o nó aparece `NotReady`; com ~25 s fica `Ready`.
- Os sete passos do Guia funcionaram: 2 pods `Running` em 9 a 10 s; `curl` devolve a mensagem e o nome do pod; `scale` para 6 em menos de 13 s; `delete pod` cria o substituto; `set image` completa em ~30 s e responde `versao 2`; `rollout undo` volta à `versao 1`. No kind a coluna `NODE` é igual para todos os pods (um nó só).
- **`port-forward` depois dos passos 5, 6 e 7:** o processo continua vivo e silencioso. O primeiro `curl` seguinte falha (`Empty reply from server`, ou timeout no passo 7); só então o terminal do `port-forward` imprime `error: lost connection to pod` e sai. Rodar o `port-forward` de novo resolve. Subir um segundo antes de o primeiro cair dá `address already in use`: Ctrl+C no primeiro.
- Desafio (3 réplicas): o substituto do pod apagado ficou `Running` em 0,5 s (imagem já no nó, API encerra no SIGTERM); com cronômetro de mão, 1 a 3 s.
- Limpeza: `kubectl delete deployment back && kind delete cluster --name aula`; `kind get clusters` devolve `No kind clusters found.`

## AWS

Ensaio técnico em 16/11, das 17:53 às 19:00, em duas rodadas completas. Versões resolvidas: provider aws 6.73.0, módulo vpc 6.7.3, módulo eks 21.29.0, Kubernetes 1.37.

### Rodada 1: roteiro inteiro

| Etapa | Resultado | Tempo |
|---|---|---|
| `scripts/preparar.sh`, 1ª tentativa | Falhou no plan: `Invalid count argument` no `data "aws_eks_cluster_versions"` do node group (módulo eks 21.x sem `kubernetes_version`). Nada foi criado. Correção abaixo. | 6 s |
| `scripts/preparar.sh`, 2ª tentativa | `saida=0`, 60 recursos, dois nós `Ready`, resumo com cluster, ECR, bucket e site | **17 min 10 s** |
| ↳ cluster EKS (`aws_eks_cluster`) | | 11 min 16 s |
| ↳ node group | | 2 min 10 s |
| ↳ NAT Gateway | | 1 min 36 s |
| Parte 1: `terraform plan` | `No changes.` | 8 s |
| Parte 1: `terraform output` | `bucket_site`, `nome_cluster`, `repositorios` (`back = <conta>.dkr.ecr.us-east-1.amazonaws.com/back`), `url_site` | segundos |
| Parte 1: `repositorios = ["back", "teste-aluno"]`, `plan` | `Plan: 1 to add` | 7 s |
| Parte 1: `apply` | `Resources: 1 added`; repositório `teste-aluno` aparece no ECR | 9 s |
| Parte 1: `git checkout` do `.tfvars` e `apply` | `Plan: 0 to add, 0 to change, 1 to destroy`, `1 destroyed` | 9 s |
| Parte 2, passo 1: `kubectl apply -f back/k8s/` | 2 pods `Running` em 5 s, sem `exec format error` | 5 s |
| Parte 2, passo 2: `kubectl get service back` | `EXTERNAL-IP` com o DNS do load balancer na hora (Classic Load Balancer, sem configuração extra) | o endereço respondeu **103 s** depois do `apply` |
| Parte 2, passo 3: `scale --replicas=6` | 6 pods `Running`, 3 em cada nó | segundos |
| Parte 2, passo 4: `curl` 5 vezes em laço | **3 nomes de pod diferentes** em 5 chamadas | |
| Parte 2, passo 5: `npm install` + `npm run build` com `VITE_API_URL=http://<LB>` | `dist/` com a URL do LB no JS | 2 s |
| Parte 2, passo 6: `aws s3 sync dist/ s3://<bucket_site> --delete` | site responde 200; CORS `access-control-allow-origin: *` | 4 s |
| Parte 2, passo 7: `kubectl delete pod <o pod que respondeu>` | substituto `Running` em 4 s; total continua 6; a API segue respondendo | 4 s |
| Parte 2, passo 8: v2 (build amd64 + push `:v2` + `set image`) | troca em 25 s; em 60 chamadas com `curl` a cada 0,5 s as mensagens `versao 1` e `versao 2` se alternaram durante a troca, nenhuma falhou | build+push 5 s (cache), troca 25 s |
| Parte 2, passo 9: `kubectl rollout undo deployment/back` | volta à `v1` (imagem `:v1`); `obter_saudacao.py` restaurado com `git checkout` | 15 s |
| `scripts/destruir.sh` | LB removido antes do destroy, `Destroy complete! Resources: 60 destroyed.`, `nada sobrando`, `saida=0`, `deployment.yaml` restaurado | **12 min 36 s** |
| ↳ node group / cluster / NAT | | 8 min 12 s / 3 min 13 s / 1 min 1 s |
| `scripts/destruir.sh` de novo | `AVISO: cluster santo-projeto não encontrado ou inacessível; pulando o kubectl.`, `No changes. No objects need to be destroyed.`, `nada sobrando`, `saida=0` | 10 s |

O clique em "Chamar a API" desta rodada foi conferido por `curl` (o Chrome mostrou uma página de erro na primeira visita; na rodada 2 o mesmo endereço abriu normalmente e o clique foi feito no navegador).

### Rodada 2: do zero, com as versões dos módulos fixadas

| Etapa | Resultado | Tempo |
|---|---|---|
| `scripts/preparar.sh` | `saida=0`, dois nós `Ready` | **15 min 11 s** (cluster 11 min 28 s, node group 1 min 49 s) |
| Extra: `kubectl apply`, `scale --replicas=6`, build e `sync` do front | LB respondeu 85 s depois do `apply` | ~3 min |
| Extra: abrir a `url_site` no Chrome e clicar em "Chamar a API" duas vezes | lista com `Ola, turma! Esta e a versao 1. Respondido por back-…-sp48k.` (as duas vezes o mesmo pod: o navegador reaproveita a conexão, como o Roteiro avisa) | |
| `scripts/destruir.sh` | LB removido, `Destroy complete! Resources: 60 destroyed.`, `nada sobrando`, `saida=0`, `deployment.yaml` restaurado | **12 min 44 s** |

### O que falhou e como foi corrigido

1. **`terraform apply` falhava no plan com `Invalid count argument`** (`.terraform/modules/eks.eks/modules/eks-managed-node-group/main.tf`, `data "aws_eks_cluster_versions"`). Sem `kubernetes_version`, o node group do módulo eks 21.x depende da versão do cluster, que só existe depois do apply. Correção: `kubernetes_version = "1.37"` em `infra/modules/eks/main.tf` (1.37 é a versão padrão do EKS hoje, em suporte padrão).
2. **Versões dos módulos fixadas** depois do ensaio: `version = "21.29.0"` (eks) e `version = "6.7.3"` (vpc), no lugar de `~> 21.0` e `~> 6.0`. A rodada 2 já subiu com elas.

Nada mais falhou: `preparar.sh`, `destruir.sh` e `conferir.sh` rodaram sem alteração.

### Custo estimado

Preços on-demand em `us-east-1` (AWS Pricing API, 16/11): EKS US$ 0,10/h por cluster; t3.medium US$ 0,0416/h; NAT Gateway US$ 0,045/h + US$ 0,045/GB; Classic Load Balancer US$ 0,025/h (hora ou fração); IPv4 público US$ 0,005/h por endereço; gp3 US$ 0,08/GB-mês (2 discos de 20 GB). Por hora, com tudo de pé: cerca de **US$ 0,27/h** (EKS 0,10 + nós 0,083 + NAT 0,05 com o IP + LB 0,035 com 2 IPs + discos e chave KMS < 0,01).

- **Este ensaio:** infraestrutura de pé por ~35 min na rodada 1 e ~30 min na rodada 2, LB por ~5 min em cada. Contando hora cheia para EKS, NAT e LB (cobrança por hora ou fração), mais tráfego de NAT (pull de imagens, < 1 GB) e logs do plano de controle: **menos de US$ 1** no total.
- **Dia da aula (08:00–12:00; infraestrutura de pé ~4,5 h, das 7h30 ao fim do destroy; LB por ~2 h):** EKS 0,45 + nós 0,37 + NAT 0,23 + LB 0,07 + IPs, discos, NAT por GB e logs ~0,15 = **cerca de US$ 1,30 a US$ 1,50**. Esquecer tudo ligado por um dia custa ~US$ 6,50.

## CI/CD

Ensaio técnico em 16/11, das 20:10 às 20:51, com o workflow `Pipeline` (`.github/workflows/pipeline.yml`) no repositório público. Infraestrutura de pé por ~40 min; load balancer por ~9 min.

| Etapa | Resultado | Tempo |
|---|---|---|
| Push do merge com a infra desligada (run 43976562360) | `ci` verde; `cd` verde com `Infra desligada: deploy pulado` | |
| `scripts/preparar.sh`, 1ª tentativa | Falhou ao criar o cluster: `InvalidParameterException: Access denied to KMS key ... due to explicit deny policy or revoked grant`. A chave KMS tinha acabado de ser criada (23 s antes); o resto da rede, inclusive o NAT, já estava de pé. Correção abaixo. | 2 min 27 s |
| `scripts/preparar.sh`, 2ª tentativa | `saida=0`, `Apply complete! Resources: 14 added`, dois nós `Ready`, resumo com `Deploy:   CD ligado`; `gh secret list` mostra `AWS_PAPEL_CICD` | **17 min 1 s** (cluster 14 min 0 s, node group 58 s) |
| `kubectl apply -f back/k8s/` | 2 pods `Running`; o endereço do LB respondeu `versao 1` | **98 s** depois do `apply` |
| `git commit -m "versao 3" back/app/application/obter_saudacao.py` e `git push` (run 43980085381) | `ci` verde (19 s); `cd` **falhou** no passo "Entrar na AWS (OIDC, sem senha)": `Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity`, depois de 12 tentativas. O LB continuou na `versao 1`. Correção abaixo. | 1 min 44 s (o `cd` gastou 71 s nas tentativas) |
| Correção do papel: `terraform apply` | `Plan: 0 to add, 1 to change`; só a confiança do papel `santo-projeto-github` mudou | 12 s |
| Push da correção (run 43980594231, já com a `versao 3`) | `ci` e `cd` verdes; `curl` no LB logo em seguida: `versao 3`, dois pods novos; imagem `back:a650479` (7 caracteres do commit) | **60 s** do run (do push ao LB respondendo, ~65 s) |
| ↳ `ci` | lint, build do front e build da imagem | 16 s |
| ↳ `cd` | login OIDC 1 s, build e push amd64 13 s, `kubectl apply` 5 s, `rollout status` 9 s | 39 s |
| `git revert` da `versao 3` e `git push` (run 43980780655) | `ci` e `cd` verdes; LB de volta à `versao 1` logo em seguida, imagem `back:ada5109` | **69 s** do run |
| ↳ `ci` / `cd` | `cd`: build e push 24 s, `apply` 10 s, `rollout` 6 s | 18 s / 46 s |
| Máscara do ID da conta no log público (`gh run view <id> --log`) | o ID da conta aparece **0 vezes** nos três runs com a infra de pé; o registro aparece como `***.dkr.ecr.us-east-1.amazonaws.com` e o papel como `***`. As sequências de 12 dígitos que o `grep -E '[0-9]{12}'` acha (17, 15 e 9) estão todas dentro de hashes `sha256` e SHAs de commit | |
| `scripts/destruir.sh` | LB removido, `Segredo apagado.`, `Destroy complete! Resources: 65 destroyed.`, `nada sobrando`, `saida=0`, `deployment.yaml` restaurado; `gh secret list` vazio | **12 min 5 s** (node group 8 min 18 s, cluster 2 min 41 s, NAT 1 min 12 s) |

No ensaio, o revert foi `git revert 84fa69d` (o hash do commit `versao 3`), porque o commit da correção entrou depois dele. Na aula, sem correção no meio, o `git revert HEAD --no-edit` do Roteiro desfaz a `versao 3`.

### O que falhou e como foi corrigido

1. **O GitHub não conseguia assumir o papel do CD** (`Not authorized to perform sts:AssumeRoleWithWebIdentity`). A confiança do papel esperava o `sub` `repo:Izaiasjun1Dev/santo-projeto:ref:refs/heads/main`, mas este repositório usa o formato imutável do GitHub, com os IDs do dono e do repositório: `repo:Izaiasjun1Dev@44451704/santo-projeto@1460652243:ref:refs/heads/main` (confere-se com `gh api repos/Izaiasjun1Dev/santo-projeto/actions/oidc/customization/sub`, que devolve `"use_immutable_subject": true`). Correção: nova variável `sub_github` (raiz e módulo `cicd`), com o valor `"repo:Izaiasjun1Dev@44451704/santo-projeto@1460652243"` no `envs/aula.tfvars`; a condição do papel virou `"${var.sub_github}:ref:refs/heads/main"`. O módulo `cicd` deixou de receber `repositorio_github`, que continua na raiz porque os scripts a usam para gravar o segredo. Os IDs são do GitHub (públicos), não da AWS. Mantivemos a opção do GitHub ligada em vez de desligá-la, porque ela impede que um repositório recriado com o mesmo nome herde o acesso.
2. **`preparar.sh` falhou uma vez com `Access denied to KMS key`** ao criar o cluster. É uma falha passageira da AWS (a chave recém-criada ainda não estava valendo para o EKS); rodar o `preparar.sh` de novo continuou de onde parou (14 recursos) e deu certo. Nenhum código mudou. Nas duas rodadas anteriores isso não aconteceu.

Nada mais falhou: o workflow, o `destruir.sh` e o `conferir.sh` rodaram sem alteração.

### Custo estimado

Infraestrutura de pé ~40 min (20:10 às 20:51) e LB ~9 min, nos mesmos preços da seção AWS (cerca de US$ 0,27/h com tudo de pé), contando hora cheia para EKS, NAT e LB: **cerca de US$ 0,30**, abaixo de US$ 0,50. O GitHub Actions não cobra em repositório público; as imagens no ECR (alguns MB por poucos minutos) não pesam.

No dia da aula, o bloco de CI/CD não aumenta o custo: usa a infra que já está de pé, e cada push leva ~1 min de pipeline.

## Mudanças para os docs

- **Roteiro › Código: infra › Módulo eks:** o `modules/eks/main.tf` ganhou a linha `kubernetes_version     = "1.37"` logo abaixo de `name`, e `version = "~> 21.0"` virou `version = "21.29.0"`.
- **Roteiro › Código: infra › Módulo rede:** `version = "~> 6.0"` virou `version = "6.7.3"` (o `~> 6.0` do provider aws na raiz continua igual).
- **Roteiro › Preparação:** o `preparar.sh` levou 15 a 17 min (o EKS sozinho, 11 min); "uns 15 minutos" continua valendo, mas vale dizer "15 a 20 minutos". O `destruir.sh` leva ~13 min.
- **Roteiro › Parte 2, passo 2:** o endereço respondeu em 85 a 103 s, menos que os "2 a 3 minutos" do texto; manter a orientação de seguir para o passo 3. O load balancer criado é um Classic Load Balancer, sem configuração extra no cluster (o plano B do `port-forward` não foi necessário na AWS).
- **Roteiro › Parte 2, passo 8:** o comando usava `$REPO`, que não existe no terminal do professor (o `preparar.sh` guarda a URL só no processo dele), e não tinha `--platform`. Trocar por quatro linhas, rodadas na raiz do projeto: `REPO=$(terraform -chdir=infra output -json repositorios | jq -r .back)`, `docker build --platform linux/amd64 -t $REPO:v2 back`, `docker push $REPO:v2` e `kubectl set image deployment/back back=$REPO:v2`. Avisar que o amd64 é obrigatório (Mac ARM, nós x86). No passo 9, lembrar de `git checkout back/app/application/obter_saudacao.py` para voltar à v1. (Já aplicado no Roteiro, rev 47.)
- **Roteiro › Parte 2, passo 9:** o `kubectl rollout undo` (kubectl 1.36) imprime um aviso sobre `last-applied-configuration` porque o deployment foi criado com `kubectl apply`. É inofensivo; vale avisar para ninguém se assustar no projetor.
- **Roteiro › Parte 2, passo 6:** a página do front usa o estilo padrão do navegador e fica pequena no projetor; dar zoom no navegador (Cmd +) antes de clicar.
- **Guia › passo 5:** trocar a frase final por: "O `port-forward` do terminal 3 vai parar de funcionar: o próximo `curl` falha (`Empty reply from server`) e o terminal 3 mostra `error: lost connection to pod`. Aperte Ctrl+C no terminal 3 se ele ainda estiver rodando, rode de novo o passo 3 e veja que agora outro pod responde." O Guia diz "cai junto", mas o processo só sai depois da primeira chamada que falha.
- **Guia › passos 6 e 7:** acrescentar "Se o `curl` falhar de novo (`Empty reply`, ou ficar parado), é o mesmo caso do passo 5: Ctrl+C no terminal 3 e rode o passo 3 outra vez." No passo 7 o `curl` pode dar timeout em vez de erro imediato.
- **Guia › Antes de começar:** depois do `kubectl get nodes`, acrescentar "Se aparecer `NotReady`, espere uns 20 segundos e rode de novo."
- **Guia › passo 2:** acrescentar "No kind só existe um nó, então a coluna `NODE` é igual para todos os pods." (opcional)
- **Guia › Desafio, item 4:** com a imagem já no nó o substituto fica `Running` em menos de 1 s; avisar que o tempo é "alguns segundos". (opcional)
- **Revisão final do CI/CD (Roteiro, já aplicado, rev 80):**
  - **Encerramento:** o bloco do destroy começa com `gh secret delete AWS_PAPEL_CICD --repo Izaiasjun1Dev/santo-projeto`; "dois passos" virou "três passos"; nova linha "Antes do destroy, confira que a aba Actions não tem execução em andamento (amarela)"; a Conferência ganhou "`gh secret list` vazio". Sem isso, todo push depois da aula deixaria a main vermelha.
  - **Preparação:** "Não dê push na main entre o preparar.sh e a Parte 2" (corrigir o repositório antes das 7h30).
  - **Parte 3:** nota de que o rollout troca os 6 pods da Parte 2 (o CD pode levar um pouco mais de 1 min); no passo 6, se entrou commit depois da "versao 3", usar `git revert <hash-da-v3> --no-edit`.
  - **Código › Acréscimos:** os trechos de `infra/variables.tf` e `infra/envs/aula.tfvars` agora batem com os arquivos, com os comentários; "duas linhas e um comentário".
  - **Árvore do projeto (Roteiro e Guia):** entram `.github/workflows/pipeline.yml` ("o pipeline de CI/CD") e `infra/modules/cicd/` ("acesso do GitHub à AWS (OIDC)"). Guia na rev 53.
- **`scripts/destruir.sh`:** o segredo `AWS_PAPEL_CICD` agora é apagado no passo 1/5 (antes dos recursos do Kubernetes e do `terraform destroy`); o `preparar.sh` sugere também `git revert` quando a mensagem não está na versão 1. A ordem do Roteiro (segredo primeiro) já bate com isso.
- **Roteiro › Cronograma (mudança de 16/11, não veio do ensaio):** a aula passou a ser das 08:00 às 12:00, com o mesmo conteúdo e mais prática: 08:00 abertura e ambiente (40 min), 08:40 Parte 1 (30), 09:10 "siga a variável" (20), 09:30 intervalo (15), 09:45 Parte 2 na AWS (40), 10:25 intervalo (15), 10:40 alunos nos sete passos no kind (45), 11:25 desafio (20), 11:45 encerramento com destroy ao vivo (15). Rodar o `preparar.sh` às 7h30; custo do dia ~US$ 1,30 a 1,50.
- **Guia › Desafio:** "em 15 minutos" vira "em 20 minutos".
- **Roteiro › Cronograma (CI/CD):** o bloco de CI/CD entra às 10:40 (25 min): 10:40 CI/CD, 11:05 alunos nos sete passos no kind (30), 11:35 desafio (10), 11:45 encerramento com destroy ao vivo (15). Os blocos anteriores não mudam. Na demo: `git commit -m "versao 3" back/app/application/obter_saudacao.py` (só esse arquivo) e, para desfazer, `git revert HEAD --no-edit && git push`; acompanhar em https://github.com/Izaiasjun1Dev/santo-projeto/actions.
- **Guia › Desafio: 20 → 10 minutos:** o desafio passa a ter 10 minutos (vinha de 20).
- **Roteiro › Código: infra › Módulo cicd (ensaio do CI/CD):** a condição do papel trocou `"repo:${var.repositorio_github}:ref:refs/heads/main"` por `"${var.sub_github}:ref:refs/heads/main"`; o `modules/cicd/variables.tf` trocou `repositorio_github` por `sub_github`; na raiz, o `module "cicd"` passa `sub_github = var.sub_github` (no lugar de `repositorio_github`), o `variables.tf` ganhou `variable "sub_github"` e o `envs/aula.tfvars` ganhou `sub_github = "repo:Izaiasjun1Dev@44451704/santo-projeto@1460652243"`. Se o Roteiro explicar a confiança do papel, dizer que o GitHub identifica o repositório por `dono@id/nome@id` (formato imutável). O CLAUDE.md (linha do módulo `cicd`) também cita a variável `repositorio_github` e deve passar a citar `sub_github`.
- **Roteiro › CI/CD:** do push ao LB respondendo a nova versão levou ~1 min (run de 60 a 69 s: `ci` ~17 s, `cd` ~40 s). Dá tempo de mostrar a aba Actions ao vivo e, logo depois, o `curl`. Se algum commit entrar depois do `versao 3`, o revert precisa do hash dele (`git revert <hash> --no-edit`), não de `HEAD`.
- **Roteiro › Preparação:** se o `preparar.sh` parar com `Access denied to KMS key ... explicit deny policy or revoked grant`, é passageiro: rode o `preparar.sh` de novo (ele continua de onde parou). No ensaio isso custou 2,5 min a mais; começar às 7h30 cobre.
- **Guia › Antes de começar e README (17/11):** novo bloco "Caminho B: instalar o kind no WSL": `docker version` (Client e Server; WSL integration no Docker Desktop), kind v0.33.0 por `curl` de `kind.sigs.k8s.io` + `sudo mv` para `/usr/local/bin`, kubectl pelo instalador oficial se faltar. Não ensaiado num WSL (o ensaio do kind usou o kind do Homebrew no Mac).

## Rodada do professor

Plano B: sua própria rodada gravada, caso a demonstração ao vivo falhe. Ela custa cerca de US$ 0,30 por hora de infraestrutura de pé (uma rodada completa leva ~1 h). Não deixe nada ligado ao terminar.

**Antes de começar**

- [ ] Perfil `default` da AWS com permissão (`aws eks list-clusters --region us-east-1` sem erro) e Docker Desktop aberto.
- [ ] Gravação de tela ligada, terminal com fonte grande.
- [ ] Um segundo terminal reservado para `kubectl get pods -w`.

**Subir (15 a 17 min)**

- [ ] `scripts/preparar.sh`. Espere 15 a 17 min (o EKS sozinho leva ~11 min) e confirme o resumo final com cluster, ECR, bucket e site.

**Parte 1: Terraform** (na pasta `infra/`)

- [ ] `cd infra`.
- [ ] Mostre a árvore e siga `repositorios` de `envs/aula.tfvars` até `modules/ecr`.
- [ ] `terraform plan -var-file=envs/aula.tfvars` (`No changes.`) e `terraform output`.
- [ ] Edite o `.tfvars` para `repositorios = ["back", "teste-aluno"]`, rode `plan` (`1 to add`) e `terraform apply -var-file=envs/aula.tfvars` (segundos). Mostre o repositório novo no console do ECR.
- [ ] Desfaça com `git checkout envs/aula.tfvars` e rode o `apply` de novo (`1 destroyed`).
- [ ] `cd ..` para voltar à raiz do projeto.

**Parte 2: Kubernetes e front** (na raiz do projeto, `kubectl get pods -w` no outro terminal)

- [ ] `kubectl apply -f back/k8s/` e `kubectl get service back`. O endereço respondeu em 85 a 103 s; siga para o próximo passo enquanto isso.
- [ ] `kubectl scale deployment back --replicas=6` e `kubectl get pods -o wide`.
- [ ] `curl http://ENDERECO/api/saudacao` em laço: aparecem vários nomes de pod.
- [ ] `cd front && npm install && VITE_API_URL=http://ENDERECO npm run build`.
- [ ] `aws s3 sync dist/ s3://$(terraform -chdir=../infra output -raw bucket_site) --delete`, e abra a `url_site`. Dê zoom no navegador (Cmd +) antes de clicar em "Chamar a API". O navegador reaproveita a conexão e pode repetir o pod; use o `curl` em laço para mostrar a distribuição.
- [ ] `kubectl delete pod NOME-DO-POD` (o que apareceu na página): o substituto nasce em ~4 s.
- [ ] Versão 2 (volte para a raiz do projeto com `cd ..`, se ainda estiver em `front/`): mude a mensagem em `back/app/application/obter_saudacao.py` e rode:

  ```bash
  REPO=$(terraform -chdir=infra output -json repositorios | jq -r .back)
  docker build --platform linux/amd64 -t $REPO:v2 back
  docker push $REPO:v2
  kubectl set image deployment/back back=$REPO:v2
  ```

  O `--platform linux/amd64` é obrigatório: seu Mac é ARM e os nós do EKS são x86; sem ele os pods dão `exec format error` ou `ImagePullBackOff`. O login no ECR feito pelo `preparar.sh` vale ~12 h; se a sessão for longa, refaça: `aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${REPO%%/*}"`. A troca leva ~25 s; clique na página durante ela. Depois, `git checkout back/app/application/obter_saudacao.py`.
- [ ] `kubectl rollout undo deployment/back` (o aviso sobre `last-applied-configuration` é inofensivo).

**Destruir (~13 min)**

- [ ] `scripts/destruir.sh`. Espere ~13 min; ele apaga o load balancer antes do `terraform destroy`.

**Conferir no fim**

- [ ] `scripts/conferir.sh` termina com `nada sobrando` e saída 0.
- [ ] `git status` limpo: `back/k8s/deployment.yaml` voltou ao placeholder `URL-DO-REPOSITORIO` e `infra/envs/aula.tfvars` está como no repositório.

**Se algo der errado**

- Chrome mostrando página de erro no site HTTP do S3: verifique "Sempre usar conexões seguras" (modo somente HTTPS) nas configurações do navegador. Aconteceu uma vez no ensaio; o `curl` na `url_site` confirma que o site responde.
- Travou e sem correção em cerca de 30 min: rode `scripts/destruir.sh` e depois `scripts/conferir.sh`.
