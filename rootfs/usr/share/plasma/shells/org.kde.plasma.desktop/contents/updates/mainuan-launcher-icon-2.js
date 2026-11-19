// Mainuan: the Mainuan logo on every application launcher of existing accounts.
// Runs once per account (Plasma desktop shell update script). It extends
// mainuan-launcher-icon.js to the launchers the Mainuan Welcome layouts use
// (Orbit, Tahoe, Deepin, Plasma Drawer) and undoes the "start-here-hexabee"
// custom image older Welcome layouts wrote. An icon the user picked is kept.
const defaults = ["", "kde", "start-here", "start-here-symbolic", "start-here-kde",
                  "start-here-kde-symbolic", "start-here-kde-plasma",
                  "start-here-kde-plasma-symbolic", "start-here-kubuntu", "kubuntu"];
const oldCustomImages = ["", "start-here-hexabee"];
const launchers = ["org.kde.plasma.kickoff", "org.kde.plasma.kicker", "org.kde.plasma.kickerdash",
                   "Orbit.Start.Menu", "TahoeLauncher", "DeepinMenu.Classic", "p-connor.plasma-drawer"];
for (const panel of panels()) {
    for (const launcher of panel.widgets()) {
        if (!launchers.includes(launcher.type)) {
            continue;
        }
        launcher.currentConfigGroup = ["General"];
        const custom = String(launcher.readConfig("useCustomButtonImage", "false")) === "true";
        const image = String(launcher.readConfig("customButtonImage", ""));
        if (custom && !oldCustomImages.includes(image)) {
            continue; // the user's own button image
        }
        if (custom) {
            launcher.writeConfig("useCustomButtonImage", false);
        }
        if (custom || defaults.includes(String(launcher.readConfig("icon", "")))) {
            launcher.writeConfig("icon", "mainuan");
        }
    }
}
