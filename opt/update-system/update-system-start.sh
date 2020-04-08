#/bin/bash

function logging () {
    echo -e "$(date +%H:%M.%S) \t start_$1 \t $2" >> "/var/log/update_system.log"
}

function check_lock_dpkg () {
	logging "check_lock_dpkg" ""
	RES=$( fuser -v /var/lib/dpkg/lock | wc -m)
	if (( $RES>0 ))
	then
		logging "check_lock_dpkg" " Служба установки пакетов занята. Повторим через 10 секунд."
		sleep 10
		check_lock_dpkg 
	else
		logging "check_lock_dpkg" " Служба установки пакетов cвободна. Продолжаем выполнение."
	fi

}

logging "update-system-start" "Начало работы"
#Время показа сообщения в мс
SHOWTIME=240000
#Иконка у сообщения
ICON="/usr/share/icons/fly-astra/96x96/actions/halfencrypted.png"
PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
#Файл  версии обновления (файлы  скаченные)
FILEFLAGUPDATE="/usr/local/rg-flag/update"
# Файл установленой версии обновления (установленные из скаченных)
FILEFLAGUPGRADE="/usr/local/rg-flag/upgrade"
DIRFLAG="/usr/local/rg-flag/"
	echo -e $(date +"%H:%M.%S %d.%m.%y") \t "Служба запустилась"
	echo -e "Список репозиториев:"
	echo -e $(cat /etc/apt/sources.list)
	echo -e $(cat /etc/apt/sources.list.d/*.list)
logging "update-system-start" "Все переменные проинициализированы"
#Проверяем есть ли обновление
while true
do
	check_lock_dpkg
	dpkg --configure -a
	logging "Start.Основной цикл" "Выполнили dpkg --conf... Результат: $?"
	apt install -f -y
	logging "Start.Основной цикл" "Выполнили apt install... Результат: $?"
	COUNT_UPDATE_PACKAGE=$( apt list --upgradable | wc -l )
	logging "Start.Основной цикл" "Проверили количество обновляемых пакетов: Количество новых пакетов: $COUNT_UPDATE_PACKAGE Результат работы команды: $?"
	if [[ $COUNT_UPDATE_PACKAGE > 1 && $(cat $FILEFLAGUPDATE) -eq $(cat $FILEFLAGUPGRADE) ]] ; then 
		logging "if" "Начало обновления"
		RESULT_UPDATE=$(apt dist-upgrade --download-only -y)
		if [ $? -eq 0 ] ; then
			logging "if2" "Обновление  информации о пакетах успешно завершенно."
			#TODO: в холостую прогнать обновление.
			apt -s dist-upgrade 
			if [ $? -eq 0 ] ; then
				UPDATE_VERSION=$(cat $FILEFLAGUPDATE)
				logging "if2" "UPDATE_VERSION=$UPDATE_VERSION"
				let "UPDATE_VERSION++"
				logging "if2" "UPDATE_VERSION+1=$UPDATE_VERSION"
				echo $UPDATE_VERSION > $FILEFLAGUPDATE
				logging "if2" "FILEFLAGUPDATE=$(cat $FILEFLAGUPDATE)"
				echo "Скачены последние пакеты для обновлений. Текущая версия обновлений: $UPDATE_VERSION, Версия установленных обновлений: $(cat $FILEFLAGUPGRADE)"
				#Выводим уведомление пользователю о готовящемся обновлении
				for user in $(who | cut -f 1 -d ' ')
				do 
				# Получаем список пользователей 
					echo "Выводим сообщение для пользователя:" $user 
					for pid in $(ps U $user | grep fly-wm | sed 's/^ *//g' | cut -f 1 -d ' ')
					do
						dbus_address=$( grep -z DBUS_SESSION_BUS_ADDRESS /proc/$pid/environ )
						echo "dbus=" $DBUS
						sudo -u $user -s $dbus_address notify-send -i $ICON -t 240000 "Внимание!" "Ваша операционная система готова к обновлению, которое будет установлено во время следующей загрузки операционной системы <br> В целях обеспечения сохраности Ваших данных <b>НЕ ВЫКЛЮЧАЙТЕ</b> и <b>НЕ ПЕРЕЗАГРУЖАЙТЕ</b> автоматизированное рабочее место в процессе обновления."
					done
				done
			else
				logging "Start. Checking compatibility update" "Проверка на приминимость обновления завершилось ошибкой"
			fi
			
		else
			logging "if2" "Обновление информации о пакетах завершилось с ошибкой. Причина: $RESULT_UPDATE."
		fi
	fi
	sleep 1800
done