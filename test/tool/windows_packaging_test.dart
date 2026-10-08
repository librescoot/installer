import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File(
    '.github/workflows/build-desktop.yml',
  ).readAsStringSync();
  final resolver = RegExp(
    r'^ {10}function Find-Makensis \{[\s\S]*?^ {10}\}',
    multiLine: true,
  ).firstMatch(workflow)!.group(0)!;

  test(
    'Windows packaging resolves installed compiler and checks installation',
    () {
      expect(
        resolver,
        contains('Get-Command makensis -CommandType Application'),
      );
      expect(resolver, contains(r'${env:ProgramFiles}\NSIS\makensis.exe'));
      expect(resolver, contains(r'${env:ProgramFiles(x86)}\NSIS\makensis.exe'));
      expect(workflow, contains('NSIS installation failed (exit'));
      expect(
        workflow,
        contains('NSIS installed but makensis.exe could not be found'),
      );
      expect(workflow, contains(r'& $makensis /V2'));
    },
  );

  String? shell;
  for (final candidate in ['pwsh', 'powershell.exe', 'powershell']) {
    try {
      if (Process.runSync(candidate, [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'exit 0',
          ]).exitCode ==
          0) {
        shell = candidate;
        break;
      }
    } on ProcessException {
      // PowerShell is optional on Linux test hosts.
    }
  }

  test(
    'compiler resolver handles PATH, 64-bit, 32-bit and absent layouts',
    () async {
      final script =
          r'''
$env:ProgramFiles = 'C:\mock64'
${env:ProgramFiles(x86)} = 'C:\mock32'
$script:mockCommand = $null
$script:existingPath = $null
function Get-Command {
  param($Name, $CommandType, $ErrorAction)
  return $script:mockCommand
}
function Test-Path {
  param($LiteralPath, $PathType)
  return $LiteralPath -eq $script:existingPath
}
''' +
          resolver +
          r'''
$script:mockCommand = @{ Source = 'C:\mock-path\makensis.exe' }
if ((Find-Makensis) -ne 'C:\mock-path\makensis.exe') { throw 'PATH resolver failed' }
$script:mockCommand = $null
$script:existingPath = 'C:\mock64\NSIS\makensis.exe'
if ((Find-Makensis) -ne $script:existingPath) { throw '64-bit layout failed' }
$script:existingPath = 'C:\mock32\NSIS\makensis.exe'
if ((Find-Makensis) -ne $script:existingPath) { throw '32-bit layout failed' }
$script:existingPath = $null
if ($null -ne (Find-Makensis)) { throw 'Missing compiler must not resolve' }
Write-Output 'NSIS resolver fixtures passed'
''';
      final bytes = <int>[];
      for (final unit in script.codeUnits) {
        bytes.addAll([unit & 0xff, unit >> 8]);
      }
      final result = await Process.run(shell!, [
        '-NoProfile',
        '-NonInteractive',
        '-EncodedCommand',
        base64Encode(bytes),
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('NSIS resolver fixtures passed'));
    },
    skip: shell == null ? 'PowerShell is unavailable on this host' : false,
  );
}
