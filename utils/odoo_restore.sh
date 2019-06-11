#!/usr/bin/env bash
#

set -e

readonly CONTAINER="<container>"

export PGHOST="<pghost>"
export PGPORT="<pgport>"
export PGUSER="<pguser>"
export PGPASSWORD="<pgpassword>"

# Is Postgres client available on this local machine?
#
    readonly PG_RESTORE="pg_restore"

# Is Postgres client available inside a Docker container?
#
    readonly POSTGRES="<postgres container>"
    readonly PG_RESTORE="docker exec -i ${POSTGRES} pg_restore -U ${PGUSER}"

readonly FILESTORE="/var/lib/odoo/filestore"

readonly ARCHIVE="${1}"

if [[ -z "${ARCHIVE}" ]]
then
    echo "Usage: $(basename "${0}") <path/to/dump/file.tar.gz>"

    exit -1
fi

read -p "New database name: " DATABASE

readonly EXTRACT_DIR="${ARCHIVE%".tar.gz"}"

mkdir -p "${EXTRACT_DIR}"

echo -e "Extracting backup... \c"
tar -xzvf "${ARCHIVE}" -C "${EXTRACT_DIR}" &> /dev/null
echo -e "\e[32mOK!\e[0m"

readonly OLD_DATABASE=$(ls "${EXTRACT_DIR}")

cd "${EXTRACT_DIR}/${OLD_DATABASE}"

echo -e "Creating new database... \c"
createdb "${DATABASE}"
echo -e "\e[32mOK!\e[0m"

echo -e "Restoring database... \c"
$PG_RESTORE -Fc -d "${DATABASE}" -O "${OLD_DATABASE}.dump"
echo -e "\e[32mOK!\e[0m"

echo -e "Copying filestore... \c"
docker exec ${CONTAINER} mkdir -p "${FILESTORE}"
docker cp "${OLD_DATABASE}" "${CONTAINER}:${FILESTORE}/"
echo -e "\e[32mOK!\e[0m"

echo -e "Renaming filestore... \c"
docker exec ${CONTAINER} bash -c "if [[ -d \"${FILESTORE}/${DATABASE}\" ]]; then rm -rf \"${FILESTORE}/${DATABASE}\"; fi"
docker exec ${CONTAINER} mv "${FILESTORE}/${OLD_DATABASE}" "${FILESTORE}/${DATABASE}"
echo -e "\e[32mOK!\e[0m"

echo -e "Changing permissions on filestore... \c"
docker exec ${CONTAINER} chown -R odoo:odoo "${FILESTORE}/${DATABASE}"
echo -e "\e[32mOK!\e[0m"

cd ../..

echo -e "Removing temporary directories... \c"
rm -rf "${EXTRACT_DIR}" &> /dev/null
echo -e "\e[32mOK!\e[0m"

echo -e "\nDone!\n"
