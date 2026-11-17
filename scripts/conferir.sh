#!/bin/bash
# Confere se sobrou algo do projeto na conta (somente leitura: describe/list/get).
# Saída: 0 = nada sobrando, 1 = sobrou algo do projeto, 2 = uma checagem falhou.
# Compatível com o bash 3.2 do macOS. Nunca imprime credenciais.

set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "falha: jq não está instalado" >&2; exit 2; }
command -v aws >/dev/null 2>&1 || { echo "falha: aws cli não está instalado" >&2; exit 2; }

REGIAO="us-east-1"
PROJETO="santo-projeto"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TFVARS="$RAIZ/infra/envs/aula.tfvars"

ERRO="$(mktemp)"
trap 'rm -f "$ERRO"' EXIT

# chamar <checagem> <comando aws...>: guarda o JSON em $R; se falhar, sai com 2.
chamar() {
  local nome="$1"
  shift
  R="$(aws --region "$REGIAO" --output json "$@" 2>"$ERRO" </dev/null)" || {
    echo "falha na checagem: $nome" >&2
    head -n 1 "$ERRO" >&2
    exit 2
  }
  [ -n "$R" ] || R='{}'
}

# processar <checagem> <args do jq...>: roda o jq sobre $R, guarda em $J; se falhar, sai com 2.
processar() {
  local nome="$1"
  shift
  J="$(printf '%s' "$R" | jq -r "$@" 2>"$ERRO")" || {
    echo "falha ao processar: $nome" >&2
    head -n 1 "$ERRO" >&2
    exit 2
  }
}

PROJ=""    # sobras do projeto, uma por linha
OUTROS=""  # recursos sem a marca do projeto, uma por linha

# registrar: lê linhas "P<TAB>texto" ou "O<TAB>texto" do stdin.
registrar() {
  local tipo texto
  while IFS=$'\t' read -r tipo texto; do
    [ -n "$texto" ] || continue
    if [ "$tipo" = "P" ]; then
      PROJ="$PROJ$texto"$'\n'
    else
      OUTROS="$OUTROS$texto"$'\n'
    fi
  done
}

# Funções jq usadas em várias checagens.
DEFS='
def tem($k): (.Tags // []) | any(.Key == $k);
def tag($k): ((.Tags // []) | map(select(.Key == $k)) | .[0].Value) // "";
def doprojeto: (tag("Projeto") == $projeto) or tem("kubernetes.io/cluster/" + $projeto);
def emvpc($v): (($v // "") != "") and (($vpcs | split("\n") | index($v)) != null);
'

# Repositórios ECR do projeto, lidos de infra/envs/aula.tfvars.
[ -f "$TFVARS" ] || { echo "falha: não achei $TFVARS" >&2; exit 2; }
REPOS="$(grep '^repositorios' "$TFVARS" | grep -o '"[^"]*"' | tr -d '"')"
[ -n "$REPOS" ] || { echo "falha: sem 'repositorios' em $TFVARS" >&2; exit 2; }

# VPCs do projeto (para NAT, EIP, instâncias e load balancers sem tag).
chamar "ec2 describe-vpcs" ec2 describe-vpcs --filters "Name=tag:Projeto,Values=$PROJETO"
processar "vpcs" '.Vpcs[].VpcId'
VPCS="$J"

# EC2 não terminadas.
chamar "ec2 describe-instances" ec2 describe-instances \
  --filters "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down"
processar "instâncias ec2" --arg projeto "$PROJETO" --arg vpcs "$VPCS" "$DEFS"'
  .Reservations[].Instances[]
  | (doprojeto or emvpc(.VpcId)) as $p
  | (if $p then "P" else "O" end) + "\tec2: " + .InstanceId
    + (if tag("Name") != "" then " (" + tag("Name") + ")" else "" end)'
registrar <<< "$J"

# Load balancers v2 (ALB/NLB).
chamar "elbv2 describe-load-balancers" elbv2 describe-load-balancers
processar "lista de load balancers v2" '.LoadBalancers[] | [.LoadBalancerArn, .LoadBalancerName, (.VpcId // "")] | @tsv'
LBS="$J"
while IFS=$'\t' read -r arn nome vpc; do
  [ -n "$arn" ] || continue
  chamar "elbv2 describe-tags ($nome)" elbv2 describe-tags --resource-arns "$arn"
  processar "tags de $nome" --arg projeto "$PROJETO" --arg vpcs "$VPCS" --arg vpc "$vpc" "$DEFS"'
    (.TagDescriptions[0] // {}) | if doprojeto or emvpc($vpc) then "P" else "O" end'
  registrar <<< "$J"$'\t'"load balancer v2: $nome"
done <<< "$LBS"

# Load balancers clássicos.
chamar "elb describe-load-balancers" elb describe-load-balancers
processar "lista de load balancers clássicos" '.LoadBalancerDescriptions[] | [.LoadBalancerName, (.VPCId // "")] | @tsv'
LBS="$J"
while IFS=$'\t' read -r nome vpc; do
  [ -n "$nome" ] || continue
  chamar "elb describe-tags ($nome)" elb describe-tags --load-balancer-names "$nome"
  processar "tags de $nome" --arg projeto "$PROJETO" --arg vpcs "$VPCS" --arg vpc "$vpc" "$DEFS"'
    (.TagDescriptions[0] // {}) | if doprojeto or emvpc($vpc) then "P" else "O" end'
  registrar <<< "$J"$'\t'"load balancer clássico: $nome"
done <<< "$LBS"

# NAT Gateways não deleted.
chamar "ec2 describe-nat-gateways" ec2 describe-nat-gateways \
  --filter "Name=state,Values=pending,available,deleting,failed"
processar "nat gateways" --arg projeto "$PROJETO" --arg vpcs "$VPCS" "$DEFS"'
  .NatGateways[]
  | (tag("Projeto") == $projeto or emvpc(.VpcId)) as $p
  | (if $p then "P" else "O" end) + "\tnat gateway: " + .NatGatewayId'
registrar <<< "$J"
# Alocações de EIP usadas por NATs do projeto (EIP sem tag, mas na VPC do projeto).
processar "alocações de eip dos nats" --arg projeto "$PROJETO" --arg vpcs "$VPCS" "$DEFS"'
  .NatGateways[] | select(tag("Projeto") == $projeto or emvpc(.VpcId))
  | .NatGatewayAddresses[]?.AllocationId'
ALOCS="$J"

# Elastic IPs.
chamar "ec2 describe-addresses" ec2 describe-addresses
processar "elastic ips" --arg projeto "$PROJETO" --arg vpcs "$VPCS" --arg alocs "$ALOCS" "$DEFS"'
  .Addresses[] | (.AllocationId // "") as $id
  | (tag("Projeto") == $projeto or (($alocs | split("\n") | index($id)) != null)) as $p
  | (if $p then "P" else "O" end) + "\telastic ip: " + (.AllocationId // .PublicIp)
    + " (" + (.PublicIp // "") + ")"'
registrar <<< "$J"

# Cluster EKS.
chamar "eks list-clusters" eks list-clusters
processar "clusters eks" --arg projeto "$PROJETO" '
  .clusters[]? | (if . == $projeto then "P" else "O" end) + "\tcluster eks: " + .'
registrar <<< "$J"

# Repositórios ECR.
chamar "ecr describe-repositories" ecr describe-repositories
processar "repositórios ecr" --arg repos "$REPOS" '
  .repositories[]? | .repositoryName as $n
  | (if (($repos | split("\n") | index($n)) != null)
    then "P" else "O" end) + "\trepositório ecr: " + .repositoryName'
registrar <<< "$J"

# Buckets S3.
chamar "s3api list-buckets" s3api list-buckets
processar "buckets s3" --arg projeto "$PROJETO" '
  .Buckets[]? | (if (.Name | startswith($projeto)) then "P" else "O" end)
    + "\tbucket s3: " + .Name'
registrar <<< "$J"

# Grupos de log do EKS.
chamar "logs describe-log-groups" logs describe-log-groups --log-group-name-prefix "/aws/eks/"
processar "grupos de log" --arg projeto "$PROJETO" '
  .logGroups[]? | (if (.logGroupName | startswith("/aws/eks/" + $projeto + "/")) or
    .logGroupName == "/aws/eks/" + $projeto then "P" else "O" end)
    + "\tgrupo de log: " + .logGroupName'
registrar <<< "$J"

# Aliases KMS (aliases alias/aws/* são das chaves gerenciadas pela AWS e ficam de fora).
chamar "kms list-aliases" kms list-aliases
processar "aliases kms" '.Aliases[]? | select(.AliasName | startswith("alias/aws/") | not)
  | [.AliasName, (.TargetKeyId // "")] | @tsv'
ALIASES="$J"
while IFS=$'\t' read -r nome_alias chave; do
  [ -n "$nome_alias" ] || continue
  if [[ "$nome_alias" == alias/eks/$PROJETO* ]]; then
    estado=""
    if [ -n "$chave" ]; then
      chamar "kms describe-key ($nome_alias)" kms describe-key --key-id "$chave"
      processar "estado da chave $chave" '.KeyMetadata.KeyState'
      estado="$J"
    fi
    if [ "$estado" != "PendingDeletion" ]; then
      PROJ="${PROJ}alias kms: $nome_alias"$'\n'
    fi
  else
    OUTROS="${OUTROS}alias kms: $nome_alias"$'\n'
  fi
done <<< "$ALIASES"

# IAM é global (sem região). Papel do CD: NoSuchEntity só quer dizer que não existe.
PAPEL="$PROJETO-github"
R="$(aws --output json iam get-role --role-name "$PAPEL" 2>"$ERRO" </dev/null)" || {
  if grep -q NoSuchEntity "$ERRO"; then
    R='{}'
  else
    echo "falha na checagem: iam get-role" >&2
    head -n 1 "$ERRO" >&2
    exit 2
  fi
}
processar "papel iam" -r '.Role.RoleName // empty | "P\tpapel iam: " + .'
registrar <<< "$J"

# Provedor OIDC do GitHub Actions: conta se tiver a tag Projeto=santo-projeto.
chamar "iam list-open-id-connect-providers" iam list-open-id-connect-providers
processar "provedores oidc" '.OpenIDConnectProviderList[]?.Arn'
PROVEDORES="$J"
while IFS= read -r arn; do
  [ -n "$arn" ] || continue
  case "$arn" in *token.actions.githubusercontent.com) ;; *) continue ;; esac
  chamar "iam list-open-id-connect-provider-tags" iam list-open-id-connect-provider-tags \
    --open-id-connect-provider-arn "$arn"
  processar "tags do provedor oidc" --arg projeto "$PROJETO" '
    (if ((.Tags // []) | any(.Key == "Projeto" and .Value == $projeto))
    then "P" else "O" end) + "\tprovedor oidc: token.actions.githubusercontent.com"'
  registrar <<< "$J"
done <<< "$PROVEDORES"

# Relatório.
if [ -n "$OUTROS" ]; then
  echo "outros recursos na região (sem a marca do projeto, não contam):"
  printf '%s' "$OUTROS" | sed 's/^/  /'
fi
if [ -n "$PROJ" ]; then
  echo "sobrou do projeto:"
  printf '%s' "$PROJ"
  exit 1
fi
echo "nada sobrando"
exit 0
