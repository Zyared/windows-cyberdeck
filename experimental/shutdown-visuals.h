#pragma once
#include <string_view>
inline const wchar_t* ArasakaStatus(std::wstring_view status) {
    if (status == L"Завершение работы" || status == L"Shutting down")
        return L"ARASAKA // ОТКЛЮЧЕНИЕ СИСТЕМЫ";
    if (status == L"Перезагрузка" || status == L"Restarting")
        return L"ARASAKA // ПЕРЕЗАПУСК СИСТЕМЫ";
    return nullptr;
}
inline constexpr wchar_t ArasakaShutdownTemplate[] = LR"xaml(
<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
  <StackPanel Width="320" HorizontalAlignment="Center" Margin="0,16,0,20">
    <TextBlock Text="ARASAKA" Foreground="#FFED2438" FontFamily="Bahnschrift"
               FontSize="34" FontWeight="Bold" HorizontalAlignment="Center"/>
    <TextBlock Text="CORPORATE SYSTEMS // SECURE TERMINAL" Foreground="#FFDBDBE0"
               FontFamily="Consolas" FontSize="12" HorizontalAlignment="Center" Margin="0,4,0,20"/>
    <ProgressBar IsIndeterminate="True" Width="320" Height="8"
                 Foreground="#FFED2438" Background="#FF300C12"/>
  </StackPanel>
</DataTemplate>)xaml";
