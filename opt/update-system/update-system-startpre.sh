#/bin/bash

function logging () {
    echo -e "$(date +%H:%M.%S) \t pre_$1 \t $2" >> "/var/log/update_system.log"
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

RED='\e[5;1;31m'
ENDFORM='\e[0m'
WHITE='\e[37m'
BOLD='\e[1m'
#Файл  версии обновления (файлы  скаченные)
FILEFLAGUPDATE="/usr/local/rg-flag/update"
# Файл установленой версии обновления (установленные из скаченных)
FILEFLAGUPGRADE="/usr/local/rg-flag/upgrade"
DIRFLAG="/usr/local/rg-flag/"
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
logging "begin" "Переменные проиницилизированы"
#Проверяем поднят ли флажок
if [ ! -e $DIRFLAG ] ; then
    echo "Вероятно служба только установлена"
    logging "-e DIRFLAG" "Папки нет, зашли в условие"
    mkdir -p /usr/local/rg-flag
    echo 0 > $FILEFLAGUPDATE
    echo 0 > $FILEFLAGUPGRADE
    logging "-e DIRFLAG" "Создали файлы и наполнили их ($FILEFLAGUPDATE, $FILEFLAGUPGRADE). Выходим из скрипта."
    exit 0
fi
if [[ !  -e $FILEFLAGUPGRADE && $FILEFLAGUPDATE ]] ; then
    echo "Ошибка, отсутсвуют файлы - флаги"
    logging "-e FILES" "Ошибка файлов флагов нет! Выходим из скрипта."
    echo 0 > $FILEFLAGUPDATE
    echo 0 > $FILEFLAGUPGRADE
    logging "-e FILES" "Файлы созданы, в них записаны нули."
    exit 0
fi
 
 if [[ $(cat $FILEFLAGUPDATE) == $(cat $FILEFLAGUPGRADE) ]] ; then
    echo "Cистема в актуальном состоянии, обновление не требуется"
    logging "UPDT=UPGRD?" "Значение  равны, дальше смысла работать нет."
    exit 0
 fi
# Чиним apt

#Обновление есть, обновляем систему
#TODO: Облагородить предупреждение для пользователя
sleep 10
# очищаем экран
logging "main" "Начинаем очистку экрана."
for ((i=10; i<81;i++))
do
    echo " " >> /dev/tty0
done
logging "Prestart" "Завершаем очистку экрана."
logging "Prestart" "Выводим предупреждение."
echo -e "${RED}                Внимание! \n ${ENDFORM}${WHITE} Начинается обновление операционной системы, продолжительность которого может составить до 40 минут. \n В целях обеспечения сохраности  Ваших данных ${BOLD}НЕ ВЫКЛЮЧАЙТЕ и НЕ ПЕРЕЗАГРУЖАЙТЕ${ENDFORM} ${WHITE} автоматизированное рабочее место. \n Телефон для справок:7101-5500"  >> /dev/tty0
check_lock_dpkg
dpkg --configure -a
logging "Prestart.Подготовка к обновлению" "Выполнили dpkg --conf... Результат: $?"
apt install -f -y
logging "Prestart.Подготовка к обновлению" "Выполнили apt install -f -y... Результат: $?"
sleep 15
logging "Prestart" "Начало проверки готовности пакетного менеджера к обновлению."
check_lock_dpkg
logging "Prestart" "Начинаем обновление."
/usr/bin/apt dist-upgrade -y >> /dev/tty0
logging "Prestart" "Обновление завершено. Результат: $?"
#Проверяем зависимость fly-dm от нашей службы
systemctl cat fly-dm | grep update_system
if [ $? -eq 1 ]
then
    logging "fly-dm_req" "fly-dm больше от нас не зависит, исправляем."
    #Если зависимости нет, то надо поправить
    #Для начала уберем все комментарии, они мешаются
    sed -i '/^#/d' /etc/systemd/system/display-manager.service
    #Вставляем нашу зависимость после after
    sed -i '/^After/a Requires=update_system.service' /etc/systemd/system/display-manager.service
    logging "fly-dm_req" "fly-dm теперь от нас зависит."
fi
 #Востанавливаем работоспобность КАП
if [ -f /usr/lib/x86_64-linux-gnu/libopensc.so.6.0.0 ]; then
    logging "cap" "создаем симлинк"
    ln -s /usr/lib/x86_64-linux-gnu/libopensc.so.6.0.0 /usr/lib/x86_64-linux-gnu/libopensc.so.4
    systemctl restart cts
    autoctsic        
    ctsic compute   
    echo "Контрольная сумма для КАП пересчитана"
    systemctl stop cts
fi

#выравниваем версию обновлений в файлах-флажках
cat $FILEFLAGUPDATE > $FILEFLAGUPGRADE
logging "main" "Все завершено. UPD=$(cat $FILEFLAGUPDATE) UPG=$(cat $FILEFLAGUPGRADE. Уходим в ребут)"
# перезагружаемся после обновления
init 6
#Обновляем систему