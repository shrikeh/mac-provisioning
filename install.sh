#!/usr/bin/env bash
# Colour _echo to make it easier to read
function _echo () {
  {
    blue=$(tput setaf 4)
    normal=$(tput sgr0)
    \printf "\n%40s\n\n" "${blue} ${1} ${normal}";
    clrstdin;
    return 0;
  } <&-
}

# Confirm if a command exists
function command_exists () {
    \command -v ${1} > /dev/null 2>&1 || {
      return 1;
    }
}
# Clear out stdin before taking fresh input
function clrstdin () {
  \read -d '' -t 0 -n 10000
  return 0;
}

# Are we being run as a normal bash script or being piped?
if [ -n "$1" ]; then
  exec <"$1"
elif tty >/dev/null; then
  NON_INTERACTIVE=false
# else we're reading from a file or pipe
else
  NON_INTERACTIVE=true
fi

# Substitute echo for our _echo
ECHO=_echo

 if [[ $EUID = 0 ]]; then
   ${ECHO} "Script is running with sudo" 1>&2;
   BASE_USER=${SUDO_USER}
   ROOT_PRIVS=true
 else
   BASE_USER=${USER}
   ROOT_PRIVS=false
 fi



echo $branch
REPO_BRANCH=${branch:-"master"}
${ECHO} ${REPO_BRANCH}


# The URI of the repo to get hold of the CLT from
REPO_URI="https://github.com/shrikeh/mac-provisioning/archive/${REPO_BRANCH}.zip";

ZIP_TARGET="${HOME}/Downloads/mac-provisioning.zip"

LOCAL_REPO_DIR="${HOME}/Downloads/mac-provisioning-${REPO_BRANCH}"

COMPOSER_TARGET="/usr/local/bin/composer"
SSH_PARANOIA=2048
OSX_GCC_TARGET=${4:-"/"}
FORCE_INSTALL=""

while (( $# > 0 ))
do
  token="${1}"
  shift
  case "${token}" in
    --non-interactive)
      AUTH_NON_INTERACTIVE=true
      ;;
    --force-installs)
       FORCE_INSTALL="--force"
      ;;
    --branch|branch)
      if [[ -n "${1:-}" ]];
      then
        version="head"
        branch="${1}"
        shift
      else
        fail "--branch must be followed by a branch name."
      fi
      ;;
    --generate-ssh-key)
      GENERATE_SSH_KEY=true
    ;;
    --user)
      if [[ -n "${1:-}" ]];
      then
        BASE_USER="${1}"
        shift
      else
        fail "--user must be followed by a user name."
      fi
      ;;
    --user)
  esac
done

if ${NON_INTERACTIVE}; then
  ${ECHO} "Running in non-interactive mode"
  if ! ${ROOT_PRIVS}; then
    ${ECHO} "You are running this non-interactively but without sudo, which can't happen. Exiting."
    exit 1;
  fi
else
  clrstdin
  ${ECHO} "Welcome to the Mac provisioning script. Press [ENTER] to continue"
  \read -r

  {
    ${ECHO} "This script requires sudo privileges. You will be prompted for your password. Do you wish to continue?";
  } <&-

  while \read -e -r -n 1 answer; do
    if [[ ${answer} = [YyNn] ]]; then
      if [[ ! ${answer} =~ ^[Yy]$ ]]; then
        ${ECHO} "You selected ${answer} so exiting"
        exit 1;
      fi
      break;
    fi
  done
fi

{
  if [[ ! -e ${ZIP_TARGET} ]]; then
    ${ECHO} "Downloading Mac OSX Command Tools for Mountain Lion"
    \curl -fsSL -o ${ZIP_TARGET} ${REPO_URI};
  fi
  ${ECHO} "Unzipping Command line tools into your Downloads dir"
  \unzip -o ${ZIP_TARGET} -d ${HOME}/Downloads;
  ${ECHO} "Installing command line tools, please wait..."
  sudo installer -pkg ${LOCAL_REPO_DIR}/clt/clt-ml.pkg -target ${OSX_GCC_TARGET};
  ${ECHO} "CLT installed"
} <&-

${ECHO} "OK, on with the show..."
# Show all hidden files on a mac
${ECHO} "Making all hidden files visible in Finder"
defaults write com.apple.Finder AppleShowAllFiles YES

if ! ${NON_INTERACTIVE}; then
  ${ECHO} "Do you wish to generate a new SSH key?";
  clrstdin
  while \read -r -n 1 -s answer; do
    if [[ ${answer} = [YyNn] ]]; then
      if [[ ${answer} =~ ^[Yy]$ ]]; then
        GENERATE_SSH_KEY=true
      else
        GENERATE_SSH_KEY=false
      fi
      break;
    fi
  done
fi
{
  if ${GENERATE_SSH_KEY}; then
    #ssh-keygen -t rsa -b ${SSH_PARANOIA} -N "" -f ${HOME}/.ssh/id_rsa;
    ${ECHO} "New ssh key generated with ${SSH_PARANOIA} bits and no passphrase"
  fi

  # Get hold of Ruby
  if command_exists "rvm"; then
    ${ECHO} "Existing RVM found , moving on";
  else
    ${ECHO} "Getting hold of latest stable Ruby RVM";
    \curl -L https://get.rvm.io | bash -s stable --autolibs=read-fail --auto-dotfiles;
    source ~/.rvm/scripts/rvm;

    rvm install ruby;
    type rvm | head -1;
    ${ECHO} "RVM installed"
  fi

  # Get hold of Homebrew
  if command_exists "brew"; then
    ${ECHO} "Detected existing install of Homebrew, moving on...";
  else
    ${ECHO} "Getting Homebrew";
    ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)";
  fi;

  rvm autolibs homebrew;

  ${ECHO} "Installing Heroku (gives you Git etc)";
  brew install ${FORCE_INSTALL} heroku-toolbelt;
} <&-

{
  brew install ${FORCE_INSTALL} wget libksba autoconf gmp4 gmp mpfr mpc automake;

  # Python
  ${ECHO} "Installing python"
  brew install ${FORCE_INSTALL} python --framework;
  export PATH=/usr/local/share/python:$PATH
  
  pip install virtualenv virtualenvwrapper yaml shyaml;

  ${ECHO} "Installing autossh, mosh, and ssh-copy-id";
  brew install ${FORCE_INSTALL} autossh mobile-shell ssh-copy-id

  ${ECHO} "Getting zsh"
  brew install zsh zsh-completions;
  curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh
  echo "fpath=(/usr/local/share/zsh-completions \$fpath)" >> ${HOME}/.zshrc


  ${ECHO} "Installing slick git tools";
  brew install ${FORCE_INSTALL} gist hub hubflow
  pip install git_sweep
} <&-

if [ ! -f ${HOME}/.config/hub ]; then
  mkdir ${HOME}/.config
  touch ${HOME}/.config/hub
fi

if ! ${NON_INTERACTIVE}; then
  ${ECHO} "Configuring git"
  
  if ! git config user.email; then
    ${ECHO} "Please input your email address"
    clrstdin
    \read -r GIT_EMAIL
  fi
  if ! git config user.name; then
    ${ECHO} "Please input your first and last name";
    clrstdin
    while \read -r first_name last_name; do
      GIT_NAME="${first_name} ${last_name}"
    done;
  fi;
  ${ECHO} "Please input your github username"
  while \read -r username; do
    GIT_USERNAME=${username}
  done
fi;

git config --global core.autocrlf input
git config --global user.email "${GIT_EMAIL}";
git config --global user.name "${GIT_NAME}";

echo "github.com: \n  - user: ${GIT_USERNAME}" > ${HOME}/.config/hub
echo "eval \"\$(hub alias -s)\"" >> ${HOME}/.zshrc

{
  ${ECHO} "Installing PHP..."
  brew untap homebrew/dupes
  brew untap josegonzalez/homebrew-php
  brew untap josegonzalez/php

  brew tap homebrew/dupes
  brew tap josegonzalez/homebrew-php
  brew tap josegonzalez/php

  brew update
  brew install ${FORCE_INSTALL} php55 php55-xhprof php55-xdebug composer

  echo "export PATH=\"\$(brew --prefix php55)/bin:$PATH\"" >> ${HOME}/.zshrc

  source ${HOME}/.zshrc

  # Get hold of cask
  ${ECHO} "Installing Cask"
  brew untap phinze/homebrew-cask;
  brew tap phinze/homebrew-cask;
  brew update;
  brew install ${FORCE_INSTALL} brew-cask;
  brew update;

  #Iterate through the manifest and install everything in there.

  ${ECHO} "Reading through the Cask manifest"
} <&-

while read app; do
  ${ECHO} "Installing ${app}"
  brew cask ${FORCE_INSTALL} install ${app};
done < ${LOCAL_REPO_DIR}/manifest.txt

brew linkapps;
brew cask alfred link;

${ECHO} "Job done"
