#!/usr/bin/env bash
# Prepara tudo para a aula: infraestrutura, imagem back:v1 e kubeconfig.
# Rode a partir de qualquer pasta; o script entra na raiz do repositório.
set -euo pipefail

cd "$(dirname "$0")/.."
export AWS_PROFILE="${AWS_PROFILE:-default}"
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1

INICIO=$(date +%s)
TF="terraform -chdir=infra"

# Repositório do GitHub (dono/nome), lido de infra/envs/aula.tfvars
REPO_GITHUB=$(grep '^repositorio_github' infra/envs/aula.tfvars 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' || true)
REPO_GITHUB=${REPO_GITHUB:-Izaiasjun1Dev/santo-projeto}

# 1. Ferramentas e identidade AWS (a conta e o usuário não são impressos)
echo "==> 1/7 Conferindo ferramentas e credenciais AWS"
for ferramenta in aws terraform kubectl docker jq node gh; do
  command -v "$ferramenta" >/dev/null 2>&1 || { echo "Falta instalar: $ferramenta" >&2; exit 1; }
done
aws sts get-caller-identity --query Account --output text >/dev/null \
  || { echo "Credenciais AWS inválidas para o perfil $AWS_PROFILE" >&2; exit 1; }
docker info >/dev/null 2>&1 \
  || { echo "Abra o Docker Desktop e rode de novo." >&2; exit 1; }
grep -q "versao 1" back/app/application/obter_saudacao.py \
  || { echo "A mensagem não está na versão 1; rode git checkout back/app/application/obter_saudacao.py (ou git revert do commit da versão 3)" >&2; exit 1; }
gh auth status --hostname github.com >/dev/null 2>&1 \
  || { echo "O gh não está logado; rode: gh auth login" >&2; exit 1; }
echo "Ferramentas, Docker, gh e credenciais OK."

# 2. Infraestrutura (leva uns 15 minutos por causa do EKS)
echo "==> 2/7 Terraform init e apply"
$TF init -input=false
$TF apply -auto-approve -input=false -var-file=envs/aula.tfvars

NOME_CLUSTER=$($TF output -raw nome_cluster)
URL_ECR=$($TF output -json repositorios | jq -r '.back')

# 3. Liga o CD: grava o ARN do papel como segredo do repositório (o ARN não é impresso)
echo "==> 3/7 Gravando o segredo AWS_PAPEL_CICD no GitHub"
CD_LIGADO="CD desligado (segredo não gravado)"
PAPEL=$($TF output -raw papel_cicd 2>/dev/null || true)
if [ -z "$PAPEL" ]; then
  echo "AVISO: saída papel_cicd vazia; CD desligado." >&2
elif gh secret set AWS_PAPEL_CICD --repo "$REPO_GITHUB" --body "$PAPEL" </dev/null >/dev/null 2>&1; then
  CD_LIGADO="CD ligado"
else
  echo "AVISO: não consegui gravar o segredo. Grave à mão:" >&2
  echo "  gh secret set AWS_PAPEL_CICD --repo $REPO_GITHUB --body \"\$(terraform -chdir=infra output -raw papel_cicd)\"" >&2
fi

# 4. Imagem back:v1 para amd64 (os nós do EKS são amd64; o Mac é arm64)
echo "==> 4/7 Login no ECR, build e push de back:v1"
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "${URL_ECR%%/*}"
docker build --platform linux/amd64 -t "$URL_ECR:v1" back
docker push "$URL_ECR:v1"

# 5. kubeconfig e espera pelos nós
echo "==> 5/7 Configurando o kubectl e esperando os nós"
aws eks update-kubeconfig --name "$NOME_CLUSTER" --region us-east-1
# Os nós demoram a aparecer; sem esperar, o "kubectl wait" falha com
# "no matching resources found".
LIMITE=$(( $(date +%s) + 600 ))
while [ -z "$(kubectl get nodes -o name 2>/dev/null || true)" ]; do
  if [ "$(date +%s)" -ge "$LIMITE" ]; then
    echo "Nenhum nó apareceu em 10 min. Confira o node group no console do EKS." >&2
    exit 1
  fi
  echo "Esperando os nós aparecerem..."
  sleep 15
done
kubectl wait --for=condition=Ready nodes --all --timeout=10m

# 6. Aponta o deployment para a imagem no ECR (só troca o placeholder;
#    se a URL já estiver lá, nada muda). Não versionar esta alteração.
echo "==> 6/7 Ajustando back/k8s/deployment.yaml"
sed -i '' "s|URL-DO-REPOSITORIO|$URL_ECR|g" back/k8s/deployment.yaml

# 7. Resumo
echo "==> 7/7 Resumo"
echo "Cluster:  $NOME_CLUSTER"
echo "ECR back: $URL_ECR"
echo "Deploy:   $CD_LIGADO"
# bucket_site e url_site só existem se o módulo "site" estiver ativo
SAIDAS=$($TF output -json)
BUCKET=$(echo "$SAIDAS" | jq -r '.bucket_site.value // empty')
URL_SITE=$(echo "$SAIDAS" | jq -r '.url_site.value // empty')
[ -z "$BUCKET" ] || echo "Bucket:   $BUCKET"
[ -z "$URL_SITE" ] || echo "Site:     $URL_SITE"

FIM=$(date +%s)
echo "Tempo total: $(( (FIM - INICIO) / 60 )) min $(( (FIM - INICIO) % 60 )) s"
