; Portable single-file SFX wrapper for the Flutter Windows build.
;
; Extracts the built bundle to %TEMP%\<rand>\app, runs librescoot_installer.exe,
; forwards CLI args, propagates exit code. The temp dir is auto-cleaned by NSIS
; when the wrapper exits. No installer UI, no Start menu entry, no registry.
;
; Build:
;   makensis /DPRODUCT_VERSION=v1.2.3 /DBUILD_DIR=...\Release \
;            /DOUT_FILE=...\librescoot-installer-windows-x64-v1.2.3.exe \
;            installer.nsi

!define PRODUCT_NAME "Librescoot Installer"

!ifndef PRODUCT_VERSION
  !define PRODUCT_VERSION "dev"
!endif
!ifndef BUILD_DIR
  !define BUILD_DIR "..\build\windows\x64\runner\Release"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "librescoot-installer-windows-x64-${PRODUCT_VERSION}.exe"
!endif
!ifndef INNER_EXE
  !define INNER_EXE "librescoot_installer.exe"
!endif

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "${OUT_FILE}"

; The inner app needs admin (pnputil, network config, ShellHWDetection).
; UAC prompt fires once; the inner exe inherits the elevated token.
RequestExecutionLevel admin

; No NSIS-side UI — pure self-extract + run.
SilentInstall silent
ShowInstDetails nevershow
SetCompressor /SOLID lzma

; VIProductVersion requires X.X.X.X. CI passes a clean numeric form via
; /DNUMERIC_VERSION=1.0.5.0; default keeps local builds working without it.
!ifndef NUMERIC_VERSION
  !define NUMERIC_VERSION "0.0.0.0"
!endif
VIProductVersion "${NUMERIC_VERSION}"
VIAddVersionKey "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "CompanyName" "Librescoot"
VIAddVersionKey "FileDescription" "${PRODUCT_NAME}"
VIAddVersionKey "LegalCopyright" "Librescoot"

!include "FileFunc.nsh"

Section
  ; $PLUGINSDIR is auto-created and auto-deleted at exit.
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\app"
  File /r "${BUILD_DIR}\*"

  ${GetParameters} $R0
  ExecWait '"$PLUGINSDIR\app\${INNER_EXE}" $R0' $R1
  SetErrorLevel $R1
SectionEnd
