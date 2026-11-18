// Mainuan: the Mainuan logo on the application launcher of existing accounts.
// Runs once per account (Plasma desktop shell update script). Only launchers
// that still show a KDE or Kubuntu default icon change.
const defaults = ["", "kde", "start-here-kde", "start-here-kde-symbolic",
                  "start-here-kde-plasma", "start-here-kde-plasma-symbolic",
                  "start-here-kubuntu", "kubuntu"];
const launchers = ["org.kde.plasma.kickoff", "org.kde.plasma.kicker", "org.kde.plasma.kickerdash"];
for (const panel of panels()) {
    for (const launcher of panel.widgets()) {
        if (!launchers.includes(launcher.type)) {
            continue;
        }
        launcher.currentConfigGroup = ["General"];
        if (defaults.includes(launcher.readConfig("icon", ""))) {
            launcher.writeConfig("icon", "mainuan");
        }
    }
}
