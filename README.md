# make.sh
Собирает образы iso и vdi ( при указании ключа -vdi ). Файлы из папки customization копируются в образ после установки. Файл config содержит большое количество настроек.
Зависимости: pacman util-linux coreutils debootstrap parted gdisk awk sed virtualbox

# dir-iso.sh
Создаёт образы из указанной папки: ./dir-iso.sh [папка] -vdi
