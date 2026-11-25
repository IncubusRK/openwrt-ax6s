
# Automatic OpenWRT builds for Xiaomi Redmi AX6S (AX3200) — OpenWrt 25.12 (apk)

## Состав прошивки

- **LuCI** + тема **argon** (настройки темы входят в неё саму) + русский язык,
  `luci-app-attendedsysupgrade` для обновлений без полной перепрошивки.
- **Диагностика**: `iperf3`, `tcpdump`, `mtr`.
- **SQM/CAKE** (`luci-app-sqm`), **nlbwmon** (учёт трафика), **watchcat**, BBR через sysctl.
- **zapret2**
- **podkop + podkop-engine**
- **WireGuard + AmneziaWG** (`luci-proto-amneziawg`) — вместо OpenVPN/L2TP.

По умолчанию **все прозрачные прокси выключены** — включайте один перехват за раз
(zapret2 *или* podkop), иначе правила будут конфликтовать.

## Обновление с 24.10 и опциональные пакеты

Переход с предыдущих образов этого репозитория (24.10) штатный: `DEVICE_COMPAT_VERSION`
устройства одинаковый в обеих ветках, достаточно залить
`openwrt-mediatek-mt7622-xiaomi_redmi-router-ax6s-squashfs-sysupgrade.itb` через
**System → Backup / Flash Firmware**. Старые `/etc/config/ruantiblock` и `/etc/config/zapret`
после обновления просто игнорируются — их можно удалить.

Пакеты, которые собраны, но **не** включены в образ (kmod-ы привязаны к версии ядра, поэтому
годится только архив того же релиза):

```sh
tar -xzf extra-packages.tar.gz -C /tmp/extra
apk add --allow-untrusted /tmp/extra/*.apk
```

## Установка прошивки с помощью Xiaomi MiR Patcher
Данный метод успешно работает на стоковой прошивке и аппаратной ревизии RB01
1. Распаковываем [XMiR Pather](https://github.com/openwrt-xiaomi/xmir-patcher/archive/refs/heads/main.zip) и помещаем прошивку [openwrt-mediatek-mt7622-xiaomi_redmi-router-ax6s-factory.bin](https://github.com/IncubusRK/openwrt-ax6s/releases/latest/download/openwrt-mediatek-mt7622-xiaomi_redmi-router-ax6s-factory.bin) в директорию firmware
2. Запускаем !START.bat
3. При необходимости в главном меню указываем другой IP адрес роутера - пункт "1 - Set IP-address"
4. Выбираем "2 - Connect to device (install exploit)", вводим пароль от Web интерфейса и дожидаемся установки
5. При необходимости можно включить постоянный доступ по SSH на стоковой прошивке пункт - "6 - Install permanent SSH"
6. Для установки прошивки выбираем "7 - Install firmware (from directory "firmware")" и дожидаемся окончания процесса. После этого роутер должен самостоятельно перезагрузиться

## Инструкция (только для ревизии RB03) по установке под Windows (гайд от [stroti](https://4pda.to/forum/index.php?showuser=4540991))
1. Скачиваем и устанавливаем через стандартное обновление роутера dev версию официальной прошивки [miwifi_rb03_firmware_stable_1.2.7.bin](https://raw.githubusercontent.com/YangWang92/AX6S-unlock/master/miwifi_rb03_firmware_stable_1.2.7.bin) (MD5: 5eedf1632ac97bb5a6bb072c08603ed7).

2. Скачиваем и устанавливаем [Python](https://www.python.org/ftp/python/3.10.10/python-3.10.10-amd64.exe)

    2.1 Скачиваем [скрипт](https://raw.githubusercontent.com/mikeeq/xiaomi_ax3200_openwrt/main/password.py) перейдя по ссылке и кликнув "Сохранить как" password.py

    2.2 Запускаем ранее установленный IDLE (Python 3.10 64-bit) >> File > Open > password.py в открывшимся окне жмем Shift+F5 > в поле ввода вставляем серийный номер роутера и жмем Ok. На выходе получаем пароль от Telnet

3. Скачиваем программу [PuTTY](https://www.putty.org/)

4. Запускаем PuTTY, в адресную строку вбиваем 192.168.31.1, в выпадающем списке под портом выбираем Telnet и жмем Open

    4.1. Откроется консоль, в поле логина вводим root в поле пароль вставляем ранее полученный пароль из скрипта (ввод символов в пароле не отображается)
    
    4.2. Копируем и вставляем следующие команды (Можно последовательно, можно скопом, если будите вставлять скопом не забудьте нажать Enter для выполнения последней в списке команды)

    ```
    nvram set ssh_en=1
    nvram set uart_en=1
    nvram set boot_wait=on
    nvram commit
    sed -i '/flg_ssh.*release/ { :a; N; /fi/! ba };/return 0/d' /etc/init.d/dropbear
    /etc/init.d/dropbear enable
    /etc/init.d/dropbear start
    ```


5. Скачиваем программу [WinSCP](https://winscp.net/eng/download.php)
    
    5.1. Запускаем 
    
    5.2 Протокол передачи выбираем SCP, Имя хоста: 192.168.31.1 Имя пользователя:  root Пароль: сгенерированный из скрипта
    
    5.3. В правой части программы поднимаемся в корневой каталог нажав на пиктограмму папки с стрелкой, после чего находим папку /tmp и переходим в нее
    
    5.4. Скачиваем прошивку [OpenWRT](https://github.com/IncubusRK/openwrt-ax6s/releases), а именно файл openwrt-mediatek-mt7622-xiaomi_redmi-router-ax6s-factory.bin и сохраняем ее как factory.bin

    5.5. Перетаскиваем наш factory.bin в открытую на WinSCP папку /tmp и дожидаемся загрузки

6. Заново открываем PyTTY в адресную строку вбиваем 192.168.31.1 (протокол в этот раз по умолчанию SSH) и жмем Open
    
    6.1. Логин root, пароль ранее полученный из скрипта (ввод символов в пароле не отображается)
    
    6.2. Вводим следующие команды (последняя команда запускает процесс прошивки, дороги назад уже не будет, будьте внимательнее)
    ```
    nvram set flag_boot_success=1
    nvram set flag_try_sys1_failed=0
    nvram set flag_try_sys2_failed=0
    nvram commit

    cd /tmp
    mtd -r write factory.bin firmware
    ```

    Если после ввода этих комманд роутер (RB03, AX6S) перегрузился со стоковой прошивкой, то используем повторяем пункт 6 со следующими комманды:

    ```
    nvram set flag_boot_rootfs=0
    nvram set "boot_fw1=run boot_rd_img;bootm"
    nvram set flag_boot_success=1
    nvram set flag_try_sys1_failed=0
    nvram set flag_try_sys2_failed=0
    nvram commit

    cd /tmp
    mtd -r write factory.bin firmware
    ```

7. Сидим и ждем, после прошивки роутер сам перезагрузится, а новая прошивка OpenWRT запустится по адресу 192.168.1.1 логин root пароль по молчанию не установлен, оставляем пустым и ждем войти.
    
    7.1 Если по новому адресу ни чего не появилось в течении 10 минут, а на роутере горит "индикатор питания" (Оранжевый диод System) тогда поздравляю, вы что то сделали не так и закирпичили роутер, скорее всего подсунули не тот образ прошивки. В таком случае переходим к пункту раскирпичивания

## Раскирпичивание в случае неудачной прошивки (гайд от [stroti](https://4pda.to/forum/index.php?showuser=4540991))

Тут есть 2 пути, воспользоваться программой заботливо сделанной китайцами из Xiaomi или поднять свой tftp сервер, мы пойдем по пути наименьшего сопротивления и выберем первый вариант.

Оригинальная инструкция с картинками

1. Скачиваем [Xiaomi Recovery Tool](http://bigota.miwifi.com/xiaoqiang/tools/MIWIFIRepairTool.x86.zip) (если не качается скопируйте адрес ссылки и вставьте в адресную строку новой вкладки)

2. Выставляем настройки сетевого интерфейса на ПК: IP 192.168.31.100 маска 255.255.255.0 и жмем окей

3. Распаковываем и запускаем MIWIFIRepairTool.x86.exe
    
    3.1. На первой странице программы выбираем стоковую прошивку, подойдет и dev версия miwifi_rb03_firmware_stable_1.2.7.bin (проверял лично) далее жмем на 3 вопросика в правом нижнем углу, на след странице оставляем все как есть и жмем на самые правые ??? в правом нижнем углу

    3.2. Подходим к роутеру -> отсоединяем кабель питания -> зажимаем кнопку reset > вставляем кабель питания и не отпускаем кнопку reset, пока не заморгает желтый светодиод system
    
    3.3. После того как заморгает, отпускаем кнопку reset, а на экране компьютера с программой можно наблюдать полоску с процессом восстановления прошивки, дожидаемся окончания, на роутере светодиоды загорятся синими начнут моргать, заходим на роутер по адресу 192.168.31.1 (не забываем сбросить настройку сетевого интерфейса в винде)

    На этом кирпич восстановлен, и можно повторить путь прошивки с начала.

## Сторонние компоненты

- [OpenWrt](https://github.com/openwrt/openwrt) — целевая прошивка.
- [GitHub Actions](https://github.com/features/actions) — сборка и публикация релизов.
- [zapret2-openwrt](https://github.com/1andrevich/zapret2-openwrt) — zapret2 (обход DPI через nftables).
- [podkop](https://github.com/itdoginfo/podkop) — маршрутизация по доменным спискам.
- [podkop-engine](https://github.com/podkop-net/podkop-engine) — сборка sing-box с XHTTP/REALITY для podkop.
- [awg-openwrt](https://github.com/Slava-Shchipunov/awg-openwrt) — AmneziaWG.
- [luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon) — тема LuCI.
- Гайды по установке и восстановлению — [stroti](https://4pda.to/forum/index.php?showuser=4540991) (4PDA).

## License

[MIT](LICENSE) © IncubusRK
