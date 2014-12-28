/* Copyright 2014 Nicolas Laplante
*
* This file is part of envelope.
*
* envelope is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* envelope is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with envelope. If not, see http://www.gnu.org/licenses/.
*/

using Envelope.DB;
using Envelope.View;
using Envelope.Service;
using Envelope.Service.Settings;

namespace Envelope.Window {

    public class MainWindow : Gtk.ApplicationWindow {

        private static const uint TRANSITION_DURATION = 100;

        // window elements
        public Gtk.HeaderBar                header_bar { get; private set; }
        public Gtk.Button                   import_button { get; private set; }
        public Gtk.Button                   add_transaction_button { get; private set; }
        public Gtk.SearchEntry              search_entry { get; private set; }
        public Sidebar                      sidebar { get; private set; }
        public Gtk.MenuButton               app_menu { get; private set; }
        public Menu                         settings_menu { get; private set; }
        public Granite.Widgets.OverlayBar   overlay_bar {get; private set; }

        private Granite.Widgets.ThinPaned   paned;
        private Gtk.MenuItem                preferences_menu_item;
        private Gtk.Popover                 menu_popover;
        private Gtk.Overlay                 overlay;

        private Gtk.Revealer                content_revealer;

        // fired when the content view changes
        public signal void main_view_changed (Gtk.Widget main_view);

        public MainWindow () {
            Object ();

            build_ui ();
            connect_signals ();
        }

        /**
         * Show a brief message in the overlay bar for a specified time, then hide it afterwards
         */
        public void show_notification (string text) {
            overlay_bar.hide ();
            overlay_bar.status = text;

            overlay_bar.show ();

            Timeout.add (Envelope.App.TOAST_TIMEOUT, () => {
                overlay_bar.hide ();
                return false;
            });
        }

        private void build_ui () {

            overlay = new Gtk.Overlay ();
            this.add (overlay);

            content_revealer = new Gtk.Revealer ();
            content_revealer.set_transition_duration (TRANSITION_DURATION);
            content_revealer.set_transition_type (Gtk.RevealerTransitionType.CROSSFADE);

            // overlay bar for toast notifitcations
            overlay_bar = new Granite.Widgets.OverlayBar (overlay);

            // Menus
            app_menu = new Gtk.MenuButton ();
            settings_menu = new Menu ();

            preferences_menu_item = new Gtk.MenuItem.with_label ("Preferences");

            var menu_icon = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
            app_menu.set_image (menu_icon);
            settings_menu.append (_("Export..."), null);
            menu_popover = new Gtk.Popover.from_model (app_menu, settings_menu);
            app_menu.popover = menu_popover;

            // main paned widget
            paned = new Granite.Widgets.ThinPaned ();
            paned.position = 250;
            paned.position_set = true;
            //paned.show_all ();
            overlay.add (paned);

            paned.pack2 (content_revealer, true, false);

            // header bar
            header_bar = new Gtk.HeaderBar ();
            header_bar.show_close_button = true;
            set_titlebar (header_bar);
            header_bar.pack_end (app_menu);

            // import button
            import_button = new Gtk.Button.from_icon_name ("document-import", Gtk.IconSize.LARGE_TOOLBAR);
            import_button.tooltip_text = _("Import transactions");
            header_bar.pack_start (import_button);

            // add transaction button
            add_transaction_button = new Gtk.Button.from_icon_name ("document-new", Gtk.IconSize.LARGE_TOOLBAR);
            add_transaction_button.tooltip_text = _("Record transaction");
            header_bar.pack_start (add_transaction_button);

            // search entry & completion
            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Search transactions\u2026");

            var search_entry_completion = new Gtk.EntryCompletion ();
            search_entry_completion.set_model (MerchantStore.get_default ());
            search_entry_completion.set_text_column (MerchantStore.COLUMN);
            search_entry_completion.popup_completion = true;
            search_entry_completion.set_match_func ( (completion, key, iter) => {

                if (key.length == 0) {
                    return false;
                }

                string store_value;
                MerchantStore.get_default ().@get (iter, MerchantStore.COLUMN, out store_value, -1);

                return store_value.up ().index_of (key.up ()) != -1;
            });

            search_entry.completion = search_entry_completion;

            header_bar.pack_end (search_entry);

            header_bar.show_all ();

            // sidebar
            sidebar = Sidebar.get_default ();

            Gee.ArrayList<Account> accounts;

            try {
                accounts = AccountManager.get_default ().get_accounts ();
                sidebar.accounts = accounts;
            }
            catch (ServiceError err) {
                warning ("could not load accounts (%s)".printf (err.message));
                accounts = new Gee.ArrayList<Account> ();
            }

            sidebar.update_view ();

            sidebar.list_account_selected.connect ((account) => {
                Gtk.Widget widget;
                determine_account_content_view (account, out widget);

                Type t = widget.get_type ();

                debug ("view to show: %s".printf (t.name ()));

                if (content_revealer.get_child () != widget) {
                    var current_view = content_revealer.get_child ();
                    current_view.@ref ();
                }

                set_content_view (widget);

                search_entry.placeholder_text = "Search in %s%s".printf (account.number, Envelope.Util.String.ELLIPSIS);
            });

            // If we have accounts, show the transaction view
            // otherwise show welcome screen
            Gtk.Widget content_view;
            determine_initial_content_view (accounts, out content_view);
            //paned.pack2 (content_view, true, false);
            set_content_view (content_view);
            main_view_changed (content_view);

            configure_window ();

            // done! show all
            overlay.show_all ();
            overlay_bar.hide ();
        }

        private void configure_window () {
            // configure window
            width_request = 1200;
            height_request = 800;

            // restore state
            var saved_state = SavedState.get_default ();

            window_position = saved_state.window_position != null ? saved_state.window_position : Gtk.WindowPosition.CENTER;

            if (saved_state.maximized) {
                maximize ();
            }
            else if (saved_state.window_width != null && saved_state.window_height != null) {
                width_request = saved_state.window_width;
                height_request = saved_state.window_height;
            }
        }

        private void connect_signals () {

            destroy.connect (on_quit);

            // connect signals
            AccountWelcomeScreen.get_default ().add_transaction_selected.connect ( (account) => {

                var transaction_view = TransactionView.get_default ();

                set_content_view (transaction_view);
                transaction_view.transactions = account.transactions;
            });

            // handle account renames
            sidebar.list_account_name_updated.connect ( (account, new_name) => {

                Account acct = account as Account;

                if (acct.number != new_name) {

                    try {
                        AccountManager.get_default ().rename_account (ref acct, new_name);
                    }
                    catch (Error err) {
                        if (err is ServiceError.DATABASE_ERROR) {
                            error ("error renaming account (%s)", err.message);
                        }
                        else if (err is AccountError.ALREADY_EXISTS) {
                            // TODO show error
                        }
                    }
                }
            });

            sidebar.overview_selected.connect ( () => {

                var budget_overview = BudgetOverview.get_default ();

                if (content_revealer.get_child () != budget_overview) {
                    set_content_view (budget_overview);
                }
            });

            main_view_changed.connect ( (window, widget) => {
                // check if we need to show the transaction search entry
                if (widget is TransactionView) {

                    import_button.show ();
                    add_transaction_button.show ();
                    search_entry.show ();
                    search_entry.text = ""; // TODO don't overwrite search entry from saved state!

                    // show sidebar if it was not there yet
                    if (paned.get_child1 () == null) {
                        paned.pack1 (Sidebar.get_default (), true, false);
                    }
                }
                else if (widget is AccountWelcomeScreen) {
                    import_button.show ();
                    add_transaction_button.show ();

                    if (paned.get_child1 () == null) {
                        paned.pack1 (Sidebar.get_default (), true, false);
                    }
                }
                else {
                    import_button.hide();
                    add_transaction_button.hide ();
                    search_entry.hide ();
                    search_entry.text = "";
                }
            });

            search_entry.search_changed.connect ( (entry) => {
                debug ("search changed to %s".printf (entry.text));
                TransactionView.get_default ().set_search_filter (entry.text);
            });

            import_button.clicked.connect ( () => {
                TransactionView.get_default ().show_import_dialog ();
            });

            add_transaction_button.clicked.connect ( () => {
                TransactionView.get_default ().add_transaction_row ();

                var child = content_revealer.get_child ();

                if (!(child is TransactionView)) {
                    set_content_view (TransactionView.get_default ());
                }
            });

            AccountManager.get_default ().transaction_recorded.connect ( () => {
                Envelope.App.toast (_("Transaction recorded"));
            });
        }

        private void determine_initial_content_view (Gee.ArrayList<Account> accounts, out Gtk.Widget widget) {
            if (accounts.size > 0) {
                widget = BudgetOverview.get_default ();
            }
            else {
                widget = Welcome.get_default ();
            }

            if (widget != Welcome.get_default ()) {
                if (paned.get_child1 () == null) {
                    paned.pack1 (sidebar, true, false);
                }
            }
            else {
                search_entry.hide ();
                import_button.hide ();
                add_transaction_button.hide ();
            }
        }

        private void determine_account_content_view (Account account, out Gtk.Widget widget) {

            try {
                var transactions = AccountManager.get_default ().load_account_transactions (account);
                account.transactions = transactions;

                if (transactions.size == 0) {
                    widget = AccountWelcomeScreen.get_default ();
                    (widget as AccountWelcomeScreen).account = account;
                }
                else {
                    widget = TransactionView.get_default ();
                    (widget as TransactionView).transactions = account.transactions;
                }
            }
            catch (ServiceError err) {
                error ("could not load account transactions (%s)", err.message);
            }
        }

        private void on_quit () {
            save_settings ();
        }

        private void restore_settings () {
            var saved_state = SavedState.get_default ();

        }

        private void save_settings () {
            var saved_state = SavedState.get_default ();

            // get window dimensions
            int height;
            int width;

            get_size (out width, out height);

            saved_state.window_height = height;
            saved_state.window_width = width;
            saved_state.maximized = get_window ().get_state () == Gdk.WindowState.MAXIMIZED;

            // sidebar width
            saved_state.sidebar_width = paned.get_position ();

            // search
            saved_state.search_term = search_entry.text;
        }

        private void set_content_view (Gtk.Widget widget) {

            if (content_revealer.child_revealed) {

                content_revealer.reveal_child = false;

                Timeout.add (TRANSITION_DURATION, () => {
                    reveal_view (widget);
                    return false;
                });
            }
            else {
                reveal_view (widget);
            }
        }

        private void reveal_view (Gtk.Widget widget) {
            var child = content_revealer.get_child ();

            if (child != null) {

                content_revealer.remove (child);

                if (child != widget) {
                    child.@ref ();
                }
            }

            content_revealer.add (widget);

            widget.show ();

            content_revealer.reveal_child = true;

            main_view_changed (widget);
        }
    }
}
