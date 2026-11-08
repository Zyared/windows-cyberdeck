#include <windows.h>
#undef GetCurrentTime
#include <cstdio>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.UI.Xaml.h>
#include <winrt/Windows.UI.Xaml.Hosting.h>
#include <winrt/Windows.UI.Xaml.Markup.h>
#include <winrt/Windows.UI.Xaml.Controls.h>
#include <winrt/Windows.System.h>
#include "shutdown-visuals.h"
int main() {
    if (!ArasakaStatus(L"Завершение работы") || !ArasakaStatus(L"Shutting down") ||
        !ArasakaStatus(L"Перезагрузка") || !ArasakaStatus(L"Restarting")) return 1;
    for (auto text : {L"", L"Installing updates 50%", L"Не выключайте компьютер",
                      L"Incorrect password", L"Shutting down service", L"Welcome"})
        if (ArasakaStatus(text)) return 2;
    try {
        winrt::init_apartment(winrt::apartment_type::single_threaded);
        struct Options { DWORD size; int threadType; int apartmentType; } options{sizeof(Options), 2, 2};
        using CreateQueue = HRESULT(WINAPI*)(Options, void**);
        auto createQueue = reinterpret_cast<CreateQueue>(GetProcAddress(LoadLibraryW(L"CoreMessaging.dll"), "CreateDispatcherQueueController"));
        if (!createQueue) return 6;
        winrt::Windows::System::DispatcherQueueController queue{nullptr};
        winrt::check_hresult(createQueue(options, winrt::put_abi(queue)));
        auto manager = winrt::Windows::UI::Xaml::Hosting::WindowsXamlManager::InitializeForCurrentThread();
        {
            using namespace winrt::Windows::UI::Xaml;
            auto data = Markup::XamlReader::Load(ArasakaShutdownTemplate).as<DataTemplate>();
            auto panel = data.LoadContent().as<Controls::StackPanel>();
            if (panel.Children().Size() != 3) return 3;
            auto progress = panel.Children().GetAt(2).as<Controls::ProgressBar>();
            if (!progress.IsIndeterminate() || progress.Width() != 320) return 4;
        }
        puts("PASS: four exact status mappings; unknown/error/update text unchanged; native XAML template instantiated; indeterminate ProgressBar verified.");
        fflush(stdout);
        manager.Close();
        return 0;
    } catch (winrt::hresult_error const& error) {
        wprintf(L"XAML validation failed: %08x %ls\n", (unsigned)error.code(), error.message().c_str());
        return 5;
    }
}
