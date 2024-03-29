#!/bin/bash
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
# Copyright

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
echo "*** $(basename "$0")"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing JDBC driver(s) for Sqoop..."
if [ -d /var/lib/sqoop ]; then
  if [ -f /usr/share/java/mysql-connector-java.jar ]; then
    ln -sf /usr/share/java/mysql-connector-java.jar /var/lib/sqoop/
  fi
  if [ -f /usr/share/java/oracle-connector-java.jar ]; then
    ln -sf /usr/share/java/oracle-connector-java.jar /var/lib/sqoop/
  fi
  if [ -f /usr/share/java/sqlserver-connector-java.jar ]; then
    ln -sf /usr/share/java/sqlserver-connector-java.jar /var/lib/sqoop/
  fi
  if [ -f /usr/share/java/postgresql-jdbc.jar ]; then
    ln -sf /usr/share/java/postgresql-jdbc.jar /var/lib/sqoop/
  fi
  if [ -f /usr/share/java/postgresql.jar ]; then
    ln -sf /usr/share/java/postgresql.jar /var/lib/sqoop/
  fi
else
  echo "WARNING: /var/lib/sqoop not found."
fi

if [ -d /var/lib/sqoop2 ]; then
  if [ -f /usr/share/java/mysql-connector-java.jar ]; then
    ln -sf /usr/share/java/mysql-connector-java.jar /var/lib/sqoop2/
  fi
  if [ -f /usr/share/java/oracle-connector-java.jar ]; then
    ln -sf /usr/share/java/oracle-connector-java.jar /var/lib/sqoop2/
  fi
  if [ -f /usr/share/java/sqlserver-connector-java.jar ]; then
    ln -sf /usr/share/java/sqlserver-connector-java.jar /var/lib/sqoop2/
  fi
  if [ -f /usr/share/java/postgresql-jdbc.jar ]; then
    ln -sf /usr/share/java/postgresql-jdbc.jar /var/lib/sqoop2/
  fi
  if [ -f /usr/share/java/postgresql.jar ]; then
    ln -sf /usr/share/java/postgresql.jar /var/lib/sqoop2/
  fi
else
  echo "WARNING: /var/lib/sqoop2 not found."
fi

