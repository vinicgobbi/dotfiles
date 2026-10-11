#!/usr/bin/env bash
# Instala e configura, a partir deste repo, todo o ambiente de shell:
# Oh My Zsh (se ausente), plugins (zsh-autosuggestions, zsh-syntax-highlighting,
# zoxide), tema, arquivos custom do Zsh, fontes, config do Solaar e o passo
# de volume do GNOME. Idempotente: pode rodar quantas vezes quiser.
# O papel de parede é escolhido e aplicado pelo post-install.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ZSHRC="$HOME/.zshrc"
DESIRED_PLUGINS="plugins=(git zsh-autosuggestions zoxide zsh-syntax-highlighting)"
DESIRED_THEME='ZSH_THEME="detail"'
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

echo "==> Oh My Zsh"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "  - já instalado, pulando"
else
  echo "  - instalando"
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

clone_plugin() {
  local name="$1"
  local url="$2"
  local dest="$ZSH_CUSTOM/plugins/$name"
  if [[ -d "$dest" ]]; then
    echo "  - $name já instalado, pulando"
  else
    echo "  - clonando $name"
    git clone --depth 1 "$url" "$dest"
  fi
}

echo "==> Plugins do Zsh"
clone_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
clone_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting"

echo "==> zoxide"
if command -v zoxide >/dev/null 2>&1; then
  echo "  - zoxide já instalado, pulando"
else
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi

echo "==> Copiando arquivos deste repo para o ambiente do usuário"
mkdir -p "$ZSH_CUSTOM" "$HOME/.local/share/fonts" "$HOME/.config/solaar"
cp -r "$SCRIPT_DIR/oh-my-zsh/custom/"* "$ZSH_CUSTOM/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/fonts/"* "$HOME/.local/share/fonts/" 2>/dev/null || true
cp -r "$SCRIPT_DIR/config/solaar/"* "$HOME/.config/solaar/" 2>/dev/null || true
command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts" >/dev/null

echo "==> Configurando ~/.zshrc"
if [[ ! -f "$ZSHRC" ]]; then
  echo "  - ~/.zshrc não encontrado, pulando (ajuste manualmente depois)"
else
  cp "$ZSHRC" "$ZSHRC.bak"

  if grep -qF "$DESIRED_PLUGINS" "$ZSHRC"; then
    echo "  - plugins já configurados"
  elif grep -q '^plugins=(' "$ZSHRC"; then
    sed -i "s/^plugins=(.*)/$DESIRED_PLUGINS/" "$ZSHRC"
    echo "  - linha plugins=() atualizada"
  else
    echo "  - linha plugins=() não encontrada, adicione manualmente:"
    echo "    $DESIRED_PLUGINS"
  fi

  if grep -qF "$DESIRED_THEME" "$ZSHRC"; then
    echo "  - tema já configurado"
  elif grep -q '^ZSH_THEME=' "$ZSHRC"; then
    sed -i "s/^ZSH_THEME=.*/$DESIRED_THEME/" "$ZSHRC"
    echo "  - tema atualizado para detail"
  else
    echo "  - linha ZSH_THEME não encontrada, adicione manualmente:"
    echo "    $DESIRED_THEME"
  fi

  if grep -qF "$PATH_LINE" "$ZSHRC"; then
    echo "  - PATH do ~/.local/bin já configurado"
  elif grep -q '^export ZSH=' "$ZSHRC"; then
    # precisa vir ANTES do "source \$ZSH/oh-my-zsh.sh", senão o plugin zoxide
    # não encontra o binário na hora de carregar
    sed -i "/^export ZSH=/a\\
\\
$PATH_LINE" "$ZSHRC"
    echo "  - PATH do ~/.local/bin adicionado"
  else
    echo "  - não achei 'export ZSH=' no ~/.zshrc, adicione manualmente antes do 'source \$ZSH/oh-my-zsh.sh':"
    echo "    $PATH_LINE"
  fi

  if diff -q "$ZSHRC" "$ZSHRC.bak" >/dev/null 2>&1; then
    rm -f "$ZSHRC.bak"
  else
    echo "  - backup do ~/.zshrc original salvo em $ZSHRC.bak"
  fi
fi

# Rodando via "su - usuario" (como no post-install), não há sessão D-Bus no
# ambiente e o gsettings grava num backend em memória, descartando tudo sem
# erro. Se o usuário tem uma sessão gráfica aberta, usa o barramento dela.
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "/run/user/$(id -u)/bus" ]]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
fi

echo "==> Passo de volume"
# A roda lateral do mouse (regras do Solaar) envia as teclas de volume, então
# quem muda o volume e mostra o OSD é o próprio GNOME; aqui só ajustamos o
# passo de cada toque para 2%.
if command -v gsettings >/dev/null 2>&1 &&
  gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 2 2>/dev/null; then
  echo "  - passo de volume do GNOME definido para 2%"
else
  echo "  - gsettings indisponível (não é GNOME), pulando"
fi

echo
echo "Tudo pronto. Reinicie o shell com: exec zsh"
