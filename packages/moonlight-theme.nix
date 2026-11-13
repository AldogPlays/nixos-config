{ moonlight-qt, desktopTheme }:

let
  inherit (desktopTheme) roles typography;
in
moonlight-qt.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    # Moonlight selects Material itself and overrides its background in QML.
    # Namespace QML caches by executable path: reproducible resource timestamps
    # otherwise let Qt reuse old QML after a theme rebuild at a new store path.
    # Configure that native style locally instead of changing other Qt clients.
    substituteInPlace app/main.cpp \
      --replace-fail '#include <QQuickStyle>' \
        '#include <QQuickStyle>
         #include <QStandardPaths>
         #include <QCryptographicHash>' \
      --replace-fail 'qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");' \
        'qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "${
          if desktopTheme.appearance == "dark" then "Dark" else "Light"
        }");' \
      --replace-fail 'qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT", "Purple");' \
        'qputenv("QT_QUICK_CONTROLS_MATERIAL_ACCENT", "${roles.accent}");' \
      --replace-fail 'QQuickStyle::setStyle("Material");' \
        'QQuickStyle::setStyle("Material");
         qputenv("QML_DISK_CACHE_PATH", (QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
             + "/qmlcache/" + QString::fromLatin1(QCryptographicHash::hash(
                 app.applicationFilePath().toUtf8(), QCryptographicHash::Sha256).toHex())).toUtf8());
         qputenv("QT_QUICK_CONTROLS_MATERIAL_BACKGROUND", "${roles.background}");
         qputenv("QT_QUICK_CONTROLS_MATERIAL_FOREGROUND", "${roles.foreground}");
         qputenv("QT_QUICK_CONTROLS_MATERIAL_PRIMARY", "${roles.backgroundAlt}");
         QFont desktopFont("${typography.family}");
         desktopFont.setPointSizeF(${toString typography.size});
         app.setFont(desktopFont);'
    substituteInPlace app/gui/main.qml \
      --replace-fail 'Material.background = "#303030"' 'Material.background = "${roles.background}"'
    substituteInPlace app/gui/AutoResizingComboBox.qml \
      --replace-fail 'popup.background.color = "#424242"' 'popup.background.color = "${roles.surface}"'
    substituteInPlace app/gui/SettingsView.qml \
      --replace-fail skyblue '${roles.accent}'
    substituteInPlace app/gui/AppView.qml \
      --replace-fail '#D0808080' '#D0${builtins.substring 1 6 roles.surface}'

    # Upstream's white-only interface icons would disappear on the light preset.
    # Keep the application logo, host artwork and stream pixels unchanged.
    sed -i -e 's/fill="white"/fill="${roles.foreground}"/g' \
      -e 's/fill="#FFFFFF"/fill="${roles.foreground}"/g' app/res/*.svg
    substituteInPlace app/res/update.svg \
      --replace-fail 'fill="#FF0000"' 'fill="${roles.warning}"'
  '';
})
