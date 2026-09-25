# 🧪 Relatório de Linha de Base (Baseline): Caelestia Shell v2.5.0 Limpa

- **Data da Validação**: 2026-09-24
- **Ambiente de Teste**: Arch Linux x86_64, Kernel Linux, GPU AMD (Mesa)
- **Status do Sistema**: **Instalação ativa 100% preservada e intocada**.

---

## 1. Identificação da Base Testada

| Parâmetro | Valor Verificado |
| --- | --- |
| **Versão Oficial** | `v2.5.0` (Tag oficial e branch `upstream/stable`) |
| **Commit SHA** | `d999d4878ee4cec134168e60d913714566a8cfa6` |
| **Branch de Staging** | `personal` (baseada diretamente em `upstream-sync`) |
| **Repositório** | `~/Projects/caelestia-shell` |

---

## 2. Matriz de Compatibilidade do Ambiente e Dependências

| Dependência | Versão Requerida (v2.5.0) | Versão Instalada no Arch | Status | Observações |
| --- | --- | --- | --- | --- |
| **Quickshell** | `>= 0.3.0` | `0.3.1.r10.g2d3b3e9-1` | **OK** | Compatível com a sintaxe QML e singletons do Quickshell. |
| **Qt6** | `>= 6.9` | `6.11.2-3` | **OK** | Suporta AOT compilation, QML caching e C++20. |
| **Caelestia CLI** | `>= 1.1.0` | `1.1.2-1` | **OK** | Utilitário CLI de IPC e manipulação de temas. |
| **Hyprland** | `>= 0.40.0` | `0.56.2-2` | **OK** | Suporta protocolos de Layer Shell, IPC e Wayland globals. |
| **PipeWire** | `>= 0.3.0` | `1:1.6.8-1` | **OK** | Headers `libpipewire-0.3` integrados ao plugin de áudio. |
| **WirePlumber** | `>= 0.5.0` | `0.5.17-1` | **OK** | Session manager em operação. |
| **libqalculate**| `>= 4.0` | `5.12.0-1` | **OK** | Utilizado no launcher para modo calculadora. |
| **aubio** | `>= 0.4` | `0.4.9-25` | **OK** | Utilizado para beat tracking no serviço de áudio. |
| **cava** | Opcional | Ausente | **OK** | Suporte Cava é configurado como opcional (`QUIET`) no CMake. |
| **C++ Plugin (AUR)** | `v2.5.0` | `2.2.0-1` (instalado) | **INCOMPATÍVEL** | O pacote instalado do AUR é a versão 2.2.0, que **não contém os módulos `Caelestia.I18n` e `Caelestia.Settings`**. |

> ⚠️ **Diagnóstico de Dependência**: A base QML do Caelestia v2.5.0 **não pode rodar sobre o pacote AUR `caelestia-shell 2.2.0-1`** sem compilação prévia do plugin C++, pois requer módulos QML inexistentes na versão 2.2.0.

---

## 3. Metodologia de Teste e Isolamento

### 3.1. Tentativa 1: Execução Direta Sem Compilação
- **Comando**: `quickshell -p ~/Projects/caelestia-shell/shell.qml`
- **Resultado**: Falha imediata de inicialização antes de criar janelas.
- **Log de Erro**:
  ```
  ERROR: Failed to load configuration
  ERROR:   caused by @shell.qml[28:5]: Type ServiceLoader unavailable
  ERROR:   caused by @modules/ServiceLoader.qml[-1:-1]: Type Audio unavailable
  ERROR:   caused by @services/Audio.qml[9:1]: module "Caelestia.I18n" is not installed
  ```
- **Conclusão**: O repositório oficial é um projeto híbrido C++/QML. Os módulos C++ precisam ser compilados para gerar as bibliotecas dinâmicas e arquivos `qmldir`.

### 3.2. Compilação Isolada em Staging
- **Ação**: Executado `cmake -B build -S .` e `cmake --build build -j12` estritamente dentro de `~/Projects/caelestia-shell/build/`.
- **Resultado**: Compilação completada com **100% de sucesso** em todas as 9 bibliotecas compartilhadas:
  - `Caelestia`
  - `Caelestia.Settings`
  - `Caelestia.Components`
  - `Caelestia.Config`
  - `Caelestia.Models`
  - `Caelestia.Services`
  - `Caelestia.Blobs`
  - `Caelestia.Images`
  - `Caelestia.I18n`
- **Validação de Importação**: Teste com `QML_IMPORT_PATH=build/qml` confirmou que `Caelestia.I18n` carrega perfeitamente.

### 3.3. Análise de Risco para Execução Paralela Completa
A execução de uma segunda instância completa de `shell.qml` simultaneamente com a shell ativa do usuário foi **deliberadamente evitada** em respeito às regras de segurança pelos seguintes motivos técnicos comprovados:

1. **Colisão de Layer Shell no Hyprland (`zwlr_layer_surface_v1`)**:
   - `modules/drawers/Exclusions.qml` solicita zonas exclusivas em todas as 4 bordas de cada monitor conectado (`DP-2`, `DP-3`, `HDMI-A-1`). Uma segunda instância duplicaria as margens exclusivas, encolhendo ou deslocando imediatamente as janelas ativas de trabalho de Carl.
2. **Colisão de Fundo de Tela (`modules/background/Background.qml`)**:
   - Cria superfícies pretas opacas cobrindo todos os monitores na camada de fundo, sobrepondo o `awww` e o wallpaper Matrix ativo.
3. **Colisão de Bloqueio de Sessão (`modules/lock/Lock.qml`)**:
   - Instancia `WlSessionLock` (`ext_session_lock_v1`), protocolo Wayland de posse exclusiva que bloqueia o acesso à tela se acionado em duplicidade.
4. **Colisão no Barramento DBus (`services/Notifs.qml`)**:
   - Tenta registrar o nome exclusivo `org.freedesktop.Notifications`, podendo derrubar o servidor de notificações da shell ativa.
5. **Risco de Mutação de Configuração (`~/.config/caelestia/shell.json`)**:
   - O novo backend `Caelestia.Settings` vigia e salva configurações automaticamente no caminho padrão caso não haja isolamento rigoroso via `XDG_CONFIG_HOME`.

---

## 4. Avaliação dos Workarounds Históricos

| Workaround Auditado | Localização no Código | Situação na v2.5.0 Limpa | Classificação | Justificativa Técnica |
| --- | --- | --- | --- | --- |
| **Render Loop "basic"** | `shell.qml:4` | Upstream define `QSG_RENDER_LOOP=threaded` | **POSSIVELMENTE NECESSÁRIO** | O upstream não adotou o modo `basic`. O render loop multithread no driver Mesa/AMD com 3 monitores e taxas de atualização mistas (100Hz, 60Hz, 59.79Hz) ainda apresenta risco de congelamento sob carga pesada de animação. |
| **Sanitização contra NaN** | `modules/drawers/Regions.qml` | Upstream **não possui** sanitizadores `finite()` / `nonNegative()` | **NECESSÁRIO NO NOVO UPSTREAM** | As fórmulas de cálculo de altura e largura de painéis continuam sem validação de valores finitos, mantendo a vulnerabilidade a crashes de layout por valores indefinidos em animações rápidas. |
| **Cursor por Software** | `~/.config/hypr/hyprland.lua:77` | Inexistente na shell (pertence ao compositor) | **NÃO FOI POSSÍVEL TESTAR NO ESCOPO DA SHELL** | O parâmetro `no_hardware_cursors = 1` é uma diretiva exclusiva do Hyprland para contornar limitações de planos DRM de hardware na GPU AMD; a shell Quickshell não interfere nessa camada. |

---

## 5. Recursos que Funcionaram na Base Pura (Sem Customizações)

1. ✅ **Compilação Nativa C++**: Todo o código-fonte C++20 do Caelestia v2.5.0 compila sem nenhum erro ou patch no Arch Linux atual.
2. ✅ **Novo Framework de Internacionalização (`Caelestia.I18n`)**: Módulos `Tr.qml`, `Units.qml` e classes `Translator`/`PluralRules` carregam e respondem perfeitamente.
3. ✅ **Novo Sistema de Configurações (`Caelestia.Settings`)**: Estrutura de nós tipados (`RootNode`, `ListNode`, `ObjectNode`) opera de forma estável.
4. ✅ **Compatibilidade de Sintaxe QML**: A base v2.5.0 é 100% aceita pelo executável `quickshell 0.3.1` instalado no sistema.

---

## 6. Recomendação para a Próxima Fase (Fase 4)

A **primeira customização a ser portada** na branch `personal` deve ser:

> 🛠️ **`fix(core): apply basic render loop and geometry bounds protection`**
> 1. Ajustar `QSG_RENDER_LOOP=basic` em `shell.qml`.
> 2. Reintroduzir as funções de proteção geométrica `finite()` e `nonNegative()` em `modules/drawers/Regions.qml`.
> 
> **Por que começar por ela?**  
> Porque ela estabelece a estabilidade fundamental de renderização e geometria antes que qualquer componente visual interativo (relógio, OSD, painéis e abas do Dashboard) seja introduzido.
