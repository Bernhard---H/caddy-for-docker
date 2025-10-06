# Setup Docker-Compose Projects with Caddy Reverse-Proxy

## Installation

Start by cloning this repo into an empty folder for your future docker compose projects.

The cloning-target may NOT be named `caddy`.
Next to the folder containing this repository, there may not be a folder named `caddy`.

You will need to place your local configuration inside the folder named `caddy` next to your clone target folder (outside of this git repo).
I personally prefere to put clone this repo into the hidden folder `/opt/apps/.caddy`, but thats really up to personal preference.

```sh
# create an empty dir for your projects / apps
mkdir -p /opt/apps
# add your first (hidden) project to get started with this caddy setup
git clone git@github.com:Bernhard---H/caddy-config.git /opt/apps/.caddy
```

### Initialization (post-clone)

After the installation, you have to manually call the post-clone script, as git does not seem to (yet) support such a feature:

```sh
# change directory to your caddy-config repo:
#cd /opt/apps/.caddy
# start the post-clone script:
./init-new-host.sh
```
