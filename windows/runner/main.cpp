#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/flutter_engine.h>
#include <windows.h>
#include "flutter_window.h"
#include "utils.h"

const wchar_t* kMutexName = L"Global\\F_SERVO_Instance";

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  bool hasArgs = !command_line_arguments.empty();

  // with the mutex we check if another instance is already running
  HANDLE hMutex = CreateMutex(nullptr, TRUE, kMutexName);
  DWORD lastError = GetLastError();
  bool anotherInstanceRunning = (lastError == ERROR_ALREADY_EXISTS || lastError == ERROR_ACCESS_DENIED);

    // if F-SERVO is already running, just starts a new flutter engine
    // to send the command line args to the existing instance
    // This fixes the issue that it opens a winndow for a split second
  if (hasArgs && anotherInstanceRunning) {
    if (hMutex) CloseHandle(hMutex);

    AttachConsole(ATTACH_PARENT_PROCESS);

    ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

    flutter::DartProject project(L"data");
    project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

    // this is for headless flutter engine to send the args
    flutter::FlutterEngine engine(project);
    if (!engine.Run()) {
      ::CoUninitialize();
      return EXIT_FAILURE;
    }

    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0)) {
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }

    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(100, 100);
  Win32Window::Size size(1280, 720);
  if (!window.CreateAndShow(L"F-SERVO", origin, size)) {
    if (hMutex) CloseHandle(hMutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (hMutex) CloseHandle(hMutex);
  return EXIT_SUCCESS;
}
