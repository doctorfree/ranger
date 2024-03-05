#!/usr/bin/env bash
#

install_external_package() {
  API_URL="https://api.github.com/repos/${OWNER}/${PROJECT}/releases/latest"
  DL_URL=
  DL_URL=$(curl --silent ${AUTH_HEADER} "${API_URL}" \
    | jq --raw-output '.assets | .[]?.browser_download_url' \
    | grep "amd64\.deb")

  [ "${DL_URL}" ] && {
    printf "\n\tInstalling %s ..." "${PROJECT}"
    TEMP_DEB="$(mktemp --suffix=.deb)"
    wget --quiet -O "${TEMP_DEB}" "${DL_URL}"
    chmod 644 "${TEMP_DEB}"
    sudo apt-get install -y "${TEMP_DEB}"
    rm -f "${TEMP_DEB}"
    printf " done"
  }
}

install_go() {
  curl --silent --location --output /tmp/go.tgz \
       https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
  [ -d /usr/local ] || sudo mkdir -p /usr/local
  sudo tar -C /usr/local -xf /tmp/go.tgz
  rm -f /tmp/go.tgz
}

install_obs() {
  API_URL="https://api.github.com/repos/Yakitrak/obsidian-cli/releases/latest"
  DL_URL=
  DL_URL=$(curl --silent ${AUTH_HEADER} "${API_URL}" \
    | jq --raw-output '.assets | .[]?.browser_download_url' \
    | grep "obsidian-cli" | grep "linux_amd64\.tar\.gz")

  [ "${DL_URL}" ] && {
    printf "\n\tInstalling OBS ..."
    TEMP_TGZ="$(mktemp --suffix=.tgz)"
    wget --quiet -O "${TEMP_TGZ}" "${DL_URL}"
    chmod 644 "${TEMP_TGZ}"
    [ -d /usr/local ] || sudo mkdir -p /usr/local
    [ -d /usr/local/bin ] || sudo mkdir -p /usr/local/bin
    sudo tar -C /usr/local/bin -xf "${TEMP_TGZ}"
    sudo rm -f "${TEMP_TGZ}" /usr/local/bin/LICENSE /usr/local/bin/README.md
    # We run through hoops because the maintainer has not changed the name of
    # the command even though it conflicts with OBS Studio but he might do so.
    # We need it to be 'obs-cli'
    if [ -f /usr/local/bin/obs ]; then
      sudo mv /usr/local/bin/obs /usr/local/bin/obs-cli
      sudo chmod 755 /usr/local/bin/obs-cli
    else
      if [ -f /usr/local/bin/obs-cli ]; then
        sudo chmod 755 /usr/local/bin/obs-cli
      else
        for cli in /usr/local/bin/obs*
        do
          [ "${cli}" == "/usr/local/bin/obs*" ] && continue
          sudo ln -s "${cli}" /usr/local/bin/obs-cli
          break
        done
      fi
    fi
    printf " done"
  }
}

if [ -d ${HOME}/bin ]; then
  cp bin/* ${HOME}/bin
else
  cp -a bin ${HOME}/bin
fi

[ -d ${HOME}/.config/ranger ] || mkdir -p ${HOME}/.config/ranger
cp commands_full.py commands.py rc.conf rifle.conf scope.sh ${HOME}/.config/ranger
chmod 755 ${HOME}/.config/ranger/*.sh
if [ -d ${HOME}/.config/ranger/plugins ]; then
  for plug in zoxide ranger-fzf-filter ranger_devicons
  do
    if [ -d ${HOME}/.config/ranger/plugins/${plug} ]; then
      cp plugins/${plug}/* ${HOME}/.config/ranger/plugins/${plug}
    else
      cp -a plugins/${plug} ${HOME}/.config/ranger/plugins
    fi
  done
else
  cp -a plugins ${HOME}/.config/ranger
fi

find share -type f | while read i
do
  [ -f ${HOME}/.local/$i ] || {
    j=$(dirname $i)
    [ -d ${HOME}/.local/$j ] || mkdir -p ${HOME}/.local/$j
    cp $i ${HOME}/.local/$j
  }
done

# GH_TOKEN, a GitHub token must be set in the environment
# If it is not already set then the convenience build script will set it
if [ "${GH_TOKEN}" ]; then
  export GH_TOKEN="${GH_TOKEN}"
else
  export GH_TOKEN="__GITHUB_API_TOKEN__"
fi
# Check to make sure
echo "${GH_TOKEN}" | grep __GITHUB_API | grep __TOKEN__ > /dev/null && {
  # It didn't get set right, unset it
  export GH_TOKEN=
}

if [ "${GH_TOKEN}" ]; then
  AUTH_HEADER="-H \"Authorization: Bearer ${GH_TOKEN}\""
else
  AUTH_HEADER=
fi

install_go
install_obs

OWNER=obsidianmd
PROJECT=obsidian-releases
install_external_package

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"

/usr/local/go/bin/go install github.com/charmbracelet/glow@latest
git clone https://github.com/doctorfree/cheat-sheets-plus ${HOME}/Documents/cheat-sheets-plus
tar xzf ${HOME}/.config/obsidian.tar.gz -C ${HOME}/.config
rm -f ${HOME}/.config/obsidian.tar.gz
tar xzf ${HOME}/.config/dotobsidian.tar.gz -C ${HOME}/Documents/cheat-sheets-plus
rm -f ${HOME}/.config/dotobsidian.tar.gz
have_mime=$(type -p xdg-mime)
[ "${have_mime}" ] && xdg-mime default obsidian.desktop x-scheme-handler/obsidian
/usr/local/bin/obs-cli set-default cheat-sheets-plus
