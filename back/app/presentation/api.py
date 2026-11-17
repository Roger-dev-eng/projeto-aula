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
