#!/bin/sh
# Starts a throwaway sshd on 127.0.0.1:2222 for the live SSH tests
# and prints the export line for DEVWIDGETS_SSH_TEST_CONFIG. It runs
# as the current user with its own host key, client key and
# authorized_keys in $DIR; nothing in ~/.ssh is read or changed.
#   eval "$(tools/ssh_test_server.sh)" && swift test
# SSHD may point at an sshd binary outside PATH (and its helper
# directory at SSHD_LIBEXEC, for sshd-session and sshd-auth).
set -eu
DIR=${DIR:-$HOME/.devwidgets-ssh-test}
PORT=${PORT:-2222}
SSHD=${SSHD:-$(command -v sshd || echo /usr/sbin/sshd)}
LIBEXEC=${SSHD_LIBEXEC:-$(dirname "$SSHD")/../lib/openssh}
mkdir -p "$DIR" && chmod 700 "$DIR" && cd "$DIR"
[ -f host_key ] || ssh-keygen -q -t ed25519 -N "" -f host_key
[ -f client_key ] || ssh-keygen -q -t ed25519 -N "" -f client_key
cp client_key.pub authorized_keys && chmod 600 authorized_keys
cat > sshd_config <<CONFIG
Port $PORT
ListenAddress 127.0.0.1
HostKey $DIR/host_key
AuthorizedKeysFile $DIR/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
StrictModes no
PidFile $DIR/sshd.pid
SshdSessionPath $LIBEXEC/sshd-session
SshdAuthPath $LIBEXEC/sshd-auth
CONFIG
cat > ssh_config <<CONFIG
Host devwidgets-test
  HostName 127.0.0.1
  Port $PORT
  User $(id -un)
  IdentityFile $DIR/client_key
  IdentitiesOnly yes
  UserKnownHostsFile $DIR/known_hosts
  StrictHostKeyChecking accept-new
Host devwidgets-closed
  HostName 127.0.0.1
  Port $((PORT + 1))
  ConnectTimeout 2
CONFIG
if ! { [ -f sshd.pid ] && kill -0 "$(cat sshd.pid)" 2>/dev/null; }
then
  "$SSHD" -f "$DIR/sshd_config" -E "$DIR/sshd.log"
fi
echo "export DEVWIDGETS_SSH_TEST_CONFIG=$DIR/ssh_config"
