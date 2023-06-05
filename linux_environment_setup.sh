#!/bin/bash

center() {
  printf '=%.0s' $(seq 1 $(tput cols))
  echo "$1" | sed -e :a -e "s/^.\{1,$(tput cols)\}$/ & /;ta" | tr -d '\n' | head -c $(tput cols)
  printf '=%.0s' $(seq 1 $(tput cols)) | sed 's/^ //'
}

#sudo /opt/McAfee/ens/tp/init/mfetpd-control.sh stop && sudo /opt/McAfee/ens/esp/init/mfeespd-control.sh stop

printf "\n"
center "Updating system"
printf "\n"
sudo apt-get update -y

printf "\n"
center "System updated"
printf "\n"

printf "\n"
center "Install basic packages"
printf "\n"

echo -n 'Do you want to install basic packages (Y/n)? '
read basic_packages_confirmation

echo -n 'Do you want to install VS Code (Y/n)? '
read vs_code_confirmation

echo -n 'Do you want to install Java (Y/n)? '
read java_confirmation

echo -n 'Do you want to install Redis (Y/n)? '
read redis_confirmation

echo -n 'Do you want to install Skype (Y/n)? '
read skype_confirmation

echo -n 'Do you want to setup SSH Keys (Y/n)? '
read ssh_confirmation

echo -n 'Do you want to install Git (Y/n)? '
read git_confirmation

echo -n 'Do you want to install Slack (Y/n)? '
read slack_confirmation

echo -n 'Do you want to install Postman (Y/n)? '
read postman_confirmation

echo -n 'Do you want to install VLC (Y/n)? '
read vlc_confirmation

echo -n 'Do you want to install NVM (Node Version Manager) (Y/n)? '
read nvm_confirmation

echo -n 'Do you want to install Subblime Text (Y/n)? '
read sublime_confirmation

echo -n 'Do you want to install Yarn (Y/n)? '
read yarn_confirmation

echo -n 'Do you want to install RabbitMQ (Y/n)? '
read rabbitmq_confirmation

echo -n 'Do you want to install Docker (Y/n)? '
read docker_confirmation

# echo -n 'Do you want to install Zoom (Y/n)? '
# read zoom_confirmation

echo -n 'Do you want to install Jetbrains Toolbox (Y/n)? '
read jetbrains_confirmation

echo -n 'Do you want to install Postgresql (Y/n)? '
read postgresql_confirmation

echo -n 'Do you want to install NodeJS (Y/n)? '
read nodejs_confirmation

echo -n 'Do you want to install Memcached (Y/n)? '
read memcached_confirmation

echo -n 'Do you want to install Elasticsearch (Y/n)? '
read elasticsearch_confirmation

echo -n 'Do you want to install TeamViewer (Y/n)? '
read teamviewer_confirmation

echo -n 'Do you want to install Python 3.10 (Y/n)? '
read python_confirmation

echo -n 'Do you want to install Go (Y/n)? '
read golang_confirmation

echo -n 'Do you want to install AWS CLI and AWS Local (Y/n)? '
read aws_confirmation

echo -n 'Do you want to install Google Chrome (Y/n)? '
read google_chrome_confirmation

echo -n 'Do you want to install CopyQ (Y/n)? '
read copyq_confirmation

echo -n 'Do you want to install Oh My ZSH (Y/n)? '
read omz_confirmation

echo -n 'Do you want to install Kubectl (Y/n)? '
read kubectl_confirmation

echo -n 'Do you want to install Minikube (Y/n)? '
read minikube_confirmation

echo -n 'Do you want to install Skaffold (Y/n)? '
read skaffold_confirmation

echo -n 'Do you want to install Terraform (Y/n)? '
read terraform_confirmation

# 0
install_basic_packages() {
    sudo apt install -y build-essential checkinstall gcc g++ make python3-distutils tree curl htop bash-completion libpq-dev gdal-bin python3-venv software-properties-common apt-transport-https wget build-essential libncursesw5-dev libssl-dev libsqlite3-dev tk-dev libgdbm-dev libc6-dev libbz2-dev libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev asciidoc xmlto docbook2x libfuse2
    sudo apt --fix-broken install
}

# 1
install_visual_studio_code_editor() {
  printf "\n"
  center "Installing Visual Studio Code Editor..."
  printf "\n"
  wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
  sudo apt install code -y
  printf "\n"
  center "Visual Studio Code Editor installed successfully."
  printf "\n"
}

# 2
install_java() {
  printf "\n"
  center "Installing Java..."
  printf "\n"
  sudo apt install openjdk-11-jdk -y
  sudo apt install maven -y
  java -version
  printf "\n"
  center "Java installed successfully."
  printf "\n"
}

# 3
install_redis() {
  printf "\n"
  center "Installing Redis..."
  printf "\n"
  sudo apt install redis-server -y
  printf "\n"
  center "Redis installed successfully."
  printf "\n"
}

# 4
install_skype() {
  printf "\n"
  center "Installing Skype..."
  printf "\n"
  wget https://go.skype.com/skypeforlinux-64.deb
  sudo chown _apt skypeforlinux-64.deb
  sudo dpkg -i ./skypeforlinux-64.deb
  sudo rm -rf skypeforlinux-64.deb
  printf "\n"
  center "Skype installed successfully."
  printf "\n"
}

# 5
install_ssh() {
  printf "\n"
  center "Setting up SSH Keys..."
  printf "\n"
  ssh-keygen -t ed25519 -C $email
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/id_ed25519
  cat ~/.ssh/id_ed25519.pub
  printf "\n"
  center "SSH Keys setup successfully."
  printf "\n"
}

# 6
install_git() {
  printf "\n"
  center "Installing Git..."
  printf "\n"
  sudo apt -y install git
  git config --global user.name $name
  git config --global user.email $email
  git config --global init.defaultBranch main
  printf "\n"
  center "Git installed successfully."
  printf "\n"
}

# 7
install_slack() {
  printf "\n"
  center "Installing Slack..."
  printf "\n"
  wget https://downloads.slack-edge.com/releases/linux/4.29.149/prod/x64/slack-desktop-4.29.149-amd64.deb
  mv slack-desktop-4.29.149-amd64.deb slack_desktop.deb
  sudo chown _apt slack_desktop.deb
  sudo dpkg -i ./slack_desktop.deb
  sudo rm -rf slack_desktop.deb
  printf "\n"
  center "Slack installed successfully."
  printf "\n"
}

# 8
install_postman() {
  printf "\n"
  center "Installing Postman..."
  printf "\n"
  sudo snap install postman
  printf "\n"
  center "Postman installed successfully."
  printf "\n"
}

# 9
install_vlc() {
  printf "\n"
  center "Installing VLC..."
  printf "\n"
  sudo apt install vlc -y
  printf "\n"
  center "VLC installed successfully."
  printf "\n"
}

# 10
install_nvm() {
  printf "\n"
  center "Installing NVM..."
  printf "\n"
  wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
  nvm install node -y
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
  source ~/.bashrc
  source ~/.zshrc
  printf "\n"
  center "NVM installed successfully."
  printf "\n"
}

# 11
install_sublime_text() {
  printf "\n"
  center "Installing Sublime Text..."
  printf "\n"
  curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
  sudo add-apt-repository "deb https://download.sublimetext.com/ apt/stable/"
  sudo apt install sublime-text -y
  printf "\n"
  center "Sublime Text installed successfully."
  printf "\n"
}

# 12
install_yarn() {
  printf "\n"
  center "Installing Yarn..."
  printf "\n"
  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
  echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
  sudo apt install yarn -y
  printf "\n"
  center "Yarn installed successfully."
  printf "\n"
}

# 13
install_rabbitmq() {
  printf "\n"
  center "Installing RabbitMQ..."
  printf "\n"
  wget -O- https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | sudo apt-key add -
  echo "deb https://dl.bintray.com/rabbitmq-erlang/debian focal erlang-22.x" | sudo tee /etc/apt/sources.list.d/rabbitmq.list
  sudo apt-get install rabbitmq-server -y
  sudo rabbitmq-plugins enable rabbitmq_management
  printf "\n"
  center "RabbitMQ installed successfully."
  printf "\n"
}

# 14
install_docker() {
  printf "\n"
  center "Installing Docker..."
  printf "\n"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt update -y
  sudo apt install docker-ce docker-ce-cli containerd.io -y
  sudo curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  docker-compose --version
  sudo service docker restart
  sudo groupadd docker
  sudo usermod -aG docker ${USER}
  sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
  sudo chmod g+rwx "$HOME/.docker" -R
  sudo usermod -a -G docker ${USER}
  printf "Now restart your machine."
  printf "\n"
  center "Docker installed successfully."
  printf "\n"
}

# 15
install_zoom() {
  printf "\n"
  center "Installing Zoom..."
  printf "\n"
  wget https://zoom.us/client/latest/zoom_amd64.deb
  sudo chown _apt zoom_amd64.deb
  sudo dpkg -i ./zoom_amd64.deb
  sudo apt --fix-broken install
  sudo dpkg -i ./zoom_amd64.deb
  sudo rm -rf zoom_amd64.deb
  printf "\n"
  center "Zoom installed successfully."
  printf "\n"
}

# 16
install_jetbrains_toolbox() {
  printf "\n"
  center "Installing Jetbrains Toolbox..."
  printf "\n"
  wget https://download.jetbrains.com/toolbox/jetbrains-toolbox-1.27.2.13801.tar.gz
  sudo tar xzf jetbrains-toolbox-1.27.2.13801.tar.gz
  cd jetbrains-toolbox-1.27.2.13801 || cd ..
  ./jetbrains-toolbox
  cd ..
  sudo rm -rf jetbrains-toolbox-1.27.2.13801.tar.gz
  printf "\n"
  center "Jetbrains Toolbox installed successfully."
  printf "\n"
}

# 17
install_postgresql() {
  printf "\n"
  center "Installing PostgreSQL..."
  printf "\n"
  sudo apt install postgresql postgresql-contrib -y
  sudo -u postgres psql -U postgres -d postgres -c "alter user postgres with password '$postgresql_password';"
  printf "\n"
  center "PostgreSQL installed successfully."
  printf "\n"
}

# 18
install_nodejs() {
  printf "\n"
  center "Installing NodeJS..."
  printf "\n"
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &&\
  sudo apt-get install -y nodejs
  printf "\n"
  center "NodeJS installed successfully."
  printf "\n"
}

# 19
install_memcached() {
  printf "\n"
  center "Installing Memcached..."
  printf "\n"
  sudo apt install memcached libmemcached-tools -y
  printf "\n"
  center "Memcached installed successfully."
  printf "\n"
}

# 20
install_elasticsearch() {
  printf "\n"
  center "Installing Elasticsearch..."
  printf "\n"
  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
  sudo sh -c 'echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list'
  sudo apt install elasticsearch
  sudo systemctl enable --now elasticsearch.service
  printf "\n"
  center "Elasticsearch installed successfully."
  printf "\n"
}

# 21
install_teamviewer() {
  printf "\n"
  center "Installing TeamViewer..."
  printf "\n"
  wget https://download.teamviewer.com/download/linux/teamviewer_amd64.deb
  sudo dpkg -i ./teamviewer_amd64.deb
  printf "\n"
  center "TeamViewer installed successfully."
  printf "\n"
}

# 22
install_python() {
  printf "\n"
  center "Installing Python..."
  printf "\n"
  wget https://www.python.org/ftp/python/3.10.11/Python-3.10.11.tgz
  tar -xf Python-3.10.11.tgz
  cd Python-3.10.11
  ./configure --enable-optimizations
  sudo make altinstall
  printf "\n"
  center "Python installed successfully."
  printf "\n"
}

# 23
install_golang() {
  printf "\n"
  center "Installing Go..."
  printf "\n"
  wget -c https://dl.google.com/go/go1.20.4.linux-amd64.tar.gz
  sudo tar -xz -C /usr/local -f go1.20.4.linux-amd64.tar.gz
  export PATH=$PATH:/usr/local/go/bin
  printf "\n"
  center "Go installed successfully."
  printf "\n"
}

# 24
install_aws() {
  printf "\n"
  center "Installing AWS CLI and AWS Local..."
  printf "\n"
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
  sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
  which aws
  pip install awscli
  pip install awscli-local
  printf "\n"
  center "AWS CLI and AWS Local installed successfully."
  printf "\n"
}

# 25
install_google_chrome() {
  printf "\n"
  center "Installing Google Chrome..."
  printf "\n"
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i ./google-chrome-stable_current_amd64.deb
  printf "\n"
  center "Google Chrome installed successfully."
  printf "\n"
}

# 26
install_copyq() {
  printf "\n"
  center "Installing CopyQ..."
  printf "\n"
  sudo add-apt-repository ppa:hluk/copyq
  sudo apt update -y
  sudo apt install copyq -y
  printf "\n"
  center "CopyQ installed successfully."
  printf "\n"
}

# 27
install_omz() {
  printf "\n"
  center "Installing Oh My ZSH..."
  printf "\n"
  sudo apt install zsh -y
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  chsh -s $(which zsh)
  printf "\n"
  center "Oh My ZSH installed successfully."
  printf "\n"
}

# 28
install_kubectl() {
  printf "\n"
  center "Installing Kubectl..."
  printf "\n"
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  kubectl version --client
  printf "\n"
  center "Kubectl installed successfully."
  printf "\n"
}

# 29
install_minikube() {
  printf "\n"
  center "Installing Minikube..."
  printf "\n"
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
  sudo dpkg -i minikube_latest_amd64.deb
  minikube addons enable ingress
  minikube addons enable metrics-server
  printf "\n"
  center "Minikube installed successfully."
  printf "\n"
}

# 30
install_skaffold() {
  printf "\n"
  center "Installing Skaffold..."
  printf "\n"
  curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && sudo install skaffold /usr/local/bin/
  printf "\n"
  center "Skaffold installed successfully."
  printf "\n"
}

# 31
install_terraform() {
  printf "\n"
  center "Installing Terraform..."
  printf "\n"
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt update && sudo apt install terraform -y
  printf "\n"
  center "Terraform installed successfully."
  printf "\n"
}

# 0
if [ "$basic_packages_confirmation" != "${basic_packages_confirmation#[Yy]}" ]; then
  install_basic_packages
else
  printf "\n"
  center "Skipping basic pakages installing..."
  printf "\n"
fi
# 1
if [ "$vs_code_confirmation" != "${vs_code_confirmation#[Yy]}" ]; then
  install_visual_studio_code_editor
else
  printf "\n"
  center "Skipping VS Code installing..."
  printf "\n"
fi
# 2
if [ "$java_confirmation" != "${java_confirmation#[Yy]}" ]; then
  install_java
else
  printf "\n"
  center "Skipping Java installing..."
  printf "\n"
fi
# 3
if [ "$redis_confirmation" != "${redis_confirmation#[Yy]}" ]; then
  install_redis
else
  printf "\n"
  center "Skipping Redis installing..."
  printf "\n"
fi
# 4
if [ "$skype_confirmation" != "${skype_confirmation#[Yy]}" ]; then
  install_skype
else
  printf "\n"
  center "Skipping Skype installing..."
  printf "\n"
fi
# 5
if [ "$ssh_confirmation" != "${ssh_confirmation#[Yy]}" ]; then
  read -p "SSH email: " email
  install_ssh $email
else
  printf "\n"
  center "Skipping SSH Keys setup..."
  printf "\n"
fi
# 6
if [ "$git_confirmation" != "${git_confirmation#[Yy]}" ]; then
  read -p "Git name: " name
  read -p "Git email: " email
  install_git $name $email
else
  printf "\n"
  center "Skipping SSH Keys installing..."
  printf "\n"
fi
# 7
if [ "$slack_confirmation" != "${slack_confirmation#[Yy]}" ]; then
  install_slack
else
  printf "\n"
  center "Skipping Slack installing..."
  printf "\n"
fi
# 8
if [ "$postman_confirmation" != "${postman_confirmation#[Yy]}" ]; then
  install_postman
else
  printf "\n"
  center "Skipping Postman installing..."
  printf "\n"
fi
# 9
if [ "$vlc_confirmation" != "${vlc_confirmation#[Yy]}" ]; then
  install_vlc
else
  printf "\n"
  center "Skipping VLC installing..."
  printf "\n"
fi
# 10
if [ "$nvm_confirmation" != "${nvm_confirmation#[Yy]}" ]; then
  install_nvm
else
  printf "\n"
  center "Skipping NVM installing..."
  printf "\n"
fi
# 11
if [ "$sublime_confirmation" != "${sublime_confirmation#[Yy]}" ]; then
  install_sublime_text
else
  printf "\n"
  center "Skipping Sublime Text installing..."
  printf "\n"
fi
# 12
if [ "$yarn_confirmation" != "${yarn_confirmation#[Yy]}" ]; then
  install_yarn
else
  printf "\n"
  center "Skipping Yarn installing..."
  printf "\n"
fi
# 13
if [ "$rabbitmq_confirmation" != "${rabbitmq_confirmation#[Yy]}" ]; then
  install_rabbitmq
else
  printf "\n"
  center "Skipping RabbitMQ installing..."
  printf "\n"
fi
# 14
if [ "$docker_confirmation" != "${docker_confirmation#[Yy]}" ]; then
  install_docker
else
  printf "\n"
  center "Skipping Docker installing..."
  printf "\n"
fi
# 15
if [ "$zoom_confirmation" != "${zoom_confirmation#[Yy]}" ]; then
  install_zoom
else
  printf "\n"
  center "Skipping Zoom installing..."
  printf "\n"
fi
# 16
if [ "$jetbrains_confirmation" != "${jetbrains_confirmation#[Yy]}" ]; then
  install_jetbrains_toolbox
else
  printf "\n"
  center "Skipping Jetbrains Toolbox installing..."
  printf "\n"
fi
# 17
if [ "$postgresql_confirmation" != "${postgresql_confirmation#[Yy]}" ]; then
  read -p "Set PostgreSQL password: " postgresql_password
  install_postgresql $postgresql_password
else
  printf "\n"
  center "Skipping Postgresql installing..."
  printf "\n"
fi
# 18
if [ "$nodejs_confirmation" != "${nodejs_confirmation#[Yy]}" ]; then
  install_nodejs
else
  printf "\n"
  center "Skipping NodeJS installing..."
  printf "\n"
fi
# 19
if [ "$memcached_confirmation" != "${memcached_confirmation#[Yy]}" ]; then
  install_memcached
else
  printf "\n"
  center "Skipping Memcached installing..."
  printf "\n"
fi

# 20
if [ "$elasticsearch_confirmation" != "${elasticsearch_confirmation#[Yy]}" ]; then
  install_elasticsearch
else
  printf "\n"
  center "Skipping Elasticsearch installing..."
  printf "\n"
fi

# 21
if [ "$teamviewer_confirmation" != "${teamviewer_confirmation#[Yy]}" ]; then
  install_teamviewer
else
  printf "\n"
  center "Skipping TeamViewer installing..."
  printf "\n"
fi

# 22
if [ "$python_confirmation" != "${python_confirmation#[Yy]}" ]; then
  install_python
else
  printf "\n"
  center "Skipping Python installing..."
  printf "\n"
fi

# 23
if [ "$golang_confirmation" != "${golang_confirmation#[Yy]}" ]; then
  install_golang
else
  printf "\n"
  center "Skipping Go installing..."
  printf "\n"
fi

# 24
if [ "$aws_confirmation" != "${aws_confirmation#[Yy]}" ]; then
  install_aws
else
  printf "\n"
  center "Skipping AWS CLI and AWS Local installing..."
  printf "\n"
fi

# 25
if [ "$google_chrome_confirmation" != "${google_chrome_confirmation#[Yy]}" ]; then
  install_google_chrome
else
  printf "\n"
  center "Skipping Google Chrome installing..."
  printf "\n"
fi

# 26
if [ "$copyq_confirmation" != "${copyq_confirmation#[Yy]}" ]; then
  install_copyq
else
  printf "\n"
  center "Skipping CopyQ installing..."
  printf "\n"
fi

# 27
if [ "$omz_confirmation" != "${omz_confirmation#[Yy]}" ]; then
  install_omz
else
  printf "\n"
  center "Skipping Oh My ZSH installing..."
  printf "\n"
fi

# 28
if [ "$kubectl_confirmation" != "${kubectl_confirmation#[Yy]}" ]; then
  install_kubectl
else
  printf "\n"
  center "Skipping Kubectl installing..."
  printf "\n"
fi

# 29
if [ "$minikube_confirmation" != "${minikube_confirmation#[Yy]}" ]; then
  install_minikube
else
  printf "\n"
  center "Skipping Minikube installing..."
  printf "\n"
fi

# 30
if [ "$skaffold_confirmation" != "${skaffold_confirmation#[Yy]}" ]; then
  install_skaffold
else
  printf "\n"
  center "Skipping Skaffold installing..."
  printf "\n"
fi

# 31
if [ "$terraform_confirmation" != "${terraform_confirmation#[Yy]}" ]; then
  install_terraform
else
  printf "\n"
  center "Skipping Terraform installing..."
  printf "\n"
fi

sudo apt update
sudo apt install --fix-missing -y
sudo apt install -f
sudo apt autoremove -y
sudo apt autoclean
sudo apt clean
