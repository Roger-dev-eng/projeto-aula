import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import { criarObterSaudacao } from "./application/obterSaudacao";
import { saudacaoApi } from "./infrastructure/saudacaoApi";
import { App } from "./presentation/App";

const obterSaudacao = criarObterSaudacao(saudacaoApi);

createRoot(document.getElementById("root")).render(
  <StrictMode>
    <App obterSaudacao={obterSaudacao} />
  </StrictMode>
);
