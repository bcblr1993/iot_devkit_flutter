#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shlobj.h> // For SHGetFolderPath
#include <fstream>
#include <string>

#include "flutter_window.h"
#include "utils.h"

void WriteNativeCrashLog(const std::string& errorMsg) {
    char path[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathA(NULL, CSIDL_PERSONAL, NULL, 0, path))) { // CSIDL_PERSONAL is My Documents
        std::string dirPath = std::string(path) + "\\IoT DevKit";
        CreateDirectoryA(dirPath.c_str(), NULL);
        
        std::string logPath = dirPath + "\\crash_native.txt";
        std::ofstream logFile(logPath, std::ios::app);
        if (logFile.is_open()) {
            SYSTEMTIME lt;
            GetLocalTime(&lt);
            logFile << "[" << lt.wYear << "-" << lt.wMonth << "-" << lt.wDay << " " 
                    << lt.wHour << ":" << lt.wMinute << ":" << lt.wSecond << "] "
                    << "NATIVE CRASH: " << errorMsg << "\n" << std::endl;
            logFile.close();
        }
    }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  try {
      // Attach to console when present (e.g., 'flutter run') or create a
      // new console when running with a debugger.
      if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
        CreateAndAttachConsole();
      }

      // Create a named mutex to detect if the application is already running
      HANDLE hMutex = ::CreateMutex(nullptr, TRUE, L"IoTDevKit_Instance_Mutex");
      (void)hMutex;

      // Initialize COM
      if (FAILED(::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) {
          WriteNativeCrashLog("Failed to CoInitializeEx");
          return EXIT_FAILURE;
      }

      flutter::DartProject project(L"data");

      std::vector<std::string> command_line_arguments = GetCommandLineArguments();

      project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

      FlutterWindow window(project);
      Win32Window::Point origin(10, 10);
      Win32Window::Size size(1280, 720);
      if (!window.Create(L"iot_devkit", origin, size)) {
        WriteNativeCrashLog("Failed to create Flutter window");
        return EXIT_FAILURE;
      }
      window.SetQuitOnClose(true);

      ::MSG msg;
      while (::GetMessage(&msg, nullptr, 0, 0)) {
        ::TranslateMessage(&msg);
        ::DispatchMessage(&msg);
      }

      ::CoUninitialize();
      return EXIT_SUCCESS;
  } catch (const std::exception& e) {
      WriteNativeCrashLog(std::string("std::exception: ") + e.what());
      MessageBoxA(NULL, e.what(), "IoT DevKit Native Crash", MB_OK | MB_ICONERROR);
      return EXIT_FAILURE;
  } catch (...) {
      WriteNativeCrashLog("Unknown C++ Exception (SEH or other)");
      MessageBoxA(NULL, "Unknown Fatal Native Error", "IoT DevKit Native Crash", MB_OK | MB_ICONERROR);
      return EXIT_FAILURE;
  }
}
