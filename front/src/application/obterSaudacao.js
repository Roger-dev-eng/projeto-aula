import { criarSaudacao } from "../domain/saudacao";

export function criarObterSaudacao(gateway) {
  return async function obterSaudacao() {
    const dados = await gateway.buscar();
    return criarSaudacao(dados);
  };
}
