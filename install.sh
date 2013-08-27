#!/usr/bin/env bash
# Colour _echo to make it easier to read
function _echo () {
    echo "\n" $(tput bold) $(tput setaf 1) ${1} $(tput sgr0) "\n";
}

function command_exists () {
	command -v ${1} > /dev/null 2>&1 || {
		return 1;
	}
}

ECHO=_echo
REPO_BRANCH=${1:-"master"}

REPO_URI=${2:-"https://github.com/shrikeh/mac-provisioning/archive/${REPO_BRANCH}.zip"}
ZIP_TARGET=${3:-"${HOME}/Downloads/mac-provisioning.zip"}
LOCAL_REPO_DIR=${4:-"${HOME}/Downloads/mac-provisioning-${REPO_BRANCH}"}
COMPOSER_TARGET="/usr/local/bin/composer"
SSH_PARANOIA=2048
OSX_GCC_TARGET=${4:-"/"}

# Check we aren't runniing as root as this will mess everything up"
if [[ $EUID = 0 ]]; then
   $ECHO "This script must not be run as root" 1>&2;
   exit 1;
fi

$ECHO "This script requires sudo privileges. You will be prompted for your password. Do you wish to continue?";
read -r -s -e -p "(y/n) > " -n 1 REPLY;

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1;
fi

# Show all hidden files on a mac
$ECHO "Making all hidden files visible in Finder"
defaults write com.apple.Finder AppleShowAllFiles YES


$ECHO "Do you wish to generate a new SSH key?";
read -r -s -e -p "(y/n) > " -n 1 REPLY;
# (optional) move to a new line;

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh-keygen -trsa -b${SSH_PARANOIA};
fi

# Is this running remotely (i.e. with curl and piped to sh) or has this been downloaded?
# If not downloaded, we need to get the rest of the archive
# @todo: check locally if we are in a folder containing the CLT
\curl -fsSL -o ${ZIP_TARGET} ${REPO_URI};
 
unzip -o ${ZIP_TARGET} -d ${HOME}/Downloads;
sudo installer -pkg ${LOCAL_REPO_DIR}/clt/clt-ml.pkg -target ${OSX_GCC_TARGET};


# Get hold of Ruby
if command_exists "rvm"; then
    $ECHO "Existing RVM found , moving on";
else
  $ECHO "Getting hold of latest stable Ruby RVM";
  \curl -L https://get.rvm.io | bash -s stable --autolibs=read-fail --auto-dotfiles;
  source ~/.rvm/scripts/rvm;

  rvm install ruby;
  type rvm | head -1;
fi

# Get hold of Homebrew
if command_exists "brew"; then
    $ECHO "Detected existing install of Homebrew, moving on...";
else
    $ECHO "Getting Homebrew";
    ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)";
fi;

rvm autolibs homebrew;

$ECHO "Installing Heroku (gives you Git etc)";
brew install --force heroku-toolbelt;

$ECHO "Configuring git"
git config --global core.autocrlf input
if ! git config user.email; then
  $ECHO "Please input your email address"
  read email;
  git config --global user.email ${email};
fi
if ! git config user.name; then
  $ECHO "Please input your first and last name";
  read first_name last_name;
  git config --global user.name "${first_name} ${last_name}";
fi;

brew install --force wget libksba autoconf gmp4 gmp mpfr mpc automake;

# Python
$ECHO "Installing python"
brew install --force python;
pip install virtualenv virtualenvwrapper shyaml;

$ECHO "Installing ssh-copy-id";
brew install --force ssh-copy-id

$ECHO "Getting zsh"
brew install zsh zsh-completions;
curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh
echo "fpath=(/usr/local/share/zsh-completions \$fpath)" >> $HOME/.zshrc

source $HOME/.zshrc

$ECHO "Installing slick git tools";
brew install --force gist hub hubflow
pip install git_sweep
if [ ! -f ${HOME}/.config/hub ]; then
  $ECHO "Please input your github username"
  read username
  mkdir ${HOME}/.config
  echo "eval \"\$(hub alias -s)\"" >> ${HOME}/.zshrc
  echo "github.com: \n  - user: ${username}" > ${HOME}/.config/hub
fi

$ECHO "Installing PHP..."
brew untap homebrew/dupes
brew tap homebrew/dupes
brew untap josegonzalez/homebrew-php
brew tap josegonzalez/homebrew-php
brew update
brew install --force php55

$ECHO "Getting composer"
\curl -sS https://getcomposer.org/installer | php
mv composer.phar ${COMPOSER_TARGET};
$ECHO "Composer installed globally at ${COMPOSER_TARGET}"

# Get hold of cask
$ECHO "Installing Cask"
brew untap phinze/homebrew-cask;
brew tap phinze/homebrew-cask;
brew update;
brew install brew-cask;
brew update;

#Iterate through the manifest and install everything in there.

$ECHO "Reading through the Cask manifest"
while read app; do
  $ECHO "Installing ${app}"
  brew cask install --force ${app};
done < ${LOCAL_REPO_DIR}/manifest.txt

brew linkapps;
brew cask linkapps;
brew cask alfred link;

$ECHO "Job done"
