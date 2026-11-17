from dataclasses import dataclass

@dataclass(frozen=True)
class Saudacao:
    mensagem: str
    servidor: str
