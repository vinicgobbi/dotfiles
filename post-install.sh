#!/usr/bin/env bash
# Post-install completo para Arch Linux, a partir deste repo: mirrors,
# atualização do sistema, pacotes base (Docker, PHP, VSCode, ferramentas de
# SQL Server), Solaar, Flatpaks (sem jogos), Tailscale, Chrome + Git
# Credential Manager, Bitwarden, todo o ambiente Sway (waybar, swaylock,
# fuzzel, wlogout, dunst, cava, flameshot — via install-sway.sh), o ambiente
# de usuário (zsh/Oh My Zsh/fnm via bootstrap.sh), Rust tools, Claude Code,
# extensões do VSCode e de copiar caminho no Nautilus, importação de perfis OpenVPN e
# virt-manager (QEMU/KVM). Baseado no projeto post_install
# (https://github.com/vinicgobbi/post_install), portado para pacman/AUR —
# NÃO instala nada de jogos (Steam/Heroic/ProtonPlus/PrismLauncher) de
# propósito. Idempotente: pode rodar quantas vezes quiser.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

aviso() { echo "  [aviso] $1" >&2; }

if [[ "$EUID" -eq 0 ]]; then
  echo "Não rode este script como root. Rode como seu usuário normal;" >&2
  echo "o sudo será pedido quando necessário." >&2
  exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "Este script é para Arch Linux (ou derivadas com pacman)." >&2
  exit 1
fi

# Autentica o sudo uma vez no início para não interromper o fluxo pedindo
# senha no meio de alguma seção mais longa.
sudo -v

# Instala um pacote AUR se ainda não estiver instalado; em caso de falha
# (pacote descontinuado, PKGBUILD quebrado etc.) só avisa e segue o script
# em vez de abortar tudo.
install_aur_best_effort() {
  local pkg
  for pkg in "$@"; do
    if yay -Qi "$pkg" >/dev/null 2>&1; then
      echo "  - $pkg já instalado, pulando"
    elif yay -S --needed --noconfirm "$pkg"; then
      echo "  - $pkg instalado"
    else
      aviso "Falha ao instalar '$pkg' via AUR — pulando."
    fi
  done
}

echo "==> Helper de AUR (yay)"
if command -v yay >/dev/null 2>&1; then
  echo "  - yay já instalado, pulando"
else
  echo "  - yay não encontrado, instalando"
  sudo pacman -S --needed base-devel git
  BUILD_DIR="$(mktemp -d)"
  git clone --depth 1 https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
  (cd "$BUILD_DIR/yay" && makepkg -si)
  rm -rf "$BUILD_DIR"
fi

echo "==> Mirrors (reflector)"
sudo pacman -S --needed reflector
if [[ ! -f /etc/pacman.d/mirrorlist.bak ]]; then
  sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
fi
# Ajuste --country se estiver rodando fora do Brasil
if sudo reflector --country Brazil --latest 10 --protocol https --sort rate \
    --save /etc/pacman.d/mirrorlist; then
  echo "  - mirrorlist atualizada com os espelhos mais rápidos"
else
  aviso "reflector falhou (sem rede?); mantendo a mirrorlist atual."
fi

echo "==> Atualização do sistema"
sudo pacman -Syu

echo "==> Pacotes base"
sudo pacman -S --needed docker docker-compose php composer zsh git curl jq bat unixodbc

echo "  - AUR: VSCode e ferramental de SQL Server (best-effort)"
install_aur_best_effort visual-studio-code-bin msodbcsql mssql-tools

# Em algumas distros o pacote "bat" instala o binário como "batcat"; no Arch
# já é nativamente "bat", mas mantemos a checagem por segurança.
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
fi

echo "==> Extensões PHP para SQL Server (sqlsrv/pdo_sqlsrv)"
if pacman -Qi msodbcsql >/dev/null 2>&1; then
  install_aur_best_effort php-sqlsrv php-pdo_sqlsrv
  if ! php -m 2>/dev/null | grep -qi '^sqlsrv$'; then
    echo "extension=sqlsrv.so" | sudo tee /etc/php/conf.d/99-sqlsrv.ini >/dev/null
  fi
  if ! php -m 2>/dev/null | grep -qi '^pdo_sqlsrv$'; then
    echo "extension=pdo_sqlsrv.so" | sudo tee /etc/php/conf.d/99-pdo_sqlsrv.ini >/dev/null
  fi
else
  aviso "msodbcsql não instalado — pulando extensões PHP sqlsrv/pdo_sqlsrv."
fi

echo "==> Solaar"
sudo pacman -S --needed solaar
getent group plugdev >/dev/null || sudo groupadd plugdev
sudo usermod -aG plugdev "$USER"
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb
sudo udevadm trigger --subsystem-match=hidraw

echo "==> Flatpaks"
sudo pacman -S --needed flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
FLATPAKS=(
  com.getpostman.Postman com.github.tchx84.Flatseal
  com.mattjakeman.ExtensionManager com.mikrotik.WinBox
  com.obsproject.Studio com.spotify.Client dev.vencord.Vesktop
  io.dbeaver.DBeaverCommunity io.ente.auth io.github.flattool.Ignition io.github.flattool.Warehouse
  io.missioncenter.MissionCenter md.obsidian.Obsidian
  org.filezillaproject.Filezilla org.gaphor.Gaphor org.gnome.Boxes
  org.libreoffice.LibreOffice org.onlyoffice.desktopeditors org.qbittorrent.qBittorrent
  org.remmina.Remmina org.telegram.desktop org.videolan.VLC me.iepure.devtoolbox
)
flatpak install -y flathub "${FLATPAKS[@]}"

echo "==> Tailscale"
sudo pacman -S --needed tailscale
sudo systemctl enable --now tailscaled
flatpak install -y flathub dev.deedles.Trayscale
sudo tailscale set --operator="$USER"

echo "==> Chrome + Git Credential Manager"
install_aur_best_effort google-chrome git-credential-manager-bin

echo "==> Bitwarden"
install_aur_best_effort bitwarden-bin

echo "==> Sway (waybar, swaylock, fuzzel, wlogout, dunst, cava, flameshot)"
bash "$SCRIPT_DIR/install-sway.sh"

echo "==> Ambiente do usuário (zsh, Oh My Zsh, fnm, dotfiles)"
bash "$SCRIPT_DIR/bootstrap.sh"

sudo usermod -aG docker "$USER"
sudo chsh -s "$(command -v zsh)" "$USER"

if command -v git-credential-manager >/dev/null 2>&1; then
  git-credential-manager configure
  git config --global credential.credentialStore secretservice
else
  aviso "git-credential-manager não encontrado — pulando 'configure' (AUR pode ter falhado acima)."
fi

echo "  - fnm + Node LTS"
if [[ ! -d "$HOME/.local/share/fnm" ]]; then
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env --shell bash)"
fnm install --lts
fnm default "$(fnm current)"
if ! grep -qF 'fnm env --shell zsh' "$HOME/.zshrc" 2>/dev/null; then
  {
    echo 'export PATH="$HOME/.local/share/fnm:$PATH"'
    echo 'eval "$(fnm env --shell zsh)"'
  } >> "$HOME/.zshrc"
fi

echo "  - Diretório de Projetos"
if [[ "${LANG:-}" == pt_* ]]; then
  DIR_NAME="Projetos"
else
  DIR_NAME="Projects"
fi
PROJECTS_DIR="$HOME/$DIR_NAME"
mkdir -p "$PROJECTS_DIR"
command -v xdg-user-dirs-update >/dev/null 2>&1 && xdg-user-dirs-update --set PROJECTS "$PROJECTS_DIR"

BOOKMARKS_FILE="$HOME/.config/gtk-3.0/bookmarks"
mkdir -p "$(dirname "$BOOKMARKS_FILE")"
touch "$BOOKMARKS_FILE"
grep -qF "file://$PROJECTS_DIR" "$BOOKMARKS_FILE" || echo "file://$PROJECTS_DIR" >> "$BOOKMARKS_FILE"

echo "  - Autostart do Solaar"
mkdir -p "$HOME/.config/autostart"
cp /usr/share/applications/solaar.desktop "$HOME/.config/autostart/" 2>/dev/null || true

echo "==> Rust tools (rustup, eza, topgrade)"
sudo pacman -S --needed rustup eza
rustup default stable
if ! pacman -Qi topgrade >/dev/null 2>&1 && ! sudo pacman -S --needed --noconfirm topgrade; then
  install_aur_best_effort topgrade
fi

echo "==> Claude Code"
curl -fsSL https://claude.ai/install.sh | bash

echo "==> Extensões do Nautilus (VSCode e copiar caminho)"
sudo pacman -S --needed nautilus-python wl-clipboard xclip
rm -rf /tmp/vscode_nautilus
git clone https://github.com/vinicgobbi/vscode_nautilus.git /tmp/vscode_nautilus
bash /tmp/vscode_nautilus/install.sh
rm -rf /tmp/nautilus-copypath
git clone https://github.com/vinicgobbi/nautilus-copypath.git /tmp/nautilus-copypath
bash /tmp/nautilus-copypath/install.sh

echo "==> Perfis OpenVPN"
sudo pacman -S --needed networkmanager-openvpn
OVPN_DIR="$SCRIPT_DIR/OVPN"
if [[ -d "$OVPN_DIR" ]] && compgen -G "$OVPN_DIR/*.ovpn" > /dev/null; then
  for arquivo in "$OVPN_DIR"/*.ovpn; do
    nome="$(basename "$arquivo" .ovpn)"

    # Reimportar do zero para o script continuar idempotente em reexecuções.
    if nmcli -g NAME connection show | grep -Fxq "$nome"; then
      nmcli connection delete "$nome" > /dev/null
    fi

    if ! nmcli connection import type openvpn file "$arquivo" > /dev/null; then
      aviso "Falha ao importar $arquivo, pulando."
      continue
    fi

    dns=$(grep -oP '^\s*dhcp-option\s+DNS\s+\K\S+' "$arquivo" | paste -sd ' ' -)
    dominios=$(grep -oP '^\s*dhcp-option\s+DOMAIN(-SEARCH)?\s+\K\S+' "$arquivo" | paste -sd ' ' -)

    [[ -n "$dns" ]] && nmcli connection modify "$nome" ipv4.dns "$dns"
    [[ -n "$dominios" ]] && nmcli connection modify "$nome" ipv4.dns-search "$dominios"

    echo "  - perfil '$nome' importado"
  done
else
  echo "  - nenhum .ovpn em $OVPN_DIR, pulando importação"
fi

echo "==> virt-manager (QEMU/KVM)"
if ! grep -qE 'vmx|svm' /proc/cpuinfo; then
  aviso "CPU sem suporte a virtualização por hardware (VT-x/AMD-V) ou não habilitado na BIOS/UEFI — o KVM pode não funcionar."
fi
sudo pacman -S --needed qemu-desktop libvirt virt-install virt-manager dnsmasq
sudo systemctl enable --now libvirtd
for grupo in libvirt kvm; do
  getent group "$grupo" >/dev/null && sudo usermod -aG "$grupo" "$USER"
done

echo "==> Limpeza final"
sudo pacman -Sc --noconfirm
mapfile -t ORFAOS < <(pacman -Qtdq 2>/dev/null || true)
if [[ "${#ORFAOS[@]}" -gt 0 ]]; then
  sudo pacman -Rns --noconfirm "${ORFAOS[@]}"
fi
yay -Sc --noconfirm

echo
echo "Tudo pronto! Recomenda-se reiniciar (ou pelo menos reabrir a sessão)"
echo "para os grupos (docker/libvirt/kvm/plugdev) e o shell (zsh) valerem,"
echo "e selecionar 'Sway' na tela de login."
