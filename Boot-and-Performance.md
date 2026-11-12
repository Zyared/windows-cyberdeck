# Arasaka: загрузка, оформление и автозапуск

## Переключение загрузки

Скопировать `Switch-Boot-Mode.ps1` в `%USERPROFILE%\CyberDeck`, а `Boot-FACEIT.cmd` и `Boot-Arasaka.cmd` на рабочий стол.

- **Boot-FACEIT.cmd** ставит Windows Boot Manager первым в UEFI.
- **Boot-Arasaka.cmd** находит единственную запись `\EFI\HackBGRT\loader.efi` и ставит её первой.
- Нужны права администратора. Автоматической перезагрузки нет. Изменение действует при следующем старте и сохраняется до обратного переключения.
- `-CheckOnly` проверяет наличие записи без изменения порядка. Логи и исходный порядок — `CyberDeck\backup\boot-switch`.

Secure Boot остаётся включённым. Темы рабочего стола и Steam не переключаются. Самоподписанный загрузчик может не пройти [аттестацию FACEIT](https://support.faceit.com/hc/en-us/articles/20669555338268-TPM-attestation-failed), поэтому режим FACEIT использует штатную цепочку. Успех запуска античита требует отдельной проверки после перезагрузки; это не обход античита.

## Оптимизация

`Optimize-Startup.ps1` сохраняет и удаляет только выбранные записи HKCU Run: Spotify, EA, LM Studio, Roblox, предзапуск Edge и Yandex. Уже запущенные приложения не закрывает. Повторное применение с существующей резервной копией блокируется. `-Undo` возвращает записи.

На этом ПК отдельно сохранён `powercfg /getactivescheme` в `CyberDeck\backup\power-before-optimization.txt`, затем включён `SCHEME_BALANCED` вместо Silent. `Restore-Optimization.cmd` запускает восстановление автозапуска и исходной схемы через `Restore-Optimization.ps1`; оба PS1 должны находиться в CyberDeck. Измеренного прироста FPS или сокращения загрузки пока нет.

## Иконки и часы

1. `Build-Theme-Addons.ps1` собирает исходники из `vendor` установленным компилятором Windhawk 1.7.3.
2. `python build-icon-resources.py --icons "$env:USERPROFILE\CyberDeck\icons" --output "$env:USERPROFILE\CyberDeck\icon-resources"` создаёт DLL только с ресурсами и theme.ini. Команда предназначена для PowerShell.
3. `Install-Theme-Addons.ps1` устанавливает Resource Redirect только в Explorer и Clock Styler только в LockApp, применяет существующие стили Arasaka. Требует отсутствия этих двух модов, чтобы не затереть чужие настройки.
4. `-Disable` отключает оба мода; аварийный CMD тоже их охватывает. Затем открыть новый сеанс, чтобы сбросить кэш процессов. Скрипты не блокируют ПК и не перезагружают его.

Ресурсы Windows не заменяются. Подменяются известные ресурсы главной страницы, галереи, компьютера, сети, корзины и пользовательских папок. Это не все значки всех программ Windows. OneDrive дополнительно настроен через apply-icons.ps1. Закреплённому File Explorer.lnk на этом ПК назначен thispc.ico; оригинал сохранён в CyberDeck\backup\File Explorer.lnk.

Проверка 12.11.2026: в живом Проводнике основные значки красные, полосы дисков красные, мод Resource Redirect загружен. Фон блокировки подтверждён через WinRT, часы сконфигурированы; реальный экран блокировки пока не проверен. Startup Sound Changer и пользовательский звук не затронуты.
