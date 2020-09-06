![Image alt](https://github.com/tank142/make-iso/raw/debian/screenshot2.png)
![Image alt](https://github.com/tank142/make-iso/raw/debian/screenshot.png)
# make.sh
Собирает образы iso и vdi ( при указании ключа -vdi ). Файлы из папки customization копируются в образ после установки. Файл config содержит большое количество настроек.
Зависимости: util-linux coreutils debootstrap parted gptfdisk awk sed
# dir-iso.sh
Создаёт образы из указанной папки: ./dir-iso.sh [папка] -vdi
