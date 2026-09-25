# 🐚 Guia de Arquitetura do Fork: Caelestia Shell

Este repositório é o fork oficial de desenvolvimento do **Caelestia Shell** (`caelestia-dots/shell`), mantido para acomodar as customizações do ambiente desktop de Carl sobre uma base limpa e atualizada.

---

## 1. Revisão Base Oficial Adotada

- **Repositório Upstream**: `https://github.com/caelestia-dots/shell.git`
- **Tag Base Oficial**: `v2.5.0`
- **Commit Base**: `d999d4878ee4cec134168e60d913714566a8cfa6`
- **Data da Base**: 18 de setembro de 2026
- **Estado Upstream na Criação**: O commit coincide exatamente com a branch `upstream/stable` oficial.

---

## 2. Topologia de Branches e Governança Git

```
upstream (caelestia-dots/shell)
       │
       ▼ (git fetch upstream --tags)
 upstream-sync (Mirror limpo / v2.5.0)
       │
       ▼ (rebase / cherry-pick / merge)
   personal (Commits atômicos e organizados do Carl)
```

### 🌿 Branch `upstream-sync`
- **Papel**: Espelho estritamente limpo do projeto oficial.
- **Regra de Ouro**: **Nenhum commit local ou personalização é feito diretamente nesta branch.**
- **Uso**: Recebe atualizações e tags oficiais via `git fetch upstream` e `git merge --ff-only upstream/main` (ou checkout da próxima tag estável).

### 🌿 Branch `personal`
- **Papel**: Branch principal de trabalho e integração de Carl.
- **Origem**: Criada a partir de `upstream-sync` no ponto da tag `v2.5.0`.
- **Conteúdo**: Abriga as melhorias, widgets e correções personalizadas da shell, mantidas em commits semânticos isolados (ex.: popout de calendário, abas Data Link e Transfer, controles OSD de som e filtros).

---

## 3. Remotes Configurados

| Remote | URL | Descrição |
| --- | --- | --- |
| `origin` | `https://github.com/carl-dourado/caelestia-shell.git` | Fork pessoal no GitHub |
| `upstream` | `https://github.com/caelestia-dots/shell.git` | Repositório oficial do Caelestia Shell |

---

## 4. Divisão de Responsabilidades com `caelestia-personal`

Para manter o código limpo e permitir fácil atualização com versões futuras do Caelestia:

1. **`caelestia-shell` (este repositório)**:
   - Código QML nativo da shell (`modules/`, `services/`, `components/`, `assets/`, `utils/`).
   - Popouts de barra (ex.: calendário interativo).
   - Abas do Dashboard (ex.: Data Link e Transfer).
   - Sliders e seletores do OSD (brilho, cor, áudio).
   - Tratamento de geometria e render loop do Quickshell.

2. **`caelestia-personal` (repositório irmão)**:
   - Configurações do Hyprland (`hypr/`).
   - Daemons em C (`daemons/` para brilho Wayland e filtros CTM).
   - Scripts e utilitários auxiliares (`scripts/` para `ddcutil`, `audio-output`, etc.).
   - Unidades supervisionadas (`systemd/` user units).
   - Automações de instalação e documentação geral do sistema.

---

## 5. Próximos Passos de Migração

As 20 customizações auditadas serão portadas em etapas modulares planejadas:
1. `fix(core)`: Ajustes base de render loop e sanitização geométrica.
2. `feat(hardware)`: Sliders OSD e serviços de hardware (brilho por software e CTM).
3. `feat(audio)`: Troca rápida de saídas de som e migração automática de streams.
4. `feat(bar)`: Relógio interativo com popout de calendário e suporte PT-BR.
5. `feat(dashboard)`: Abas de monitoramento Data Link e Transfer.
