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
