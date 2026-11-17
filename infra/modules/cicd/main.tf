# O GitHub Actions entra na AWS sem chave guardada: o GitHub prova quem é (OIDC)
# e a AWS entrega credenciais temporárias.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Só o branch main deste repositório pode assumir o papel.
resource "aws_iam_role" "github" {
  name = "${var.nome}-github"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "${var.sub_github}:ref:refs/heads/main"
        }
      }
    }]
  })
}

# O que o pipeline pode fazer: enviar imagem para o ECR e achar o cluster.
resource "aws_iam_role_policy" "github" {
  name = "${var.nome}-github"
  role = aws_iam_role.github.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
        ]
        Resource = var.arn_repositorio_ecr
      },
      {
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = var.arn_cluster
      },
    ]
  })
}

# Dentro do Kubernetes: o papel pode editar recursos só no namespace default.
resource "aws_eks_access_entry" "github" {
  cluster_name  = var.nome_cluster
  principal_arn = aws_iam_role.github.arn
}

resource "aws_eks_access_policy_association" "github" {
  cluster_name  = var.nome_cluster
  principal_arn = aws_iam_role.github.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }

  depends_on = [aws_eks_access_entry.github]
}
