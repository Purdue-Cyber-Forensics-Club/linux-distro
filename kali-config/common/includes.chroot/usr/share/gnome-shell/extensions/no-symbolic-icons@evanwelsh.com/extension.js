/* exported init, enable, disable */

const Lang = imports.lang;

const Me = imports.misc.extensionUtils.getCurrentExtension();
const Convenience = Me.imports.convenience;

const Main = imports.ui.main;
const MessageList = imports.ui.messageList;

const IconMode = {
    SYMBOLIC: { value: 0, name: 'Symbolic', css: 'icon-mode-symbolic' },
    REGULAR: { value: 1, name: 'Regular', css: 'icon-mode-regular' },
    /* Not used for now... but maybe in the future. */
    REQUEST: { value: 2, name: 'Request', css: 'icon-mode-request' }
};
Object.freeze(IconMode);

const ORIG_Message_init = MessageList.Message.prototype._init;


function init() { /* We don't need to init anything */ }

function enable() {
    this.settings = Convenience.getSettings();

    if (this.settings.get_boolean('app-menu')) {
        modify_app_menu();
    }

    if (this.settings.get_boolean('notifications')) {
        inject_notification_icon_mode();
    }

    this._iconModeChangedSig = this.settings.connect('changed::icon-mode', Lang.bind(this, function () {
        unmodify_app_menu();

        if (this.settings.get_boolean('app-menu')) {
            modify_app_menu();
        }

        if (this.settings.get_boolean('notifications')) {
            update_notification_icon_mode();
        }
    }));

    this._notificationsChangedSig = this.settings.connect('changed::notifications', Lang.bind(this, function () {
        remove_notification_icon_mode();

        if (this.settings.get_boolean('notifications')) {
            inject_notification_icon_mode();
        }
    }));

    this._appMenuChangedSig = this.settings.connect('changed::app-menu', Lang.bind(this, function () {
        unmodify_app_menu();

        if (this.settings.get_boolean('app-menu')) {
            modify_app_menu();
        }
    }));
}

function disable() {
    this.settings.disconnect(this._iconModeChangedSig);
    this.settings.disconnect(this._notificationsChangedSig);
    this.settings.disconnect(this._appMenuChangedSig);
    this.settings = null;

    remove_notification_icon_mode();
    unmodify_app_menu();
}

function update_notification_icon_mode() {
    let icon_mode_name = this.settings.get_string('icon-mode');
    let icon_mode = null;

    for (let mode of Object.keys(IconMode)) {
        if (IconMode[mode].name === icon_mode_name) {
            icon_mode = IconMode[mode];
        }
    }

    MessageList.Message._nsi_mode = icon_mode;
}

function inject_notification_icon_mode() {
    update_notification_icon_mode();

    MessageList.Message.prototype._init = function (title, body) {
        ORIG_Message_init.call(this, title, body);

        if (typeof (MessageList.Message._nsi_mode) !== 'undefined' && MessageList.Message._nsi_mode !== null) {
            this._iconBin.add_style_class_name(MessageList.Message._nsi_mode.css);
        }
    };
}

function remove_notification_icon_mode() {
    MessageList.Message._init = ORIG_Message_init;

    delete MessageList.Message._nsi_mode;
}

function modify_app_menu() {
    let icon_mode_name = this.settings.get_string('icon-mode');
    let icon_mode = null;

    let icon_box = Main.panel.statusArea.appMenu._iconBox;

    for (let mode of Object.keys(IconMode)) {
        if (IconMode[mode].name === icon_mode_name) {
            icon_mode = IconMode[mode];
        }
    }

    /* Make sure _iconBox exists... */
    if (typeof icon_box !== 'undefined' && icon_box !== null && icon_mode !== null) {
        /* Style it. */
        icon_box.add_style_class_name(icon_mode.css);
    }
}

function unmodify_app_menu() {
    /* Set it back to the Gnome Shell default. */
    let icon_box = Main.panel.statusArea.appMenu._iconBox;

    /* Make sure _iconBox exists... */
    if (typeof icon_box !== 'undefined' && icon_box !== null) {
        /* Remove any styles. */
        for (let mode of Object.keys(IconMode)) {
            let css = IconMode[mode].css;
            icon_box.remove_style_class_name(css);
        }
    }
}