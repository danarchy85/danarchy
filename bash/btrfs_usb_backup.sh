#!/bin/bash
set -o pipefail

check_if_charging() {
    if [[ $(find /sys/devices/ -type d -name BAT* -exec grep 'Discharging' {}/status \;) ]]; then
        echo "Battery is discharging. Skipping this run."
        exit
    fi
}

check_if_running() {
    if [[ -f ${state_file} ]]; then
        pgrep_rsync=$(/usr/bin/pgrep -f rsync &> /dev/null ; echo ${?})

        if [[ ${pgrep_rsync} == 0 ]]; then
	    echo "$(date +%FT%T) Rsync already running. Skipping this run."
	    exit 1
        fi

        rm ${state_file}
    fi
}

decrypt_and_mount_volume() {
    touch ${state_file}
    dev_path="/dev/disk/by-uuid/${uuid}"
    luks_vol="luks-usb-backup"
    luks_path="/dev/mapper/${luks_vol}"

    if [[ ! -L ${dev_path} ]]; then
        echo "$(date +%FT%T) Disk not present."
        exit
    elif [[ ! -L ${luks_path} ]]; then
        echo "$(date +%FT%T) Disk present: decrypting volume."
        /usr/sbin/cryptsetup open -d ${key_file} ${dev_path} ${luks_vol}
    else
        echo 'Volume already decrypted.'
    fi

    if [[ -L ${luks_path} ]]; then
        test -d ${mount} || mkdir -vp ${mount}
        /usr/bin/mount ${luks_path} ${mount} 2>&1
    fi
}

unmount_volume() {
    mount_not_in_use=$(lsof ${mount} &>/dev/null ; echo ${?})
    if [[ ${mount_not_in_use} == 1 ]]; then
        /usr/bin/umount ${mount} 2>&1
    else
        echo 'Mount still in use!'
        exit 1
    fi

    luks_vol="luks-usb-backup"
    /usr/sbin/cryptsetup close ${luks_vol}
    rm ${state_file}
}

run_backup() {
    touch ${state_file}
    echo -e "\nRunning Rsync for: ${datasets}"
    for dataset in ${datasets}; do
        echo " |_ Rsyncing: /${dataset} => ${mount}/${dataset}"
	/usr/bin/rsync -Havu --delete --delete-excluded \
                       --exclude=*cache* --exclude=*Cache* \
                       /${dataset}/ ${mount}/${dataset}/ \
                       > ${logdir}/rsync-${dataset}.btrfs_usb_backup.log 2>&1
    done

    echo -e "\n$(date +%FT%T) Backup complete!"
}

snapshots_frequent() {
    touch ${state_file}
    local dataset=${1}
    local snap=".snapshots.${dataset}/snapshot.${date}T${time}"

    echo -n '   |+ '
    /sbin/btrfs subvolume snapshot -r ${mount}/${dataset} ${mount}/${snap} 2>&1

    local latest_snaps=$(/sbin/btrfs subvolume list -t ${mount} | \
                             awk "/${dataset}.*snapshot\.[0-9]/ {print\$4}")

    for snap in ${latest_snaps} ; do
	local _date=$(date -d "$(echo ${snap} | awk -F\. '{print$4}')" '+%s')

	if [[ ${_date} < $(date -d "${frequent}" '+%s') ]]; then
	    echo "   |- Removing snapshot: ${mount}/${snap}"
	    /sbin/btrfs subvolume delete -C "${mount}/${snap}"
        else
            break
	fi
    done
}

snapshots_daily() {
    touch ${state_file}
    local dataset=${1}
    local snap=".snapshots.${dataset}/snapshot.daily.${date}T${time}"

    local daily_snaps=$(/sbin/btrfs subvolume list -t ${mount} | \
                             awk "/${dataset}.*snapshot\.daily/ {print\$4}")
    if [[ $(echo "${daily_snaps}" | tail -1 | grep ${date}) ]]; then
        echo "   |_ Daily  Snapshot: ${date} already exists!"
    else
        /sbin/btrfs subvolume snapshot -r ${mount}/${dataset} ${mount}/${snap} 2>&1

        for snap in ${daily_snaps} ; do
	    local _date=$(date -d "$(echo ${snap} | awk -F\. '{print$5}')" '+%s')

	    if [[ ${_date} < $(date -d "${daily}" '+%s') ]]; then
	        echo "     |- Removing snapshot: ${mount}/${snap}"
	        /sbin/btrfs subvolume delete -C "${mount}/${snap}"
            else
                break
	    fi
        done
    fi
    
}

snapshots_weekly() {
    touch ${state_file}
    local dataset=${1}
    local snap=".snapshots.${dataset}/snapshot.weekly.${date}T${time}"

    if [[ ! $(date | grep Fri) ]]; then
        echo "   |_ Weekly Snapshot: Not Friday, skipping weekly snapshot."
        return
    fi

    local weekly_snaps=$(/sbin/btrfs subvolume list -t ${mount} | \
                             awk "/${dataset}.*snapshot\.weekly/ {print\$4}")
    if [[ $(echo "${weekly_snaps}" | tail -1 | grep ${date}) ]]; then
        echo "   |_ Weekly snapshot for ${date} already exists!"
    else
        /sbin/btrfs subvolume snapshot -r ${mount}/${dataset} ${mount}/${snap} 2>&1

        for snap in ${weekly_snaps} ; do
	    local _date=$(date -d "$(echo ${snap} | awk -F\. '{print$5}')" '+%s')

	    if [[ ${_date} < $(date -d "${weekly}" '+%s') ]]; then
	        echo "    |- Removing snapshot: ${mount}/${snap}"
	        /sbin/btrfs subvolume delete -C "${mount}/${snap}"
            else
                break
	    fi
        done
    fi
}

run_snapshots() {
    echo -e "\nRunning Snapshots: ${datasets}"
    for dataset in ${datasets}; do
        echo " |_ Managing snapshots for ${dataset}"
        snapshots_frequent ${dataset}
        snapshots_daily    ${dataset}
        snapshots_weekly   ${dataset}
    done
}

main() {
    echo -e "\n================="
    date=$(date +%F)
    time=$(date +%T)

    check_if_charging
    check_if_running
    decrypt_and_mount_volume

    run_snapshots
    run_backup
    unmount_volume
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    config=${1}
    state_file='/tmp/btrfs_usb_backup.run'
    mount='/mnt/usb_backup'

    if [[ -f ${config} ]]; then
        source ${config}
        main &>> ${logdir}/btrfs_usb_backup.log
    else
        echo "Could not find a config at ${config}"
        cat <<EOF
Example:
  ## Volume Information
  uuid='USB-UUID'
  key_file='Cryptsetup Key Location'

  ## Datasets: directories to backup minus leading /
  ##  For example, to backup /home/user1/ and /server_data/:
  datasets='home/user1 server_data'

  ## Snapshot Retention in $(date) style:
  frequent='14 days ago'
  daily='2 weeks ago'
  weekly='2 months ago'
EOF
        echo -e "\nExiting!"
        exit 1
    fi
fi
