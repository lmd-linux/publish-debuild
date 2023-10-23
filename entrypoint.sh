#! /bin/bash
set -e

REPO="${1}"
SSH_KEY="${2}"

log() {
    echo -e "\033[0;32m${@}\033[0m"
}

changelog_line() {
    echo "${@}" >> debian/changelog
}

apt-get -y update
apt-get -y install \
    ca-certificates \
    devscripts \
    git \
    openssh-client \
    pkg-config \
    systemd

log "Cloning ${REPO}"
git clone --depth 1 https://github.com/${REPO}.git

log "Setting up SSH"
mkdir -p /root/.ssh
ssh-keyscan github.com > /root/.ssh/known_hosts
echo "${SSH_KEY}" > /root/.ssh/key
chmod -R go-rwx /root/.ssh
export GIT_SSH_COMMAND="ssh -i /root/.ssh/key"

log "Cloning lmd-linux/lmd-linux.github.io"
git clone --depth 1 git@github.com:lmd-linux/lmd-linux.github.io.git

log "Building ${REPO##*/}"
cd ${REPO##*/}

rm -f debian/changelog
COMMITS=$(git rev-list HEAD -- *)
PREVIOUS_COMMIT=""
PREVIOUS_VERSION=""
for COMMIT in ${COMMITS}; do
    VERSION=$(git show ${COMMIT}:debian/version)
    if [[ ${PREVIOUS_VERSION} != ${VERSION} ]]; then
        if [[ -n ${PREVIOUS_COMMIT} ]]; then
            changelog_line
            changelog_line " -- lmd Linux <lmd.linux@gmail.com>  ${DATE}"
            changelog_line
        fi
        DATE=$(git log --format=%cD -n 1 ${COMMIT})
        URGENCY=$(git show ${COMMIT}:debian/urgency)
        changelog_line "${REPO##*/} (${VERSION}) all; urgency=${URGENCY}"
        changelog_line
    fi
    MESSAGE=$(git log --format=%B -n 1 ${COMMIT})
    changelog_line "${MESSAGE}" | sed -e '/^$/d' -e 's/^/    /' -e '1s/^    /  * /'
    changelog_line "    https://github.com/${REPO}/commit/${COMMIT:0:8}"
    PREVIOUS_COMMIT=${COMMIT}
    PREVIOUS_VERSION=${VERSION}
done
DATE=$(git log --format=%cD -n 1 ${COMMIT})
changelog_line
changelog_line " -- lmd Linux <lmd.linux@gmail.com>  ${DATE}"

debuild -uc -us

log "Publishing ${REPO##*/}"
for DEST in $(cat debian/destination); do
    mkdir -p ../lmd-linux.github.io/pool/${DEST}
    cp $(ls -1 ../*.deb | grep -v '\-dbgsym_') ../lmd-linux.github.io/pool/${DEST}
done
cd ../lmd-linux.github.io
git config user.name "lmd Linux"
git config user.email lmd.linux@gmail.com
git add .
git commit -m "Update packages for ${REPO}"
git push
