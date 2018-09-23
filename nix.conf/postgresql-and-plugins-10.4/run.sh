set -e; set -m
my=$(cd -P -- "$(dirname -- "${BASH_SOURCE-$0}")" > /dev/null && pwd -P)
_home=$(readlink -f "$my/../..") # my-env/nix.conf/${my}/run.sh

gettext_package=gettext-0.19.8.1

_action=$1; _host=$2; _package=$3

_ip=$(echo $_host | cut -d: -f1)
_id=$(echo $_host | cut -d: -f2)

export _home _ip _id _package kafkas cluster_id

my_data=${_home}/nix.var/data/${_package}/${_id}
_id_log=${_home}/nix.var/log/${_package}/${_id}
mkdir -p ${my_data}/{data,config} ${_id_log}

if [ "$(shopt -s nullglob; echo /nix/store/*-${gettext_package})" != "" ]; then
  envsubst_cmd=$(shopt -s nullglob; echo /nix/store/*-${gettext_package} | cut -d ' ' -f1)/bin/envsubst
elif [ -e "/usr/bin/envsubst" ]; then
  envsubst_cmd="/usr/bin/envsubst"
else
  echo "----> [ERROR] envsubst@gettext NOT FOUND!"
fi

my_package=$(grep -E "(src|tgt).postgresql-and-plugins-10.4" ${_home}/nix.sh.dic | cut -d= -f2)
my_cmd=${my_package}/bin/pg_ctl

export PGPORT=${_id}
if [ ! -e ${my_data}/data/PG_VERSION ]; then
  echo "--> [info] init db..." 
  ${my_package}/bin/initdb -E 'UTF-8' --no-locale -D ${my_data}/data
fi

cfg_file=pg_hba.conf
echo "enbsubst_cmd: ${envsubst_cmd}"
cat $my/${cfg_file}.template | ${envsubst_cmd} > ${my_data}/data/${cfg_file}
echo "====dump file content start===="
cat ${my_data}/data/${cfg_file}
echo "====dump file content end===="

if [ "${_action}" == "start-foreground" ]; then
  echo "${my_package}/bin/postgres -D ${my_data}/data -h ${_ip} -p ${_id}"
  ${my_package}/bin/postgres -D ${my_data}/data -h "${_ip}" -p "${_id}"
elif [ "${_action}" == "start" ]; then
  echo "nohup ${my_package}/bin/postgres -D ${my_data}/data -h \"${_ip}\" -p \"${_id}\" 2>&1 > ${_id_log}/logfile &"
  nohup ${my_package}/bin/postgres -D ${my_data}/data -h "${_ip}" -p "${_id}" 2>&1 > ${_id_log}/logfile &
fi
