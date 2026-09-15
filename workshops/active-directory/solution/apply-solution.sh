#!/usr/bin/env bash
# Trainerloesung: LDAP-Provider fuer den eigenen DC per kcadm anlegen und umstellen.
# Aufruf im Keycloak-Container:
#   bash /workshop/solution/apply-solution.sh <befehl> [arg]
#   Befehle: create | strategy direct|recursive | users-dn users|workshop | sync | logout-sessions | status | delete
set -euo pipefail

REALM=mustertech
KCADM=/opt/keycloak/bin/kcadm.sh
BASE="DC=ad,DC=mustertech,DC=test"
WORKSHOP_DN="OU=Workshop,${BASE}"
USERS_DN="OU=Users,${WORKSHOP_DN}"
GROUPS_DN="OU=Groups,${WORKSHOP_DN}"
BIND_DN="bind@ad.mustertech.test"
BIND_PW_FILE="${BIND_PW_FILE:-/workshop/secrets/bind.pw}"
PROVIDER_NAME="ad-workshop"

login() {
  "$KCADM" config credentials --server http://localhost:8080 --realm master --user admin --password admin >/dev/null
}

realm_id() { "$KCADM" get "realms/${REALM}" --fields id --format csv --noquotes; }

provider_id() {
  "$KCADM" get components -r "$REALM" -q name="$PROVIDER_NAME" -q type=org.keycloak.storage.UserStorageProvider \
    --fields id --format csv --noquotes | head -n1
}

mapper_id() {
  "$KCADM" get components -r "$REALM" -q parent="$1" -q name=ad-groups --fields id --format csv --noquotes | head -n1
}

require_provider() {
  PID="$(provider_id)"
  if [ -z "$PID" ]; then
    echo "Provider $PROVIDER_NAME existiert nicht. Zuerst: create" >&2
    exit 1
  fi
  MID="$(mapper_id "$PID")"
}

create() {
  if [ ! -r "$BIND_PW_FILE" ]; then
    echo "Bind-Passwort fehlt: $BIND_PW_FILE (im Werkzeugcontainer: save-secret bind)" >&2
    exit 1
  fi
  if [ -n "$(provider_id)" ]; then
    echo "Provider $PROVIDER_NAME existiert bereits" >&2
    exit 1
  fi
  local rid
  rid="$(realm_id)"
  "$KCADM" create components -r "$REALM" \
    -s name="$PROVIDER_NAME" -s providerId=ldap -s parentId="$rid" \
    -s providerType=org.keycloak.storage.UserStorageProvider \
    -s 'config.enabled=["true"]' -s 'config.priority=["0"]' -s 'config.vendor=["ad"]' \
    -s 'config.editMode=["READ_ONLY"]' -s 'config.importEnabled=["true"]' -s 'config.syncRegistrations=["false"]' \
    -s 'config.connectionUrl=["ldaps://dc01.ad.mustertech.test:636"]' -s 'config.useTruststoreSpi=["always"]' \
    -s 'config.startTls=["false"]' -s 'config.connectionPooling=["false"]' \
    -s "config.usersDn=[\"${USERS_DN}\"]" -s 'config.searchScope=["2"]' \
    -s 'config.authType=["simple"]' -s "config.bindDn=[\"${BIND_DN}\"]" \
    -s "config.bindCredential=[\"$(cat "$BIND_PW_FILE")\"]" \
    -s 'config.usernameLDAPAttribute=["userPrincipalName"]' -s 'config.rdnLDAPAttribute=["cn"]' \
    -s 'config.uuidLDAPAttribute=["objectGUID"]' \
    -s 'config.userObjectClasses=["person, organizationalPerson, user"]' \
    -s 'config.customUserSearchFilter=["(|(sAMAccountName=hans)(sAMAccountName=anna))"]' \
    -s 'config.pagination=["true"]' -s 'config.batchSizeForSync=["1000"]' -s 'config.trustEmail=["false"]' \
    -s 'config.cachePolicy=["DEFAULT"]' -s 'config.fullSyncPeriod=["-1"]' -s 'config.changedSyncPeriod=["-1"]' \
    -s 'config.allowKerberosAuthentication=["false"]' -s 'config.useKerberosForPasswordAuthentication=["false"]' \
    -s 'config.validatePasswordPolicy=["false"]' -s 'config.usePasswordModifyExtendedOp=["false"]'
  local pid
  pid="$(provider_id)"
  "$KCADM" create components -r "$REALM" \
    -s name=ad-groups -s providerId=group-ldap-mapper \
    -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper -s parentId="$pid" \
    -s "config.\"groups.dn\"=[\"${GROUPS_DN}\"]" -s 'config."group.name.ldap.attribute"=["cn"]' \
    -s 'config."group.object.classes"=["group"]' -s 'config."preserve.group.inheritance"=["false"]' \
    -s 'config."ignore.missing.groups"=["false"]' -s 'config."membership.ldap.attribute"=["member"]' \
    -s 'config."membership.attribute.type"=["DN"]' -s 'config."membership.user.ldap.attribute"=["cn"]' \
    -s 'config."groups.ldap.filter"=[""]' -s 'config.mode=["READ_ONLY"]' \
    -s 'config."user.roles.retrieve.strategy"=["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"]' \
    -s 'config."memberof.ldap.attribute"=["memberOf"]' -s 'config."mapped.group.attributes"=[""]' \
    -s 'config."drop.non.existing.groups.during.sync"=["false"]' -s 'config."groups.path"=["/"]'
  echo "Provider $PROVIDER_NAME und Mapper ad-groups angelegt"
}

strategy() {
  require_provider
  case "${1:-}" in
    direct)
      "$KCADM" update "components/${MID}" -r "$REALM" \
        -s 'config."user.roles.retrieve.strategy"=["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"]' ;;
    recursive)
      "$KCADM" update "components/${MID}" -r "$REALM" \
        -s 'config."user.roles.retrieve.strategy"=["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE_RECURSIVELY"]' ;;
    *) echo "strategy direct|recursive" >&2; exit 2 ;;
  esac
  echo "Strategie: $1"
}

users_dn() {
  require_provider
  case "${1:-}" in
    users) "$KCADM" update "components/${PID}" -r "$REALM" -s "config.usersDn=[\"${USERS_DN}\"]" ;;
    workshop) "$KCADM" update "components/${PID}" -r "$REALM" -s "config.usersDn=[\"${WORKSHOP_DN}\"]" ;;
    *) echo "users-dn users|workshop" >&2; exit 2 ;;
  esac
  echo "Users DN: $1"
}

sync() {
  require_provider
  "$KCADM" create "user-storage/${PID}/sync?action=triggerFullSync" -r "$REALM"
  "$KCADM" create "user-storage/${PID}/mappers/${MID}/sync?direction=fedToKeycloak" -r "$REALM"
}

logout_sessions() {
  "$KCADM" create logout-all -r "$REALM"
  echo "alle Sitzungen im Realm $REALM beendet"
}

status() {
  require_provider
  "$KCADM" get "components/${PID}" -r "$REALM" --fields 'config(usersDn,customUserSearchFilter,editMode,vendor)'
  "$KCADM" get "components/${MID}" -r "$REALM" \
    --fields 'config(user.roles.retrieve.strategy,groups.dn,preserve.group.inheritance)'
  for u in hans anna; do
    echo "--- ${u}@ad.mustertech.test"
    uid="$("$KCADM" get users -r "$REALM" -q "username=${u}@ad.mustertech.test" -q exact=true \
      --fields id --format csv --noquotes | head -n1)"
    if [ -n "$uid" ]; then
      "$KCADM" get "users/${uid}/groups" -r "$REALM" --fields name --format csv --noquotes
    else
      echo "(nicht importiert)"
    fi
  done
}

delete_provider() {
  require_provider
  "$KCADM" delete "components/${PID}" -r "$REALM"
  echo "Provider $PROVIDER_NAME geloescht"
}

login
case "${1:-}" in
  create) create ;;
  strategy) strategy "${2:-}" ;;
  users-dn) users_dn "${2:-}" ;;
  sync) sync ;;
  logout-sessions) logout_sessions ;;
  status) status ;;
  delete) delete_provider ;;
  *)
    echo "Befehle: create | strategy direct|recursive | users-dn users|workshop | sync |" >&2
    echo "         logout-sessions | status | delete" >&2
    exit 2 ;;
esac
