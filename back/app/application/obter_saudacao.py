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
