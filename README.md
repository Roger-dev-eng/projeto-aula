# Santo Projeto

Projeto da aula de infraestrutura: uma API e um site React. O professor demonstra na AWS, com Terraform e Kubernetes (EKS); você sobe a API em um cluster Kubernetes local (kind) ou no Killercoda.

## Estrutura

```
santo-projeto/
├── infra/      # Terraform: raiz + modules/{rede,ecr,eks,site,cicd} + envs/aula.tfvars
├── .github/    # workflows/pipeline.yml (CI/CD)
├── back/       # API FastAPI em quatro camadas + Dockerfile + k8s/
├── front/      # React (Vite) em quatro camadas
├── scripts/    # preparar.sh, publicar-imagens.sh, destruir.sh, conferir.sh
├── docs/       # especificação e referência do Roteiro
├── README.md
└── .gitignore
```

## Roteiro principal

Siga o **Guia do participante**: https://claude.ai/artifact/84trFcnbNVicMbhbnDAq7n

Ele é o roteiro da aula. Este README só mostra como preparar o ambiente.

## Caminho sem custo: kind no WSL

Execute os comandos abaixo no **terminal WSL (bash)**, não no PowerShell nem no cmd.

1. Prepare o ambiente: Docker respondendo no WSL, kind v0.33.0 (a versão da imagem de nó da aula) e kubectl.

   ```bash
   docker version        # precisa mostrar Client e Server; sem Server, ligue no Docker Desktop:
                         # Settings › Resources › WSL integration › Ubuntu
   curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
   chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind && kind version
   # só se "kubectl version --client" der command not found:
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && kubectl version --client
   ```

2. Clone o repositório:

   ```bash
   git clone https://github.com/Izaiasjun1Dev/santo-projeto.git
   cd santo-projeto
   ```

3. Crie o cluster com a imagem de nó do GHCR:

   ```bash
   kind create cluster --name aula --image ghcr.io/izaiasjun1dev/kindest-node:v1.37.0
   ```

4. Siga os sete passos do Guia. Os comandos principais são:

   ```bash
   kubectl create deployment back --image=ghcr.io/izaiasjun1dev/santo-projeto-back:v1 --replicas=2 --port=8000
   kubectl scale deployment back --replicas=6
   kubectl delete pod NOME                              # NOME de um pod listado em: kubectl get pods
   kubectl set image deployment/back '*=ghcr.io/izaiasjun1dev/santo-projeto-back:v2'
   kubectl rollout undo deployment/back
   ```

   Para chamar a API, abra **um segundo terminal** (WSL) e deixe o `port-forward` rodando nele:

   ```bash
   # Terminal 2
   kubectl port-forward deployment/back 8000:8000
   ```

   ```bash
   # Terminal 1
   curl localhost:8000/api/saudacao
   ```

   Depois de apagar um pod, trocar a imagem ou voltar a versão, o `port-forward` não encerra na hora: o próximo `curl` falha (`Empty reply from server`) e só então o terminal 2 mostra `error: lost connection to pod`. Se o `curl` falhar, aperte Ctrl+C no terminal do `port-forward` e rode-o de novo.

## Pipeline (CI/CD)

Todo push na `main` dispara o workflow "Pipeline" (CI e deploy no EKS): https://github.com/Izaiasjun1Dev/santo-projeto/actions

## Atenção: custo na AWS

Não rode `terraform apply`. O cluster EKS e os demais recursos são cobrados por hora e podem gerar custo sem você perceber. Se tiver conta AWS, `terraform plan` é seguro, porque só mostra o que seria criado.
