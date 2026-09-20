# Dotfiles

Minhas configurações pessoais, organizadas e versionadas em um único lugar.

Este repositório reúne configs de terminal, shell, aplicativos e ferramentas que uso no dia a dia — a ideia é ter um ponto único de referência para reaproveitar e sincronizar essas configurações onde quer que eu esteja trabalhando.

## Estrutura

- `config/` — configurações ativas dos apps do dia a dia (sway, waybar,
  swaylock, alacritty, fuzzel, wlogout, dunst, cava, flameshot, nwg-look,
  solaar). As configs do Omarchy (Hyprland e omarchy-shell) ficam em
  `post_omarchy/dots/`
- `legacy/` — setups antigos mantidos só como referência (i3 + polybar,
  tema pywal/xrdb), não usados nem instalados por nenhum script deste repo
- `oh-my-zsh/custom/` — aliases, plugins e temas personalizados para o Zsh
- `oh-my-posh/` — réplica do setup do Zsh (tema, aliases e editor padrão) para PowerShell no Windows
- `fonts/` — fontes utilizadas nas configurações
- `Wallpapers/` — papéis de parede
- `etc/` — arquivos de configuração diversos
- `bootstrap.sh` — instala Oh My Zsh (se ausente), os plugins do Zsh
  (`zsh-autosuggestions`, `zsh-syntax-highlighting`, `zoxide`), aplica o tema
  e os arquivos de `oh-my-zsh/custom/`, copia fontes e a config do Solaar, e
  define o papel de parede (GNOME). Idempotente — pode rodar quantas vezes
  quiser. É o script usado tanto localmente quanto pelo módulo
  `ambiente_usuario` do [post_install](https://github.com/vinicgobbi/post_install).
- `install-sway.sh` — instala o Sway e todo o ecossistema (waybar, swaylock,
  fuzzel, wlogout, dunst, cava, flameshot) e copia as respectivas configs
  para `~/.config`, resolvendo caminhos como o wallpaper e o savePath do
  flameshot via XDG (`xdg-user-dirs`) em vez de caminho fixo na home.
  Idempotente.
- `post-install.sh` — post-install completo para Arch Linux, baseado no
  projeto [post_install](https://github.com/vinicgobbi/post_install) porém
  via `pacman`/AUR (`yay`): mirrors, atualização do sistema, Docker, PHP +
  ferramental de SQL Server, Solaar, Flatpaks, Tailscale, Chrome + Git
  Credential Manager, Bitwarden, todo o Sway (chama `install-sway.sh`), o
  ambiente do usuário (chama `bootstrap.sh`), Rust tools, Claude Code,
  extensões do VSCode e de copiar caminho no Nautilus, perfis OpenVPN (`.ovpn` em `OVPN/`) e
  virt-manager. Não instala jogos (Steam/Heroic/ProtonPlus/PrismLauncher) de
  propósito. Idempotente — pode rodar sozinho ou como próximo passo depois
  do `install-sway.sh`.
- `OVPN/` — perfis `.ovpn` a importar pelo `post-install.sh` (não
  versionados, veja `OVPN/README.md`)

## Foto

![Captura da tela](./print.png)
