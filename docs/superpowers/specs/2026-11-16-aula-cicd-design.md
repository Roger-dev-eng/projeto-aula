# CI/CD na aula: push no main → deploy no EKS — Design

Data: 16/11/2026. Aula: quarta, 18/11/2026, 08:00–12:00. Complementa `2026-11-16-aula-infra-design.md` (que continua valendo; esta spec só acrescenta).

## 1. Intenção

O professor quer acrescentar um bloco de CI/CD à aula. A turma assiste a um ciclo completo sem ninguém tocar no cluster: o professor muda a mensagem da API para a versão 3, faz `git push` no `main`, o GitHub Actions testa, constrói a imagem, publica no ECR e faz o deploy no EKS, e a página do front passa a mostrar "versao 3". Em seguida ele desfaz com `git revert` + `git push`, e o mesmo pipeline devolve a versão 1. É a versão automatizada do que a Parte 2 fez à mão (`docker build`/`push`/`kubectl set image`).

## 2. Objetivos

- Todo push no `main` do repositório `Izaiasjun1Dev/santo-projeto` dispara o pipeline (decisão do professor).
- **CI** (sempre): lint e build do front; build da imagem do back.
- **CD** (só quando a infra da aula está de pé): build `linux/amd64`, push no ECR com a tag do commit, deploy no EKS e espera do rollout.
- Fora do dia da aula (infra destruída), o push continua verde: o CD é pulado com uma mensagem clara ("infra desligada: deploy pulado").
- O acesso do GitHub à AWS é criado e destruído pelo Terraform da aula, como todo o resto. Depois do `destruir.sh`, o `conferir.sh` continua dizendo "nada sobrando".
- Reverter é parte da demonstração: `git revert` + `git push` faz o pipeline voltar a v1, e o `main` termina a aula na v1.

## 3. Não objetivos

- Alunos não rodam pipeline (sem fork, sem conta AWS para eles). O Guia só ganha "o que observar".
- Sem deploy do front pelo pipeline (o front no S3 continua manual na Parte 2).
- Sem ambientes múltiplos, aprovação manual, testes automatizados do back (continua sem suíte de testes) ou pipeline de Terraform.
- O `publicar-imagens.sh` (GHCR, para os alunos) continua manual e não muda.

## 4. Anti-objetivos (falha mesmo que funcione)

- Chave de acesso AWS de longa duração em segredo do GitHub. O acesso é só por OIDC com papel IAM temporário.
- ID da conta AWS aparecendo nos logs públicos do Actions (o repositório é público) ou em arquivo versionado.
- ✗ vermelho no `main` nos dias sem aula por causa do deploy.
- Recurso IAM sobrando na conta depois do `destruir.sh`.
- Um workflow que iniciante não consegue ler no projetor: um arquivo, dois jobs, passos com nomes em português, sem ações de terceiros além das oficiais (`actions/*`, `aws-actions/*`).

## 5. Abordagens consideradas

- **A (escolhida):** OIDC + papel IAM num módulo Terraform novo; o `preparar.sh` grava o ARN do papel como segredo do repositório (`gh secret set`) e o `destruir.sh` o apaga; o workflow pula o CD quando o segredo não existe. Nada fica na conta, sem chave longa, e o módulo reforça o "siga a variável". Custo: um módulo e duas linhas nos scripts.
- **B:** papel IAM permanente fora do Terraform da aula, e o workflow checa se o cluster existe. Rejeitada: recurso permanente na conta, exceção no `conferir.sh`, e a turma não vê como o acesso nasce.
- **C:** chave de acesso de usuário IAM como segredo. Rejeitada: ensina a prática que a AWS desaconselha e não some com o destroy.

## 6. Desenho

### 6.1 Terraform

- Novo módulo `infra/modules/cicd/` com `main.tf`, `variables.tf` e `outputs.tf` (mesmo formato dos outros), chamado da raiz.
  - `aws_iam_openid_connect_provider` para `https://token.actions.githubusercontent.com`, audiência `sts.amazonaws.com`. (A conta hoje não tem nenhum provedor OIDC; o Terraform cria e destrói.)
  - `aws_iam_role` com nome derivado do projeto (ex.: `santo-projeto-github`), confiança só para o `sub` que o token do GitHub realmente carrega (formato imutável, `repo:<dono>@<id>/<repo>@<id>:ref:refs/heads/main`, guardado na variável `sub_github`), com `aud = sts.amazonaws.com`.
  - Atualização de 16/11 (ensaio): o GitHub emite o token deste repositório com o `sub` imutável (IDs numéricos), então o `sub` simples `repo:Izaiasjun1Dev/santo-projeto:...` era recusado no `AssumeRoleWithWebIdentity`.
  - Política do papel: `ecr:GetAuthorizationToken` (recurso `*`), as ações de push só no repositório ECR `back`, e `eks:DescribeCluster` no cluster da aula.
  - Acesso ao Kubernetes por **EKS access entry** (`aws_eks_access_entry` + `aws_eks_access_policy_association` com `AmazonEKSEditPolicy`, escopo namespace `default`). Fica no módulo `cicd`, que recebe o nome do cluster do módulo `eks` (assim não há dependência circular).
  - Saída: `arn_papel`.
- Raiz: nova variável `repositorio_github` (`"Izaiasjun1Dev/santo-projeto"` no `envs/aula.tfvars`), usada pelos scripts (o módulo recebe `sub_github`, não ela); nova variável `sub_github` (`"repo:Izaiasjun1Dev@44451704/santo-projeto@1460652243"`); nova saída `papel_cicd`. As tags `Projeto` vêm do `default_tags`, como o resto.
- O módulo `ecr` pode ganhar uma saída `arns` se o `cicd` precisar do ARN do repositório (escolha do construtor).
- O exercício "siga a variável" (`repositorios`) não muda.

### 6.2 Workflow `.github/workflows/pipeline.yml`

- Nome legível ("Pipeline"); gatilhos: `push` em `main` e `workflow_dispatch`.
- Job `ci` (ubuntu): checkout; front com Node (versão do projeto) `npm ci`, `npm run lint`, `npm run build`; back `docker build back`.
- Job `cd` (`needs: ci`), com `permissions: id-token: write, contents: read`:
  - O ARN do papel vem do segredo `AWS_PAPEL_CICD`. Primeiro passo: se o segredo estiver vazio, imprime "Infra desligada: deploy pulado" e os passos seguintes são pulados (o job termina verde).
  - `aws-actions/configure-aws-credentials` com `role-to-assume` e região `us-east-1`, mascarando o ID da conta (`mask-aws-account-id: true`).
  - Login no ECR; `docker build --platform linux/amd64`; push com a tag dos 7 primeiros caracteres do commit.
  - `aws eks update-kubeconfig`; troca da linha `image:` do contêiner `back` no `back/k8s/deployment.yaml` (só na cópia do runner) pela imagem nova, aceitando tanto o placeholder `URL-DO-REPOSITORIO:v1` quanto uma URL real; `kubectl apply -f back/k8s/`; `kubectl rollout status deployment/back --timeout=5m`.
  - `apply` (e não só `set image`) para funcionar mesmo se o deployment ainda não existir.
- Versões das ações fixadas por tag de versão maior.

### 6.3 Scripts

- `preparar.sh`: exige `gh` logado (na checagem de ferramentas); depois do `apply`, `gh secret set AWS_PAPEL_CICD` com a saída `papel_cicd`, no repositório de `repositorio_github`. O ARN não é impresso. Se o `gh secret set` falhar, o script **continua** (a infra já está de pé e cobrando) e imprime um aviso com o comando para rodar à mão; sem o segredo, o CD só fica pulado.
- `destruir.sh`: antes do `terraform destroy`, `gh secret delete AWS_PAPEL_CICD`, para um push durante o destroy já pular o CD. Se falhar (segredo inexistente, `gh` sem login), só avisa e o destroy segue.
- `conferir.sh`: passa a listar também papel IAM do projeto e provedor OIDC do GitHub com a tag `Projeto=santo-projeto` (IAM é global).
- A guarda "mensagem na versão 1" do `preparar.sh` continua: se o professor esquecer o revert, o próximo `preparar.sh` avisa.

### 6.4 Aula (Roteiro e Guia)

- Cronograma: 10:40 CI/CD (25 min), 11:05 sete passos no kind (30), 11:35 desafio (10), 11:45 encerramento com destroy (15).
- Roteiro, bloco CI/CD: mostrar o `pipeline.yml` no projetor (CI × CD, OIDC sem senha); mudar a mensagem para "versao 3", commitar **só esse arquivo** (`git commit -m "versao 3" back/app/application/obter_saudacao.py`, porque o `deployment.yaml` está com a URL real do ECR depois do `preparar.sh` e não pode ir para o repositório público) e `git push`; abrir a aba Actions; recarregar a página do front até aparecer v3; `git revert HEAD --no-edit` + `git push`; ver o pipeline voltar a v1. Plano B se o Actions demorar ou falhar: o mesmo resultado à mão, como na Parte 2.
- Guia: um bloco curto "CI/CD: o que observar" (o que dispara o pipeline, o que é CI e o que é CD, por que não há senha da AWS no GitHub, link para a aba Actions do repositório).
- `CLAUDE.md`, README e a spec da aula: CI deixa de ser não objetivo do repositório nesse sentido; registrar o pipeline.

## 7. Fatos já conferidos (16/11)

- A conta AWS não tem nenhum provedor OIDC; o Terraform cria o do GitHub sem conflito.
- O repositório `Izaiasjun1Dev/santo-projeto` existe, é público, com `main` como branch padrão.
- O `gh` do Mac do professor está logado como `Izaiasjun1Dev` com escopo `repo`, que permite gravar segredos do Actions.
- O repositório ECR `back` é mutável e sem política de ciclo de vida; tags por commit não conflitam.
- `AmazonEKSEditPolicy` no namespace `default` cobre criar e alterar Deployment e Service (inclusive do tipo LoadBalancer).

## 8. Restrições

- Repositório público: nada de ID de conta em arquivo versionado; conferir os logs públicos do Actions no ensaio.
- O `main` termina a aula e o ensaio na v1.
- Scripts bash 3.2/macOS; código legível para iniciantes.
- Infra na AWS nunca sem acompanhamento; regra dos 30 minutos.
- Prazo: pronto e ensaiado até terça, 17/11.

## 9. Ensaio

Uma rodada na AWS (~60–70 min, < US$ 1): `preparar.sh` → Parte 2 mínima (`kubectl apply`) → push da v3 no `main` → Actions verde → load balancer responde v3 → revert + push → v1 → `destruir.sh` → um push qualquer no `main` com a infra desligada → Actions verde com "deploy pulado" → `conferir.sh` "nada sobrando". Conferir nos logs públicos que o ID da conta aparece mascarado. Como o gatilho é só o `main`, o código precisa estar no `main` antes do ensaio: o construtor decide a ordem (ex.: revisão estática → merge → ensaio → correções).

## 10. Deixado ao construtor

Nomes exatos do papel e da política, formato da checagem do segredo vazio no workflow, versão do Node no CI, se o `ecr` ganha saída `arns`, texto exato do Roteiro e do Guia.
