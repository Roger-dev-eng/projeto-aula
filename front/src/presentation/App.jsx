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
