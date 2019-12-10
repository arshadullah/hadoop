#!/bin/bash
# shellcheck disable=SC1090
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2015

# ARGV:
# 1 - SCM server hostname - required
# 2 - SCM agent version - optional
SCMVERSION=6.1.1

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu, RedHatEnterpriseServer, Debian, SUSE LINUX
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # CentOS= 6.10, 7.2.1511, Ubuntu= 14.04, RHEL= 6.10, 7.5, SLES= 11
    # shellcheck disable=SC2034
    OSVER=$(lsb_release -rs)
    # 7, 14
    # shellcheck disable=SC2034
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # Ubuntu= trusty, wheezy, CentOS= Final, RHEL= Santiago, Maipo, SLES= n/a
    # shellcheck disable=SC2034
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        # shellcheck disable=SC2034
        OS=CentOS
        # 7.5.1804.4.el7.centos, 6.10.el6.centos.12.3
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2}')
        # shellcheck disable=SC2034
        OSREL=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n')
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
        # 7.5, 6Server
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n')
        if [ "$OSVER" == "6Server" ]; then
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/redhat-release --qf='%{RELEASE}\n' | awk -F. '{print $1"."$2}')
          # shellcheck disable=SC2034
          OSNAME=Santiago
        else
          # shellcheck disable=SC2034
          OSNAME=Maipo
        fi
        # shellcheck disable=SC2034
        OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
      fi
    elif [ -f /etc/SuSE-release ]; then
      if grep -q "^SUSE Linux Enterprise Server" /etc/SuSE-release; then
        # shellcheck disable=SC2034
        OS="SUSE LINUX"
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSREL=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSNAME="n/a"
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename "$0") $*"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

SCMHOST=$1
if [ -z "$SCMHOST" ]; then
  echo "ERROR: Missing SCM hostname."
  exit 1
fi
SCMVERSION=${2:-$SCMVERSION}
SCMVERSION_MAJ=$(echo "${SCMVERSION}" | awk -F. '{print $1}')

PROXY=$(grep -Eh '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*)
eval "$PROXY"
export http_proxy
export https_proxy
if [ -z "$http_proxy" ]; then
  PROXY=$(grep -El 'http_proxy=|https_proxy=' /etc/profile.d/*)
  if [ -n "$PROXY" ]; then
    . "$PROXY"
  fi
fi

echo "Installing Cloudera Manager Agent..."
echo "CM server is: $SCMHOST"
echo "CM version is: $SCMVERSION"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  # Because it may have been put there by some other process.
  if [ ! -f /etc/yum.repos.d/cloudera-manager.repo ]; then
    if [ "$SCMVERSION_MAJ" -eq 6 ]; then
      wget -q "https://archive.cloudera.com/cm6/${SCMVERSION}/redhat${OSREL}/yum/cloudera-manager.repo" -O /etc/yum.repos.d/cloudera-manager.repo
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://archive.cloudera.com/cm6/${SCMVERSION}/redhat${OSREL}/yum/cloudera-manager.repo"
        exit 6
      fi
      chown root:root /etc/yum.repos.d/cloudera-manager.repo
      chmod 0644 /etc/yum.repos.d/cloudera-manager.repo
#      if [ -n "$SCMVERSION" ]; then
#        sed -e "s|6.0.0|${SCMVERSION}|g" -i /etc/yum.repos.d/cloudera-manager.repo
#      fi
    elif [ "$SCMVERSION_MAJ" -eq 5 ]; then
      wget -q "https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo" -O /etc/yum.repos.d/cloudera-manager.repo
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo"
        exit 4
      fi
      chown root:root /etc/yum.repos.d/cloudera-manager.repo
      chmod 0644 /etc/yum.repos.d/cloudera-manager.repo
      if [ -n "$SCMVERSION" ]; then
        sed -e "s|/cm/5/|/cm/${SCMVERSION}/|" -i /etc/yum.repos.d/cloudera-manager.repo
      fi
    else
      echo "ERROR: $SCMVERSION_MAJ is not supported."
      exit 10
    fi
  fi
  yum -y -e1 -d1 install cloudera-manager-agent
  sed -i -e "/server_host/s|=.*|=${SCMHOST}|" /etc/cloudera-scm-agent/config.ini
  service cloudera-scm-agent start
  chkconfig cloudera-scm-agent on
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  # Because it may have been put there by some other process.
  if [ ! -f /etc/apt/sources.list.d/cloudera-manager.list ]; then
    if [ "$OS" == Debian ]; then
      OS_LOWER=debian
    elif [ "$OS" == Ubuntu ]; then
      OS_LOWER=ubuntu
    fi
    if [ "$SCMVERSION_MAJ" -eq 6 ]; then
      OSVER_NUMERIC=${OSVER//./}
      wget -q "https://archive.cloudera.com/cm6/${SCMVERSION}/${OS_LOWER}${OSVER_NUMERIC}/apt/cloudera-manager.list" -O /etc/apt/sources.list.d/cloudera-manager.list
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://archive.cloudera.com/cm6/${SCMVERSION}/${OS_LOWER}${OSVER_NUMERIC}/apt/cloudera-manager.list"
        exit 7
      fi
      chown root:root /etc/apt/sources.list.d/cloudera-manager.list
      chmod 0644 /etc/apt/sources.list.d/cloudera-manager.list
#      if [ -n "$SCMVERSION" ]; then
#        sed -e "s|6.0.0|${SCMVERSION}|g" -i /etc/apt/sources.list.d/cloudera-manager.list
#      fi
      curl -s "https://archive.cloudera.com/cm6/${SCMVERSION}/${OS_LOWER}${OSVER_NUMERIC}/apt/archive.key" | apt-key add -
    elif [ "$SCMVERSION_MAJ" -eq 5 ]; then
      wget -q "https://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/cloudera.list" -O /etc/apt/sources.list.d/cloudera-manager.list
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/cloudera.list"
        exit 5
      fi
      chown root:root /etc/apt/sources.list.d/cloudera-manager.list
      chmod 0644 /etc/apt/sources.list.d/cloudera-manager.list
      if [ -n "$SCMVERSION" ]; then
        sed -e "s|-cm5 |-cm${SCMVERSION} |" -i /etc/apt/sources.list.d/cloudera-manager.list
      fi
      curl -s "http://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/archive.key" | apt-key add -
    else
      echo "ERROR: $SCMVERSION_MAJ is not supported."
      exit 11
    fi
  fi
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -qq update
  apt-get -y -q install cloudera-manager-agent
  sed -i -e "/server_host/s|=.*|=${SCMHOST}|" /etc/cloudera-scm-agent/config.ini
  service cloudera-scm-agent start
  update-rc.d cloudera-scm-agent defaults
  update-rc.d apache2 disable
  service apache2 stop
fi

