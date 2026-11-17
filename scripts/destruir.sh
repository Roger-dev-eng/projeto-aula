#!/usr/bin/env bash
# Desfaz tudo que o preparar.sh e a aula criaram, na ordem certa.
# Pode ser rodado de novo sem problema.
set -euo pipefail

cd "$(dirname "$0")/.."
export AWS_PROFILE="${AWS_PROFILE:-default}"
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1

TF="terraform -chdir=infra"

# Repositório do GitHub (dono/nome), lido de infra/envs/aula.tfvars
REPO_GITHUB=$(grep '^repositorio_github' infra/envs/aula.tfvars 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' || true)
REPO_GITHUB=${REPO_GITHUB:-Izaiasjun1Dev/santo-projeto}

# O init é necessário numa cópia nova do repositório
if [ ! -d infra/.terraform ]; then
  echo "==> terraform init"
  $TF init -input=false
fi

# Nome do cluster: do Terraform, ou o padrão se o estado estiver vazio
NOME_CLUSTER=$($TF output -raw nome_cluster 2>/dev/null || true)
NOME_CLUSTER=${NOME_CLUSTER:-santo-projeto}

# 1. Desliga o CD: apaga o segredo, para o deploy não apontar para um papel que vai sumir
echo "==> 1/5 Apagando o segredo AWS_PAPEL_CICD do GitHub"
if command -v gh >/dev/null 2>&1 \
   && gh secret delete AWS_PAPEL_CICD --repo "$REPO_GITHUB" >/dev/null 2>&1; then
  echo "Segredo apagado."
else
  echo "AVISO: não apaguei o segredo (já não existia, ou o gh não está logado); seguindo." >&2
fi

# 2. Remove o Service/Deployment antes: o load balancer criado pelo
#    Kubernetes não é do Terraform e travaria a remoção da VPC.
echo "==> 2/5 Removendo a aplicação do cluster $NOME_CLUSTER"
if aws eks describe-cluster --name "$NOME_CLUSTER" --region us-east-1 >/dev/null 2>&1; then
  if aws eks update-kubeconfig --name "$NOME_CLUSTER" --region us-east-1 >/dev/null 2>&1 \
     && kubectl delete -f back/k8s/ --ignore-not-found --timeout=5m; then
    echo "Esperando o load balancer sumir (até 5 min)..."
    LIMITE=$(( $(date +%s) + 300 ))
    while :; do
      QTD=$(aws resourcegroupstaggingapi get-resources --region us-east-1 \
        --resource-type-filters elasticloadbalancing:loadbalancer \
        --tag-filters "Key=kubernetes.io/cluster/$NOME_CLUSTER" \
        --query 'length(ResourceTagMappingList)' --output text 2>/dev/null || echo "?")
      [ "$QTD" = "0" ] && { echo "Load balancer removido."; break; }
      if [ "$(date +%s)" -ge "$LIMITE" ]; then
        echo "AVISO: o load balancer ainda existe após 5 min; seguindo mesmo assim." >&2
        break
      fi
      sleep 15
    done
  else
    echo "AVISO: não consegui apagar os recursos do Kubernetes; seguindo." >&2
  fi
else
  echo "AVISO: cluster $NOME_CLUSTER não encontrado ou inacessível; pulando o kubectl." >&2
fi

# 3. Infraestrutura
echo "==> 3/5 terraform destroy"
$TF destroy -auto-approve -input=false -var-file=envs/aula.tfvars

# 4. Devolve o placeholder ao deployment.yaml
echo "==> 4/5 Restaurando back/k8s/deployment.yaml"
git checkout -- back/k8s/deployment.yaml \
  || echo "AVISO: não consegui restaurar o deployment.yaml; troque a URL por URL-DO-REPOSITORIO." >&2

# 5. Confere o que sobrou (o código de saída é o do conferir.sh)
echo "==> 5/5 Conferindo o que sobrou"
exec scripts/conferir.sh
