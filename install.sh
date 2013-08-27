#!/usr/bin/env bash
# Colour _echo to make it easier to read
function _echo () {
  {
    blue=$(tput setaf 4)
    normal=$(tput sgr0)
    \printf "\n%40s\n\n" "${blue} ${1} ${normal}";
    return 0;
  } <&-
}

function command_exists () {
    \command -v ${1} > /dev/null 2>&1 || {
      return 1;
    }
}

function clrstdin () {
  \read -d '' -t 1 -n 10000
}

ECHO=_echo
REPO_BRANCH=${1:-"master"}

REPO_URI=${2:-"https://github.com/shrikeh/mac-provisioning/archive/${REPO_BRANCH}.zip"}
ZIP_TARGET=${3:-"${HOME}/Downloads/mac-provisioning.zip"}
LOCAL_REPO_DIR=${4:-"${HOME}/Downloads/mac-provisioning-${REPO_BRANCH}"}
COMPOSER_TARGET="/usr/local/bin/composer"
SSH_PARANOIA=2048
OSX_GCC_TARGET=${4:-"/"}
clrstdin
${ECHO} "Welcome to the Mac provisioning script. Press [ENTER] to continue"
\read -r

# Check we aren't runniing as root as this will mess everything up
if [[ $EUID = 0 ]]; then
   ${ECHO} "This script must not be run as root" 1>&2;
   exit 1;
fi
{
  ${ECHO} "This script requires sudo privileges. You will be prompted for your password. Do you wish to continue?";
} <&-
clrstdin

while \read -r -n 1 answer; do
  if [[ ${answer} = [YyNn] ]]; then
    if [[ ! ${answer} =~ ^[Yy]$ ]]; then
      ${ECHO} "You selected ${answer} so exiting"
      exit 1;
    fi
    break;
  fi
done

${ECHO} "OK, on with the show..."
# Show all hidden files on a mac
$ECHO "Making all hidden files visible in Finder"
defaults write com.apple.Finder AppleShowAllFiles YES

${ECHO} "Do you wish to generate a new SSH key?";
clrstdin
while \read -r -n 1 -s answer; do
  if [[ ${answer} = [YyNn] ]]; then
    if [[ ${answer} =~ ^[Yy]$ ]]; then
      ssh-keygen -t rsa -b ${SSH_PARANOIA} -N "" -f ${HOME}/.ssh/id_rsa;
      $ECHO "New ssh key generated with ${SSH_PARANOIA} bits and no passphrase"
    fi
    break;
  fi
done


# Is this running remotely (i.e. with curl and piped to sh) or has this been downloaded?
# If not downloaded, we need to get the rest of the archive
# @todo: check locally if we are in a folder containing the CLT
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
    $ECHO "Detected existing install of Homebrew, moving on...";
  else
    $ECHO "Getting Homebrew";
    ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)";
  fi;

  rvm autolibs homebrew;

  ${ECHO} "Installing Heroku (gives you Git etc)";
  brew install heroku-toolbelt;

  ${ECHO} "Configuring git"
  git config --global core.autocrlf input
} <&-
if ! git config user.email; then
  ${ECHO} "Please input your email address"
  clrstdin
  while \read -r email; do
    git config --global user.email ${email};
  done;
fi
if ! git config user.name; then
  ${ECHO} "Please input your first and last name";
  clrstdin
  while \read -r first_name last_name; do
    git config --global user.name "${first_name} ${last_name}";
  done;
fi;

{
  brew install wget libksba autoconf gmp4 gmp mpfr mpc automake;

  # Python
  ${ECHO} "Installing python"
  brew install python;
  pip install virtualenv virtualenvwrapper shyaml;

  ${ECHO} "Installing ssh-copy-id";
  brew install ssh-copy-id

  ${ECHO} "Getting zsh"
  brew install zsh zsh-completions;
  curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh
  echo "fpath=(/usr/local/share/zsh-completions \$fpath)" >> ${HOME}/.zshrc


  ${ECHO} "Installing slick git tools";
  brew install gist hub hubflow
  pip install git_sweep
} <&-

if [ ! -f ${HOME}/.config/hub ]; then
  $ECHO "Please input your github username"
  clrstdin
  while \read -r username; do
    mkdir ${HOME}/.config
    echo "eval \"\$(hub alias -s)\"" >> ${HOME}/.zshrc
    echo "github.com: \n  - user: ${username}" > ${HOME}/.config/hub
  done;
fi
{
  ${ECHO} "Installing PHP..."
  brew untap homebrew/dupes
  brew tap homebrew/dupes
  brew untap josegonzalez/homebrew-php
  brew tap josegonzalez/homebrew-php
  brew update
  brew install --force php55

  echo "export PATH=\"\$(brew --prefix php55)/bin:$PATH\"" >> ${HOME}/.zshrc

  source ${HOME}/.zshrc

  ${ECHO} "Getting composer"
  \curl -sS https://getcomposer.org/installer | php
  mv composer.phar ${COMPOSER_TARGET};
  ${ECHO} "Composer installed globally at ${COMPOSER_TARGET}"

  # Get hold of cask
  $ECHO "Installing Cask"
  brew untap phinze/homebrew-cask;
  brew tap phinze/homebrew-cask;
  brew update;
  brew install brew-cask;
  brew update;

  #Iterate through the manifest and install everything in there.

  ${ECHO} "Reading through the Cask manifest"
} <&-

while read app; do
  $ECHO "Installing ${app}"
  brew cask install ${app};
done < ${LOCAL_REPO_DIR}/manifest.txt

brew linkapps;
brew cask linkapps;
brew cask alfred link;

$ECHO "Job done"
