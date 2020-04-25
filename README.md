# make.sh
Собирает образы iso и vdi ( при указании ключа -vdi ). Файлы из папки customization копируются в образ после установки. Файл config содержит большое количество настроек.
Зависимости: pacman util-linux coreutils parted gptfdisk awk sed

# dir-iso.sh
Создаёт образы из указанной папки: ./dir-iso.sh [папка] -vdi
