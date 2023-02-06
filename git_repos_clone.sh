# You need to get you personal access token from
# https://github.com/settings/tokens
# Allow permission carefully for the token
# Don't share your personal token with anyone else.

for i in `curl -H "Authorization: token <your-token-goes-here>" https://api.github.com/user/repos?per_page=1000 | grep ssh_url | cut -d ':' -f 2-3|tr -d '",'`; do git clone $i; done
