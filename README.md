# ARASAKA / CYBER//DECK — оформление Windows 11

Красно-чёрный корпоративный терминал из Cyberpunk 2077: эмблема Arasaka, 荒坂, Night City, сетка интерфейса и контрастные панели. Персональная фанатская тема, не официальный продукт CD PROJEKT RED.

## Что входит

| Часть | Реализация |
|---|---|
| Рабочий стол | HTML/SVG-обои, часы, мягкий импульс и сканирование; Wallpaper Engine или Lively |
| Экран блокировки | Статическое изображение Arasaka через штатный Windows API |
| Windows | Тёмный режим, красные акценты, курсоры и значки |
| Пуск и панели | Эмблема Arasaka, красные рамки и подписи, почти чёрные поверхности через Windhawk |
| Вход | Заставка на 6 секунд после входа в учётную запись |
| Выключение и перезагрузка | Отдельные ярлыки Arasaka с заставкой на 9 секунд; Esc отменяет действие |
| Дополнительно | Палитра Rainmeter и Windows Terminal при наличии поддерживаемой установки |

## Установка с Wallpaper Engine

Перед обновлением сохраните папку `%USERPROFILE%\CyberDeck` и конфигурацию Wallpaper Engine. Исходная папка `backup` при повторной установке сохраняется.

В обычном Windows PowerShell из папки репозитория:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\apply.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\CyberDeck\apply-wallpaper-engine.ps1"
```

Установка генерирует графику, применяет цвета, курсоры, значки, экран блокировки, автозапуск заставки и три ярлыка. Проводник перезапускается: окна папок закроются, программы остаются запущенными.

Для меню и панелей нужны Windhawk и моды Windows 11 Start Menu Styler, Windows 11 File Explorer Styler, Windows 11 Taskbar Styler, Windows 11 Notification Center Styler, Windows 11 Settings Styler, Translucent Windows. Настройки применяются с правами администратора:

```powershell
Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$env:USERPROFILE\CyberDeck\windhawk-settings.ps1`" -WithTranslucent"
```

Lively и Rainmeter — дополнительный вариант: `apply-live.ps1` требует установленный Rainmeter, а без `-Wallpaper WallpaperEngine` ещё и Lively. Для одного Wallpaper Engine этот скрипт не нужен.

## Заставки сеанса

- **Arasaka - Preview** показывает заставку без выключения.
- **Arasaka - Shutdown** показывает отсчёт перед выключением Windows.
- **Arasaka - Restart** показывает отсчёт перед перезагрузкой Windows.
- Esc или закрытие окна до конца отсчёта отменяет действие.
- `-Preview` для любого режима исключает вызов выключения.
- Принудительное закрытие приложений не используется: программы с несохранёнными данными могут остановить завершение работы стандартным способом.

```powershell
powershell -NoProfile -STA -File .\session-screen.ps1 -Mode Shutdown -Preview
```

Заставка работает на основном экране пользовательского сеанса. Обычная кнопка выключения Windows её не запускает. Winlogon, экран обновлений и ранний логотип UEFI не подменяются. [Microsoft: Unbranded Boot и BGRT](https://learn.microsoft.com/en-us/windows/configuration/unbranded-boot/).

## Откат

`%USERPROFILE%\CyberDeck\Restore-Windows-Look.bat` использует исходный backup, возвращает прежние настройки и отключает моды. Также удаляет ярлыки Arasaka и автозапуск заставки. Программы остаются установленными. Только убрать заставки и ярлыки:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\CyberDeck\install-session.ps1" -Undo
```

## Проверки и ограничения

Графика генерируется локально. Обои не выполняют сетевые запросы. Надписи корпоративной сети — оформление, а не мониторинг защиты. Часы показывают время Windows. Анимации поддерживают паузу Wallpaper Engine и `prefers-reduced-motion`.

Windhawk зависит от сборки Windows. Не добавляйте окраску `SystemTray.ChevronIconView` и общих `TextBlock` в трее: ранее это вызывало падения Explorer в `Windows.UI.Xaml.dll`. Значки сторонних программ в трее задаются самими программами. Часть специальных значков Windows может сохраняться или требовать обновления кэша.

Реальную перезагрузку и выключение проверяйте после сохранения работы; предпросмотр их не проверяет.
