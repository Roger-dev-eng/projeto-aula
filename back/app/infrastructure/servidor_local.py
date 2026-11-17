import socket

class ServidorLocal:
    def nome(self) -> str:
        return socket.gethostname()
