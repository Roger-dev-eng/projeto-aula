from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.application.obter_saudacao import ObterSaudacao
from app.infrastructure.servidor_local import ServidorLocal
from app.presentation.api import criar_rotas

app = FastAPI(title="API da aula")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["GET"])
app.include_router(criar_rotas(ObterSaudacao(ServidorLocal())))
