# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este repositório

Projeto didático de uma aula das 8h às 12h (quarta, 18/11/2026; o conteúdo é o de uma aula de 90 minutos, com mais tempo de prática) sobre AWS, Terraform e Kubernetes, para alunos iniciantes. O professor (dono do repositório) demonstra ao vivo, e os alunos clonam o repositório (público no GitHub como `santo-projeto`) e sobem a API num cluster próprio (kind no WSL ou Killercoda).

Estado atual: em construção, conforme o plano. Antes de mexer em qualquer coisa, leia:
- `docs/superpowers/specs/2026-11-16-aula-infra-design.md`: a spec aprovada (o que construir e o que não construir).
- `docs/superpowers/plans/2026-11-16-aula-infra.md`: o plano, tarefa por tarefa.
- `docs/superpowers/specs/2026-11-16-aula-infra-roteiro-referencia.md`: o código-base de todas as pastas.
- `docs/superpowers/specs/2026-11-16-aula-cicd-design.md`: o bloco de CI/CD (pipeline) da aula.
- `docs/ensaio.md` (quando existir): resultados do ensaio, tempos e a seção "Mudanças para os docs".

## O código precisa bater com dois docs externos

Os alunos e o professor seguem dois docs do Claude Docs, não este repositório:
- **Roteiro da demonstração** (professor): https://claude.ai/artifact/KksVhYknkS6PcgKDuoxqzS
- **Guia do participante** (alunos): https://claude.ai/artifact/84trFcnbNVicMbhbnDAq7n

Qualquer mudança em nome de pasta, comando, porta, rota, mensagem ou output do Terraform precisa ser anotada em `docs/ensaio.md` › "Mudanças para os docs" e levada para o doc correspondente, editado pelo conector Claude Docs.

Também precisam continuar de pé:
- o exercício "siga a variável" do Guia, que acompanha `repositorios` em `envs/aula.tfvars` → `variables.tf` → `main.tf` → `modules/ecr/{variables,main,outputs}.tf` → `outputs.tf`;
- o fato de a mensagem da API ficar em `back/app/application/obter_saudacao.py`.

## Arquitetura (visão geral)

- **`infra/`:** uma raiz Terraform que só chama módulos (`rede`, `ecr`, `eks`, `site`, `cicd`) e um `.tfvars` por ambiente (só existe `envs/aula.tfvars`). O estado fica local, de propósito: a aula mostra o `terraform.tfstate`. As tags `Projeto=santo-projeto` vêm via `default_tags`, e o `scripts/conferir.sh` depende delas.
- **`back/`:** API FastAPI em Clean Architecture, com as dependências apontando para dentro:
  - `presentation` e `infrastructure` → `application` → `domain`;
  - `main.py` monta tudo;
  - a rota `GET /api/saudacao` devolve `{mensagem, servidor}`, e `servidor` é o hostname, ou seja, o nome do pod;
  - `GET /health` serve para a readiness probe;
  - a porta é 8000.
- **`front/`:** React com Vite nas mesmas quatro camadas. A URL da API entra por `VITE_API_URL` no build, e o resultado é publicado no bucket S3 (site estático em HTTP).
- **`.github/workflows/pipeline.yml`** (workflow "Pipeline"): roda em todo push na `main` (e manualmente).
  - job `ci`: lint e build do front e build da imagem do back;
  - job `cd`: autentica por OIDC (sem chave de acesso guardada), faz build `linux/amd64` e push no ECR com a tag do SHA do commit (7 caracteres), `aws eks update-kubeconfig`, troca a linha `image:` do `back/k8s/deployment.yaml` com `sed` (só dentro do runner), `kubectl apply -f back/k8s/` e `kubectl rollout status deployment/back --timeout=5m`;
  - o módulo `infra/modules/cicd` cria o provedor OIDC, o papel IAM `santo-projeto-github` (só pode ser assumido a partir de `refs/heads/main` do repositório, conforme o `sub` imutável da variável `sub_github`; uma execução manual em outra branch falha no login da AWS) e o acesso ao cluster (`AmazonEKSEditPolicy` no namespace `default`); variáveis `sub_github` (confiança do papel) e `repositorio_github` (só os scripts a usam, para gravar e apagar o segredo), saída `papel_cicd`;
  - se o repositório for renomeado ou recriado, atualize `sub_github` em `envs/aula.tfvars` (os IDs mudam). Para achar o valor: a linha de erro do `AssumeRoleWithWebIdentity` no log do `cd`, ou `gh api repos/DONO/REPO --jq .id` e `gh api users/DONO --jq .id`, montando `repo:DONO@ID_DONO/REPO@ID_REPO`;
  - o segredo `AWS_PAPEL_CICD` é criado pelo `preparar.sh` e apagado pelo `destruir.sh`; sem ele o `cd` imprime "Infra desligada: deploy pulado" e termina verde.
- **`scripts/`** (bash, só macOS):
  - `preparar.sh`: `terraform apply`, push da `back:v1` (amd64) para o ECR, kubeconfig, e troca do placeholder `URL-DO-REPOSITORIO` em `back/k8s/deployment.yaml`, que não deve ser commitada com a URL real.
  - `publicar-imagens.sh`: `v1` e `v2` multi-arquitetura no GHCR e uma cópia de `kindest/node`.
  - `destruir.sh`: primeiro o segredo do CD, depois os recursos k8s (para o load balancer não ficar órfão), depois o `terraform destroy`, e restaura o placeholder.
  - `preparar.sh` também grava o segredo `AWS_PAPEL_CICD` (gh) e o `destruir.sh` o apaga como primeiro passo, antes de tudo.
  - `conferir.sh`: só lê; sai com 1 se sobrou recurso do projeto.

## Imagens

| Imagem | Destino | Arquitetura |
|---|---|---|
| Para o EKS | ECR (`terraform output repositorios` → `.back`) | `linux/amd64`, obrigatoriamente: o Mac do professor é ARM e os nós do EKS são x86 |
| Para os alunos | `ghcr.io/$GITHUB_USER/santo-projeto-back:v1`/`:v2` | amd64 e arm64 |

- A `v2` difere da `v1` só na mensagem (`versao 2`) e é gerada a partir de uma cópia temporária; o repositório fica sempre na `v1`.
- O GHCR foi escolhido em vez do Docker Hub por causa do limite de downloads anônimos por IP no laboratório.

## Comandos

```bash
# back (o Python local é 3.9; use o Docker, a imagem é 3.12)
docker build -t santo-back:local back && docker run --rm -p 8000:8000 santo-back:local
curl -s localhost:8000/api/saudacao

# front
cd front && npm install && npm run lint
VITE_API_URL=http://localhost:8000 npm run dev      # ou npm run build → dist/

# infra (sem custo)
cd infra && terraform fmt -recursive -check && terraform init -backend=false && terraform validate

# AWS (com custo; perfil default, us-east-1)
scripts/preparar.sh
scripts/destruir.sh        # sempre ao terminar; termina chamando conferir.sh
scripts/conferir.sh

# pipeline (demo da aula): só o arquivo da mensagem
git commit -m "versao 3" back/app/application/obter_saudacao.py && git push
git revert HEAD --no-edit && git push     # desfaz
# acompanhar: https://github.com/Izaiasjun1Dev/santo-projeto/actions

# imagens públicas (pede GITHUB_USER e GITHUB_TOKEN com write:packages no ambiente)
scripts/publicar-imagens.sh
```

Não há suíte de testes automatizados (não objetivo da spec). A verificação é o ensaio: os comandos e as saídas esperadas estão em cada tarefa do plano.

## Regras deste projeto

- **Infraestrutura na AWS nunca fica de pé sem acompanhamento.** O EKS, o NAT e o load balancer cobram por hora. Se travar e não houver correção em cerca de 30 minutos, rode `scripts/destruir.sh` e confira com `scripts/conferir.sh`.
- **Na demo do pipeline, commite só o arquivo da mensagem:** `git commit -m "versao 3" back/app/application/obter_saudacao.py`. Nunca `git commit -am`: depois do `preparar.sh` o `back/k8s/deployment.yaml` tem a URL real do ECR, com o ID da conta.
- **Nunca desligue o bloqueio de acesso público do S3 da conta.** Se ele estiver ligado, o módulo `site` sai e o front roda local (decisão do professor).
- **O ID da conta AWS nunca entra em arquivo versionado,** porque o repositório é público. Na tela ele pode aparecer.
- **Os alunos usam Windows com WSL.** Comandos destinados a eles devem funcionar no bash do WSL.
- **O código precisa continuar legível no projetor, para iniciantes.** Não acrescente abstrações, ferramentas ou camadas que eles teriam de entender.
