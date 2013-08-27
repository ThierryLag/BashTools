 #!/usr/bin/env bash
#
#   Small script to install "dnsmasq" on Max OSX
#
#   @author Thierry 'Akarun' Lagasse
#   @since August 2013
#   @link http://www.echoditto.com/blog/never-touch-your-local-etchosts-file-os-x-again
#   @link https://gist.github.com/r10r/5108046
# 
#       sudo launchctl stop homebrew.mxcl.dnsmasq
#       sudo launchctl start homebrew.mxcl.dnsmasq
#  ============================================================================

# Installing brew (si nécessaire)
[ -z $(which brew) ] || ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go)"

# Install "dnsmasq"
brew install dnsmasq

# Configure "dnsmaq"
mkdir -pv $(brew --prefix)/etc/

sudo tee $(brew --prefix)/etc/dnsmasq.conf <<EOF
# Listen request only from local
listen-address=127.0.0.1

# Answer '.dev' domains with '10.0.0.6' 
address=/.dev/10.0.0.6
#adresss=/.node.dev/10.0.0.7

# Expands simple hosts with "vagrant.dev" domain
# ...but only for domain in 10.0.0.x
expand-hosts
domain=vagrant.dev,10.0.0.0/24
EOF

# Add DNS server to resolver list
[ -d /etc/resolver ] || sudo mkdir -v /etc/resolver
sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/dev'

# Load "dnsmasq" at startup (deamon)
sudo cp -v $(brew --prefix dnsmasq)/homebrew.mxcl.dnsmasq.plist /Library/LaunchDaemons/

# Load the deamon, now!
sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist 

# Clear the cache
dscacheutil -flushcache

# Test one domain
#ping -c 1 vagrant.dev