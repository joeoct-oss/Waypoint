/*
 *  waypoint.js
 *  Waypoint
 *
 *  Created by Yousef Mohamed <youseef.elserwey@gmail.com>.
 *  Copyright © 2026 Yousef Mohamed. MIT License.
 *
 *  A sun and moon toggle in the navigation bar for the DocC site. It drives DocC's own
 *  color scheme setting (the Light/Dark/Auto picker in the footer, which waypoint.css hides),
 *  so DocC keeps remembering the choice. scripts/build-docs.sh links this file from every page.
 */
(function () {
    "use strict";

    var SUN = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4.2"/>' +
        '<path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.55 1.55M17.15 17.15l1.55 1.55M5.3 18.7l1.55-1.55M17.15 6.85l1.55-1.55"/></svg>';
    var MOON = '<svg viewBox="0 0 24 24" aria-hidden="true">' +
        '<path d="M20.2 14.6A8.3 8.3 0 0 1 9.4 3.8a8.3 8.3 0 1 0 10.8 10.8z"/></svg>';
    var darkQuery = window.matchMedia("(prefers-color-scheme: dark)");

    function currentScheme() {
        var setting = document.body.getAttribute("data-color-scheme") || "auto";

        if (setting === "auto") {
            return darkQuery.matches ? "dark" : "light";
        }

        return setting;
    }

    function choose(scheme) {
        var input = document.querySelector('.color-scheme-toggle input[value="' + scheme + '"]');

        if (input) {
            input.click();
        }
    }

    function render(button) {
        var isDark = currentScheme() === "dark";

        button.innerHTML = '<span class="wp-theme-icon wp-theme-sun">' + SUN + '</span>' +
            '<span class="wp-theme-icon wp-theme-moon">' + MOON + '</span>';
        button.setAttribute("data-scheme", isDark ? "dark" : "light");
        button.setAttribute("aria-label", isDark ? "Switch to light mode" : "Switch to dark mode");
        button.title = button.getAttribute("aria-label");
    }

    function toggle(event) {
        var button = event.currentTarget;
        var next = currentScheme() === "dark" ? "light" : "dark";

        choose(next);
        button.setAttribute("data-scheme", next);
        button.setAttribute("aria-label", next === "dark" ? "Switch to light mode" : "Switch to dark mode");
        button.title = button.getAttribute("aria-label");
    }

    function install() {
        var bar = document.querySelector(".nav-content");

        if (!bar || bar.querySelector(".wp-theme-toggle")) {
            return;
        }

        var button = document.createElement("button");

        button.type = "button";
        button.className = "wp-theme-toggle";
        button.addEventListener("click", toggle);
        render(button);
        bar.insertBefore(button, bar.querySelector(".nav-actions"));
    }

    function refresh() {
        var button = document.querySelector(".wp-theme-toggle");

        if (button) {
            button.setAttribute("data-scheme", currentScheme());
        }
    }

    // DocC renders the page after load and redraws the bar on navigation, so watch for it.
    new MutationObserver(install).observe(document.documentElement, {
        childList: true,
        subtree: true
    });
    darkQuery.addEventListener("change", refresh);
    document.addEventListener("DOMContentLoaded", install);
})();
