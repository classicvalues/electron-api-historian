#!/usr/bin/env bash

set -v            # print commands before execution, but don't expand env vars in output
set -o errexit    # always exit on error
set -o pipefail   # honor exit codes when piping
set -o nounset    # fail on unset variables

git clone "https://electron-bot:$GH_TOKEN@github.com/electron/electron-api-historian" module
cd module
git submodule update --init
npm ci

git config user.email electron@github.com
git config user.name electron-bot

# Update the electron submodule
pushd electron && git checkout origin/master && popd
# bail if the submodule sha didn't change
if [ "$(git status --porcelain -- electron)" = "" ]; then
  echo "electron origin/master ref has not changed; goodbye!"
  exit 78
fi
git add electron
ELECTRON_SHA=$(git submodule status --cached electron | awk '{print $1}')
git commit -m "chore: update to latest electron ($ELECTRON_SHA)"

npm run build

# bail if the data didn't change;
# the build script will change the checked out submodule sha,
# so don't include it in the check
if [ "$(git status --porcelain -- index.json)" = "" ]; then
  echo "no new content found; goodbye!"
  exit 78
fi

npm test

git add index.json
git commit -am "feat: update electron-releases"
git pull --rebase && git push && git push --tags
npm run semantic-release
