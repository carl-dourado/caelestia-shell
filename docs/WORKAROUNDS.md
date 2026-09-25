# 🛡️ Workarounds Históricos de Estabilidade

Este documento registra os workarounds de estabilidade portados preventivamente para a branch `personal` da Caelestia Shell (`~/Projects/caelestia-shell`).

---

## 1. Proteção Geométrica contra NaN e Dimensões Inválidas

- **Status**: `HISTORICAL_WORKAROUND (runtime necessity not yet proven on v2.5.0)`
- **Arquivo Modificado**: [`modules/drawers/Regions.qml`](file:///home/carl/Projects/caelestia-shell/modules/drawers/Regions.qml)
- **Commit**: `fix(core): guard drawer geometry against invalid values`
- **Origem Histórica**: Implementado no setup de produção de Carl em agosto de 2026 (`~/.config/quickshell/caelestia/modules/drawers/Regions.qml`).

### Descrição Técnica
Adição das funções auxiliares tipadas `finite()` e `nonNegative()`, além de verificações de nulidade via encadeamento opcional (`?.` e `??`):
```qml
function finite(value, fallback = 0): real {
    return Number.isFinite(value) ? value : fallback;
}

function nonNegative(value): real {
    return Math.max(0, finite(value));
}
```
Essas funções envolvem as coordenadas raiz (`x`, `y`, `width`, `height`) e as extensões dinâmicas dos painéis (`dashboard`, `launcher`, `session`, `sidebar`, `osd`, `notifications`, `utilities`, `popoutsWrapper` e delegate `R`).

### Justificativa e Ressalva
- **Motivação**: Prevenir que valores transitórios indefinidos (`undefined`), não-numéricos (`NaN`), infinitos (`±Infinity`) ou negativos gerados durante interpolações de animação ou redimensionamento de monitores sejam repassados aos protocolos do Wayland Layer Shell (`zwlr_layer_surface_v1`), o que poderia disparar avisos no compositor ou quebras de geometria.
- **Situação no Upstream v2.5.0**: O upstream oficial não possui essas proteções nas fórmulas de `Regions.qml`.
- **Ressalva Metodológica**: A ausência dessa proteção no código upstream não comprova por si só que falhas de `NaN` ocorrerão em runtime na v2.5.0. O workaround foi preservado preventivamente como precaução histórica e será reavaliado sob testes reais de carga.

---

## 2. Render Loop "basic" no Qt Quick

- **Status**: `HISTORICAL_WORKAROUND (runtime necessity not yet proven on v2.5.0)`
- **Arquivo Modificado**: [`shell.qml`](file:///home/carl/Projects/caelestia-shell/shell.qml)
- **Commit**: `fix(runtime): preserve basic Qt Quick render loop workaround`
- **Origem Histórica**: Presente na instalação ativa estável de Carl (`shell.qml:4`).

### Descrição Técnica
Alteração da diretiva de ambiente padrão do Quickshell:
```qml
//@ pragma DefaultEnv QSG_RENDER_LOOP=basic
```

### Justificativa e Ressalva
- **Motivação**: O ambiente opera com GPU AMD (driver Mesa/DRM) e três monitores com taxas de atualização díspares (`DP-2` a 100Hz, `DP-3` a 59.79Hz e `HDMI-A-1` a 60Hz). No histórico do setup, o render loop multithread padrão (`threaded`) provocava engasgos perceptíveis e instabilidade na sincronização de buffers gráficos. O modo `basic` executa a renderização na thread principal da GUI de forma previsível e serializada.
- **Situação no Upstream v2.5.0**: O upstream continua configurando `QSG_RENDER_LOOP=threaded` por padrão.
- **Ressalva Metodológica**: Não há prova experimental prévia de que o modo `threaded` da v2.5.0 falhará neste hardware (o upstream realizou diversas melhorias em C++ no plugin). O uso do modo `basic` é mantido como salvaguarda inicial, sendo candidato prioritário para teste A/B comparativo futuro.

---

## 3. Diretiva de Cursor por Software no Compositor (Escopo Externo)

- **Status**: `NON_SHELL_SETTING (Compositor / Hyprland)`
- **Localização**: `~/.config/hypr/hyprland.lua:77` (`cursor.no_hardware_cursors = 1`)
- **Tratamento**: Esta configuração pertence estritamente ao compositor Hyprland (`caelestia-personal`), pois aborda o gerenciamento de planos de hardware KMS no driver AMD DRM. Não integra a base da Caelestia Shell.
