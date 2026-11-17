# Referência: Roteiro da demonstração (cópia em texto)

Cópia em texto do doc "Roteiro da demonstração: AWS, Terraform e Kubernetes" (https://claude.ai/artifact/KksVhYknkS6PcgKDuoxqzS), extraída em 2026-11-16. Tabelas e listas perderam a formatação; os blocos de código estão completos. O doc original é a fonte; esta cópia existe para quem implementa ler o código sem abrir o doc.

```text


# Roteiro da demonstração: AWS, Terraform e Kubernetes
 · 

## Visão geral
Em 1h30 os alunos veem um projeto completo, com três pastas (infra, back e front), ir do repositório para a internet: o Terraform modular cria a nuvem, o back roda no Kubernetes (EKS) e o front é publicado no S3.
O fio condutor é uma pergunta por etapa:

Projeto: como o código está organizado? Três pastas, cada uma em camadas (Clean Architecture).

Terraform: como criar a infraestrutura sem clicar? Módulos reutilizáveis, uma raiz e um arquivo de variáveis por ambiente.

Kubernetes: como manter a API no ar? Réplicas, autorrecuperação e atualização sem derrubar o serviço.

Front: como o usuário chega até a API? Uma página React no S3 que mostra qual pod respondeu.
Premissas deste roteiro, para ajustar depois de falar com o professor:

Duração de 90 minutos, começando às 10h.

Alunos iniciantes em nuvem, com noção básica de terminal.

Laboratório com projetor e internet.
Perguntas em aberto para o professor:

Qual é o dia exato e quanto tempo de aula está disponível?

Os alunos têm conta AWS (própria ou AWS Academy) ou só vão acompanhar?

O que está instalado nas máquinas do laboratório (Docker, Terraform, kubectl)?

## Estrutura do projeto
O repositório tem três pastas independentes; infra segue o padrão raiz + módulos + um .tfvars por ambiente, e back e front repetem as mesmas quatro camadas.
projeto-aula/
├── infra/
│   ├── main.tf              # chama os módulos
│   ├── variables.tf         # declara as variáveis da raiz
│   ├── outputs.tf           # o que a raiz devolve
│   ├── envs/
│   │   └── aula.tfvars      # valores do ambiente da aula
│   └── modules/
│       ├── rede/            # VPC e sub-redes
│       ├── ecr/             # repositórios de imagens
│       ├── eks/             # cluster Kubernetes
│       └── site/            # bucket S3 do front
├── back/
│   ├── app/
│   │   ├── domain/          # entidade Saudacao
│   │   ├── application/     # caso de uso ObterSaudacao
│   │   ├── infrastructure/  # quem descobre o nome do servidor
│   │   ├── presentation/    # rotas HTTP (FastAPI)
│   │   └── main.py          # monta tudo
│   ├── k8s/                 # deployment.yaml e service.yaml
│   ├── Dockerfile
│   └── requirements.txt
└── front/
    ├── src/
    │   ├── domain/          # formato da Saudacao
    │   ├── application/     # caso de uso obterSaudacao
    │   ├── infrastructure/  # chamada HTTP à API
    │   ├── presentation/    # componente App
    │   └── main.jsx         # monta tudo
    ├── index.html
    └── package.json
Cada módulo de infra/modules tem os mesmos três arquivos: main.tf, variables.tf e outputs.tf. O código completo está nas três seções finais deste documento.
Duas decisões minhas para você validar:

Módulo site: você escolheu rede, ecr e eks. Acrescentei um quarto, porque o front no S3 precisa de um bucket.

Front sem CloudFront: o bucket usa a hospedagem de site estático do S3, em HTTP. Com CloudFront a página seria HTTPS e o navegador bloquearia a chamada à API, que fica em HTTP no load balancer. Vale dizer à turma que em produção os dois teriam HTTPS.

## Preparação antes da aula
Toda a infraestrutura sobe com um único terraform apply antes de você entrar na sala: o cluster EKS leva em torno de 15 minutos e não cabe ao vivo. Na aula você mostra o código, faz uma alteração pequena e publica a aplicação.
Na véspera:

Instalar e testar no notebook da apresentação: AWS CLI, Terraform, kubectl, Docker, Node.js e jq.

Criar um alerta de orçamento (AWS Budgets) na conta que vai usar.

Publicar o projeto em um repositório público no GitHub, para os alunos clonarem.

Publicar a imagem do back, nas versões v1 e v2, em um registro público (Docker Hub, por exemplo), para os alunos usarem sem conta AWS.

Rodar o roteiro inteiro uma vez, do terraform init ao terraform destroy, cronometrando cada parte.

Gravar a tela desse ensaio. É o plano B se a internet do laboratório falhar.

Aumentar a fonte do terminal e do editor para leitura no projetor.
No dia, uma hora antes:
cd infra
terraform init
terraform apply -var-file=envs/aula.tfvars

# login no ECR, build e envio da imagem v1 do back
REPO=$(terraform output -json repositorios | jq -r '.back')
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "${REPO%%/*}"
docker build --platform linux/amd64 -t "$REPO:v1" ../back
docker push "$REPO:v1"

aws eks update-kubeconfig --name "$(terraform output -raw nome_cluster)" --region us-east-1
kubectl get nodes

Os nós aparecem como Ready.

A imagem back:v1 aparece no console do ECR.

O arquivo back/k8s/deployment.yaml aponta para a URL real do seu repositório ECR.

Abas do console abertas: VPC, ECR, EKS e S3, na região us-east-1.

Histórico do terminal limpo. Nunca exibir chaves de acesso na tela; use um perfil já configurado.
O --platform linux/amd64 importa se o seu notebook for ARM (Mac com Apple Silicon): os nós do cluster são x86 e não rodam imagem ARM.
Custo aproximado, de memória e para conferir na calculadora da AWS: o plano de controle do EKS custa cerca de US$ 0,10 por hora, mais dois nós pequenos e um NAT Gateway. Subindo uma hora antes e destruindo ao final, a aula fica em poucos dólares. O risco real é esquecer algo ligado.
Se o bloqueio de acesso público do S3 estiver ativado no nível da conta, o módulo site falha ao aplicar a política do bucket. Confira isso no ensaio.

## Cronograma
A aula tem sete blocos; os dois de demonstração ao vivo somam 50 dos 90 minutos.
 | 
Horário | 
Bloco | 
O que acontece
 | 
10:00–10:10 | 
Abertura | 
Quem é você, o problema ("como um projeto vai para a internet?") e um passeio pelas três pastas
 | 
10:10–10:15 | 
Tour pela AWS | 
Console: VPC, ECR, EKS e S3 já criados. Tudo isso veio de um comando
 | 
10:15–10:35 | 
Parte 1: Terraform | 
Raiz, módulos e .tfvars; plan sem mudanças; alterar o .tfvars e aplicar
 | 
10:35–10:40 | 
Ponte | 
"A infraestrutura existe. E a aplicação?" Contêineres e Kubernetes em duas frases
 | 
10:40–11:10 | 
Parte 2: Kubernetes e front | 
Deploy do back, escala, publicar o front, matar um pod, versão 2
 | 
11:10–11:25 | 
Mão na massa | 
Alunos fazem o desafio
 | 
11:25–11:30 | 
Encerramento | 
Destruir tudo, recapitular, perguntas
Se a aula tiver só 50 minutos, corte o tour pelo console e o desafio, e pule a versão 2 na Parte 2.

## Parte 1: Terraform modular ao vivo
A turma vê como um valor sai do aula.tfvars, passa pela raiz e chega a um recurso dentro de um módulo, e depois vê uma mudança de uma linha virar um recurso novo na AWS.

### Passo a passo

Mostrar a árvore de infra/. Três ideias: a raiz orquestra, os módulos fazem, o .tfvars configura.

Seguir uma variável de ponta a ponta. Abra, nesta ordem: envs/aula.tfvars (repositorios = ["back"]), variables.tf da raiz, main.tf da raiz (module "ecr"), modules/ecr/variables.tf e modules/ecr/main.tf (o for_each).

terraform plan -var-file=envs/aula.tfvars. A saída é "No changes": o código e a nuvem estão iguais. Explique que o Terraform comparou os dois.

terraform output. Mostre o nome do cluster, a URL do repositório e a URL do site. É assim que a raiz expõe o que os módulos criaram.

Alterar o .tfvars ao vivo. Peça a um aluno um nome e acrescente à lista: repositorios = ["back", "nome-do-aluno"].

terraform plan -var-file=envs/aula.tfvars de novo. Agora aparece "1 to add". Nenhum arquivo .tf foi tocado.

terraform apply -var-file=envs/aula.tfvars. Leva segundos. Atualize o console do ECR e mostre o repositório novo.

### O que falar

Módulo é função: recebe variáveis, devolve outputs e esconde os detalhes. O main.tf da raiz lê como um índice do que existe na conta.

Um .tfvars por ambiente permite subir a mesma infraestrutura para aula, homologacao e producao trocando só o arquivo passado em -var-file.

O código fica no Git, passa por revisão e documenta a conta melhor do que qualquer diagrama desatualizado.

O arquivo terraform.tfstate é a memória do Terraform. Mostre que ele existe, sem abrir em detalhe.

## Parte 2: back no EKS e front no S3
A API sobe no cluster, o front vai para o S3 e a página mostra qual pod respondeu cada chamada. Isso torna visíveis a escala, a autorrecuperação e a troca de versão.
Deixe um segundo terminal aberto com kubectl get pods -w durante todo o bloco. Os comandos partem da raiz do projeto.
 | 
Passo | 
Comando | 
O que mostrar e falar
 | 
1. Deploy do back | 
kubectl apply -f back/k8s/ | 
Abra o deployment.yaml antes: é o estado desejado, em arquivo, como no Terraform
 | 
2. Endereço da API | 
kubectl get service back | 
O Kubernetes pediu um load balancer à AWS. O endereço leva de 2 a 3 minutos para responder; siga para o passo 3 enquanto isso
 | 
3. Escalar | 
kubectl scale deployment back --replicas=6 | 
Seis cópias em segundos, espalhadas pelos nós (kubectl get pods -o wide)
 | 
4. Testar a API | 
curl http://ENDERECO-DO-PASSO-2/api/saudacao | 
A resposta traz a mensagem e o nome do pod que atendeu
 | 
5. Build do front | 
cd front && npm install && VITE_API_URL=http://ENDERECO-DO-PASSO-2 npm run build | 
O front descobre a API por uma variável de ambiente, na camada de infraestrutura
 | 
6. Publicar o front | 
aws s3 sync dist/ s3://$(terraform -chdir=../infra output -raw bucket_site) --delete | 
Abra a url_site do terraform output e clique em "Chamar a API" algumas vezes
 | 
7. Autorrecuperação | 
kubectl delete pod NOME-DO-POD | 
Apague o pod que aparece na página e clique de novo: outro pod responde, e um substituto nasce
 | 
8. Versão 2 | 
Mudar a mensagem em back/app/application/obter_saudacao.py; build e push de $REPO:v2; kubectl set image deployment/back back=$REPO:v2 | 
Os pods são trocados aos poucos. Clique na página durante a troca: aparecem as duas mensagens
 | 
9. Voltar atrás | 
kubectl rollout undo deployment/back | 
Um comando desfaz a atualização
O navegador pode reutilizar a mesma conexão e mostrar o mesmo pod em cliques seguidos. Se isso acontecer, use o curl do passo 4 em laço para mostrar a distribuição.
Valide no ensaio se o passo 2 cria o load balancer sem configuração extra no seu cluster. Se não criar, use kubectl port-forward service/back 8000:80 e faça o build do front com VITE_API_URL=http://localhost:8000, rodando npm run dev em vez de publicar no S3.

### O que falar

A mudança da versão 2 tocou um arquivo da camada application. Rotas, Dockerfile e infraestrutura ficaram iguais: é isso que a Clean Architecture compra.

O Kubernetes é um laço que compara o estado desejado com o real e corrige a diferença. É a mesma ideia do terraform plan, rodando o tempo todo.

Terraform cria a infraestrutura; Kubernetes cuida da aplicação em cima dela; o front estático nem precisa de servidor.

## Mão na massa dos alunos
Os alunos clonam o repositório, exploram a estrutura e sobem o back em um cluster deles; o que muda é onde esse cluster roda.
 | 
Situação | 
O que os alunos fazem | 
Cuidado
 | 
Têm conta AWS (própria ou AWS Academy) | 
Rodam terraform init e terraform plan -var-file=envs/aula.tfvars em infra/ e leem o plano. Não aplicam | 
O plan não cria nada e não custa. Um apply de 30 alunos seriam 30 clusters
 | 
Sem conta, com Docker nas máquinas | 
Sobem um cluster local com kind e fazem deploy da imagem pública do back | 
Sem load balancer em cluster local; usam kubectl port-forward
 | 
Sem conta e sem nada instalado | 
Usam um ambiente Kubernetes no navegador (Killercoda ou Play with Kubernetes) com a mesma imagem pública | 
Depende da internet do laboratório; confirme que os sites abrem na rede da faculdade
Não distribua credenciais da sua conta nem acesso ao seu cluster. A imagem pública do back resolve isso.

### Desafio de 15 minutos

Encontrar no repositório em qual arquivo está a mensagem da API e em qual camada ele fica.

Subir um deployment chamado back com 3 réplicas da imagem pública.

Chamar /api/saudacao cinco vezes e anotar quantos pods diferentes responderam.

Apagar um pod e contar quantos segundos o substituto leva para ficar Running.

Responder: para criar um segundo repositório de imagens, qual arquivo de infra/ precisa mudar?
Circule pela sala durante o desafio. Os erros mais comuns são nome de pod digitado errado e comando rodado no terminal que está preso no -w.

## Encerramento
Destrua tudo na frente da turma, na ordem abaixo: apagar os recursos do Kubernetes antes do destroy evita que o load balancer fique órfão e trave a remoção da rede.
kubectl delete -f back/k8s/

cd infra
terraform destroy -var-file=envs/aula.tfvars
O destroy leva cerca de 10 minutos; deixe rodando enquanto recapitula e responde perguntas. O bucket e os repositórios ECR são apagados mesmo com conteúdo, porque os módulos usam force_destroy e force_delete.

### Três ideias para a turma levar

Separar o projeto em infra, back e front, cada um em camadas, permite mudar uma parte sem quebrar as outras.

Infraestrutura como código, em módulos, torna o ambiente repetível, revisável e versionado.

Kubernetes mantém a aplicação no estado que você declarou, mesmo quando algo falha.
Sugestão de próximo passo para os alunos: instalar o kind em casa e repetir a Parte 2 sem gastar nada.

### Conferência depois da aula

O terraform destroy terminou sem erro.

No console, em us-east-1: nenhuma instância EC2, load balancer, NAT Gateway ou Elastic IP restante.

Nenhum cluster no EKS, nenhum repositório no ECR e nenhum bucket do projeto no S3.

Imagem pública do back mantida ou removida, conforme combinado com o professor.

## Código: infra
A raiz tem três arquivos e só chama módulos; cada módulo tem main.tf, variables.tf e outputs.tf. Os módulos rede e eks embrulham os módulos da comunidade. Os parâmetros seguem a versão 21 do módulo de EKS como eu a conheço; valide com terraform validate no ensaio.

### Raiz
infra/main.tf
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.regiao

  default_tags {
    tags = {
      Projeto  = var.projeto
      Ambiente = var.ambiente
    }
  }
}

data "aws_caller_identity" "atual" {}

module "rede" {
  source = "./modules/rede"

  nome  = var.projeto
  cidr  = var.cidr_vpc
  zonas = var.zonas
}

module "ecr" {
  source = "./modules/ecr"

  repositorios = var.repositorios
}

module "eks" {
  source = "./modules/eks"

  nome           = var.projeto
  vpc_id         = module.rede.vpc_id
  subnet_ids     = module.rede.subnets_privadas
  tipo_instancia = var.tipo_instancia
  quantidade_nos = var.quantidade_nos
}

module "site" {
  source = "./modules/site"

  nome_bucket = "${var.projeto}-front-${data.aws_caller_identity.atual.account_id}"
}
infra/variables.tf
variable "regiao" {
  type = string
}

variable "projeto" {
  type = string
}

variable "ambiente" {
  type = string
}

variable "cidr_vpc" {
  type = string
}

variable "zonas" {
  type = list(string)
}

variable "repositorios" {
  type = list(string)
}

variable "tipo_instancia" {
  type = string
}

variable "quantidade_nos" {
  type = number
}
infra/outputs.tf
output "nome_cluster" {
  value = module.eks.nome
}

output "repositorios" {
  value = module.ecr.urls
}

output "bucket_site" {
  value = module.site.bucket
}

output "url_site" {
  value = module.site.url
}
infra/envs/aula.tfvars
regiao         = "us-east-1"
projeto        = "projeto-aula"
ambiente       = "aula"
cidr_vpc       = "10.0.0.0/16"
zonas          = ["us-east-1a", "us-east-1b"]
repositorios   = ["back"]
tipo_instancia = "t3.medium"
quantidade_nos = 2

### Módulo rede
# modules/rede/main.tf
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name            = var.nome
  cidr            = var.cidr
  azs             = var.zonas
  public_subnets  = [for i, z in var.zonas : cidrsubnet(var.cidr, 8, i + 1)]
  private_subnets = [for i, z in var.zonas : cidrsubnet(var.cidr, 8, i + 11)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

# modules/rede/variables.tf
variable "nome" {
  type = string
}

variable "cidr" {
  type = string
}

variable "zonas" {
  type = list(string)
}

# modules/rede/outputs.tf
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "subnets_privadas" {
  value = module.vpc.private_subnets
}

### Módulo ecr
# modules/ecr/main.tf
resource "aws_ecr_repository" "este" {
  for_each = toset(var.repositorios)

  name         = each.value
  force_delete = true
}

# modules/ecr/variables.tf
variable "repositorios" {
  type = list(string)
}

# modules/ecr/outputs.tf
output "urls" {
  value = { for nome, repo in aws_ecr_repository.este : nome => repo.repository_url }
}

### Módulo eks
# modules/eks/main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                   = var.nome
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = { before_compute = true }
  }

  eks_managed_node_groups = {
    padrao = {
      instance_types = [var.tipo_instancia]
      min_size       = var.quantidade_nos
      max_size       = var.quantidade_nos + 1
      desired_size   = var.quantidade_nos
    }
  }
}

# modules/eks/variables.tf
variable "nome" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "tipo_instancia" {
  type = string
}

variable "quantidade_nos" {
  type = number
}

# modules/eks/outputs.tf
output "nome" {
  value = module.eks.cluster_name
}

### Módulo site
# modules/site/main.tf
resource "aws_s3_bucket" "site" {
  bucket        = var.nome_bucket
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "site" {
  bucket     = aws_s3_bucket.site.id
  depends_on = [aws_s3_bucket_public_access_block.site]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.site.arn}/*"
    }]
  })
}

# modules/site/variables.tf
variable "nome_bucket" {
  type = string
}

# modules/site/outputs.tf
output "bucket" {
  value = aws_s3_bucket.site.bucket
}

output "url" {
  value = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}

## Código: back
Uma API FastAPI com um caso de uso: devolver uma saudação e o nome do servidor que respondeu. As dependências apontam sempre para dentro: presentation e infrastructure conhecem application, que conhece domain.
back/app/domain/saudacao.py
from dataclasses import dataclass

@dataclass(frozen=True)
class Saudacao:
    mensagem: str
    servidor: str
back/app/application/obter_saudacao.py
from typing import Protocol

from app.domain.saudacao import Saudacao

class IdentificadorDeServidor(Protocol):
    def nome(self) -> str: ...

class ObterSaudacao:
    def __init__(self, servidor: IdentificadorDeServidor):
        self._servidor = servidor

    def executar(self) -> Saudacao:
        return Saudacao(
            mensagem="Ola, turma! Esta e a versao 1.",
            servidor=self._servidor.nome(),
        )
back/app/infrastructure/servidor_local.py
import socket

class ServidorLocal:
    def nome(self) -> str:
        return socket.gethostname()
back/app/presentation/api.py
from fastapi import APIRouter

from app.application.obter_saudacao import ObterSaudacao

def criar_rotas(caso_de_uso: ObterSaudacao) -> APIRouter:
    rotas = APIRouter()

    @rotas.get("/api/saudacao")
    def saudacao():
        resultado = caso_de_uso.executar()
        return {"mensagem": resultado.mensagem, "servidor": resultado.servidor}

    @rotas.get("/health")
    def health():
        return {"status": "ok"}

    return rotas
back/app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.application.obter_saudacao import ObterSaudacao
from app.infrastructure.servidor_local import ServidorLocal
from app.presentation.api import criar_rotas

app = FastAPI(title="API da aula")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["GET"])
app.include_router(criar_rotas(ObterSaudacao(ServidorLocal())))
back/requirements.txt
fastapi
uvicorn[standard]
Fixe as versões no requirements.txt depois do ensaio, para o build do dia ser igual ao testado.
back/Dockerfile
FROM python:3.12-slim
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
back/k8s/deployment.yaml (a URL do repositório já termina em /back; troque URL-DO-REPOSITORIO pela saída de terraform output repositorios)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: back
spec:
  replicas: 2
  selector:
    matchLabels:
      app: back
  template:
    metadata:
      labels:
        app: back
    spec:
      containers:
        - name: back
          image: URL-DO-REPOSITORIO:v1
          ports:
            - containerPort: 8000
          readinessProbe:
            httpGet:
              path: /health
              port: 8000
back/k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: back
spec:
  type: LoadBalancer
  selector:
    app: back
  ports:
    - port: 80
      targetPort: 8000
Para testar sem Docker: dentro de back/, pip install -r requirements.txt e uvicorn app.main:app --reload.

## Código: front
Uma página React com um botão que chama a API e lista as respostas, com o nome do pod que atendeu cada uma. Crie o projeto com npm create vite@latest front -- --template react e substitua o conteúdo de src/ pelos cinco arquivos abaixo.
front/src/domain/saudacao.js
export function criarSaudacao({ mensagem, servidor }) {
  return { mensagem, servidor };
}
front/src/application/obterSaudacao.js
import { criarSaudacao } from "../domain/saudacao";

export function criarObterSaudacao(gateway) {
  return async function obterSaudacao() {
    const dados = await gateway.buscar();
    return criarSaudacao(dados);
  };
}
front/src/infrastructure/saudacaoApi.js
const baseUrl = import.meta.env.VITE_API_URL;

export const saudacaoApi = {
  async buscar() {
    const resposta = await fetch(`${baseUrl}/api/saudacao`);
    if (!resposta.ok) {
      throw new Error(`A API respondeu ${resposta.status}`);
    }
    return resposta.json();
  },
};
front/src/presentation/App.jsx
import { useState } from "react";

export function App({ obterSaudacao }) {
  const [respostas, setRespostas] = useState([]);
  const [erro, setErro] = useState(null);

  async function chamar() {
    try {
      const saudacao = await obterSaudacao();
      setRespostas((anteriores) => [saudacao, ...anteriores]);
      setErro(null);
    } catch (falha) {
      setErro(falha.message);
    }
  }

  return (
    <main>
      <h1>Projeto da aula</h1>
      <button onClick={chamar}>Chamar a API</button>
      {erro && <p>Erro: {erro}</p>}
      <ul>
        {respostas.map((resposta, indice) => (
          <li key={indice}>
            {resposta.mensagem} Respondido por <strong>{resposta.servidor}</strong>.
          </li>
        ))}
      </ul>
    </main>
  );
}
front/src/main.jsx
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import { criarObterSaudacao } from "./application/obterSaudacao";
import { saudacaoApi } from "./infrastructure/saudacaoApi";
import { App } from "./presentation/App";

const obterSaudacao = criarObterSaudacao(saudacaoApi);

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <App obterSaudacao={obterSaudacao} />
  </StrictMode>
);
Para testar localmente com o back rodando na porta 8000: VITE_API_URL=http://localhost:8000 npm run dev.

## Fontes

terraform-aws-eks v21.0.0, notas da versão: requisitos mínimos de Terraform e do provider AWS.

Tempos de criação e custos são aproximados, de memória; confirme no ensaio e na calculadora de preços da AWS.

Nenhum código deste documento foi executado; o ensaio é o teste.
```
