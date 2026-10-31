import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GTK titlebar setup terminates and follows subsequent window titles',
    () async {
      final source = File('linux/runner/my_application.cc').readAsStringSync();
      final start = source.indexOf('  if (use_header_bar) {');
      final end = source.indexOf('  // Same on every platform.', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final root = Directory.systemTemp.createTempSync('installer-gtk-title-');
      addTearDown(() => root.deleteSync(recursive: true));
      final testSource = File('${root.path}/titlebar.c');
      testSource.writeAsStringSync('''
#include <gtk/gtk.h>

static void check_window(gboolean use_header_bar) {
  GtkWindow *window = GTK_WINDOW(gtk_window_new(GTK_WINDOW_TOPLEVEL));
${source.substring(start, end)}
  g_assert_cmpstr(gtk_window_get_title(window), ==, "Librescoot Installer");
  GtkWidget *header = gtk_window_get_titlebar(window);
  g_assert((header != NULL) == use_header_bar);
  const gchar *titles[] = {
    "Librescoot Installer v1.4.5",
    "Librescoot Installer v1.4.6-beta.1",
    "Librescoot Installer v1.4.6-beta.1",
  };
  for (guint i = 0; i < G_N_ELEMENTS(titles); i++) {
    gtk_window_set_title(window, titles[i]);
    g_assert_cmpstr(gtk_window_get_title(window), ==, titles[i]);
    if (use_header_bar) {
      g_assert_cmpstr(gtk_header_bar_get_title(GTK_HEADER_BAR(header)), ==, titles[i]);
    }
  }
  gtk_widget_show_all(GTK_WIDGET(window));
  g_assert(gtk_widget_get_mapped(GTK_WIDGET(window)));
  gtk_widget_destroy(GTK_WIDGET(window));
}

int main(int argc, char **argv) {
  gtk_init(&argc, &argv);
  check_window(TRUE);
  check_window(FALSE);
  g_print("Both GTK titlebar paths completed\\n");
  return 0;
}
''');
      final flags = await Process.run('pkg-config', [
        '--cflags',
        '--libs',
        'gtk+-3.0',
      ]);
      expect(
        flags.exitCode,
        0,
        reason: 'GTK tests require libgtk-3-dev: ${flags.stderr}',
      );
      final executable = '${root.path}/titlebar';
      final compile = await Process.run('cc', [
        testSource.path,
        '-o',
        executable,
        ...flags.stdout.toString().trim().split(RegExp(r'\s+')),
      ]);
      expect(compile.exitCode, 0, reason: compile.stderr.toString());
      // timeout terminates the entire process group, including Xvfb and a
      // GTK process caught in a title-notification loop.
      final result = await Process.run(
        'timeout',
        ['8', 'xvfb-run', '-a', executable],
        environment: {'GDK_BACKEND': 'x11', 'NO_AT_BRIDGE': '1'},
      );
      expect(
        result.exitCode,
        0,
        reason: 'GTK titlebar setup hung or failed: ${result.stderr}',
      );
      expect(result.stdout, contains('Both GTK titlebar paths completed'));
    },
    skip: !Platform.isLinux,
  );
}
