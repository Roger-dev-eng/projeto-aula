#!/usr/bin/env bash
# Publica no GHCR as imagens que os alunos baixam: a API (v1 e v2) e a
# imagem de nó do kind. Roda uma vez, antes da aula, no Mac do professor.
#
# Precisa de GITHUB_USER e GITHUB_TOKEN (token com write:packages) no ambiente.
set -euo pipefail

# Imagem de nó padrão do kind v0.33.0 (notas da versão em
# github.com/kubernetes-sigs/kind/releases). Ao trocar a versão do kind, troque aqui.
KIND_NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
KIND_NODE_TAG="v1.37.0"

# 1. Variáveis (antes de qualquer outra coisa)
FALTAM=""
[ -n "${GITHUB_USER:-}" ] || FALTAM="$FALTAM GITHUB_USER"
[ -n "${GITHUB_TOKEN:-}" ] || FALTAM="$FALTAM GITHUB_TOKEN"
if [ -n "$FALTAM" ]; then
  echo "Faltam variáveis de ambiente:$FALTAM"
  echo "GITHUB_TOKEN precisa da permissão write:packages."
  exit 1
fi

cd "$(dirname "$0")/.."

# A v1 precisa sair com a mensagem da versão 1
grep -q "versao 1" back/app/application/obter_saudacao.py \
  || { echo "A mensagem não está na versão 1; rode: git checkout back/app/application/obter_saudacao.py"; exit 1; }

# Nomes de imagem precisam estar em minúsculas (o usuário do GitHub pode ter maiúsculas)
DONO=$(echo "$GITHUB_USER" | tr '[:upper:]' '[:lower:]')
BACK="ghcr.io/$DONO/santo-projeto-back"
NODE="ghcr.io/$DONO/kindest-node"
ORIGEM="https://github.com/$GITHUB_USER/santo-projeto"

# 2. Login no GHCR
echo "==> Login no ghcr.io"
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin

# 3. Builder com suporte a várias arquiteturas
if ! docker buildx inspect santo-multi >/dev/null 2>&1; then
  echo "==> Criando o builder santo-multi"
  docker buildx create --name santo-multi --driver docker-container >/dev/null
fi
docker buildx use santo-multi

# 4. v1: direto da pasta back/
echo "==> Publicando $BACK:v1"
docker buildx build --platform linux/amd64,linux/arm64 \
  --label "org.opencontainers.image.source=$ORIGEM" \
  -t "$BACK:v1" --push back

# 5. v2: cópia temporária com a mensagem trocada (o repositório fica na v1)
echo "==> Publicando $BACK:v2"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -R back/. "$TMP/"
ARQUIVO="$TMP/app/application/obter_saudacao.py"
sed -i.bak 's/versao 1/versao 2/' "$ARQUIVO"
rm -f "$ARQUIVO.bak"
if ! grep -q "versao 2" "$ARQUIVO"; then
  echo "Erro: a troca de 'versao 1' por 'versao 2' não aconteceu em $ARQUIVO"
  exit 1
fi
docker buildx build --platform linux/amd64,linux/arm64 \
  --label "org.opencontainers.image.source=$ORIGEM" \
  -t "$BACK:v2" --push "$TMP"

# 7. Cópia da imagem de nó do kind para o GHCR
echo "==> Copiando $KIND_NODE_IMAGE"
docker buildx imagetools create -t "$NODE:$KIND_NODE_TAG" "$KIND_NODE_IMAGE"

# 8. Teste de download anônimo (sem login)
echo "==> Testando download anônimo"
docker logout ghcr.io >/dev/null
FALHOU=0
for IMG in "$BACK:v1" "$BACK:v2" "$NODE:$KIND_NODE_TAG"; do
  if docker buildx imagetools inspect "$IMG" >/dev/null 2>&1; then
    echo "ok: $IMG"
  else
    echo "FALHOU: $IMG"
    FALHOU=1
  fi
done
if [ "$FALHOU" = 1 ]; then
  echo "Torne o pacote público em github.com/users/$GITHUB_USER/packages"
  echo "(torne o pacote público e rode o script de novo)"
  exit 1
fi

echo
echo "Tudo publicado. Comando do Guia:"
echo "kind create cluster --name aula --image $NODE:$KIND_NODE_TAG"
