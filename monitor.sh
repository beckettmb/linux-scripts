#!/bin/bash


function network {
	ping -c 1 192.168.1.1 2>&1 > /dev/null
	if [ $?  -eq  0 ]
	then
		echo -en $GREEN"Up"
	else
		echo -en $RED"Down"
	fi
}

function cpu_temp {
	temp=$(sensors | grep "CPU Temp:" | awk '{ print $3 }' | cut -d '+' -f 2)
	temp_comp=$(echo $temp | cut -d '.' -f 1)
	if [ $temp_comp -le 25 ]
	then
		echo $GREEN$temp
	elif [ $temp_comp -le 50 ]
	then
		echo $YELLOW$temp
	elif [ $temp_comp -le 75 ]
	then
		echo $ORANGE$temp
	else
		echo $RED$temp
	fi
}

function cpu_usage {
	usage=$(top -b -n2 -p 1 | fgrep "Cpu(s)" | tail -1 | \
		awk -F'id,' -v prefix="$prefix" \
		'{ split($1, vs, ","); v=vs[length(vs)]; sub("%", "", v); printf "%s%.1f%%\n", prefix, 100 - v }')
	usage_comp=$(echo $usage | cut -d '.' -f 1)
	if [ $usage_comp -le 25 ]
	then
		echo $GREEN$usage
	elif [ $usage_comp -le 50 ]
	then
		echo $YELLOW$usage
	elif [ $usage_comp -le 75 ]
	then
		echo $ORANGE$usage
	else
		echo $RED$usage
	fi
}

function ram_usage {
	usage=$(free -h | sed -n '2 p' | awk '{ print $3"/"$2 }' | sed 's/Gi//')
	used=$(free -h | sed -n '2 p' | awk '{ print $3 }' | sed 's/Gi//')
	total=$(free -h | sed -n '2 p' | awk '{ print $2 }' | sed 's/Gi//')

	l1=$(echo "$total / 4" | bc -l)
	l2=$(echo "$total / 4 * 2" | bc -l)
	l3=$(echo "$total / 4 * 3" | bc -l)
	if [ $(echo "$used <= $l1" | bc) -eq 1 ]
	then
		echo $GREEN$usage
	elif [ $(echo "$used <= $l2" | bc) -eq 1 ]
	then
		echo $YELLOW$usage
	elif [ $(echo "$used <= $l3" | bc) -eq 1 ]
	then
		echo $ORANGE$usage
	else
		echo $RED$usage
	fi
}

function last_update {
	date=$(cat /var/log/pacman.log | grep "pacman -Syu" | tail -n 1 | awk '{ print $1 }')
	days=$((($(date +%s)-$(date +%s --date ${date:1:10}))/(3600*24)))
	if [ $days -le 2 ]
	then
		if [ $days -eq 1 ]
		then
			echo "$GREEN$days day ago"
		else
			echo "$GREEN$days days ago"
		fi
	elif [ $days -le 7 ]
	then
		echo "$YELLOW$days days ago"
	elif [ $days -le 30 ]
	then
		echo "$ORANGE$days days ago"
	else
		echo "$RED$days days ago"
	fi
}

function write {
	stop="\033[0m\033[10;1H"

	echo -en "\033[5;14H$5 $6 $7 $stop"
	echo -en "\033[6;10H$1  $stop"
	echo -en "\033[7;11H$2  $stop"
	echo -en "\033[8;12H$3  $stop"
	echo -en "\033[9;12H$4  $stop"
}

function update {
	network=$(network&)
	cpu_temp=$(cpu_temp&)
	cpu_usage=$(cpu_usage&)
	ram_usage=$(ram_usage&)
	last_update=$(last_update&)
	sleep 6
	write $network $cpu_temp $cpu_usage $ram_usage $last_update
}

GREEN="\033[32m"
YELLOW="\033[38;5;220m"
ORANGE="\033[38;5;208m"
RED="\033[31m"

clear -x

echo "Hostname: $(hostnamectl | grep "hostname" | awk '{ print $3 }')"
echo "$(hostnamectl | grep "Operating" | sed "s/^[ \t]*//")"
echo "$(hostnamectl | grep "Kernel" | sed "s/^[ \t]*//")"
echo "$(hostnamectl | grep "Architecture" | sed "s/^[ \t]*//")"
echo "Last Update:"
echo "Network:"
echo "CPU Temp:"
echo "CPU Usage:"
echo "RAM Usage:"
update&

while true; do
	read -rsn1 -t 6 KEY
	case $KEY in
		q)
			pkill -P $$
			break
			;;
		*)
			update&
			;;
	esac
done
