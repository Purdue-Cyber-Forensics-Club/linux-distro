/* exported init, buildPrefsWidget */

const Lang = imports.lang;

const Gtk = imports.gi.Gtk;

const ExtensionUtils = imports.misc.extensionUtils;
const Me = ExtensionUtils.getCurrentExtension();
const Convenience = Me.imports.convenience;

function init() { }

function buildPrefsWidget() {
    this._settings = Convenience.getSettings();

    let widget = new Gtk.Box({
        orientation: Gtk.Orientation.VERTICAL,
        margin_left: 20,
        margin_top: 20
    });

    let hbox = new Gtk.Box({ margin_bottom: 5 });
    hbox.add(new Gtk.Label({ label: 'Icon Mode' }));

    let combo = new Gtk.ComboBoxText({ margin_left: 5 });
    // TODO: Do I need to include this?
    // box.append('Symbolic', 'Symbolic');
    combo.append('Regular', 'Regular');
    combo.append('Request', 'Request');

    let mode = this._settings.get_string('icon-mode');

    combo.set_active_id(mode);
    combo.connect('changed', Lang.bind(this, function () {
        let mode = combo.get_active_id();
        this._settings.set_string('icon-mode', mode);
    }));

    hbox.add(combo);

    widget.add(hbox);

    let label = new Gtk.Label({
        label: 'Apply to...',
        halign: Gtk.Align.START,
        hexpand: false,
        margin_bottom: 5
    });

    widget.add(label);

    let app_menu_check = new Gtk.CheckButton({
        label: 'App Menu',
        margin_left: 5
    });

    let app_menu = this._settings.get_boolean('app-menu');

    app_menu_check.set_active(app_menu);
    app_menu_check.connect('toggled', Lang.bind(this, function (button) {
        let active = button.get_active();
        this._settings.set_boolean('app-menu', active);
    }));

    widget.add(app_menu_check);

    let notifications_check = new Gtk.CheckButton({
        label: 'Notifications',
        margin_left: 5
    });

    let notifications = this._settings.get_boolean('notifications');

    notifications_check.set_active(notifications);
    notifications_check.connect('toggled', Lang.bind(this, function (button) {
        let active = button.get_active();
        this._settings.set_boolean('notifications', active);
    }));

    widget.add(notifications_check);
    widget.show_all();

    return widget;
}