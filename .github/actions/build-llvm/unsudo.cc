#define _WIN32_WINNT 0x0A00

#include <windows.h>
#include <winsafer.h>

static inline bool xisspace(wchar_t c) {
    return c == L' ' || c == L'\t';
}

extern "C" void __main() {}
int main() {
    SAFER_LEVEL_HANDLE safer = nullptr;
    if (!SaferCreateLevel(SAFER_SCOPEID_USER, SAFER_LEVELID_NORMALUSER, SAFER_LEVEL_OPEN, &safer, nullptr)) {
        ExitProcess(1);
        return 1;
    }

    HANDLE hnew = nullptr;
    if (!SaferComputeTokenFromLevel(safer, nullptr, &hnew, 0, nullptr)) {
        SaferCloseLevel(safer);
        ExitProcess(2);
        return 2;
    }
    SaferCloseLevel(safer);

    HANDLE huser = nullptr;
    if (!DuplicateTokenEx(hnew, MAXIMUM_ALLOWED, NULL, SecurityImpersonation, TokenPrimary, &huser)) {
        CloseHandle(hnew);
        ExitProcess(3);
        return 3;
    }
    CloseHandle(hnew);

    STARTUPINFOW si{};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi;

    const wchar_t *p = GetCommandLineW();
    if (*p == L'"') {
        while (*p && *++p != L'"');
    }
    while (*p && !xisspace(*p)) ++p;
    while (xisspace(*p)) ++p;

    wchar_t *buf = (wchar_t *)HeapAlloc(GetProcessHeap(), 0, lstrlenW(p) * 2 + 2);
    lstrcpyW(buf, p);
    if (!CreateProcessAsUserW(huser, nullptr, buf, nullptr, nullptr, true, 0, nullptr, nullptr, &si, &pi)) {
        CloseHandle(huser);
        ExitProcess(4);
        return 4;
    }
    HeapFree(GetProcessHeap(), 0, buf);
    CloseHandle(huser);

    CloseHandle(pi.hThread);
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD e;
    if (!GetExitCodeProcess(pi.hProcess, &e)) {
        ExitProcess(5);
        return 5;
    }
    CloseHandle(pi.hProcess);

    ExitProcess(e);
    return e;
}
