# Первый запуск Arasaka / HackBGRT

HackBGRT установлен отдельной записью; исходный Windows Boot Manager сохранён.
ПК автоматически не перезагружался. Secure Boot включён.

При следующей перезагрузке возможен экран Verification failed / Security Violation:
1. OK, затем быстро нажать клавишу для MOK management.
2. Enroll hash from disk → системный EFI-раздел → EFI → HackBGRT → grubx64.efi.
3. Continue → Yes → Reboot. Не выбирать Enroll key from disk.

Если загрузка не продолжается: в меню загрузки UEFI выбрать Windows Boot Manager.
В Windows запустить Restore-Windows-Boot.cmd от администратора: он возвращает
Windows Boot Manager первым и отключает запись HackBGRT. Автоперезагрузки нет.
Этот файл нужен после входа в Windows; до загрузки использовать меню UEFI.

Логотип заменяет изображение BGRT. Кружок ранней загрузки остаётся штатным.
Фактическая работа после перезагрузки ещё не проверена.
